/tmp/apache-maven-3.2.2-bin.tar.gz:
  file.managed:
    - source: salt://maven/apache-maven-3.2.2-bin.tar.gz 
    - user: root
    - group: root
    - mode: 644

/tmp/install_maven.sh:
  file.managed:
    - source: salt://maven/install.sh
    - user: root
    - group: root
    - mode: 744
