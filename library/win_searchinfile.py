
DOCUMENTATION = r'''
---
EXAMPLE OF USAGE:  (Choco will install only if the contents are found in the file)

- name: 'check if appconfig is corrupt/missing UrlRewrite section'
  win_searchinfile:
    path: 'C:\Windows\System32\inetsrv\config\applicationhost.config'
    string: '<sectionGroup name="rewrite">'
  register: searchinfile

  #Install third party apps
- name: 'choco: Install URLRewrite'
  win_chocolatey:
    name: 
      - UrlRewrite
    ignore_checksums: 'true'
    source: 'http://mynugetrepo/nuget/Choco/'
    state: 'reinstalled'
  when: searchinfile.matched != true
'''