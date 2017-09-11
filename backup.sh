#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# Name: backup.sh
# Purpose: Backup specified files to an S3 bucket
# Version: 1.0
# Date: May 25, 2017
# Author: Mark Saum
# GitHub: https://github.com/msaum
# -------------------------------------------------------------------------------
# Requirements:
# - AWS client installed and configured
# - AWS credentials or role assigned to instance
# - S3 Bucket and permissions to role
# -------------------------------------------------------------------------------
# Installation:
# Script installs in: /usr/local/bin/backup.sh
# Transform installs in: /usr/local/etc/backup_transform
# Configuration installs in: /usr/local/etc/backup.conf
# Pre and Post backup scripts are optional and are installed in:
# /usr/local/bin/pre_backup.sh
# /usr/local/bin/post_backup.sh
# -------------------------------------------------------------------------------

echo "** Starting: backup.sh"
######################
# exit_error()
function exit_error() {
    if [ -f ${BACKUP_TEMP_FILE} ]; then
        rm -f ${BACKUP_TEMP_FILE}
    fi
    echo "** Falure: $1"
    echo "** Ending: backup.sh"
    exit 1
}

######################
# Program variables
HOSTNAME=`which hostname`  || exit_error "Can't find hostname"
GAWK=`which gawk`  || exit_error "Can't find gawk"
CURL=`which curl`  || exit_error "Can't find curl"
DU=`which du`  || exit_error "Can't find du"
TAR=`which tar`  || exit_error "Can't find tar"
WC=`which wc`  || exit_error "Can't find wc"
AWSCMD=`which aws`  || exit_error "Can't find awscli"
S3CMD="${AWSCMD} s3 cp"
BACKUP_HOSTNAME=`${HOSTNAME}`
BACKUP_DOMAIN=`${HOSTNAME} -d`
BACKUP_TEMP_FILE=$(mktemp /var/tmp/backup-XXXXXXXXXX) || exit_error "Failed to create temp file"

######################
# Read Config File
shopt -s extglob
CONFIGFILE="/usr/local/etc/backup.conf"
while IFS='= ' read lhs rhs
do
    if [[ ! $lhs =~ ^\ *# && -n $lhs ]]; then
        rhs="${rhs%%\#*}"    # Del in line right comments
        rhs="${rhs%%*( )}"   # Del trailing spaces
        rhs="${rhs%\"}"     # Del opening string quotes
        rhs="${rhs#\"}"     # Del closing string quotes
        declare $lhs="$rhs"
    fi
done < ${CONFIGFILE}

BACKUP_FILE=`date +'%Y-%m-%d-%H'`.tb${BACKUP_COMPRESSION}

######################
# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

######################
# exit_function()
function exit_function() {
    ###########################
    # Remove backup file
    rm -f ${BACKUP_TEMP_FILE}
    echo "** Ending: backup.sh"
    exit 0
}

######################
# ctrl_c()
function ctrl_c() {
        echo "** Interrupted: Trapped CTRL-C"
        exit_function
}

###########################
# Check for Transform file
if [ ! -f ${BACKUP_TRANSFORM} ]; then
    exit_error "Backup Transform file: \"${BACKUP_TRANSFORM}\" not found!"
fi

###########################
# Run pre-backup script
if [ -x ${BACKUP_PRE_SCRIPT} ]; then
	${BACKUP_PRE_SCRIPT}
fi

###########################
# Create backup file
cd /
echo "** Running: ${TAR} c${BACKUP_VERBOSE}f${BACKUP_COMPRESSION} ${BACKUP_TEMP_FILE} -T ${BACKUP_TRANSFORM}"
${TAR} c${BACKUP_VERBOSE}f${BACKUP_COMPRESSION} ${BACKUP_TEMP_FILE} -T ${BACKUP_TRANSFORM} || exit_error "tar command failed"

###########################
# Transfer backup to S3
echo "** Running: ${S3CMD} ${BACKUP_TEMP_FILE} ${BACKUP_REPO}/${BACKUP_DOMAIN}/${BACKUP_HOSTNAME}/${BACKUP_FILE}"
${S3CMD} ${BACKUP_TEMP_FILE} ${BACKUP_REPO}/${BACKUP_DOMAIN}/${BACKUP_HOSTNAME}/${BACKUP_FILE} || exit_error "s3 file copy failed"

###########################
# Get backup stats
BACKUP_SIZE=`${DU} -sh ${BACKUP_TEMP_FILE} | ${GAWK} '{print $1}'` || exit_error "Calculating backup file size failed"
BACKUP_FILE_COUNT=`${TAR} tvf ${BACKUP_TEMP_FILE} | ${WC} -l` || exit_error "Calculating backup file count failed"

###########################
# Run post-backup script
if [ -x ${BACKUP_POST_SCRIPT} ]; then
	${BACKUP_POST_SCRIPT}
fi

echo "** Status: A backup of host ${BACKUP_HOSTNAME}.${BACKUP_DOMAIN} has completed which contains ${BACKUP_FILE_COUNT} files and is ${BACKUP_SIZE}."

###########################
# Send status to HipChat
#${CURL} --silent -d "room_id=${BACKUP_MSG_ROOM_ID}&from=${BACKUP_MSG_FROM}&message=A+backup+of+host+${BACKUP_HOSTNAME}.${BACKUP_DOMAIN}+has+completed+which+contains+${BACKUP_FILE_COUNT}+files+and+is+${BACKUP_SIZE}+in+size.&color=red&message_format=text&notify=0&auth_token=${BACKUP_MSG_AUTHTOKEN}"  https://api.hipchat.com/v1/rooms/message > /dev/null

exit_function

###########################
# End
###########################
