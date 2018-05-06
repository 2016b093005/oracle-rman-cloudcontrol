# Backupscript for Oracle Database with RMAN

## State of Repository: Major Scripts added

## USAGE
USE SCRIPTS AT YOUR OWN RISK and always validate BACKUP/RESTORE SCRIPTS in DEVELOPMENT ENVIRONMENTS specially for new Oracle Versions or infrastructure changes and change scripts to your needs !! Verify if you have license for oracle database - maybe also for backup compression.  
**IMPORTANT**: Tested with RHEL 6/7 and Oracle Database 11 and 12.1 with SINGLE INSTANCE per virtual server (or container).  
You can use the flexible **rman scripts only** or in **combination with the simple shell scripts**.  
**YOU ARE WELCOME TO IMPROVE THIS REPOSITORY.**  

## Description
This rman/shell scripts could be used on command line on Linux OS and via Oracle CloudControl (call linux shell scripts)  
to backup an oracle database (single instance/RAC or dataguard) to mounted NFS share.  

This scripts follow the KISS concept (keep it simple and stupid) with all advantages and disadvantages - and needs some
work for maintenance and setup.  
IMPROVEMENTS: GLOBALIZE variable section and pre check scripts.     
(Maybe verify new feature max. parallel jobs if scheduled via CloudControl.)  
Archivelogs should be backuped via cron or maybe use CHRONOS Job scheduler.  

## Repository Information
./sbin      => contains an example linux shell caller scripts  
./etc/rman  => contains the very flexible rman scripts with many variables inside  
./connect   => contains an example for rman connect to the database and catalog - should be edited and protected
./tests     => for testing

## BACKUP

### FULL BACKUP LONGTERM - example
```
INFO: Backup of database via CloudControl to NFS and keep 186 days - maybe for every 2 weeks.

TASKS (all OS COMMANDS)
CHECK_DIR_LONGTERM                          => ALWAYS
    	CREATE_DIR_LONGTERM_ON_ERROR        => ON_FAILURE
BACKUP_DB_COMP_LONGTERM                     => ALWAYS
         DELETE_ARCH_BACKUP_40DAYS_OLD      => ON SUCCESS
         

CHECK_DIR_LONGTERM 
/bin/ls -d /nfs-shared/backup/%SID%/longterm/   

CREATE_DIR_LONGTERM_ON_ERROR
/bin/mkdir -p /nfs-shared/backup/%SID%/longterm

BACKUP_DB_COMP_LONGTERM
/usr/local/sbin/rman_backup_database_longterm.sh %SID% longterm AS COMPRESSED BACKUPSET LONGTERM 186

DELETE_ARCH_BACKUP_40DAYS_OLD
/usr/local/sbin/rman_delete_archivelog_backup.sh %SID% 40
```

### CRON: ARCHIVELOG BACKUP - example
```
Requires LINUX LOGGING Script: /usr/local/sbin/linux_logging.sh
CRONTAB SCRIPT for archivelog backups
05,25,45 * * * * oracle /usr/local/sbin/rman_backup_archivelog_cron.sh -f \%d_arch_\%T_\%U -d 7 1>> /var/log/rman/orabackup 2>&1

DOCKER: Use LOGFILE on mounted LOGVOL (or enable SYSLOG inside DOCKER)
# CRONTAB: root@DockerHost
05,21,44 * * * * docker exec -d -u oracle db "/home/oracle/scripts/start_arch_backup.sh"

# SCRIPT: oracle@Container:db
# /home/oracle/scripts/start_arch_backup.sh
#!/usr/bin/env bash
# startscript to start outside docker container 
/usr/local/sbin/rman_backup_archivelog_cron.sh -f \%d_arch_\%T_\%U -d 7 1>> /var/log/rman/orabackup 2>&1
```

### FULL BACKUP INCREMENTAL L0 RAC - example
```
# Maybe use Standby on Dataguard
# Further shell scripts for normal databases: rman_backup_database_inc.sh
TASKS (all OS COMMANDS)
CHECK_DIR                   => ALWAYS
    CREATE_DIR_ON_ERROR     => ON_FAILURE
BACKUP_DB_COMP_L0           => ALWAYS

CHECK_DIR
/bin/ls -d /nfs-shared/backup/%DBName%/database/

CREATE_DIR_ON_ERROR
/bin/mkdir -p /nfs-shared/backup/%DBName%/database

BACKUP_DB_COMP_L0
/usr/local/sbin/rman_backup_database_inc_rac.sh %SID% database 0 " " AS COMPRESSED BACKUPSET BACKUP_INC_L0 %DBName%
```

### BACKUP INCREMENTAL L1 RAC - example
```
# Maybe use Standby on Dataguard
TASKS	
CHECK_DIR                           => ALWAYS
    CREATE_DIR_ON_ERROR             => ON FAILURE
CROSSCHECK_BACKUP                   => ALWAYS
BACKUP_DB_COMP_L1                   => ALWAYS
    DELETE_OBSOLETE_17DAYS_PAST     => ON SUCCESS
    DELETE_ARCH_BACKUP_40DAYS_OLD   => ON SUCCESS
    
 
CHECK_DIR
/bin/ls -d /nfs-shared/backup/%DBName%/database/
 
CREATE_DIR_ON_ERROR
/bin/mkdir -p /nfs-shared/backup/%DBName%/database

CROSSCHECK_BACKUP
/usr/local/sbin/rman_crosscheck.sh %SID%

BACKUP_DB_COMP_L1
/usr/local/sbin/rman_backup_database_inc_rac.sh %SID% database 1 " " AS COMPRESSED BACKUPSET BACKUP_INC_L1 %DBName%

DELETE_OBSOLETE_17DAYS_PAST
/usr/local/sbin/rman_delete_obsolete_reco_window.sh %SID% 17

DELETE_ARCH_BACKUP_40DAYS_OLD
/usr/local/sbin/rman_delete_archivelog_backup.sh %DBName% 40
```

### BACKUP DELETE daily - example (maybe with RECO WINDOW 31 days as separate job)
```
# On DATAGUARD use PRIMARY
TASKS
CROSSCHECK_BACKUP           => ALWAYS
DELETE_OBSOLETE_31DAYS_PAST => ALWAYS
DELETE_BACKUP_40DAYS_OLD    => ALWAYS


CROSSCHECK_BACKUP 
/usr/local/sbin/rman_crosscheck.sh %SID%

DELETE_OBSOLETE_31DAYS_PAST
/usr/local/sbin/rman_delete_obsolete_reco_window.sh %SID% 31

DELETE_ARCH_BACKUP_40DAYS_OLD
/usr/local/sbin/rman_delete_archivelog_backup.sh %SID% 40
```

### VALIDATE DATABASE - example - currently not in the repo
```
RMAN Backup validate database and archivelogs for v$database_block_corruption view
# primary & standby

TASKS
VALIDATE_DB_2_CHANNELS                     => ALWAYS
/usr/local/sbin/rman_validate_db.sh %SID%
```

### ENABLE/DISABLE Backups - CC Job - example
```
TASKS in CC

DISABLE_ALL_BACKUPS
Script to remove backup skip file /tmp/skip_rman run on all database server.
rm /tmp/skip_rman

ENABLE_ALL_BACKUPS
Script to create backup skip file /tmp/skip_rman run on all database server.
echo "cloud_control_disabled" > /tmp/skip_rman
```

### COLD BACKUP - CC Job - example
```
TASKS
STARTBLACKOUT               => ALWAYS
CHECK_DIR                   => ALWAYS
    CREATE_DIR_ON_ERROR     => ON ERROR
BACKUP_DATABASE_COLD        => ALWAYS    
    DELETE_BACKUP_40DAYS_OLD=> ON SUCCESS
ENDBLACKOUT => ALWAYS    


STARTBLACKOUT  
/u01/app/oracle/product/agent12c/core/latest/bin/emctl start blackout cold_backup -nodeLevel

CHECK_DIR 
/bin/ls -d /nfs-shared/backup/%SID%/database/

CREATE_DIR_ON_ERROR
/bin/mkdir -p /nfs-shared/backup/%SID%/database/

BACKUP_DATABASE_COLD # RMAN SCRIPT: maybe add 3 logswitches 
run {
  shutdown immediate;
  startup mount;
  backup database;
  backup current controlfile;
  backup spfile;
  sql "alter database backup controlfile to trace as ''/nfs-shared/backup/%SID%/database/control.trc'' reuse";
  sql "create pfile=''/nfs-shared/backup/%SID%/database/pfile.ora'' from spfile";
  shutdown immediate;
  startup;
}

DELETE_BACKUP_40DAYS_OLD
/usr/local/sbin/rman_delete_archivelog_backup.sh %SID% 40

NDBLACKOUT
/u01/app/oracle/product/agent12c/core/latest/bin/emctl stop blackout cold_backup
```

### BACKUP Current Controlfile - example
Maybe to sync. controlfile backup information from DATAGUARD standby.
```
CHECK_DIR
/bin/ls -d /nfs-shared/backup/%SID%/archivelog/
CREATE_DIR_ON_ERROR
/bin/mkdir -p /nfs-shared/backup/%SID%/archivelog/
BACKUP_CONTROLFILE
/usr/local/sbin/rman_backup_controlfile.sh %SID% %%d_control_%%T_%%U
```
