#!/usr/bin/env bash
#
# Owner: J. Halwachs
# ------------------------------------------------------------------------------------------------------------
# ----  Script Name:  linux_logging.sh
# ----  Modification History:
# ----  Date,           Author,         Desc.,
# ----  2018-04-29,     J.Halwachs,     github creation
# ----  INPUT:   logname of the mainscript, example oracle_server
# ----  OUTPUT:  logfile of the mainscript
# ----  DEFAULT: DEFAULT_LOG_NAME - see below
# ----  Short Description: global logging for linux scripts - for example oracle software
# ----                     example call for main script "log 1 "*** install software - oracle_server - `date "format"`"
# ------------------------------------------------------------------------------------------------------------
# ---- BEFORE:
# ---- 		PATH:		/var/log/${USER} - if not run script as root create this user directory 
# ---- 		SCRIPTLOCATION: /usr/local/sbin
# ----
# ---- AFTER: Todo's
# ---- check the output from this script inside logfile or syslog
# ------------------------------------------------------------------------------------------------------------

# ---- Global packages or module integration


# ------------------------------------------------------------------------------------------------------------
# INPUT/SCRIPT Variables
# ------------------------------------------------------------------------------------------------------------
SWLOG_NAME=$2

# ------------------------------------------------------------------------------------------------------------
# init base variables
# ------------------------------------------------------------------------------------------------------------
# DEFAULT LOG FACILITY for oracle scripts
BIN_USR_BASE="/usr/bin"
LOG_FACILITY="local4"
SCRIPT_LOC="$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"
SCRIPT_PATH=`dirname $SCRIPT_LOC`
SCRIPT=`basename $SCRIPT_LOC`
USER=$(whoami)
SWLOG_BASE="/var/log/${USER}"

SWLOG_EXT=".log"
DATE_FORMAT='+%Y-%m-%d %H:%M:%S'

# ------------------------------------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------------------------------------
SWLOG=${SWLOG_BASE}/${SWLOG_NAME}${SWLOG_EXT}

#CURRDIR=`dirname $0`
#HOST=`hostname | cut -f1 -d.`
#NETLOC=`host $HOST |awk '{print $1}' | cut -f2 -d.`

# ------------------------------------------------------------------------------------------------------------
# Get commandline options
# ------------------------------------------------------------------------------------------------------------
function usage {
  echo "$MYSCRIPT [-hq] [-n logfilename ] arguments
          Create $SWLOG_BASE directory if you are not root os user.
          Arguments:
                  -h : show this message on screen
                  -q : show this message on screen
                  -n : an argument that expects a logfilename without file extension. default=syslog; example => -n oracle_server
  "
  exit 0
}
MYSCRIPT=${0##*/}
while getopts "hqn:" Arg ; do
  case $Arg in
    h) usage ;;
    q) usage ;;
    n) SWLOG_NAME="$OPTARG" ;;
    *) usage ;;
  esac
done
shift $(( OPTIND - 1 ))

# ------------------------------------------------------------------------------------------------------------
# prechecks
# ------------------------------------------------------------------------------------------------------------
if [ -z "$SWLOG_NAME" ]; then
  echo  "no parameter given for logging - use instead SYSLOG !"
  # USE SYSLOG as default logging if no INPUTPARAMETER  (-n name)
  DEFAULT_LOG_NAME=SYSLOG
  SWLOG_NAME=${DEFAULT_LOG_NAME}
  SWLOG=${SWLOG_NAME}
fi
if [ "$DEFAULT_LOG_NAME" != "SYSLOG" ] && [ ! -f "$SWLOG" ]; then
  if [ ! -d ${SWLOG_BASE} ] && [ "${SWLOG_BASE_OWNER}" != "root" ] ; then
    echo "Please create log directory ${SWLOG_BASE} as os user ${USER} and change permission to this user."
    exit 1
  elif [ "${SWLOG_BASE_OWNER}" = "root" ]; then
    echo "Create directory ${SWLOG_BASE} as user $USER."
    mkdir -p ${SWLOG_BASE}
  else
    SWLOG_BASE_OWNER=$(stat -c '%U' ${SWLOG_BASE})
    if [ "${SWLOG_BASE_OWNER}" != "${USER}" ]; then
      echo "Owner of directory ${SWLOG_BASE} is os user ${SWLOG_BASE_OWNER} change this to os user ${USER}."
      exit 1
    else
      echo "Create logfile ${SWLOG} for user ${USER} and change permissions to 750."
      touch ${SWLOG}
      chmod 750 ${SWLOG}
    fi
  fi
fi


##############################################################################################################
# ------------------------------------------------------------------------------------------------------------
# sub log & removelog -  for logging of script or the software or patch installation
# ------------------------------------------------------------------------------------------------------------
function log {
  LOG_DATE=`date "${DATE_FORMAT}"`
  USER=`eval whoami`
  if [ "$1" -eq "1" ] ; then
     SEV=info
  elif [ "$1" -eq "2" ] ; then
     SEV=warning
  elif [ "$1" -eq "3" ] ; then
     SEV=error
  elif [ "$1" -eq "4" ] ; then
     SEV=crit
  else
     SEV=notice
  fi
if [ "$DEFAULT_LOG_NAME" != "SYSLOG" ]; then
    if [ "$1" -lt "3" ] ; then
      echo "${LOG_DATE} ; COMMAND=${SCRIPT} ; USER=$USER ; TAG=ORASCRIPT ; [LOGFILE] ; "["$SEV"]" "MSG=""""$2""" ; "PATH="${SCRIPT_PATH}"| tee -a "${SWLOG}"
    else
      echo "${LOG_DATE} ; COMMAND=${SCRIPT} ; USER=$USER ; TAG=ORASCRIPT ; [LOGFILE] ; "["$SEV"]" "MSG=""""$2""" ; "PATH="${SCRIPT_PATH}"| tee -a "${SWLOG}.err"
    fi
  else
    #-------------------------------
    # to enable syslog logging and redirect stderr and stdout to syslog
    #-------------------------------
    TAG="COMMAND=${SCRIPT} ; USER=$USER ; TAG=ORASCRIPT ; "["${LOG_FACILITY}"]" ; "["$SEV"]" "MSG=""\""$2"\"" ; "PATH="${SCRIPT_PATH}"
    LOG_FACLEV=${LOG_FACILITY}"."${SEV}
    LOG_TOPIC=${SCRIPT}
    LOG_TOPIC_OUT="stdout[$$] ${TAG}"
    LOG_TOPIC_ERR="stderr[$$] ${TAG}"
    # LOG STDOUT to SYSLOG and TMPLOG file (see above)
    exec 3>&1> >(${BIN_USR_BASE}/logger -p "${LOG_FACILITY}"."info" -t "$LOG_TOPIC_OUT")
    # LOG STDERR to SYSLOG and TMPLOG file (see above)
    exec 2> >(${BIN_USR_BASE}/logger -p "${LOG_FACILITY}"."error" -t "$LOG_TOPIC_ERR")

    # NORMAL LOG entries for SYSLOGS
    ${BIN_USR_BASE}/logger -p ${LOG_FACLEV} -i -t$TAG
fi
}

function removelog {
if [ ! -z "${SWLOG}" ]; then
  echo "start remove of logfile= ${SWLOG}"
  rm "${SWLOG}"
  rm "${SWLOG}.err"
fi
}

#
# ------------------------------------------------------------------------------------------------------------
# Begin MAIN PART
# ------------------------------------------------------------------------------------------------------------
##############################################################################################################

log 1 "******************************************************************"
log 1 "*** start logging - for script ${SCRIPT} - use - ${SWLOG}"
