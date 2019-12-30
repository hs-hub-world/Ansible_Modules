#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2019, Harry Saryan  <hs-hub-world@github>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

ANSIBLE_METADATA = {'metadata_version': '1.1',
                    'status': ['preview'],
                    'supported_by': 'community'}

DOCUMENTATION = r'''
---
module: win_iis_auth
version_added: "2.8"
short_description: apply IIS site authentication settings
description:
     - Configure IIS site authentication properties
options:
  Sitename:
    description:
      - Site name to update (i.e. My Site)
    type: str
    required: yes
  AnonymouseAuth:
    description:
      - use AnonymouseAuthentication or not -? (True/False)
    type: bool
    required: yes
  AspNetImpersonation:
    description:
      - use AspNetImpersonation or not ? (True/False)
    type: bool
    required: yes
  BasicAuth:
    description:
      - use BasicAuth or not ? (True/False)
    type: bool
    required: yes
  WinAuth:
    description:
      - use WinAuth or not ? (True/False)
    type: bool
    required: yes
  WinAuthProviders:
    description:
      - when using winAuth specify provider (i.e. Nergotiate, NTLM)
    type: str
    required: yes
  DigestAuth:
    description:
      - use DigestAuth or not ? (True/False)
    type: bool
    required: yes
  DigestRealm:
    description:
      - when using  DigestAuth specify Realm.
    type: str
    required: yes
author:
  - Harry Saryan (@hs-hub-world)
'''

EXAMPLES = r'''
- name: 'IIS Auth Settings for my site'
  win_iis_auth:
    sitename: 'my site'
    anonymouseauth: true
    aspnetimpersonation: false
    winauth: true
    WinAuthProviders:
      - 'NTLM'
    basicauth: false
    DigestAuth: false
    DigestRealm: ""
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
