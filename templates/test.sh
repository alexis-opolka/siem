#! /bin/bash
TEMPLATE_DIR=$(readlink -e $(dirname $0))
echo $TEMPLATE_DIR
parentdir=$(builtin cd ..; pwd)
echo $parentdir
