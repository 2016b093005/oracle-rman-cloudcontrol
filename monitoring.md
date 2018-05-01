# QUERIES FOR RMAN CATALOG - maybe for Nagios

#### 11g until 12.1 - FOR NORMAL DB´s
```
my @backup_types = ( 'LEVEL0_COPY', 'LEVEL0', 'DATABASE', 'FRA', 'INCR', 'LONGTERM', 'ARCHIVELOG', 'ROLLFORWARD' );
my %descriptions = (
  'LEVEL0_COPY' => 'Level 0 Backup Copy',
  'LEVEL0' => 'Level 0 Backup',
  'DATABASE' => 'Database Full Backup',
  'FRA' => 'Fast Recovery Area Backup',
  'INCR' => 'Incremental (Level 1) Backup',
  'LONGTERM' => 'Longterm Backup',
  'ARCHIVELOG' => 'Backup of Database Archivelogs',
  'ROLLFORWARD' => 'Rollforward of L0 Backup',
);
my %queries;
%queries = (
  'LEVEL0_COPY' => qq{select round((sysdate - max(completion_time))*24*60*60) as last_l0_backup_sec from $rman_schema.rc_backup_copy_details where marked_corrupt = 0 and db_name = ? },
  'LEVEL0' => qq{select round((sysdate - max(completion_time))*24*60*60) as last_l0_backup_sec from $rman_schema.rc_backup_set_details where backup_type='D' and incremental_level = '0' and status ='A' and db_name = ? },
  'DATABASE' => qq{select round((sysdate - max(end_time))*24*60*60) as last_full_backup_sec from $rman_schema.rc_rman_status where object_type='DB FULL' and operation like 'BACKUP%' and row_level=1 and status = 'COMPLETED' and db_name = ? },
  'FRA' => qq{select round((sysdate - max(end_time))*24*60*60) as last_fra_backup_sec from $rman_schema.rc_rman_backup_job_details where input_type='RECVR AREA' and status ='COMPLETED' and db_name = ? },
  'INCR' => qq{select round((sysdate - max(completion_time))*24*60*60) as last_inc_backup_sec from $rman_schema.rc_backup_set_details where backup_type='I' and status ='A' and db_name = ? },
  'LONGTERM' => qq{select round((sysdate - max(completion_time))*24*60*60) as last_longterm_backup_sec from $rman_schema.rc_backup_set_details where incremental_level is null and keep = 'YES' and status ='A'  and db_name = ? },
  'ARCHIVELOG' => qq{select round((sysdate - max(end_time))*24*60*60) as last_archivelog_backup_sec from $rman_schema.rc_rman_backup_job_details where input_type = 'ARCHIVELOG' and status ='COMPLETED' and db_name = ? },
  'ROLLFORWARD' => qq{select round((sysdate - max(completion_time))*24*60*60) as last_rollforward_sec from $rman_schema.rc_backup_copy_details where marked_corrupt = 0 and db_name = ? },
);

# RMAN Catalog changes from 11g to 12c go here
if ($dbversion_main == 12) {
  $queries{'LEVEL0'} = qq{select round((sysdate - max(completion_time))*24*60*60) as last_l0_backup_sec from $rman_schema.rc_backup_set_details where backup_type='I' and incremental_level = '0' and status ='A' and db_name = ? };
}
```


#### 11g until 12.1 - FOR RAC
```
my @backup_types = ( 'LEVEL0_COPY_RAC', 'LEVEL0_RAC', 'DATABASE_RAC', 'FRA_RAC', 'INCR_RAC', 'LONGTERM_RAC', 'ARCHIVELOG_RAC', 'ROLLFORWARD_RAC' );

my %descriptions = (
    'LEVEL0_COPY_RAC' => 'Level 0 Backup Copy',
    'LEVEL0_RAC' => 'Level 0 Backup',
    'DATABASE_RAC' => 'Database Full Backup',
    'FRA_RAC' => 'Fast Recovery Area Backup',
    'INCR_RAC' => 'Incremental (Level 1) Backup',
    'LONGTERM_RAC' => 'Longterm Backup',
    'ARCHIVELOG_RAC' => 'Backup of Database Archivelogs',
    'ROLLFORWARD_RAC' => 'Rollforward of L0 Backup',
    );

my %queries = (
'LEVEL0_COPY_RAC' => qq{select round((sysdate - max(completion_time))*24*60*60) as last_l0_backup_sec from $rman_schema.rc_backup_copy_details where marked_corrupt = 0 and db_name = ? },
'LEVEL0_RAC' => qq{select round((sysdate - max(completion_time))*24*60*60) as last_l0_backup_sec from $rman_schema.rc_backup_set_details where backup_type='D' and incremental_level = '0' and status ='A' and db_name = ? },
'DATABASE_RAC' => qq{select round((sysdate - max(end_time))*24*60*60) as last_full_backup_sec from $rman_schema.rc_rman_status where object_type='DB FULL' and operation like 'BACKUP%' and row_level=1 and status = 'COMPLETED' and db_name = ? },
'FRA_RAC' => qq{select round((sysdate - max(end_time))*24*60*60) as last_fra_backup_sec from $rman_schema.RC_RMAN_BACKUP_JOB_DETAILS where input_type='RECVR AREA' and status ='COMPLETED' and db_name = ? },
'INCR_RAC' => qq{select round((sysdate - max(completion_time))*24*60*60) as last_inc_backup_sec
from $rman_schema.rc_backup_set_details where backup_type='I' and status ='A' and db_name = ? },
'LONGTERM_RAC' => qq{select round((sysdate - max(completion_time))*24*60*60) as last_longterm_backup_sec from $rman_schema.rc_backup_set_details where incremental_level is null and keep = 'YES' and status ='A'  and db_name = ? },
'ARCHIVELOG_RAC' => qq{select round((sysdate - max(end_time))*24*60*60) as last_archivelog_backup_sec from $rman_schema.RC_RMAN_BACKUP_JOB_DETAILS where input_type = 'ARCHIVELOG' and status ='COMPLETED' and db_name = ? },
'ROLLFORWARD_RAC' => qq{select round((sysdate - max(completion_time))*24*60*60) as last_rollforward_sec from $rman_schema.rc_backup_copy_details where marked_corrupt = 0 and db_name = ? },
    );
```
