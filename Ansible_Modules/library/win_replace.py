#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2019, Harry Saryan  <hs-hub-world@github>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

ANSIBLE_METADATA = {'metadata_version': '1.1',
                    'status': ['preview'],
                    'supported_by': 'community'}

DOCUMENTATION = r'''
---
module: win_iis_webbinding
version_added: "2.8"
short_description: Find/Replace text/string for a win machine
description:
     - Find and Replace a text in a file. Can be used with template files.
options:
  path:
    description:
      - Path to file (i.e. c:\My Director\MyFile.htm)
    type: str
    required: yes
  findstring:
    description:
      - string to find in the file.
    type: str
    required: yes
  replace:
    description:
      - Replace found string with this string
    type: str
    required: yes
author:
  - Harry Saryan (@hs-hub-world)
'''

EXAMPLES = r'''
- name: Update Default.html file
  win_replace:
    path: 'c:\\IISServer\\Default.htm'
    findstring: '{{ item.search_patttern }}' 
    replace: '{{ item.replacement }}'
  with_items:
    - { search_patttern: "site1", replacement: "site2" }
    - { search_patttern: "pages for site1service", replacement: "pages for site2service" }
'''

RETURN = r'''
matchcount:
  description:
    - Number of matches found during search in the file.
    - Helpful to detect number of items being replaced
  returned: always
  type: int
  sample: 36
findstring:
  description:
    - show what string was being searched 
  returned: always
  type: str
  sample: "site1"
replace:
  description:
    - show what was replaced with.
  returned: always
  type: str
  sample: "site2"
path:
  description:
    - show file being modified.
  returned: always
  type: str
  sample: "c:\\IISServer\\Default.htm"
changed:
  description:
    - show if the item was changed..
  returned: always
  type: bool
  sample: "false"
message:
  description:
    - show any applicable messages.
  returned: always
  type: str
  sample: "Replaced 36 number of strings"
'''
