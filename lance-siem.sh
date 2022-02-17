docker stop suricata
docker stop elasticsearch
docker stop kibana
docker stop logstash
docker stop evebox
docker stop filebeat
docker rm suricata
docker rm elasticsearch
docker rm kibana
docker rm logstash
docker rm evebox
docker rm filebeat


docker network create elasticsearch
docker run -d --name elasticsearch \
--publish 9200:9200 --publish 9300:9300 --net elasticsearch \
--env discovery.type=single-node \
--env xpack.security.authc.anonymous.authz_exception=true \
--env xpack.security.authc.anonymous.username=anonymous_user \
--env xpack.security.authc.anonymous.roles=role1,role2 \
--volume='elasticsearch:/usr/share/elasticsearch/data' \
--env xpack.security.enabled=false \
docker.elastic.co/elasticsearch/elasticsearch:8.0.0

  
docker run -d --name suricata -e SURICATA_OPTIONS="-i enp12s0  -vvv" -e PUID=$(id -u)  -e PGID=$(id -g) \
    --rm -it --net=host \
    --cap-add=net_admin --cap-add=net_raw --cap-add=sys_nice \
    -v $(pwd)/logs:/var/log/suricata \
        -v $(pwd)/etc:/etc/suricata \
    jasonish/suricata:latest
docker exec -it suricata bash -c 'dnf -y update && dnf -y install git vim wget jq less GeoIP-GeoLite-data-extra sudo initscripts'

docker exec -it suricata bash -c 'curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.0.0-x86_64.rpm &&
rpm -vi filebeat-8.0.0-x86_64.rpm'
docker exec suricata bash -c '
suricata-update list-sources
suricata-update enable-source oisf/trafficid
suricata-update enable-source etnetera/aggressive
suricata-update enable-source sslbl/ssl-fp-blacklist
suricata-update enable-source et/open
suricata-update enable-source tgreen/hunting
suricata-update enable-source sslbl/ja3-fingerprints
suricata-update enable-source ptresearch/attackdetection
suricata-update
'
docker run --net elasticsearch -d --publish=127.0.0.1:5636:5636 -it jasonish/evebox:latest -e http://elasticsearch:9200 -i 'logstash*'


docker run -d --name kibana --network=elasticsearch --publish=127.0.0.1:5601:5601 docker.elastic.co/kibana/kibana:8.0.0 
sleep 60
docker run -d --name logstash -e PUID=$(id -u)  -e PGID=$(id -g)  -e XPACK_MONITORING_ENABLED=false -it --rm --net=elasticsearch --volumes-from=suricata -v $(pwd)/pipeline/:/usr/share/logstash/pipeline/ logstash:8.0.0

docker run -d --name filebeat --user=root --network=elasticsearch  --volume="$(pwd)/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro" --volume="$(pwd)/suricata.yml:/usr/share/filebeat/modules.d/suricata.yml:ro"  --volume=$(pwd)/logs:/var/log/suricata docker.elastic.co/beats/filebeat:8.0.0 filebeat -e -strict.perms=false -E setup.kibana.host=kibana:5601 -E output.elasticsearch.hosts="elasticsearch:9200"
docker exec -it filebeat filebeat setup -E setup.kibana.host=kibana:5601 -E output.elasticsearch.hosts="elasticsearch:9200"


