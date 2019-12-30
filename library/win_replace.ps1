#!powershell

# Copyright: (c) 2019, Harry Saryan  <hs-hub-world@github>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#!powershell
#Requires -Module Ansible.ModuleUtils.Legacy
#

$ErrorActionPreference = "Stop"
$params  = Parse-Args $args -supports_check_mode $true
$path    = Get-AnsibleParam -obj $params -name "path" -type "str" -failifempty $true
$findstring  = Get-AnsibleParam -obj $params -name "findstring" -type "str" -failifempty $true
$replace = Get-AnsibleParam -obj $params -name "replace" -type "str" -failifempty $true

$msg = "";
$configchanged=$false

#if any match found execute replace to optimize/save select -first 1
if(Get-Content "$path" |Select-String "$($findstring)" |select -First 1)
{
  $matchcount= (Get-Content "$path" |Select-String "$($findstring)" ).count
  (Get-Content "$path") -replace "$findstring",$replace |Out-File "$path" -Force
  $msg +="Replaced $($matchcount) strings"
  $configchanged=$true
}

$result = @{
  matchcount = $matchcount
  findstring = $findstring
  replace    = $replace
  path       = $path
  changed    = $configchanged
  message    = $msg
}
Exit-Json $result