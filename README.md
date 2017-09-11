# s3_backup_bash
S3 Backup Script written in bash

# Requirements:
 - AWS client installed and configured
 - AWS credentials or role assigned to instance
 - S3 Bucket and permissions to role

# Installation
 Script installs in: ```/usr/local/bin/backup.sh```
 
 Transform installs in: ```/usr/local/etc/backup_transform```
 
 Pre and Post backup scripts are optional and are installed in:
 
```
/usr/local/bin/pre_backup.sh  
/usr/local/bin/post_backup.sh
```

## Scheduling via Cron
To schedule a backup via cron, an entry like this one should be used:

``````

```
# minute   hour   dayOfMonth   Month   dayOfWeek   commandToRun
15         0      *            *       *           /usr/local/bin/backup.sh
```

## Transforms
The transform file defines what files and/or directories are backed up.

## Pre and Post Backup Scripts
Pre and Post backup scripts are custom scripts that are run before or after a backup.  
End users are responsible for writing these scripts to meet any custom needs such as stopping and restarting a database server, etc.

## AWS Permissions
The host or AWS instance will need access to the AWS bucket specificed.

This is most easily done in AWS with a role that provides access to the bucket.  However, configuring the AWS client with a set of keys will also work. 

