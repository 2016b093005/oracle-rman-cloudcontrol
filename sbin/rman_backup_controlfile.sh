#!/usr/bin/env bash
# ------------------------------------------------------------------------------------------------------------
# ----  Script Name: rman_backup_controlfile.sh
# ----  Versioninformation
# ----  Modification History:
# ----  Date,           Author,         Desc.,
# ----  2018-04-29,     J.Halwachs,     github creation 
# ----  INPUT:   Variables from callerscript or CloudControl 
# ----  OUTPUT:  logfile of the mainscript or CloudControl
# ----  DEFAULT: ORATAB, RMAN_LOGFILE, BACKUP_BASE, BACKUP_DIR_NAME, SKIP_FILE name
# ----  Short Description: RMANSCRIPT: Backup Oracle Database - Backup current controlfile
# ----                                          maybe on Dataguard Standby to sync. backupinformation
# ------------------------------------------------------------------------------------------------------------
# ---- BEFORE:
# ---- CONNECT SCRIPTS: /usr/local/connect/*.rman - connect scripts should exists
# ---- CALLER SCRIPTS:  /usr/local/sbin/*.rman - caller scripts should exists
# ---- RMAN SCRIPTS:    /usr/local/etc/rman/*.rman - rman scripts should exists
# ----
# ---- AFTER: verify logfiles 
# ------------------------------------------------------------------------------------------------------------

# ---- Long Description: For CloudControl usage 
# For CC use OS COMMANDS with multitaskjobs. Maybe for Dataguard sync. controlfile backupinformation. 
# TASKNAME/CONDITION: os command to call
  # /usr/local/sbin/rman_backup_controlfile.sh %SID% %%d_control_%%T_%%U 
# ------------------------------------------------------------------------------------------------------------


# Input
export ORACLE_SID=$1
export BACKUP_FORMAT=$2
export VARCOUNT=$#

# Variables
ORATAB=/etc/oratab
RMAN_LOGFILE=/var/log/rman/rman
BACKUP_BASE="/nfs-shared/backup"
BACKUP_DIR_NAME="database"
SKIP_FILE=/tmp/skip_rman
export PS_COUNT=`pstree -n|grep -i rman|grep -v sqlplus|grep -v logger|wc -l`
export PS_ORA_COUNT=`ps -ef|grep -E 'smon|pmon'|grep -v grep|wc -l`

# Prechecks
if [ $VARCOUNT -ne 2 ];then
 echo "Please provide ORACLE_SID and BACKUP_FORMAT - as input parameter. VARCOUNT=${VARCOUNT}";
 echo "example for BACKUP_FORMAT: %d_%s_%p_%T";
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
BACKUP_DIR="${BACKUP_BASE}/${ORACLE_SID}/${BACKUP_DIR_NAME}"

if [ ! -d "${BACKUP_DIR}" ] ; then
  echo "Please Create Backup Path ${BACKUP_DIR} !"
  echo "mkdir -p ${BACKUP_DIR}"
  exit 1;
else
  echo "Directory ${BACKUP_DIR} exists."
fi

# Source the correct environment
export ORAENV_ASK=NO
. $ORACLE_HOME/bin/oraenv -s

# RMAN Call
echo "Starting Backup with command"
echo "rman cmdfile=/usr/local/etc/rman/rman_backup_controlfile.rcv $ORACLE_SID \'${BACKUP_FORMAT}\' log ${RMAN_LOGFILE} append"
$ORACLE_HOME/bin/rman cmdfile=/usr/local/etc/rman/rman_backup_controlfile.rcv $ORACLE_SID \'${BACKUP_FORMAT}\' log ${RMAN_LOGFILE} append
