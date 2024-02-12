#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2019, Harry Saryan  <hs-hub-world@github>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

ANSIBLE_METADATA = {'metadata_version': '1.1',
                    'status': ['preview'],
                    'supported_by': 'community'}

DOCUMENTATION = r'''
---
module: win_iis_ConfigEditor
version_added: "1.1"
short_description: apply IIS specific configuration value
description:
     - Configure IIS site configuration value
options:
  Sitename:
    description:
      - Site name to update (i.e. My Site)
    type: str
    required: yes
  ConfigSectionPath:
    description:
      - IIS Config Section Path to update
      - Example: system.webServer/httpRedirect
    type: str
    required: yes
  ConfigSectionField:
    description:
      - IIS  Config Section Field from the Section Path.
      - Example 'destination'
    type: str
    required: yes
  ConfigSectionValue:
    description:
      - The value of the Config. 
      - Example 'true'      
    type: str
    required: yes
author:
  - Harry Saryan (@hs-hub-world)
'''

EXAMPLES = r'''
- name: 'IIS Auth Settings for my site'
  win_iis_ConfigEditor:
    sitename: 'myiissite01'
    configsectionpath: 'system.webServer/security/authentication/windowsAuthentication'
    configsectionfield: 'useAppPoolCredentials'
    configsectionvalue: 'True'
'''

RETURN = r'''
sitename:
  returned: always
  type: str
anonymouseauth:
  returned: always
  type: str
AspNetImpersonation:
  returned: always
  type: str
BasicAuth:
  returned: always
  type: str
WinAuth:
  returned: always
  type: str
WinAuthProviders:
  returned: always
  type: str
DigestAuth:
  returned: always
  type: str
DigestRealm:
  returned: always
  type: str
changed:
  returned: always
  type: str
message:
  returned: always
  type: str
'''
