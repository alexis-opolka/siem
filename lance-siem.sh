#! /bin/bash


make cleansiem

echo "récupération des mots de passes dans les variables depuis passwords.txt"
source passwords.txt

####################################################################################################
echo "run de l'image suricata (Alma 8 redhat like) voir https://github.com/jasonish/docker-suricata"
####################################################################################################
# recup des interfaces de la machine
SURICATA_OPTIONS=$(find /sys/class/net -mindepth 1 -maxdepth 1 -lname '*virtual*' -prune -o -printf '-i %f ')-vvv
echo "suricata va écouter sur $SURICATA_OPTIONS"

docker run  -d --name suricata --env SURICATA_OPTIONS="${SURICATA_OPTIONS}" -e PUID=$(id -u)  -e PGID=$(id -g) \
    -it --net=host \
    --cap-add=net_admin --cap-add=net_raw --cap-add=sys_nice \
    -v $(pwd)/logs:/var/log/suricata \
    -v $(pwd)/etc:/etc/suricata \
    -v $(pwd)/lib:/var/lib/suricata \
    jasonish/suricata:latest

# Rajout de packages de bases dans l'image

docker exec -it suricata bash -c 'dnf -y update && dnf -y install git vim wget jq less GeoIP-GeoLite-data-extra sudo initscripts'
#on utilise un container filebeat donc pas utile  
#docker exec -it suricata bash -c 'curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.0.0-x86_64.rpm && rpm -vi filebeat-8.0.0-x86_64.rpm'

echo "activation des repos de règles"
docker exec suricata bash -c '
suricata-update list-sources
suricata-update enable-source oisf/trafficid
suricata-update enable-source etnetera/aggressive
suricata-update enable-source sslbl/ssl-fp-blacklist
suricata-update enable-source et/open
suricata-update enable-source tgreen/hunting
suricata-update enable-source sslbl/ja3-fingerprints
suricata-update enable-source ptresearch/attackdetection
suricata-update &
'
###################################################################
echo "création d'une instance de Evebox voir https://evebox.org/ elle va indexer dans ES tout les _index=logstash*"
echo "evebox ne supporte pas les entrées ES provenant de filebeat"
###################################################################

docker run --name evebox --rm --net elasticsearch -env ELASTIC_USERNAME=elastic --env ELASTIC_PASSWORD=${ELASTIC_PASSWORD} -d --publish=127.0.0.1:5636:5636 -it jasonish/evebox:latest -e https://es01:9200 -i 'logstash*'


###################################################################
echo "lancement de Kibana" 
###################################################################
KIBANA_CONFIG_FILE=$(pwd)/config/kibana.yml
KIBANA_CONFIG_TEMPLATE=$(pwd)/config/kibana.yml.template
sudo cp $KIBANA_CONFIG_TEMPLATE $KIBANA_CONFIG_FILE
printf "%s\n" "kibana file:  ${KIBANA_CONFIG_FILE}"

## Pour kibana il faut aussi renseigner le fichier de config avec le nouveau mot de passe
sudo echo "elasticsearch.password: ${KIBANA_PASSWORD}" >> ${KIBANA_CONFIG_FILE}

# supression d'un ^M dans le fichier config de Kibana
sudo sed -i 's/\r//g' ${KIBANA_CONFIG_FILE}


docker run   -d --name kibana --network=elasticsearch --volume='certs:/usr/share/kibana/config/certs' -v $(pwd)/config:/usr/share/kibana/config --publish=127.0.0.1:5601:5601 --env ELASTICSEARCH_SSL_CERTIFICATEAUTHORITIES=/usr/share/kibana/config/certs/ca/ca.crt --env ELASTICSEARCH_HOSTS='https://es01:9200' --env ELASTICSEARCH_USERNAME=kibana_system  docker.elastic.co/kibana/kibana:8.0.0

echo "Attente Kibana up...";
until curl -XGET http://localhost:5601/status -I 2>&1 | grep -v "init"; do sleep 10; done;
sleep 60

###################################################################
echo "lancement de logstash" 
###################################################################

# ajout du pass pour logstash.conf
sed "s/{ELASTIC_PASSWORD}/$ELASTIC_PASSWORD/g" $PWD/pipeline/logstash.conf.template > $PWD/pipeline/logstash.conf
sed -i 's/\r//g' $PWD/pipeline/logstash.conf


docker run -d --name logstash -e PUID=$(id -u)  -e PGID=$(id -g) --env ELASTIC_USERNAME=logstash_system --env ELASTIC_PASSWORD=${LOGSTASH_PASSWORD}   -e XPACK_MONITORING_ENABLED=false -it --rm --net=elasticsearch --volumes-from=suricata  --volume='certs:/usr/share/logstatsh/config/certs' -v $(pwd)/pipeline/:/usr/share/logstash/pipeline/ logstash:8.0.0  


###################################################################
echo "lancement de filebeats" 
###################################################################

# ajout du pass pour filebeat.yml
sudo sed "s/ELASTIC_PASSWORD/${ELASTIC_PASSWORD}/g" filebeat.yml.template > filebeat.yml
sudo sed -i 's/\r//g' filebeat.yml
sudo chown root.root filebeat.yml
sudo chmod go-w filebeat.yml

# d'abord setup
docker run --user=root --name filebeat  --volume='certs:/usr/share/filebeats/config/certs'  --network=elasticsearch --volume="$(pwd)/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro" --volume='certs:/usr/share/filebeats/config/certs' --volume="$(pwd)/suricata.yml:/usr/share/filebeat/modules.d/suricata.yml:ro" --volume="$(pwd)/logs:/var/log/suricata" --env ELASTIC_USERNAME=beats_system --env ELASTIC_PASSWORD=${BEATS_PASSWORD}  docker.elastic.co/beats/filebeat:8.0.0 setup  -E setup.kibana.host=kibana:5601 -E output.elasticsearch.hosts="https://es01:9200" -E output.elasticsearch.ssl.certificate_authorities=/usr/share/filebeats/config/certs/ca/ca.crt

# ensuite lancement en scrutation
docker run --user=root  -d --name filebeat  --volume='certs:/usr/share/filebeats/config/certs'  --network=elasticsearch --volume="$(pwd)/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro" --volume='certs:/usr/share/filebeats/config/certs' --volume="$(pwd)/suricata.yml:/usr/share/filebeat/modules.d/suricata.yml:ro" --volume="$(pwd)/logs:/var/log/suricata" --env ELASTIC_USERNAME=beats_system --env ELASTIC_PASSWORD=${BEATS_PASSWORD}  docker.elastic.co/beats/filebeat:8.0.0 filebeat -e -strict.perms=false -E setup.kibana.host=kibana:5601 -E output.elasticsearch.hosts="https://es01:9200" -E output.elasticsearch.ssl.certificate_authorities=/usr/share/filebeats/config/certs/ca/ca.crt

#docker exec --user=root -it filebeat filebeat setup -E setup.kibana.host=kibana:E5601 -E setup.kibana.host=kibana:5601 -E output.elasticsearch.ho  sts="https://es01:9200" -E output.elasticsearch.ssl.certificate_authorities=/usr/share/filebeats/config/certs/ca/ca.crt filebeat  setup --dashboards


###################################################################
echo "lancement de zeek" 
###################################################################
docker run -d --rm  --name zeek  --net=elasticsearch --volumes-from=suricata registry.iutbeziers.fr/bro:4.2.0 /bin/bash -c 'while true; do sleep 100; done'
docker exec -it zeek   /bin/bash -c 'apt update && apt -y install python3'
