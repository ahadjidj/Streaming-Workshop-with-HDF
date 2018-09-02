#!/usr/bin/env bash
# Parameters for installing Ambari with ambari-bootstrap-2.7
export install_ambari_server=true
export install_hdf_mpack=true
export ambari_server=$(hostname -f)
export ambari_version=2.7.0.0
export password=${password:-StrongPassword}
export nifi_password=${nifi_password:-StrongPassword}
bootstrap_url=https://raw.githubusercontent.com/ahadjidj/Streaming-Workshop-with-HDF/master/scripts/ambari-bootstrap-2.7.sh

# Parameters for installing HDF with deploy-recommended-cluster
export host_count=${host_count:-1}
export ambari_services="AMBARI_INFRA_SOLR ZOOKEEPER STREAMLINE NIFI KAFKA STORM REGISTRY NIFI_REGISTRY AMBARI_METRICS LOGSEARCH"
export ambari_stack_name=HDF
export ambari_stack_version=3.2
export cluster_name=${cluster_name:-hdfcluster}
export ambari_password=${password}

echo ""
echo "#################################################"
echo "Installing required packages"
echo "#################################################"

sudo yum localinstall -y https://dev.mysql.com/get/mysql57-community-release-el7-8.noarch.rpm
sudo yum install -y git python-argparse epel-release mysql-connector-java* mysql-community-server nc
sudo systemctl enable mysqld.service
sudo systemctl start mysqld.service
oldpass=$( grep 'temporary.*root@localhost' /var/log/mysqld.log | tail -n 1 | sed 's/.*root@localhost: //' )
# setup SAM and SR users and DBs
cat << EOF > mysql-setup.sql
ALTER USER 'root'@'localhost' IDENTIFIED BY 'Secur1ty!'; 
uninstall plugin validate_password;
CREATE DATABASE registry DEFAULT CHARACTER SET utf8; CREATE DATABASE streamline DEFAULT CHARACTER SET utf8; 
CREATE USER 'registry'@'%' IDENTIFIED BY '${password}'; CREATE USER 'streamline'@'%' IDENTIFIED BY '${password}'; 
GRANT ALL PRIVILEGES ON registry.* TO 'registry'@'%' WITH GRANT OPTION ; GRANT ALL PRIVILEGES ON streamline.* TO 'streamline'@'%' WITH GRANT OPTION ; 
commit; 
EOF
mysql -h localhost -u root -p"$oldpass" --connect-expired-password < mysql-setup.sql
#change Mysql password to ${password}
mysqladmin -u root -p'Secur1ty!' password ${password}

echo ""
echo "#################################################"
echo "Installing Ambari"
echo "#################################################"

sudo ln -s /mnt /hadoop
curl -sSL ${bootstrap_url} | sudo -E sh
sleep 15
sudo ambari-server setup --jdbc-db=mysql --jdbc-driver=/usr/share/java/mysql-connector-java.jar
# change ambari password
curl -iv -u admin:admin -H "X-Requested-By: blah" -X PUT -d "{ \"Users\": { \"user_name\": \"admin\", \"old_password\": \"admin\", \"password\": \"${ambari_password}\" }}" http://localhost:8080/api/v1/users/admin
sudo ambari-server restart
while ! echo exit | nc ${ambari_server} 8080; do echo "waiting for Ambari to be fully up..."; sleep 10; done

echo ""
echo "#################################################"
echo "Installing HDF"
echo "#################################################"

curl -ssLO https://github.com/seanorama/ambari-bootstrap/archive/master.zip
unzip -q master.zip -d  /tmp
cd /tmp/ambari-bootstrap-master/deploy
cat << EOF > configuration-custom.json
{
  "configurations": {
    "ams-grafana-env": {
      "metrics_grafana_password": "${ambari_password}"
    },
    "streamline-common": {
      "jar.storage.type": "local",
      "streamline.storage.type": "mysql",
      "streamline.storage.connector.connectURI": "jdbc:mysql://${ambari_server}:3306/streamline",
      "registry.url" : "http://${ambari_server}:7788/api/v1",
      "streamline.dashboard.url" : "http://${ambari_server}:9089",
      "streamline.storage.connector.password": "${password}"
    },
    "registry-common": {
      "jar.storage.type": "local",
      "registry.storage.connector.connectURI": "jdbc:mysql://${ambari_server}:3306/registry",
      "registry.storage.type": "mysql",
      "registry.storage.connector.password": "${password}"
    },
    "nifi-registry-ambari-config": {
      "nifi.registry.security.encrypt.configuration.password": "${nifi_password}"
    },
    "nifi-registry-properties": {
    	"nifi.registry.db.password": "${nifi_password}"
    },
    "nifi-ambari-config": {
      "nifi.sensitive.props.key": "${nifi_password}",
      "nifi.security.encrypt.configuration.password": "${nifi_password}"
    },
    "kafka-broker": {
        "offsets.topic.replication.factor": "1"
    },
    "logsearch-admin-json": {
    	"logsearch_admin_password": "${password}"
    }
  }
}
EOF
#sleep 30
sudo -E /tmp/ambari-bootstrap-master/deploy/deploy-recommended-cluster.bash
echo "Waiting for blueprint installation \n"
sleep 5
ambari_pass="${ambari_password}" source /tmp/ambari-bootstrap-master/extras/ambari_functions.sh
ambari_configs
ambari_wait_request_complete 1

echo ""
echo "#################################################"
echo "Install successful"
echo "#################################################"
