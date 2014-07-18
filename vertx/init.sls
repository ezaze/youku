/tmp/vert.x-2.1.1.tar.gz:
  file.managed:
    - source: salt://vertx/vert.x-2.1.1.tar.gz 
    - user: root
    - group: root
    - mode: 644
/tmp/install_vertx.sh:
  file.managed:
    - source: salt://vertx/install.sh 
    - user: root
    - group: root
    - mode: 744
