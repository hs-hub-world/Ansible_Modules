#!powershell

# Copyright: (c) 2019, Harry Saryan  <hs-hub-world@github>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.Legacy
#


$ErrorActionPreference = "Stop"
$params                 = Parse-Args $args -supports_check_mode $true
$Sitename               = Get-AnsibleParam -obj $params -name "sitename" -type "str" -failifempty $true
$AnonymouseAuth         = Get-AnsibleParam -obj $params -name "anonymouseauth" -type "bool"
$AspNetImpersonation    = Get-AnsibleParam -obj $params -name "aspnetimpersonation" -type "bool"
$BasicAuth              = Get-AnsibleParam -obj $params -name "basicauth" -type "bool"
$WinAuth                = Get-AnsibleParam -obj $params -name "winauth" -type "bool"
$WinAuthProviders       = Get-AnsibleParam -obj $params -name "winauthproviders" -type "list"
$DigestAuth             = Get-AnsibleParam -obj $params -name "digestauth" -type "bool"
$DigestRealm            = Get-AnsibleParam -obj $params -name "digestrealm" -type "str" -default ""


#Note: If the auth type is not installed/avail it still works...
#$WarningPreference = 'SilentlyContinue'
$msg = "";
$configchanged=$false

try {
    Import-Module WebAdministration
}
catch {
    throw "Failed to Load WebAdmin Module $($_.exception.message)"
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

#AnonymousAuth
#######################
if($(Get-WebConfigurationProperty -Filter /system.webServer/security/authentication/anonymousAuthentication -Name Enabled -PSPath "MACHINE/WEBROOT/APPHOST/$($Sitename)").value -ne $AnonymouseAuth)
{
    $section ="/system.webServer/security/authentication/anonymousAuthentication"
    UnlockConfigSection -Sitename "$Sitename" -section "$section"
    Set-WebConfigurationProperty -Filter "$section" -Name Enabled -Value $AnonymouseAuth -PSPath "MACHINE/WEBROOT/APPHOST/$($Sitename)"
    $msg +="Anonymouse Value Changed"
    $configchanged=$true
}


#WinAuth
#################
if($(Get-WebConfigurationProperty -Filter /system.webServer/security/authentication/windowsAuthentication -Name enabled -PSPath "MACHINE/WEBROOT/APPHOST/$($Sitename)").value -ne $WinAuth)
{
    $section ="/system.webServer/security/authentication/windowsAuthentication"
    UnlockConfigSection -Sitename "$Sitename" -section "$section"
    Set-WebConfigurationProperty -Filter "$section" -Name Enabled -Value $WinAuth -PSPath "MACHINE/WEBROOT/APPHOST/$($Sitename)"
    $msg +="WinAuth Value Changed"
    $configchanged=$true
}

#WinAuth Providers
###############
$Proviers = (get-WebConfiguration -Filter system.webServer/security/authentication/windowsAuthentication/providers -PSPath IIS:\ -Location "$Sitename").collection |?{$_.value -ne ""}    
if(Compare-Object $Proviers.value $WinAuthProviders)
{
    $msg +=" WinAuth Providers Changed: Resetting "
    Remove-WebConfigurationProperty -PSPath IIS:\ -Location "$Sitename" -filter system.webServer/security/authentication/windowsAuthentication/providers -name "."
    foreach($Provider in $WinAuthProviders)
    {
        $msg +=" Setting Provider: $($Provider) "
        Add-WebConfiguration -Filter system.webServer/security/authentication/windowsAuthentication/providers -PSPath IIS:\ -Location "$Sitename" -Value "$Provider"
    }
    $configchanged=$true
}


#BasicAuth
###########
if($(Get-WebConfigurationProperty -Filter /system.webServer/security/authentication/basicAuthentication -Name Enabled -PSPath iis:\  -location "$Sitename").value -ne $BasicAuth)
{
    $section = "/system.webServer/security/authentication/basicAuthentication"
    UnlockConfigSection -Sitename "$Sitename" -section "$section"
    Set-WebConfigurationProperty -Filter "$section" -Name Enabled -Value $BasicAuth -PSPath iis:\  -location "$Sitename"
    $msg +="BasicAuth Value Changed"
    $configchanged=$true
}


#AspNetImpersonation
####################
if($(Get-WebConfigurationProperty -filter system.web/identity -name impersonate -PSPath IIS: -Location "$Sitename").value -ne $AspNetImpersonation)
{
    
    Set-WebConfigurationProperty -filter system.web/identity -name impersonate -value $AspNetImpersonation -PSPath IIS: -Location "$Sitename"
    $msg +="AspNetImpersonation Value Changed"
    $configchanged=$true
}

#DigestAuth
#TODO 
###########
if($(Get-WebConfigurationProperty -Filter /system.webServer/security/authentication/digestAuthentication -Name Enabled -PSPath iis:\  -location "$Sitename").value -ne $DigestAuth)
{
    Set-WebConfigurationProperty -Filter /system.webServer/security/authentication/digestAuthentication -Name Enabled -Value $DigestAuth -PSPath iis:\  -location "$Sitename"
    $msg +="DigestAuth Value Changed"
    $configchanged=$true
}

#if DigestAuth is enabled ensure Realm value is up to date
#DigetRealm
if($(Get-WebConfigurationProperty -Filter /system.webServer/security/authentication/digestAuthentication -Name Enabled -PSPath iis:\  -location "$Sitename").value -eq $true)
{
    if((Get-WebConfigurationProperty -Filter /system.webServer/security/authentication/digestAuthentication -Name * -PSPath iis:\  -location "$Sitename").realm -ne $DigestRealm)
    {
        Set-WebConfigurationProperty -Filter /system.webServer/security/authentication/digestAuthentication -Name realm -Value $DigestRealm -PSPath iis:\  -location "$Sitename"
        $msg +="DigetRealm Value Changed"
        $configchanged=$true
    }
}


$result = @{
  sitename              = $Sitename
  anonymouseauth        = $AnonymouseAuth
  AspNetImpersonation   = $AspNetImpersonation
  BasicAuth             = $BasicAuth
  WinAuth               = $WinAuth
  WinAuthProviders      = $WinAuthProviders -join(",")
  DigestAuth            = $DigestAuth
  DigestRealm           = $DigestRealm
  changed               = $configchanged  #TODO
  message               = $msg
}
Exit-Json $result

