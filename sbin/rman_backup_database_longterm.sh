#!/usr/bin/env bash
# ------------------------------------------------------------------------------------------------------------
# ----  Script Name: rman_backup_database_longterm.rcv 
# ----  Versioninformation
# ----  Modification History:
# ----  Date,           Author,         Desc.,
# ----  2018-04-29,     J.Halwachs,     github creation 
# ----  INPUT:   Variables from callerscript or CloudControl 
# ----  OUTPUT:  logfile of the mainscript or CloudControl
# ----  DEFAULT: ORATAB, BACKUP_BASE, part of BACKUP_TAG, RMAN_SCRIPT_BASE_PATH 
# ----  Short Description: RMANSCRIPT: Backup Oracle Database - LONGTERM/FULL DATABASE BACKUP without archivelogs 
# ------------------------------------------------------------------------------------------------------------
# ---- BEFORE:		IF USED WITH CRONTAB ADD FULL PATH TO EACH CALL
# ---- ORATAB:		no hacks inside this file and only one database instance inside and startflag=Y
# ---- BACKUP PATH:     /nfs-shared/backup/%SID%/longterm/ - backup mountpoint should exist
# ---- CONNECT SCRIPTS: /usr/local/connect/*.rman - connect scripts should exists
# ---- RMAN SCRIPTS:    /usr/local/etc/rman/*.rman - rman scripts should exists
# ---- CALLER SCRIPTS:  /usr/local/sbin/*.sh - caller scripts should exists
# ----
# ---- AFTER: verify logfiles 
# ------------------------------------------------------------------------------------------------------------

# ---- Long Description: For CloudControl usage 
# For CC use OS COMMANDS with multitaskjobs and change the below NFS backupdirs
# TASKNAME/CONDITION: os command to call
 # CHECK_DIR_LONGTERM/ALWAYS: /bin/ls -d /nfs-shared/backup/%SID%/longterm/  
   # CREATE_DIR_LONGTERM_ON_ERROR/ON_FAILURE: /bin/mkdir -p /nfs-shared/backup/%SID%/longterm
 # BACKUP_DB_COMP_LONGTERM/ALWAYS: /usr/local/sbin/rman_backup_database_longterm.sh %SID% longterm AS COMPRESSED BACKUPSET LONGTERM 186
   # DELETE_BACKUP_40DAYS_OLD/ON_SUCCESS: /usr/local/sbin/rman_delete_backup.sh %SID% 40
# ------------------------------------------------------------------------------------------------------------

# INPUT
export ORACLE_SID=$1
export BACKUP_DIR=$2
export BACKUP_AS=$3
export BACKUP_COMP=$4
export BACKUP_TYPE=$5
export BACKUP_TAG=$6_`date +"%Y%m%d%H%M%S"`
export BACKUP_KEEPTIME=$7

# Variables
export VARCOUNT=$#
export SCRIPT=${0}
export RMAN_SCRIPT_BASE_PATH=/usr/local/etc/rman
export ORATAB=/etc/oratab
export BACKUP_BASE="/nfs-shared/backup"
export SKIP_FILE=/tmp/skip_rman

export PS_COUNT=`pstree -n|grep -i rman|grep -v sqlplus|grep -v logger|wc -l`
export PS_ORA_COUNT=`ps -ef|grep -E 'smon|pmon'|grep -v grep|wc -l`

## Prechecks
if [ $VARCOUNT -ne 7 ];then
 echo "Please provide at least ORACLE_SID, BACKUP_DIR, BACKUP_AS, BACKUP_COMP, BACKUP_TYPE, BACKUP_TAG, BACKUP_KEEPTIME as input vars. VARCOUNT=${VARCOUNT}";
 echo ""
 echo "compressed:    ${SCRIPT} ORACLESID longterm AS COMPRESSED BACKUPSET LONGTERM 186"
 echo "uncompressed:  ${SCRIPT} ORACLESID longterm \" \" \" \" \" \" LONGTERM 186"
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


# Check if more than one value/line for ORACLE_SID is returned and exit if true - as active flag for backups and db startup
export wc_SID=`echo $ORACLE_SID|wc -w`

if [ $wc_SID -gt 1 ] ; then
  echo "Some troubles in file $ORATAB - found $wc_SID enabled SERVICES/entries - please verify that the last parameter is set to Y only for the database"
  exit 1;
fi

# Set the backuppath and create if this path do not exists
BACKUP_FULL_DIR="${BACKUP_BASE}/${ORACLE_SID}/${BACKUP_DIR}"

if [ ! -d "${BACKUP_FULL_DIR}" ] ; then
  echo "Please Create Backup Path ${BACKUP_FULL_DIR} !"
  echo "mkdir -p ${BACKUP_FULL_DIR}"
  exit 1;
else
  echo "Directory ${BACKUP_FULL_DIR} exists."
fi

# Source the correct environment
export ORAENV_ASK=NO
. oraenv

# RMAN Call
echo "rman cmdfile=${RMAN_SCRIPT_BASE_PATH}/rman_backup_database_longterm.rcv $ORACLE_SID \"$BACKUP_DIR\" \"$BACKUP_AS\" \"$BACKUP_COMP\" \"$BACKUP_TYPE\" \"$BACKUP_TAG\" \"$BACKUP_KEEPTIME\" "
rman cmdfile=${RMAN_SCRIPT_BASE_PATH}/rman_backup_database_longterm.rcv $ORACLE_SID \"$BACKUP_DIR\" \"$BACKUP_AS\" \"$BACKUP_COMP\" \"$BACKUP_TYPE\" \"$BACKUP_TAG\" \"$BACKUP_KEEPTIME\"
