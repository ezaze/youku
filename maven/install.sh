tar zxf /tmp/apache-maven-3.2.2-bin.tar.gz  -C /usr/local/
echo 'export M2_HOME=/usr/local/apache-maven-3.2.2' >> /etc/profile
echo 'export M2=$M2_HOME/bin' >> /etc/profile
echo 'export PATH=$M2:$PATH' >> /etc/profile
