#!/usr/bin/env bash
#
# RUNAS: root on the machine or docker container
# Test this on Develpment Server and change this file to your needs !

#export MY_CHECKOUT_DIR="/root/git"
#mkdir -p ${MY_CHECKOUT_DIR} && cd ${MY_CHECKOUT_DIR }

## Create directories and checkout from github
export RMAN_CONNECT_DIR=/usr/local/connect
export RMAN_CONNECT_FILE_DB="db_ora_catcon.rman"
export RMAN_CONNECT_SCHEMA=rman
export RMAN_CONNECT_PASSWORD=rman
export RMAN_CONNECT_DBSERVICE=CAT
export RMAN_SCRIPT_DIR=/usr/local/etc/rman
export RMAN_SBIN_DIR=/usr/local/sbin
export SCRIPT_OWNER=oracle
export SCRIPT_GROUP=dba

export GIT_REPO_NAME="oracle-rman-cloudcontrol"
export GIT_CONNECT_DIR="./connect/"
export GIT_RMAN_SCRIPT_DIR="./etc/rman/"
export GIT_SBIN_SCRIPT_DIR="./sbin/"
# Checkout to current directory 
git clone https://github.com/jochen-halwachs/oracle-rman-cloudcontrol

# Create local rman directory - as root 
mkdir -p ${RMAN_CONNECT_DIR}
mkdir -p ${RMAN_SCRIPT_DIR}
mkdir -p ${RMAN_SBIN_DIR}

# Copy files to the destination directory
cp ${GIT_REPO_NAME}/${GIT_CONNECT_DIR}/* ${RMAN_CONNECT_DIR}
cp ${GIT_REPO_NAME}/${GIT_RMAN_SCRIPT_DIR}/* ${RMAN_SCRIPT_DIR}
cp ${GIT_REPO_NAME}/${GIT_SBIN_SCRIPT_DIR}/* ${RMAN_SBIN_DIR}

# Change Permissions to your database user
#chown ${SCRIPT_OWNER}:${SCRIPT_GROUP} ${RMAN_CONNECT_DIR}/db_ora_catcon*.rman
#chown ${SCRIPT_OWNER}:${SCRIPT_GROUP} ${RMAN_SCRIPT_DIR}/rman_*.rcv
#chown ${SCRIPT_OWNER}:${SCRIPT_GROUP} ${RMAN_SBIN_DIR}/rman_*.sh

# Edit connect files to your environment
sed -i -e 's/'"catalog_rman_schema"'/'"${RMAN_CONNECT_SCHEMA}"'/g' ${RMAN_CONNECT_DIR}/${RMAN_CONNECT_FILE_DB}
sed -i -e 's/'"catalog_rman_password"'/'"${RMAN_CONNECT_PASSWORD}"'/g' ${RMAN_CONNECT_DIR}/${RMAN_CONNECT_FILE_DB}
sed -i -e 's/'"catalog_rman_db_service"'/'"${RMAN_CONNECT_DBSERVICE}"'/g' ${RMAN_CONNECT_DIR}/${RMAN_CONNECT_FILE_DB}

# Cleanup git clone directory
#rm -rf ${GIT_REPO_NAME}
