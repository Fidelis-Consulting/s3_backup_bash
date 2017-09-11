#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# Name: backup.sh
# Purpose: Backup specified files to an S3 bucket
# Version: 1.0
# Date: May 25, 2017
# Author: Mark Saum
# -------------------------------------------------------------------------------
# Requirements:
# - AWS client installed and configured
# - AWS credentials or role assigned to instance
# - S3 Bucket and permissions to role
# -------------------------------------------------------------------------------
# Installation:
# Script installs in: /usr/local/bin/backup.sh
# Transform installs in: /usr/local/etc/backup_transform
# Pre and Post backup scripts are optional and are installed in:
# /usr/local/bin/pre_backup.sh
# /usr/local/bin/post_backup.sh
# -------------------------------------------------------------------------------

######################
# Program variables
HOSTNAME=`which hostname`
GAWK=`which gawk`
CURL=`which curl`
DU=`which du`
TAR=`which tar`
WC=`which wc`
AWSCMD=`which aws`
S3CMD="${AWSCMD} s3 cp"
#BACKUP_COMPRESSION="z"
BACKUP_COMPRESSION="j"
#VERBOSE="v"

# Chat Details
BACKUP_MSG_ROOM_ID="Backups"
BACKUP_MSG_FROM="Backup Bot"
BACKUP_MSG_AUTHTOKEN=""

# Backup Details
BACKUP_PRE_SCRIPT=/usr/local/bin/pre_backup.sh
BACKUP_POST_SCRIPT=/usr/local/bin/post_backup.sh
BACKUP_REPO="s3://backups"
BACKUP_TRANSFORM="/usr/local/etc/backup_transform"
BACKUP_HOSTNAME=`${HOSTNAME}`
BACKUP_DOMAIN=`${HOSTNAME} -d`
TEMP_BACKUP_FILE=$(mktemp /var/tmp/backup-XXXXXXXXXX) || { echo "Failed to create temp file"; exit 1; }
BACKUP_FILE=`date +'%Y-%m-%d-%H'`.tb${BACKUP_COMPRESSION}

######################
# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

######################
# exit_function()
function exit_function() {
    ###########################
    # Remove backup file
    rm -f ${TEMP_BACKUP_FILE}
    exit
}

######################
# ctrl_c()
function ctrl_c() {
        echo "** Trapped CTRL-C"
        exit_function
}

###########################
# Run pre-backup script
if [ -x ${BACKUP_PRE_SCRIPT} ]; then
	${BACKUP_PRE_SCRIPT}
fi

###########################
# Create backup file
cd /
echo "** Running: ${TAR} c${VERBOSE}f${BACKUP_COMPRESSION} ${TEMP_BACKUP_FILE} -T ${BACKUP_TRANSFORM}"
${TAR} c${VERBOSE}f${BACKUP_COMPRESSION} ${TEMP_BACKUP_FILE} -T ${BACKUP_TRANSFORM}

###########################
# Transfer backup to S3
echo "** Running: ${S3CMD} ${TEMP_BACKUP_FILE} ${BACKUP_REPO}/${BACKUP_DOMAIN}/${BACKUP_HOSTNAME}/${BACKUP_FILE}"
${S3CMD} ${TEMP_BACKUP_FILE} ${BACKUP_REPO}/${BACKUP_DOMAIN}/${BACKUP_HOSTNAME}/${BACKUP_FILE}

###########################
# Get backup stats
BACKUP_SIZE=`${DU} -sh ${TEMP_BACKUP_FILE} | ${GAWK} '{print $1}'`
BACKUP_FILE=`${TAR} tvf ${TEMP_BACKUP_FILE} | ${WC} -l`


###########################
# Run post-backup script
if [ -x ${BACKUP_POST_SCRIPT} ]; then
	${BACKUP_POST_SCRIPT}
fi

###########################
# Send status to HipChat
#${CURL} --silent -d "room_id=${BACKUP_MSG_ROOM_ID}&from=${BACKUP_MSG_FROM}&message=A+backup+of+host+${BACKUP_HOSTNAME}.${BACKUP_DOMAIN}+has+completed+which+contains+${BACKUP_FILEs}+files+and+is+${BACKUP_SIZE}+in+size.&color=red&message_format=text&notify=0&auth_token=${BACKUP_MSG_AUTHTOKEN}"  https://api.hipchat.com/v1/rooms/message > /dev/null

exit_function

###########################
# End
###########################
