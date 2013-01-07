#!/bin/bash

#
# Copyright (C) 2005  James Bly
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
# 

# Backup command, creates gzip file with some exclusions
BACKUP_CMD="tar czfX"
BACKUP_DIR=/var/backup
BACKUP_FILE=`hostname`-`/bin/date +%H%M_%m_%d_%Y`.tgz
OLD_LOG_DIR=/var/oldlogs
EXCLUDE_FILE=exclude-list
CPDIR=/opt/CPshrd-R55
SENDMAIL=/opt/CPfw1-R55/bin/sendmail
SENDMAIL_HOST=smtp.domain.com
SENDMAIL_FROM=firewall@domain.com
SENDMAIL_TO=firewall@domain.com
BACKUP_ERROR="Unknown Error"

# Source the Check Point profile for library settings
. $CPDIR/tmp/.CPprofile.sh

SSH_BACKUP_USER="cpbuser"
SSH_BACKUP_HOST="myhost.domain.com"
SSH_BACKUP_DIR="/where/to/put/files/"

FILES_TO_BACKUP="/etc\
                 /home\
                 /var/backup\
                 $CPDIR/registry\
                 $CPDIR/conf\
                 $CPDIR/database\
                 $FWDIR/conf\
                 $FWDIR/database\
                 $FWDIR/state\
                 /var/spool/cron\
                 /var/opt/CPfw1-R55\
                 /var/opt/CPshrd-R55/conf\
                 /var/net-snmp\
                 /var/opt/CPshrd-R55/registry"

# Our crash-bang error out
crash() {
        echo -e "Firewall backup for `hostname` failed!\n\nError was: $BACKUP_ERROR" | $SENDMAIL  \
                -t $SENDMAIL_HOST -s "Backup Failure: `hostname`" -f $SENDMAIL_FROM $SENDMAIL_TO
        echo "Error: $BACKUP_ERROR"
        cleanup
        exit;
}

# Our clean up function
cleanup() {
        rm $BACKUP_DIR/$BACKUP_FILE > /dev/null 2>&1
        rm $BACKUP_DIR/$EXCLUDE_FILE > /dev/null 2>&1
}

# Check our staging
if [ ! -d $BACKUP_DIR ] ; then
        mkdir $BACKUP_DIR > /dev/null 2>&1
        if [ ! -d $BACKUP_DIR ] ; then
                BACKUP_ERROR="Could not create backup directory!"
                crash
        fi
fi

# Take-over necessary files
if [ -f $BACKUP_DIR/$BACKUP_FILE ] ; then
        rm -f $BACKUP_DIR/$BACKUP_FILE > /dev/null 2>&1
fi
touch $BACKUP_DIR/$BACKUP_FILE

if [ -f $BACKUP_DIR/$EXCLUDE_FILE ] ; then
        rm -f $EXCLUDE_FILE > /dev/null 2>&1
fi
touch $BACKUP_DIR/$EXCLUDE_FILE

# Switch the old log
if [ "$1" == "rotate" ] ; then
        $FWDIR/bin/fw logswitch
fi

# Start by moving all old log files.
if [ ! -d $OLD_LOG_DIR ] ; then
        mkdir $OLD_LOG_DIR > /dev/null 2>&1
        if [ ! -d $OLD_LOG_DIR ] ; then
                BACKUP_ERROR="Could not create old log directory!"
                crash
        fi
fi
find /var/opt/CPfw1-R55/log -name "*.log*" -mtime +14 -exec mv {} $OLD_LOG_DIR \;

# Setup the exclude filter
# Remove the log line if you want to backup log files
FILES_TO_EXCLUDE="*.o\
                  /var/opt/CPfw1-R55/log/*
                  $EXCLUDE_FILE\
                  $BACKUP_FILE"

FILES_TO_EXCLUDE=`echo $FILES_TO_EXCLUDE | sed 's/ /\\\\n/g'`
echo -e $FILES_TO_EXCLUDE > $BACKUP_DIR/$EXCLUDE_FILE

# Run the backup
$BACKUP_CMD $BACKUP_DIR/$BACKUP_FILE $BACKUP_DIR/$EXCLUDE_FILE $FILES_TO_BACKUP > /dev/null 2>&1
if [ ! -f $BACKUP_DIR/$BACKUP_FILE ] ; then
        BACKUP_ERROR="Could not create the backup file!"
        crash
fi

# Transfer the backup and log its md5sum
scp $BACKUP_DIR/$BACKUP_FILE ${SSH_BACKUP_USER}@${SSH_BACKUP_HOST}:${SSH_BACKUP_DIR} > /dev/null 2>&1
if [ ! $? == 0 ] ; then
        BACKUP_ERROR="Could not copy the backup file to the server!"
        rm $BACKUP_DIR/$BACKUP_FILE
        crash
fi

# Log the results
MD5SUM=`/usr/bin/md5sum $BACKUP_DIR/$BACKUP_FILE | awk '{ print $1; }'`
/usr/bin/logger "BACKUP: ${BACKUP_FILE} created with md5sum ${MD5SUM}"

cleanup
