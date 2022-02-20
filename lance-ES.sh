#! /bin/bash
# test de sudo
if (sudo -vn && sudo -ln) 2>&1 |grep 'ne pas' > /dev/null; then 
  printf "%s\n" "vous devez pouvoir faire sudo"
  exit 0 
fi


# nettoyage
make clean
#creation network et volumes 
docker network create elasticsearch
CLUSTER_NAME=HandOn
CERTS_DIR=/usr/share/elasticsearch/config/certificates
KIBANA_CONFIG_FILE=$(pwd)/config/kibana.yml
printf "%s\n" "kibana file:  ${KIBANA_CONFIG_FILE}"
PASSWORDS='passwords.txt'

docker volume create elasticdata
docker volume create elasticonfig
docker volume create certs

# création des fichiers sans les mots de passes
# avec la version 8.0 de kibana le mot de passe du compte kibana_system est ignoré en tant que variable d'environnement, il faut 
# mettre le mot de passe généré dans le fichier config/kibana.yml d'ou le besoin d'un template propre

cp env.template .env
sudo chown -R $(id -u).$(id -g) $(pwd)/config
cp kibana.yml.template $KIBANA_CONFIG_FILE

# recup des interfaces pour la conf de suricata
find /sys/class/net -mindepth 1 -maxdepth 1 -lname '*virtual*' -prune -o -printf '%f\n'

###############################################################
# ce premier container éphémère crée le certificats auto-signés
# on prend un mot de passe par default qui sera changé ensuite
###############################################################

docker run --rm -it --env ELASTIC_PASSWORD=changeme --env KIBANA_PASSWORD=changeme --volume='elasticonfig:/usr/share/elasticsearch/config' --volume='certs:/usr/share/elasticsearch/config/certs' --user root docker.elastic.co/elasticsearch/elasticsearch:8.0.0  bash -c 'mkdir -p /usr/share/elasticsearch/config/certs/ca;  
         if [ x${ELASTIC_PASSWORD} == x ]; then
          echo "Set the ELASTIC_PASSWORD environment variable in the .env file";
          exit 1;
        elif [ x${KIBANA_PASSWORD} == x ]; then
          echo "Set the KIBANA_PASSWORD environment variable in the .env file";
          exit 1;
        fi;
        if [ ! -f certs/ca.zip ]; then
          echo "Creating CA";
          bin/elasticsearch-certutil ca --silent --pem -out config/certs/ca.zip;
	  pe
          unzip config/certs/ca.zip -d config/certs;
        fi;
        if [ ! -f certs/certs.zip ]; then
          echo "Creating certs";
          echo -ne \
          "instances:\n"\
          "  - name: es01\n"\
          "    dns:\n"\
          "      - es01\n"\
          "      - localhost\n"\
          "    ip:\n"\
          "      - 127.0.0.1\n"\
          "  - name: es02\n"\
          "    dns:\n"\
          "      - es02\n"\
          "      - localhost\n"\
          "    ip:\n"\
          "      - 127.0.0.1\n"\
          "  - name: es03\n"\
          "    dns:\n"\
          "      - es03\n"\
          "      - localhost\n"\
          "    ip:\n"\
          "      - 127.0.0.1\n"\
          > config/certs/instances.yml;
          bin/elasticsearch-certutil cert --silent --pem -out config/certs/certs.zip --in config/certs/instances.yml --ca-cert config/certs/ca/ca.crt --ca-key config/certs/ca/ca.key;
          unzip config/certs/certs.zip -d config/certs;
        fi;
	openssl pkcs12 -export -in config/certs/ca/ca.crt -inkey config/certs/ca/ca.key -out certificate.p12  -passin pass: -passout pass:;
        echo "Setting file permissions"
        chown -R root:root config/certs;
        find . -type d -exec chmod 750 \{\} \;;
        find . -type f -exec chmod 640 \{\} \;;
        echo "All done!";exit 0
      ' 

# création de l'instance es01 avec le volume contenant les certificats précédents 

docker run  -d  --name es01 \
--env cluster.name=${CLUSTER_NAME}  \
--env discovery.type=single-node \
--env ELASTIC_PASSWORD=${ELASTIC_PASSWORD} \
--env bootstrap.memory_lock=true \
--env xpack.security.enabled=true \
--env xpack.security.http.ssl.enabled=true \
--env xpack.security.http.ssl.key=/usr/share/elasticsearch/config/certs/es01/es01.key \
--env xpack.security.http.ssl.certificate=/usr/share/elasticsearch/config/certs/es01/es01.crt \
--env xpack.security.http.ssl.certificate_authorities=/usr/share/elasticsearch/config/certs/ca/ca.crt \
--env xpack.security.http.ssl.verification_mode=certificate \
--env xpack.security.transport.ssl.enabled=true \
--env xpack.security.transport.ssl.key=/usr/share/elasticsearch/config/certs/es01/es01.key \
--env xpack.security.transport.ssl.certificate=/usr/share/elasticsearch/config/certs/es01/es01.crt \
--env xpack.security.transport.ssl.certificate_authorities=/usr/share/elasticsearch/config/certs/ca/ca.crt \
--env xpack.security.transport.ssl.verification_mode=certificate \
--env xpack.license.self_generated.type=basic \
--env xpack.security.enrollment.enabled=false \
--env ES_JAVA_OPTS="-Xms2048m -Xmx2048m" \
--volume='elasticdata:/usr/share/elasticsearch/data' \
--volume='elasticonfig:/usr/share/elasticsearch/config' \
--volume='certs:/usr/share/elasticsearch/config/certs' \
--publish 127.0.0.1:9200:9200 --publish 127.0.0.1:9300:9300 --net elasticsearch \
docker.elastic.co/elasticsearch/elasticsearch:8.0.0

# On récupére la CA pour faire des curl
docker cp es01:/usr/share/elasticsearch/config/certs/ca/ca.crt .

# ES met un peu de temps à être accessible
echo "Attente ES up...";
until curl -s --cacert ca.crt https://localhost:9200 2>&1 | grep -q "missing authentication credentials"; do sleep 10; done;

printf "génération des password pour les systèmes et sauvegarde dans .env (pour docker-compose) et ${PASSWORDS} (pour docker run)\n"

# Création de tous les mots de passes systèmes standard de ES et récupération pour dans une second temps permettent à la stack elastic et plus 
# de s'y connecter

ELASTIC_PASSWORD=$(docker exec --user root -it es01 bash -c './bin/elasticsearch-reset-password  -u elastic -s -b')
echo  "password elastic ${ELASTIC_PASSWORD}" 
printf "ELASTIC_PASSWORD=%q\n" "${ELASTIC_PASSWORD}" >> .env
printf "ELASTIC_PASSWORD=%q\n" "${ELASTIC_PASSWORD}" >>  ${PASSWORDS}

## Pour kibana il faut aussi renseigner le fichier de config avec le nouveau mot de passe
KIBANA_PASSWORD=$(docker exec --user root -it es01 bash -c './bin/elasticsearch-reset-password  -u kibana_system -s -b')
echo  "password kibana_system ${KIBANA_PASSWORD}" 
printf  "KIBANA_PASSWORD=%q\n" "${KIBANA_PASSWORD}" >> .env
printf  "KIBANA_PASSWORD=%q\n" "${KIBANA_PASSWORD}" >> ${PASSWORDS}
echo "elasticsearch.password: ${KIBANA_PASSWORD}" >> ${KIBANA_CONFIG_FILE}

# supression d'un ^M dans le fichier config de Kibana
sed -i 's/\r//g' ${KIBANA_CONFIG_FILE}

BEATS_PASSWORD=$(docker exec --user root -it es01 bash -c './bin/elasticsearch-reset-password  -u beats_system -s -b')
echo  "password beats ${BEATS_PASSWORD}" 
printf "BEATS_PASSWORD=%q\n" "${BEATS_PASSWORD}" >> .env
printf "BEATS_PASSWORD=%q\n" "${BEATS_PASSWORD}" >> ${PASSWORDS}

APM_PASSWORD=$(docker exec --user root -it es01 bash -c './bin/elasticsearch-reset-password  -u apm_system -s -b')
echo  "password apm ${BEATS_PASSWORD}" 
printf "APM_PASSWORD=%q\n" "${APM_PASSWORD}" >> .env
printf "APM_PASSWORD=%s\n" "${APM_PASSWORD}" >> ${PASSWORDS}

MONITORING_PASSWORD=$(docker exec --user root -it es01 bash -c './bin/elasticsearch-reset-password  -u remote_monitoring_user -s -b')
echo  "password monitoring ${MONITORING_PASSWORD}" 
printf "MONITORING_PASSWORD=%q\n" "${MONITORING_PASSWORD}" >> .env
printf "MONITORING_PASSWORD=%q\n" "${MONITORING_PASSWORD}" >> ${PASSWORDS}


#KIBANA_TOKEN=$(docker exec --user root -it es01 bash -c './bin/elasticsearch-create-enrollment-token -s kibana  -b')
#echo  "enrollment kibana token ${TOKEN}" 
#printf "KIBANA_TOKEN=${KIBANA_TOKEN}\n" >> ${PASSWORDS}

curl --cacert ca.crt -u elastic:${ELASTIC_PASSWORD} https://localhost:9200

# ajout du pass pour filebeat
sed "s/ELASTIC_PASSWORD/${ELASTIC_PASSWORD}/g" filebeat.yml.template > filebeat.yml
sed -i 's/\r//g' filebeat.yml
sudo chown root.root filebeat.yml
sudo chmod go-w filebeat.yml

#cat .env
#cat ${KIBANA_CONFIG_FILE}
sudo chown -R root.root $(pwd)/config
