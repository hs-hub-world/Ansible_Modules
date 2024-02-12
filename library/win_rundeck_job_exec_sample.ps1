#!powershell

<#
 Copyright: (c) 2019, Harry Saryan  <hs-hub-world@github>
 GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

 Ansible module to search for a string in a file, something simple compared to win_lineinfile module
 NOTE: this module does not make modifications, hence check_mode is not used

 Note: By setting RemoveDupRecords to True this is what will happen:
  - if the SPN is missing from the SVC Account it will try to add the SVC acme_account
  - if the same SPN is found in another SVC account it will be Removed from the other SVC acme_account and the SPN will be assigned to the selected SVC acme_account
  - by leaving RemoveDupRecord=False will cause Playbook to fail and will require user intervention.
#>

#Requires -Module Ansible.ModuleUtils.Legacy
#

$ErrorActionPreference = "Stop"
$params                = Parse-Args $args -supports_check_mode $true
$check_mode           = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -type "bool" -default $false
$spn                  = Get-AnsibleParam -obj $params -name "spn" -type "list" -failifempty $true
$State                = Get-AnsibleParam -obj $params -name "state" -type "str"  -failifempty $true 
$svcacct              = Get-AnsibleParam -obj $params -name "svcacct" -type "str" -failifempty $true
$RemoveDupRecords     = Get-AnsibleParam -obj $params -name "removeduprecords" -type "bool"   -default $false #This will remove existing SPN records from AD then re-add to the new acct. this is usefull when switching spn's between accounts


try {
    #initialize hash
    $Params =@{}
    $option =@{}

    #Add options values
    $option.spn = @($spn)
    $option.state="$State"
    $option.svcacct="$svcacct"
    $option.RemoveDupRecords="$RemoveDupRecords"
    $option.WhatIf = "$check_mode"
    
    #$option.username='Rdecksvc_server'

    #Add properties to Params and associated OPS to options property
    #$Params.loglevel='DEBUG'
    $Params.options = $option


    #Invoke rundeck jobs
    $RundeckURL = "http://rundeck:4440/api/30"
    $jobID      = "<rundeck-job-id>"
    $APIToken   = "<rundeck Api Token>"

    #write "URL:"
    #write "URL:$($RundeckURL)/job/$($jobID)/run?authtoken=$($APIToken)"

    $jobstat= Invoke-RestMethod -uri "$($RundeckURL)/job/$($jobID)/run?authtoken=$($APIToken)" -Method Post -Body ($Params |ConvertTo-Json -Compress) -ContentType 'application/json'
    $NewJobID = $jobstat.executions.execution.id

    $url = "$($RundeckURL)/job/$($jobID)/executions?authtoken=$($APIToken)"
    $Timeout = 120

    do
    {
        $RunningJob = (Invoke-RestMethod -uri $url  -Method get -ContentType 'application/json').executions.execution |?{$_.id -eq "$($NewJobID)"}
        #write "Job Running ..."
        sleep -Seconds 1
        $Timeout--;
    }while($RunningJob.status -eq "running" -and $Timeout -gt 0)

    #Output results
    #Ensure results in Ansible format! 
    (Invoke-RestMethod -uri "$($RundeckURL)/execution/$($NewJobID)/output/step?authtoken=$($APIToken)" -Method get -ContentType 'application/json').output.entries.entry.log

    if($RunningJob.state -eq "failed")
    {
        write "Job Failed, please review logs"
    }
    #$output = (Invoke-RestMethod -uri "$($RundeckURL)/execution/$($NewJobID)/output/step?authtoken=$($APIToken)" -Method get -ContentType 'application/json').output.entries.entry.log    
    #$output
}
catch {
    throw "Rundeck exec Error:$($_.Exception.Message)"    
}
