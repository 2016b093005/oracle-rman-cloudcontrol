#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------------------------------------
# ----  Script Name:  rman_backup_archivelog_cron.sh
# ----  Modification History:   
# ----  Date,           Author,         Desc.,                          
# ----  2018-04-29,     J.Halwachs,     github creation 
# ----  INPUT:  BACKUP_FORMAT, BACKUP_ARCHDEL
# ----  OUTPUT: see textfile and loggingfile or DEFAULT SYSLOG
# ----  DEFAULT: see default variable/value settings - see below 
# ----  Short Description: ORACLE BACKUP RMAN - Crontab script to backup the archivelogs and delete archivelogs until time sysdate-$BACKUP_ARCHDEL
# ------------------------------------------------------------------------------------------------------------
# ---- BEFORE:  LINUX LOGGING SCRIPT SHOULD exists - see below - and /var/log/$EXEC_USER dir should exits
# ----		FOR RAC - backup will run only on the node with the highest available instance number 
# ----          IMPORTANT !!! Please change MIN_DEL_DAYS to you needs - should be longer than intervall of L1 backups for rollforward. !!!
# ----          If there are old hung rman processes - please kill (see process check below).
# ----          /etc/oratab should contain Instance with ending Flag :Y and DB_NAME is one letter shorter. After reboot this will be changed by the RAC software.
# ----		CREATE DIRECTORY: /var/log/rman/rman # Change permissions to os user oracle
# ---- AFTER or TODOs:
# ----          Check syslog entries and/or /var/log/rman directory for logfiles. 
# ----          For 12c - dNFS needs separated archivelogs (not in FRA) - maybe some special additional archivelogdeletion handling is needed.
# ----          Use custom configuration file - example: DB_CONFIG_FILE="/etc/cmdb_oracle.json" 
# ----          Maybe enable backups if max. Cluster Instance is only mounted. ADD NOLOGGING CHECK
# ---- DOCKER	Create archivelog backupscript that contains the crontab call from SETUP.md. If SYSLOG is not enabled - use linux_logging.sh -n logfilename.
# ------------------------------------------------------------------------------------------------------------

# ---- Global packages or module integration
LOGSCRIPTLOC=/usr/local/sbin/linux_logging.sh

# ------------------------------------------------------------------------------------------------------------
# Begin MAIN PART
# ------------------------------------------------------------------------------------------------------------
function main {
  # CHANGE TO YOUR NEED - SYSLOG or LOGFILE 
  if [ -f "${LOGSCRIPTLOC}" ] ; then
    source ${LOGSCRIPTLOC} 
    #source ${LOGSCRIPTLOC} -n rman_backup_archivelog_cron 
  else
    echo "Logging Script under ${LOGSCRIPTLOC} not found"
    exit 1
  fi

  # Do some prechecks and set important vars
  prepare

  # Source the correct environment
  export ORAENV_ASK=NO
  . $ORACLE_HOME/bin/oraenv -s

  # RMAN Calls
  if [ "${INSTANCE_TYPE}" == "NOCLUSTER" ] ; then
    log 1 "BACKUP-RUN: Starting Backup - nocluster mode."
    log 1 "$ORACLE_HOME/bin/rman cmdfile=/usr/local/etc/rman/rman_backup_archivelog_cron.rcv $ORACLE_SID \'$BACKUP_FORMAT\' \'$BACKUP_ARCHDEL\' log ${RMAN_LOGFILE} append"
    $ORACLE_HOME/bin/rman cmdfile=/usr/local/etc/rman/rman_backup_archivelog_cron.rcv $ORACLE_SID \'$BACKUP_FORMAT\' \'$BACKUP_ARCHDEL\' log ${RMAN_LOGFILE} append
  elif [ "${INSTANCE_TYPE}" == "CLUSTER" ] ; then
    log 1 "BACKUP-RUN: Starting Backup - cluster mode."
    log 1 "$ORACLE_HOME/bin/rman cmdfile=/usr/local/etc/rman/rman_backup_archivelog_cron.rcv $ORACLE_DB \'$BACKUP_FORMAT\' \'$BACKUP_ARCHDEL\' log ${RMAN_LOGFILE} append"
    $ORACLE_HOME/bin/rman cmdfile=/usr/local/etc/rman/rman_backup_archivelog_cron.rcv $ORACLE_DB \'$BACKUP_FORMAT\' \'$BACKUP_ARCHDEL\' log ${RMAN_LOGFILE} append
  else
    log 3 "Could not start rman backup command. Database Upgrade ?"
    exit $E_WARN
  fi
  # Verify return code and exit
  if [ $? -eq 0 ]; then
    log 1 "**************** RMAN Backup finished with NO ERRORS - see next line  *******************"
    exit $OK
  else
    log 3 "**************** RMAN Backup finished with ERRORS - EXITCODE=$? - see next line !   *******************"
    exit $E_WARN
   fi

  # removelog function only needed if LOGFILE instead of SYSLOG is used
  #removelog 
}

# ------------------------------------------------------------------------------------------------------------
# INPUT/SCRIPT Variables
# ------------------------------------------------------------------------------------------------------------
export BACKUP_FORMAT=$2
export BACKUP_ARCHDEL=$4
export VARCOUNT=$#
export SCRIPT_NAME=$0

# ------------------------------------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------------------------------------
export BIN_BASE="/bin"
export SUPPORT_LIST='yourmail@yourdomain.com'
export SKIP_FILE=/tmp/skip_rman
export LOGNAME=rman_backup_archivelog_cron
export ORATAB=/etc/oratab
export MIN_DEL_DAYS=2
export RMAN_LOGFILE=/var/log/rman/rman
export BACKUP_BASE="/nfs-shared/backup"
export BACKUP_DIR_NAME="archivelog"
export BACKUP_OK='false'
export PS_COUNT=`pstree -n|grep -i rman|grep -v sqlplus|grep -v logger|wc -l`
export PS_ORA_COUNT=`ps -ef|grep -E 'smon|pmon'|grep -v grep|wc -l`
export USER=$(whoami)
# Compare valid related parameter. Maybe oracle version dependent in the future 
export DBTYPE_PRIMARY='PRIMARY'
export DBTYPE_STANDBY='STANDBY'
export ARCHIVELOG_ENABLED='STARTED'
export ARCHIVELOG_NOT_ENABLED='STOPPED'
export ARCH_BACKUP_SESSION_PATTERN='%rman%backup%arch%'
# SQL related parameter
export QUERY_ARCHIVER="select ARCHIVER FROM v\$instance;"
export QUERY_DBTYPE="SELECT upper(decode(instr(database_role,'${DBTYPE_PRIMARY}'), '1', 'PRIMARY', '0', 'STANDBY')) FROM v\$database;"
export QUERY_CLUSTER_ENABLED="SELECT upper(value) FROM v\$parameter WHERE lower(name) = 'cluster_database';"
export QUERY_CLUSTER_INST_IS_MAX="SELECT decode(max(ci.instance_number),i.instance_number,'TRUE','FALSE') FROM v\$instance i, gv\$instance ci GROUP BY i.instance_number;"
export QUERY_RMAN_ARCH_RUNNING="SELECT count(SPID) FROM V\$PROCESS p, V\$SESSION s WHERE p.ADDR = s.PADDR and lower(module) like '%rman%' and lower(CLIENT_INFO) like '${ARCH_BACKUP_SESSION_PATTERN}';"
export DBTYPE=''
export INSTANCE_TYPE=''
export ARCHIVELOG_STATE=''
export SPOOL_LOG_NAME=sqlplus
export SPOOL_FILE=/tmp/${SPOOL_LOG_NAME}.lst
# Exit codes
export OK=0
export E_INFO=1
export E_WARN=2
export E_CRITICAL=3
# Prevent parallel archivelog backups and wait some time
export WAIT_SEC=`echo $((RANDOM % 10+1))`
export WAIT_SEC_pc=$(echo "$WAIT_SEC*$PS_COUNT+1"|bc)
export WAIT_MS=`echo $((RANDOM % 10+1))`
export WAIT_TIME=`echo $WAIT_SEC_pc.$WAIT_MS`

# ------------------------------------------------------------------------------------------------------------
# prepare: Some prechecks, set Backup Path and start delay - before starting backup in main section
# ------------------------------------------------------------------------------------------------------------
function prepare {

  # Check - Skip Backups
  if [ -f ${SKIP_FILE} ];then
    log 1 "SKIP-CHECK: Skip Backups - File ${SKIP_FILE} exists - BACKUPS disabled !"
    exit $OK;
  fi 

  if [ "${USER}" != "oracle" ] ; then
    echo "Use oracle os user for this script"
    log 1 "OSUSER-CHECK: This script should be started as oracle os user"
    exit $E_WARN
  fi

  if [ "$PS_ORA_COUNT" -eq 0 ] ; then
    log 1 "DATABASE-CHECK: Oracle Database - seems not running according smon|pmon process check"
    exit $E_WARN
  fi
  
  if [ "$VARCOUNT" -eq 0 ] ; then
    usage
    exit $OK;
  fi

  # Check INPUT varcount => RMAN backupformat and archivelog delete "until sysdate - n days" (n should be > 2)
  if [ $VARCOUNT -ne 4 ];then
    echo "Please provide BACKUP_FORMAT and BACKUP_ARCHDEL as input parameter. VARCOUNT=${VARCOUNT}"
    echo "example: scriptname.sh %d_arch_%T_%U 2"
    echo "BACKUP_ARCHDEL in format sysdate-BACKUP_ARCHDEL. ATTENTION do not use less than 2 day for deletion or you must recreate the L0 Backup again or you change schedule of L1 more often. VARCOUNT=${VARCOUNT}"
    log 1 "Not enough Input Variables - see script usage"
    exit $OK;
  fi 

  # Exit if less than sysdate - 2 days for archivelog deletion is used - based on backup intervall of L1 backups
  if [ $BACKUP_ARCHDEL -lt $MIN_DEL_DAYS ] ; then
    log 3 "Please use min $MIN_DEL_DAYS for archivelog deletion timeframe !!"
    exit $E_INFO;
  fi
    
  # Check - if rman is already active
  if [ $PS_COUNT -gt 2 ];then
    log 3 "PROCESS-CHECK: Skip backup - to many rman processes found - check hung rman backup processes !"
    exit $E_CRITICAL;
  fi
 
  # Check if /etc/oratab exists
  if [ ! $ORATAB ] ; then
    log 3 "ORATAB-FILE-CHECK: $ORATAB file not found - script needed this to set ORACLE_SID and ORACLE_HOME env vars"
    exit $E_WARN;
  fi 
  
  # Get local ORACLE ENV details by parsing /etc/oratab
  # Format: SID:ORACLE_HOME_PATH:START_FLAG
  # START_FLAG used for Backup - verify set only once
  regex='^(\w)*:(/[a-zA-Z 0-9 _ .]*)*:Y' 

  # Parse /etc/oratab and set important env parameter for later oraenv script usage
  export ORACLE_SID=`egrep -E "$regex" $ORATAB|awk '{print $1}'|awk -F: '{print $1}'`
  export ORACLE_HOME=`egrep -E "$regex" $ORATAB|awk '{print $1}'|awk -F: '{print $2}'`
  export ORACLE_START=`egrep -E "$regex" $ORATAB|awk '{print $1}'|awk -F: '{print $3}'`

  # Check if more than one value/line for ORACLE_SID is returned and exit if true
  export wc_START=`echo $ORACLE_START|wc -w`

  if [ $wc_START -gt 1 ] || [ $wc_START -eq 0 ] ; then
    log 3 "ORATAB-FILE-CHECK: Some troubles in file $ORATAB - found $wc_START enabled SERVICES/entries - please verify that the last parameter is set to Y only for the database"
    exit $E_WARN;
  fi

  # ORACLE_DB used as cluster name for later backup path
  ORACLE_DB=`echo $ORACLE_SID|head -c -2`

  # try to prevent parallel starts
  log 1 "OTHER-PROCESS-CHECK: We found $PS_COUNT rman process. To prevent parallel starts. We will sleep $WAIT_TIME sek. for PROCESSID $$"
  sleep $WAIT_TIME
  
  # set important vars
  #isBackupArchRunning "${QUERY_RMAN_ARCH_RUNNING}" 
  archiverEnabled "${QUERY_ARCHIVER}"
  getDatabaseType "${QUERY_DBTYPE}"
  getInstanceType "${QUERY_CLUSTER_ENABLED}"

  # verify if backup is ok
  backupValid ${DBTYPE}
  BACKUP_OK=`echo $?`
  if [ $BACKUP_OK = 1 ] ; then
    log 1 "BACKUP-VALID-CHECK: Seems we are no valid host for oracle archivelog backups (STANDBY|NOT HIGHEST CLUSTERNODE)."
    exit $OK
  fi  

  # Set the backuppath and inform user to create path if it do not exists
  if [ "${INSTANCE_TYPE}" == "NOCLUSTER" ] ; then
    BACKUP_DIR="${BACKUP_BASE}/${ORACLE_SID}/${BACKUP_DIR_NAME}"
  elif [ "${INSTANCE_TYPE}" == "CLUSTER" ] ; then
    BACKUP_DIR="${BACKUP_BASE}/${ORACLE_DB}/${BACKUP_DIR_NAME}"
  fi

  if [ ! -d "${BACKUP_DIR}" ] ; then
    log 3 "BACKUP-PATH-CHECK: Please Create Backup Path ${BACKUP_DIR}."
    log 3 "BACKUP-PATH-CHECK: mkdir \-p ${BACKUP_DIR}"
    exit $E_WARN;
  else
    log 1 "BACKUP-PATH-CHECK: Directory ${BACKUP_DIR} exists."
  fi
}

# ------------------------------------------------------------------------------------------------------------
# databaseQuery: Function that takes an Query as INPUT PARAMETER and set the QUERY_RESULT
# ------------------------------------------------------------------------------------------------------------
function databaseQuery() {
  local query=$@
  local _SCRIPT_FUNC=$FUNCNAME
#  echo "Using Query: ${query}"
  query_output=`$ORACLE_HOME/bin/sqlplus -S / as sysdba << EOF

    SET HEAD OFF
    SET AUTOPRINT OFF
    SET TERMOUT OFF
    SET FEEDBACK OFF
    SET SERVEROUTPUT ON
    SPOOL  ${SPOOL_FILE}

    WHENEVER SQLERROR EXIT SQL.SQLCODE

    ${query}
EOF`
rc=$?
  if [[ $rc != 0 ]] ; then
    echo "QUERY-DATABASE: RDBMS exit code : $rc  "     | tee -a ${SPOOL_FILE}
    # mail prog not installed on all machines
    #cat ${SPOOL_FILE} | ${BIN_BASE}/mail -s "Script ${SCRIPT_NAME} failed on $_SCRIPT_FUNC with oracle return code $rc." $SUPPORT_LIST
    exit $E_WARN;
  else
    QUERY_RESULT="$(echo -e "${query_output}" | tr -d '[[:space:]]')"
  fi
}

# ------------------------------------------------------------------------------------------------------------
# DATABASE-QUERIES: get needed vars to compare 
# ------------------------------------------------------------------------------------------------------------
function archiverEnabled() {
  databaseQuery ${QUERY_ARCHIVER}
  ARCHIVELOG_STATE=${QUERY_RESULT}
}

function getDatabaseType() {
  databaseQuery ${QUERY_DBTYPE}
  DBTYPE=${QUERY_RESULT}
}

function getInstanceType() {
  databaseQuery ${QUERY_CLUSTER_ENABLED}
  if [ "${QUERY_RESULT}" = 'TRUE' ] ; then
    export INSTANCE_TYPE='CLUSTER'
  else
    export INSTANCE_TYPE='NOCLUSTER'
  fi
}

function isCluster() {
  databaseQuery ${QUERY_CLUSTER_ENABLED}
  CLUSTER_ENABLED=${QUERY_RESULT}
}

function isMaxClusterInstance() {
  databaseQuery ${QUERY_CLUSTER_INST_IS_MAX}
  CLUSTER_INST_IS_MAX=${QUERY_RESULT}
}

function isBackupArchRunning() {
  databaseQuery ${QUERY_RMAN_ARCH_RUNNING}
  BACKUP_ARCHIVELOG_STATE=${QUERY_RESULT}
}

# ------------------------------------------------------------------------------------------------------------
# backupValid: on single instance, on dataguard primary and on max. RAC instance   
# ------------------------------------------------------------------------------------------------------------
function backupValid() {
  isBackupArchRunning
  if [ "${BACKUP_ARCHIVELOG_STATE}" -gt 0 ] ; then
    log 2 "BACKUP-CHECK: ${BACKUP_ARCHIVELOG_STATE} backup session. Seems Backup of Archivelog is currently running. Wait until next run."
    exit $E_WARN;
  fi 
  if [ "${ARCHIVELOG_STATE}" = ${ARCHIVELOG_NOT_ENABLED} ] ; then
    log 1 "ARCHIVELOG-CHECK: ${ARCHIVELOG_STATE}. Seems Archivelog Mode IS NOT enabled - Backup of Archivelogs not valid - use export or cold backups instead."
    return $E_INFO
  elif [ "${ARCHIVELOG_STATE}" = ${ARCHIVELOG_ENABLED} ]
  then
    log 1 "ARCHIVELOG-CHECK: ${ARCHIVELOG_STATE}. Seems Archivelog Mode is enabled or archiver process is started - Archivelog Backup is valid."
  else
    log 3 "ARCHIVELOG-CHECK: ${ARCHIVELOG_STATE}. Archivelog Mode string from database query is not valid."
    exit $E_WARN;
  fi
  if  [ ${DBTYPE} = ${DBTYPE_PRIMARY} ] && [ $E_WARN != 1 ]
  then
    log 1 "DATAGUARD-CHECK: ${DBTYPE}. Database is valid for Archivelog Backup. Now let us check if it is a Cluster Database."
    isCluster
    if [ ${CLUSTER_ENABLED} = 'TRUE' ] ; then
      isMaxClusterInstance
      log 1 "CLUSTER-CHECK: $CLUSTER_INST_IS_MAX. Seems Cluster Database is enabled."
      if [ $CLUSTER_INST_IS_MAX = 'TRUE' ] ; then
        log 1 "CLUSTER-CHECK: $CLUSTER_INST_IS_MAX. Seems Cluster Instance is max Instance for backup. Backup of Archivelogs valid."
        return $OK
      else
        log 1 "CLUSTER-CHECK: Seems we are not on the max Instance in Cluster for archivelog backup. Nothing further todo."
        return $E_INFO
      fi
    else
      log 1 "CLUSTER-CHECK: No Cluster Database. Local database is a normal database."
      return $OK
    fi
  elif [ ${DBTYPE} = ${DBTYPE_STANDBY} ]
  then
    log 1 "DATAGUARD-CHECK: ${QUERY_RESULT}. Archivelog Backup on Standby Database is not valid. Nothing further todo"
    return $E_INFO
  else
    log 3 "DATAGUARD-CHECK: Query for Database Type returns unkown value !"
    exit $E_WARN;
  fi
}

# ------------------------------------------------------------------------------------------------------------
# Get commandline options
# ------------------------------------------------------------------------------------------------------------
# see http://home.comcast.net/~dwm042/Standards.htm
function usage {
  echo "$MYSCRIPT [-hq] [-f format_string] [-d days] arguments
          Arguments:
                  -h : show this message on screen
                  -q : show this message on screen
                  -f : format_string; example \%d_arch_\%T_\%U
                  -d : delete backups older than given days
  "
  exit $OK;
}
MYSCRIPT=${0##*/}
while getopts "hqf:d:" Arg ; do
  case $Arg in
    h) usage ;;
    q) usage ;;
    f) BACKUP_FORMAT="$OPTARG" ;;
    d) BACKUP_ARCHDEL="$OPTARG" ;;
    *) usage ;;
  esac
done
shift $(( OPTIND - 1 ))

# ------------------------------------------------------------------------------------------------------------
# std main call
# ------------------------------------------------------------------------------------------------------------
main
