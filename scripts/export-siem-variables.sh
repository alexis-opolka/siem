# variables
export CLUSTER_NAME="HandOnPackets"
export TEMPLATE_DIR=$(cd ../templates;pwd)
export TEMP_DIR=$(cd ../temp;pwd)
export CA_FILE=${TEMP_DIR}/ca.crt
export SECRETS_DIR=$(cd ../secrets;pwd)
export CONFIG_DIR=$(cd ../config;pwd)
export PASSWORDS_FILE=${SECRETS_DIR}/passwords.txt
export ETC_DIR=$(cd ../etc ; pwd)
export SCRIPT_DIR=$(readlink -f ${0%/*})
export LOGS_DIR=$(cd ../logs ; pwd)
echo $TEMPLATE_DIR
echo $TEMP_DIR
echo $CA_FILE
echo $SECRETS_DIR
echo $CONFIG_DIR
echo $ETC_DIR
echo $SCRIPT_DIR
echo $LOGS_DIR
