/etc/yum.repos.d/myrepo.repo:
  file.managed:
    - source: salt://yum/myrepo.repo
    - user: root
    - group: root
    - mode: 644
