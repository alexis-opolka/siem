# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help

.DEFAULT_GOAL := help

es:
	${PWD}/lance-ES.sh
siem:
	${PWD}/lance-siem.sh

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
	@echo "régénérés après chaque make es" 
	@echo "ES https://localhost:9200"
	@echo "Kibana http://localhost:5601"
	@echo "EveBox http://localhost:5636"
	@echo "------------------------------------"

clean:
	- docker stop suricata && docker rm suricata
	- docker stop es01 && docker rm es01
	- docker stop kibana && docker rm kibana
	- docker stop logstash && docker rm logstash
	- docker stop evebox && docker rm evebox
	- docker stop filebeat && docker rm filebeat
	- docker stop zeek && docker rm zeek
	- docker network rm elasticsearch
	- docker system prune -f
	- docker volume prune -f
	- rm -f .env
	- rm -f ca.crt
	- sudo rm -f config/kibana.yml
	- sudo rm -f filebeat.yml
	- rm -f passwords.txt

cleansiem:
	- docker stop suricata && docker rm suricata
	- docker stop kibana && docker rm kibana
	- docker stop logstash && docker rm logstash
	- docker stop evebox && docker rm evebox
	- docker stop filebeat && docker rm filebeat
	- docker stop zeek && docker rm zeek
	- sudo rm -f config/kibana.yml

pass: 
	${PWD}/print_password.sh

all: clean es siem pass
