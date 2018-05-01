#!/usr/bin/env bash                                                                                                                                                                          
# ------------------------------------------------------------------------------------------------------------                                                                               
# ----  Script Name: rman_backup_database_inc.sh                                                                                                                                       
# ----  Versioninformation                                                                                                                                                                   
# ----  Modification History:                                                                                                                                                                
# ----  Date,           Author,         Desc.,                                                                                                                                               
# ----  2018-04-29,     J.Halwachs,     github creation                                                                                                                                      
# ----  INPUT:   Variables from callerscript or CloudControl                                                                                                                                 
# ----  OUTPUT:  logfile of the mainscript or CloudControl                                                                                                                                   
# ----  DEFAULT: ORATAB, BACKUP_BASE, part of BACKUP_TAG, RMAN_SCRIPT_BASE_PATH, SKIP_FILE name
# ----  Short Description: RMANSCRIPT: Backup Oracle Database - INCREMENTAL STRATEGY L1/L0  without archivelogs                                                                             
# ------------------------------------------------------------------------------------------------------------                                                                               
# ---- BEFORE:          IF USED WITH CRONTAB ADD FULL PATH TO EACH CALL                                                                                                                      
# ---- ORATAB:          no hacks inside this file and only one database instance inside and startflag=Y 
# ---- BACKUP PATH:     /nfs-shared/backup/%SID%/database/ - backup mountpoint should exist                                                                                                  
# ---- CONNECT SCRIPTS: /usr/local/connect/*.rman - connect scripts should exists                                                                                                            
# ---- RMAN SCRIPTS:    /usr/local/etc/rman/*.rman - rman scripts should exists                                                                                                              
# ---- CALLER SCRIPTS:  /usr/local/sbin/*.sh - caller scripts should exists                                                                                                                  
# ----                                                                                                                                                                                       
# ---- AFTER: verify logfiles                                                                                                                                                                
# ------------------------------------------------------------------------------------------------------------

# ---- Long Description: For CloudControl usage - example - see DBname for PATH used for RAC
# For CC use OS COMMANDS with multitaskjobs and change the below NFS backupdirs
# TASKNAME/CONDITION: os command to call
 # CHECK_DIR/ALWAYS: /bin/ls -d /nfs-shared/backup/%SID%/database
   # CREATE_DIR_ON_ERROR/ON_FAILURE: /bin/mkdir -p /nfs-shared/backup/%SID%/database
 # BACKUP_DB_COMP_L0: /usr/local/sbin/rman_backup_database_inc.sh %SID% database 0 " " AS COMPRESSED BACKUPSET BACKUP_INC_L0
   # DELETE_ARCHIVELOGS_40DAYS_OLD/ON_SUCCESS: /usr/local/sbin/rman_delete_backup.sh %SID% 40
# ------------------------------------------------------------------------------------------------------------

# Input
export ORACLE_SID=$1
export BACKUP_DIR=$2
export BACKUP_LEVEL=$3
export BACKUP_CUMULATIV=$4
export BACKUP_AS=$5
export BACKUP_COMP=$6
export BACKUP_TYPE=$7
export BACKUP_TAG=$8_`date +"%Y%m%d%H%M%S"`
export VARCOUNT=$#

# Variables
ORATAB=/etc/oratab
BACKUP_BASE="/nfs-shared/backup"
SKIP_FILE=/tmp/skip_rman
export PS_COUNT=`pstree -n|grep -i rman|grep -v sqlplus|grep -v logger|wc -l`
export PS_ORA_COUNT=`ps -ef|grep -E 'smon|pmon'|grep -v grep|wc -l`

# Prechecks
if [ $VARCOUNT -ne 8 ];then
 echo "Please provide at least ORACLE_SID,BACKUP_DIR, BACKUP_LEVEL, BACKUP_CUMULATIV, BACKUP_AS, BACKUP_COMP, BACKUP_TYPE, BACKUP_TAG is input vars. VARCOUNT=${VARCOUNT}";
 echo "compressed - level 0: scriptname.sh DBSID database 0 \" \" AS COMPRESSED BACKUPSET DATABASE_INC"
 echo "uncompressed - level 0: scriptname.sh DBSID database 0 \" \" \" \" \" \" \" \" DATABASE_INC"
 echo "compressed - level 1: scriptname.sh DBSID database 1 \" \" AS COMPRESSED BACKUPSET DATABASE_INC"
 echo "uncompressed - level 1: scriptname.sh DBSID database 1 \" \" \" \" \" \" \" \" DATABASE_INC"
echo "compressed - level 1c: scriptname.sh DBSID database 1 cumulative AS COMPRESSED BACKUPSET DATABASE_INC"
 echo "uncompressed - level 1c: scriptname.sh DBSID database 1 cumulative \" \" \" \" \" \" DATABASE_INC"
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
echo "rman cmdfile=/usr/local/etc/rman/rman_backup_database_inc.rcv $ORACLE_SID \"$BACKUP_DIR\" \"$BACKUP_LEVEL\" \"$BACKUP_CUMULATIV\" \"$BACKUP_AS\" \"$BACKUP_COMP\" \"$BACKUP_TYPE\" \"$BACKUP_TAG\" "
rman cmdfile=/usr/local/etc/rman/rman_backup_database_inc.rcv $ORACLE_SID \"$BACKUP_DIR\" \"$BACKUP_LEVEL\" \"$BACKUP_CUMULATIV\" \"$BACKUP_AS\" \"$BACKUP_COMP\" \"$BACKUP_TYPE\" \"$BACKUP_TAG\"
