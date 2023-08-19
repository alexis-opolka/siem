# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help
SHELL := /bin/bash

TEMPLATE_DIR:=${PWD}/templates
SCRIPTS_DIR:=${PWD}/scripts
TEMP_DIR=${PWD}/temp
CA_FILE=${TEMP_DIR}/ca.crt
SECRETS_DIR=${PWD}/secrets
CONFIG_DIR=${PWD}/config
CONFIG_FILEBEAT_DIR=${PWD}/config.filebeat
PASSWORDS_FILE=${SECRETS_DIR}/passwords.txt
ENV_FILE=${PWD}/.env



CURRENT_UID := $(shell id -u)
CURRENT_GID := $(shell id -g)

export CURRENT_UID
export CURRENT_GID

.DEFAULT_GOAL := help

es:
	${SCRIPTS_DIR}/lance-ES.sh

siem:
	${SCRIPTS_DIR}/lance-siem.sh

fleet:
	${SCRIPTS_DIR}/lance-fleet.sh

help:
	@echo "---------------HELP-----------------"
	@echo "Pour Initialiser un container ES et "
	@echo "renseigner les variables d'authentification"
	@echo "nécessaires à Kibana, beats..."
	@echo "make es"
	@echo "------------------------------------"
	@echo "pour lancer la stack sécu (suricata," 
	@echo "logstash, evebox,filebeat,kibana)"
	@echo "make siem"
	@echo "------------------------------------"
	@echo "pour tout nettoyer (data comprises)"
	@echo "sans demander confirmation"
	@echo "make clean"
	@echo "------------------------------------"
	@echo "make pass pour afficher les users/passwords" 
	@echo "------------------------------------"
	@echo "make curlES pour tester elasticsearch"
	@echo "------------------------------------"
	@echo "make fleet pour installer un server fleet"
	@echo "------------------------------------"
	@echo "make fgprint pour afficher le fingerprint de la CA"
	@echo "------------------------------------"
	@echo "make prca  pour afficher la config ca pour fleet"
	@echo "------------------------------------"
	@echo "régénérés après chaque make es" 
	@echo "ES https://IP_HOTE:9200"
	@echo "Kibana https://IP_HOTE:5601"
	@echo "EveBox http://localhost:5636"
	@echo "------------------------------------"

curlES:
	- ${SCRIPTS_DIR}/testES.sh

fgprint:
	- ${SCRIPTS_DIR}/getFingerprint.sh

prca:
	- ${SCRIPTS_DIR}/printcrt.sh

clean:
	- docker stop suricata && docker rm suricata
	- docker stop es01 && docker rm es01
	- docker stop kibana && docker rm kibana
	- docker stop logstash && docker rm logstash
	- docker stop evebox && docker rm evebox
	- docker stop filebeat && docker rm filebeat
	- docker stop zeek && docker rm zeek
	- docker stop fleet && docker rm fleet
	- docker network rm elasticsearch
	- docker volume rm elasticdata
	- docker volume rm elasticonfig
	- docker volume rm certs
	- docker system prune -f
	- docker volume prune -f
	- sudo rm -f "${TEMP_DIR}"/*
	- sudo rm -f "${CONFIG_DIR}"/*.yml
	- sudo rm -f "${CONFIG_FILEBEAT_DIR}"/*.yml
	- sudo rm -f "${CONFIG_DIR}"/pipeline/*.yml
	- sudo rm -f ${SECRETS_DIR}/*
	- rm -f ${PWD}/.env
	- sudo chown -R ${CURRENT_UID}.${CURRENT_GID} ${PWD}


cleansiem:
	- docker stop suricata && docker rm suricata
	- docker stop kibana && docker rm kibana
	- docker stop logstash && docker rm logstash
	- docker stop evebox && docker rm evebox
	- docker stop filebeat && docker rm filebeat
	- docker stop zeek && docker rm zeek
	- docker stop fleet && docker rm fleet
	- docker system prune -f
	- sudo rm -f config/kibana.yml
	- sudo rm -f "${CONFIG_DIR}"/*.yml
	- sudo rm -f "${CONFIG_FILEBEAT_DIR}"/*.yml
	- sudo rm -f "${CONFIG_DIR}"/pipeline/*.yml
stop:
	- docker stop suricata
	- docker stop kibana
	- docker stop logstash
	- docker stop evebox
	- docker stop filebeat
	- docker stop zeek
#start:
#	- docker start suricata
#	- docker start kibana
#	- docker start logstash
#	- docker start evebox
#	- docker start filebeat
#	- docker start zeek


pass: 
	${SCRIPTS_DIR}/print_password.sh

all: clean es siem pass
