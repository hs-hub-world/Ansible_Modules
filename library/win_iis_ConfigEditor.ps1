# Copyright: (c) 2020, Harry Saryan  <hs-hub-world@github>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)


#!powershell
#Requires -Module Ansible.ModuleUtils.Legacy
#

$ErrorActionPreference  = "Stop"
$params                 = Parse-Args $args -supports_check_mode $true
$Sitename               = Get-AnsibleParam -obj $params -name "sitename" -type "str" -failifempty $true
$ConfigSectionPath      = Get-AnsibleParam -obj $params -name "configsectionpath" -type "str" -failifempty $true
$ConfigSectionField     = Get-AnsibleParam -obj $params -name "configsectionfield" -type "str" -failifempty $true
$ConfigSectionValue     = Get-AnsibleParam -obj $params -name "configsectionvalue" -type "str" -failifempty $true


$msg = @();
$configchanged=$false



try {
    Import-Module WebAdministration
}
catch {
    Fail-Json -obj $result -message "Failed to Load WebAdmin Module $($_.exception.message)"
    
}

function UnlockConfigSection
{
    param($Sitename,$section)
    if($section -match '^/')
    {
        $section = $section.substring(1)
    }
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Web.Administration")
    $oIIS = new-object Microsoft.Web.Administration.ServerManager
    $oGlobalConfig = $oIIS.GetApplicationHostConfiguration()
    $oConfig = $oGlobalConfig.GetSection("$section", "$Sitename")
    $oConfig.OverrideMode="Allow"
    $oIIS.CommitChanges()
}

#TODO
#NOTE this only works with a single filed prop/value. it does not work with list value
#
#######################
if($(Get-WebConfigurationProperty -Filter "$ConfigSectionPath" -Name "$ConfigSectionField" -PSPath "MACHINE/WEBROOT/APPHOST/$($Sitename)").value -ne $ConfigSectionValue)
{
    UnlockConfigSection -Sitename "$Sitename" -section "$ConfigSectionPath"
    #Set-WebConfigurationProperty -Filter "$ConfigSectionPath" -Name "$ConfigSectionField" -PSPath "iis:\sites\"  -location "$Sitename" -Value $ConfigSectionValue
    Set-WebConfigurationProperty -Filter "$ConfigSectionPath" -Name "$ConfigSectionField" -Value $ConfigSectionValue -PSPath "MACHINE/WEBROOT/APPHOST/$($Sitename)"
    $msg +="$($ConfigSectionPath)/$($ConfigSectionField) Changed:$($ConfigSectionValue) "
    $configchanged=$true
}

$result = @{
  ConfigSectionPath  = $ConfigSectionPath
  ConfigSectionField = $ConfigSectionField
  ConfigSectionValue = $ConfigSectionValue
  changed            = $configchanged
  message            = $msg
}
Exit-Json -obj $result 




