#!powershell

<#
 Copyright: (c) 2019, Harry Saryan  <hs-hub-world@github>
 GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

 Ansible module to search for a string in a file, something simple compared to win_lineinfile module
 NOTE: this module does not make modifications, hence check_mode is not used
#>

#Requires -Module Ansible.ModuleUtils.Legacy
#

#$WarningPreference    = 'SilentlyContinue'
$ErrorActionPreference = "Stop"
$params                = Parse-Args $args -supports_check_mode $true
#$check_mode           = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -type "bool" -default $false
$path                  = Get-AnsibleParam -obj $params -name "path" -type "list" -failifempty $true
$string                = Get-AnsibleParam -obj $params -name "String" -type "str"  -failifempty $true
$filefilter            = Get-AnsibleParam -obj $params -name "filefilter" -type "str" -default "*.*"  #required when $path is a folder
$FailPathNotFound      = Get-AnsibleParam -obj $params -name "filefilter" -type "bool"  -default $true

$msg = @();
$configchanged=$false
$Matched=$false

$matchedfiles=@()
foreach($item in $path)
{
    if(test-path "$item")
    {
        try {
        $searchItem = Get-Item "$item"
        #$msg +=""
        if ( -not $searchItem.PSIsContainer)
        {
            #Item is a file...
            If (Get-Content "$searchItem" | ?{$_ -match "$string"}) 
            {
                $Matched=$true
                $matchedfiles +=$searchItem.FullName
            }
        }
        else 
        {
            #Item is a folder and we'll be searching for all files in the folder
            foreach($file in (Get-ChildItem "$item" |?{$_.name -like "$filefilter"}))
            {
                if ( -not $file.PSIsContainer)
                {
                    #Item is a file...
                    $msg +="Reading file:$($file)"
                    If (Get-Content "$($file.FullName)" | ?{$_ -match "$string"})
                    {
                        $Matched=$true
                        $matchedfiles +=$file.FullName
                    }
                }
            }

        }
        }
        catch {
            throw "Error during file string search: $($_.Exception.Message)"    
        }
    }
    else {
        $msg = $_.exception.message
        if($FailPathNotFound)
        {
            throw "Error path not found: $($item) $($_.exception.message)"
        }
    }

    
}


$result = @{
  matched       = $Matched
  matchedfiles  = $matchedfiles
  path          = $path
  string        = $string
  filefilter    = $filefilter
  message       = $msg
  configchanged = $configchanged
  msg           = $msg
}

Exit-Json $result