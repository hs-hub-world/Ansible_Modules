#!powershell

# Copyright: (c) 2020, Harry Saryan  <hs-hub-world@github>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)
#Requires -Module Ansible.ModuleUtils.Legacy

<#
    Note:
        When hash is generated very first time a change will not be triggered (change=false). Subsequent executions will compare file hash to detect changes
        This module can be used for various register/trigger purposes to save time with other modules. For example this module can be used with choco package manager to detect repair/reinstall.
        Since choco by design does not detect file changes and reinstall always returns a change and it slows down the process this module can save huge time
        by detecting changes and trigger choco reinstall accordingly by restoring files back to their original state(s).

    Params:
    - Path  is the src path where files will be parsed and hash will be generated for each file
    - hashfilepath is optional, is the path where the actual hashes will be stored. this is auto generated
    - hashfileName is optional, is the file name where the actual hashes will be stored. this is auto generated
    - FilestoExclude is optiona, it's a list where you can define files to be excluded from being monitoried for changes
    - FilesToInclude takes precedence over filestoexclude, this will include monitor specific files only.
    - reset is boolean can be used to trigger a reset/regenerate hash file without triggering a change.
#>



$ErrorActionPreference = "Stop"
$params                = Parse-Args $args -supports_check_mode $true
$Path                  = Get-AnsibleParam -obj $params -name "path" -type "list" -failifempty $true
#$hashfilepath          = Get-AnsibleParam -obj $params -name "hashfilepath" -type "str"
$hashfileName          = Get-AnsibleParam -obj $params -name "hashfilename" -type "str" -default ".ans_hash"
$FilestoExclude        = Get-AnsibleParam -obj $params -name "FilestoExclude" -type "list" -default ""
$FilesToInclude        = Get-AnsibleParam -obj $params -name "FilesToInclude" -type "list" -default "*.*"
$reset                 = Get-AnsibleParam -obj $params -name "reset" -type "bool"


$msg              = @();
$configchanged    = $false
$hashmatches      = $false
$ChangedFiles     = @()
$pathMissing      = $false
$hashfileexists   = $false
$NewHashGenerated = $false
$hashfiles=@()
$pathsize = 0;  #The combined size of all the paths...


#PSRS Function
########################
$HashJobScript={
    param(
        $JobParams
    )
    $Res=@{}

    try 
    {
        $HashString = (($JobParams.LineHash -split("File:"))[1].Split("|"))
        $FilePath = $HashString[0]

        if(test-path -Path "$FilePath")
        {
            #$Res.msg ="Path Valid $($HashString[0])"
            $OrigHash = ("$($HashString[1])" -split(":"))[1]
            if((Get-FileHash -LiteralPath "$($HashString[0])" -Algorithm SHA1).Hash -ne "$OrigHash")
            {
                $Res.configchanged = $true
                $Res.msg =" File changed: $($HashString[0])"
                $Res.ChangedFiles = $HashString[0]
                #break;
            }
        }
        else {
            #$Res.msg ="Path NOT Valid"
            $Res.configchanged=$true
            $Res.msg =" File changed[missing]: $($HashString[0])"
            $Res.ChangedFiles =$HashString[0]
            #break;
        }
    }
    catch {
        $Res.msg ="Error: Failed for line item:$($LineHash) $($_.Exception.Message)"
        #Throw "Hash compare failed for line item:$($LineHash)"
    }
    ##############
    #$Res.configchanged=$true
    return $Res
}

function fn_WaitForPSJObs
{
    param($WaitJobParams)

    #Wait for the jobs to finish
    ##############################
    while( $($WaitJobParams.jobs.PSJOB |?{[string]$_.IsCompleted -eq "False"}).count -gt 0)
    {
        #Terminate expired jobs
        $ExpiredJobs = $WaitJobParams.jobs | ? {[string]$_.PSJOB.isCompleted -eq "False" -and $($(New-TimeSpan -Start $_.StartTime -end (Get-date)).Minutes -gt $WaitJobParams.JobTimeoutMin) }
        if($ExpiredJobs)
        {
            $ExpiredJobs |%{
                $ExpiredJOb = $_.JobName
                $script:jobResults += @{"Timeout"="WARNING: Job exceeded allowed time:$($ExpiredJOb)"}
                $_.PS.Dispose();
                $WaitJobParams.jobs = $WaitJobParams.jobs |?{$_.JobName -ne $ExpiredJOb}; #Remove expired from from JObs array list
            }   
        }
        #sleep 1
    }
    ##return $WaitJobParams
}

#Use PS Parallel/Runspace execution to save time
#INIT PS RS
####################################################
# $JobTimeoutMin = 1;
# $jobs=@();
# $jobResults =@()
# $i=0;
#Init PS RS
# $RSpool = [RunspaceFactory]::CreateRunspacePool(1, [int]$env:NUMBER_OF_PROCESSORS * 4)
# $RSpool.open();


foreach($Pitem in $Path)
{
    try {
        if(test-path -Path "$Pitem")
        {
            
            #if(!$hashfilepath)
            #{
            $hashfilepath ="$($Pitem)\$($hashfileName)"
            #}

            if($reset)
            {
                $msg +="Doing Reset."
                if(test-path -Path "$hashfilepath")
                {
                    try {
                        Remove-Item -LiteralPath "$hashfilepath" -Force -Confirm:$false
                    }
                    catch {
                        $msg +="Reset failed, trying to delete $($hashfilepath)"
                        Throw "Reset failed, trying to delete $($hashfilepath)"
                    }
                }
            }

            try {
                ##############
                #READ FILES
                ###############
                #$Files  = Get-ChildItem -Recurse -Path "$Pitem" -Include $FilesToInclude -Exclude $FilestoExclude
                $Files = [System.IO.Directory]::EnumerateFiles("$Pitem","$FilesToInclude","AllDirectories")
                $Files = $Files |?{$_ -notmatch [regex]::Escape("$hashfilepath")}  #Exclude .anshash file.
                
                if($FilestoExclude)
                {
                    foreach($exclusion in $FilestoExclude)
                    {
                        $Files = $Files |?{$_ -notmatch [regex]::Escape("$exclusion")}  #Apply Exclude 
                    }
                }


                $pathsize = ($Files | Measure-Object -Property Length -Sum -ErrorAction Stop).sum
            }
            catch {
                $msg +="Error trying to read "
                throw "Error trying to read:$($_.Exception.Message)"
            }

            if(!(test-path -Path "$hashfilepath"))
            {
                $msg +="Hash not found, generating new hash file"
                #Config should NOT be changed when generating hash very first time...
                #Generate hash.
                try {
                    ##############
                    #GENERATE HASH
                    ###############
                    #$Files |Where-Object{Test-path -LiteralPath $_ -PathType Leaf} | ForEach-Object{Write-Output "File:$($_)|Hash:$($(Get-FileHash -LiteralPath $_ -Algorithm SHA1).hash)"}|Out-File  "$hashfilepath" -Append
                    #$Files | ForEach-Object{Write-Output "File:$($_)|Hash:$($(Get-FileHash -LiteralPath $_ -Algorithm SHA1).hash)"}|Out-File  "$hashfilepath" -Append
                    $Content = @($Files |  ForEach-Object{Write "File:$($_)|Hash:$($(Get-FileHash -LiteralPath $_ -Algorithm SHA1).hash)"})
                    $Content |Out-File  "$hashfilepath"
                    $HashGenTime = (get-item -LiteralPath "$hashfilepath").CreationTime.ToString("MM/dd/yyyy HH:mm:ss.fff")
                    $NewHashGenerated = $true
                }
                catch {
                    throw "Error when generating new hash file:$($_.Exception.Message)"
                }
            }
            else {

                $hashfileexists   = $true
                $HashGenTime      = (get-item -LiteralPath "$hashfilepath").CreationTime.ToString("MM/dd/yyyy HH:mm:ss.fff")
                
                #Hash exists, do compare
                #Config should be considered changed when existing hash does not match...
                $msg +="Hash file found, doing compare"
                #$hashContent = @(Get-Content -LiteralPath "$hashfilepath")
                $hashContent = [IO.File]::ReadAllLines("$hashfilepath")

                #$FilesProcessed=@()
                foreach($LineHash in $hashContent)
                {

                    # $stLine = $LineHash            
                    # $JobParams=@{}
                    # $PSJobs=@{}    #Runspace Jobs will be stored in this object
                    # #$FilesProcessed +=$LineHash
                    # $JobParams.LineHash = "$stLine";
                    # $jobName = "Job:$($i++)"

                    # [PowerShell]$PSJobs.PS = [PowerShell]::Create()            
                    # $PSJobs.PS.AddScript($HashJobScript)   |Out-Null
                    # $PSJobs.PS.AddArgument($JobParams)     |Out-Null
                    # $PSJobs.JobName = $jobName
                    # $PSJobs.PS.RunspacePool = $RSpool
                    # $PSJobs.StartTime = get-date
                    
                    # #Invoke the job
                    # $PSJobs.PSJOB = $PSJobs.PS.BeginInvoke()
                    # $jobs += $PSjobs


                     try 
                    {
                        $HashString = (($LineHash -split("File:"))[1].Split("|"))
                        $FilePath = $HashString[0]

                        if(test-path -Path "$FilePath")
                        {
                            
                            $OrigHash = ("$($HashString[1])" -split(":"))[1]
                            if((Get-FileHash -LiteralPath "$($HashString[0])" -Algorithm SHA1).Hash -ne "$OrigHash")
                            {
                                $configchanged = $true
                                $msg +="File changed: $($HashString[0])"
                                $ChangedFiles += $HashString[0]
                                #break;
                            }
                        }
                        else {
                            #$Res.msg ="Path NOT Valid"
                            $configchanged=$true
                            $msg +=" File changed[missing]: $($HashString[0])"
                            $ChangedFiles +=$HashString[0]
                            #break;
                        }
                    }
                    catch {
                        $msg +="Error: Failed for line item:$($LineHash) $($_.Exception.Message)"
                        #Throw "Hash compare failed for line item:$($LineHash)"
                    }
                } 
            }
        }
        else {
            $pathMissing = $true
            $msg +=" Path not found:$($Pitem)"
            $configchanged = $true;  #return change to trigger necessary event to install/create the path
            #$hashmatches = $false  #ignore -?
        }

    }
    catch {
        ##ignore -?
    }
    $hashfiles +=$hashfilepath
}


# if($RSpool)
# {
#     try {

#         $WaitJobParams=@{}
#         $WaitJobParams.jobs = $jobs
#         $WaitJobParams.JobTimeoutMin = $JobTimeoutMin
#         fn_WaitForPSJObs -WaitJobParams $WaitJobParams
        
#         #Capture output and Cleanup runspace
#         foreach($job in $jobs)
#         {
#             $jobResults +=$job.PS.EndInvoke($job.PSJOB)
#         }
#         $ChangedFiles = @($jobResults.ChangedFiles)  #Get changed Files
#         $configchanged = $jobResults.ConfigChanged -contains $true  #Entry true from job result = Changed
#         $msg += @($jobResults.msg)  

#         $RSpool.close()
#         $RSpool.Dispose();    
#     }
#     catch {
        
#     }    
# }

if(!$pathsize -or $pathsize -eq 0 -or $pathsize -eq $null)
{
    #folder is empty
    $hashmatches=$false
    $configchanged = $true
}
else {
    $hashmatches = ($configchanged -eq $false)    
}


$result = @{
  pathsize          = $pathsize
  path             = $path
  hashgentime      = $hashgentime
  filestoexclude   = $filestoexclude
  filestoinclude   = $filestoinclude
  newhashgenerated = $newhashgenerated
  hashfiles        = $hashfiles
  hashfileexists   = $hashfileexists
  pathmissing      = $pathmissing
  changed          = $configchanged
  hashmatches      = $hashmatches
  changedfiles     = $changedfiles
  message          = $msg
  #jobResults       = $jobResults
}
Exit-Json $result

