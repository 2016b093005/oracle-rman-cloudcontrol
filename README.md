# Backupscript for Oracle Database with RMAN

## State of Repository: WIP

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
         DELETE_ARCHIVELOGS_40DAYS_OLD      => ON SUCCESS
         

CHECK_DIR_LONGTERM 
/bin/ls -d /nfs-shared/backup/%SID%/longterm/   

CREATE_DIR_LONGTERM_ON_ERROR
/bin/mkdir -p /nfs-shared/backup/%SID%/longterm

BACKUP_DB_COMP_LONGTERM
/usr/local/sbin/rman_backup_database_longterm.sh %SID% longterm AS COMPRESSED BACKUPSET LONGTERM 186

DELETE_ARCHIVELOGS_40DAYS_OLD
/usr/local/sbin/rman_delete_archivelog_backup.sh %SID% 40
```
