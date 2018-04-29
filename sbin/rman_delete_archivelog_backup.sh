#!/usr/bin/env bash
# ------------------------------------------------------------------------------------------------------------
# ----  Script Name: rman_delete_archivelog_backup.sh 
# ----  Versioninformation
# ----  Modification History:
# ----  Date,           Author,         Desc.,
# ----  2018-04-29,     J.Halwachs,     github creation 
# ----  INPUT:   Variables from callerscript or CloudControl 
# ----  OUTPUT:  logfile of the mainscript or CloudControl
# ----  DEFAULT: ORATAB, BACKUP_BASE, part of BACKUP_TAG, RMAN_SCRIPT_BASE_PATH 
# ----  Short Description: RMANSCRIPT: Backup Oracle Database - delete archivelog backups older than n days 
# ------------------------------------------------------------------------------------------------------------
# ---- BEFORE:          IF USED WITH CRONTAB ADD FULL PATH TO EACH CALL
# ---- ORATAB:          no hacks inside this file and only one database instance inside and startflag=Y
# ---- CONNECT SCRIPTS: /usr/local/connect/*.rman - connect scripts should exists
# ---- RMAN SCRIPTS:    /usr/local/etc/rman/*.rman - rman scripts should exists
# ---- CALLER SCRIPTS:  /usr/local/sbin/*.sh - caller scripts should exists
# ----
# ---- AFTER: verify logfiles 
# ------------------------------------------------------------------------------------------------------------

# ---- Long Description: For CloudControl usage - maybe in combination with FULL BACKUPS
# For CC use OS COMMANDS with multitaskjobs.INFO: if used in CloudControl in combination delete only ON_SUCCESS
# TASKNAME/CONDITION: os command to call
  # DELETE_ARCHIVELOGS_40DAYS_OLD/ON_SUCCESS: /usr/local/sbin/rman_delete_archivelog_backup.sh %SID% 40
# ------------------------------------------------------------------------------------------------------------

# INPUT
export ORACLE_SID=$1
export DELETE_UNTIL_DAYS=$2
export VARCOUNT=$#

# Variables
export SCRIPT=${0}
export RMAN_SCRIPT_BASE_PATH=/usr/local/etc/rman
export ORATAB=/etc/oratab
export BACKUP_BASE="/nfs-shared/backup"
export SKIP_FILE=/tmp/skip_rman

export PS_COUNT=`pstree -n|grep -i rman|grep -v sqlplus|grep -v logger|wc -l`
export PS_ORA_COUNT=`ps -ef|grep -E 'smon|pmon'|grep -v grep|wc -l`

# Prechecks
if [ $VARCOUNT -ne 2 ];then
 echo "Please provide ORACLE_SID and DELETE_UNTIL_DAYS in days as input parameter. VARCOUNT=${VARCOUNT}";
 exit 1;
fi

# Check - Skip Backups
if [ -f ${SKIP_FILE} ];then
  echo "Skip Backups - File ${SKIP_FILE} exists !"
  exit 0;
fi

# Check - if rman is already active
if [ $PS_COUNT -gt 3 ];then
  echo "PROCESS-CHECK: To many rman processes found - check hung rman backup processes !"
  exit 1;
fi

# Check if database is running
if [ "$PS_ORA_COUNT" -eq 0 ] ; then
  echo "DATABASE-CHECK: Oracle Database - seems not running according smon|pmon process check !"
  exit 1;
fi

# Check if /etc/oratab exists
if [ ! $ORATAB ] ; then
  echo "$ORATAB not found"
  exit 1;
fi

# Get local ORACLE ENV details by parsing /etc/oratab
# This works only if there are no manual hacks inside and only one database exists !!
# Format: SID:ORACLE_HOME_PATH:START_FLAG
# START_FLAG used for Backup - verify set only once
regex='^(\w)*:(/[a-zA-Z 0-9 .]*)*:Y' 

# Parse /etc/oratab and set important env parameter for later oraenv script usage
ORACLE_SID=`egrep -E "$regex" $ORATAB|awk '{print $1}'|awk -F: '{print $1}'`
ORACLE_HOME=`egrep -E "$regex" $ORATAB|awk '{print $1}'|awk -F: '{print $2}'`
ORACLE_START=`egrep -E "$regex" $ORATAB|awk '{print $1}'|awk -F: '{print $3}'`


# Check if more than one value/line for ORACLE_SID is returned and exit if true
export wc_SID=`echo $ORACLE_SID|wc -w`

if [ $wc_SID -gt 1 ] ; then
  echo "Some troubles in file $ORATAB - found $wc_SID enabled SERVICES/entries - please verify that the last parameter is set to Y only for the database"
  exit 1;
fi

# Source the correct environment
export ORAENV_ASK=NO
. oraenv

# RMAN Call
echo "rman cmdfile=${RMAN_SCRIPT_BASE_PATH}/rman_delete_archivelog_backup.rcv $ORACLE_SID \'$DELETE_UNTIL_DAYS\' "
rman cmdfile=${RMAN_SCRIPT_BASE_PATH}/rman_delete_archivelog_backup.rcv $ORACLE_SID \'$DELETE_UNTIL_DAYS\'
