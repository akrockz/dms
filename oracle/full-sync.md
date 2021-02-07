# Full Sync to RDS

## RELOAD ALL SCHEMA TABLES

 This will fail for any table prefixed with awsdms_
 for those tables, login as root and remove them either with a 'drop tables' command or manually
 The following command will generate the correct statement for you to run to drop all tables.
1. Run the below command
2. DISCONNECT FROM ANY ON PREMISE SERVERS AND DROP YOUR TUNNEL.
3. DOUBLE, TRIPPLE CHECK THAT YOU ARE ON THE RIGHT SCHEMA (SR4UAT) AND THE RIGHT DB SERVER
4. Copy and paste the output into a new SQL worksheet and CHECK AGAIN that you are connected to RDS.

## STEP 0 - Add any new tables to replication.

See `sia-dba-scripts\saa-replication\modify-replication-task.sh` for example.

## STEP 1 - Drop the tables.

SQL to generate drop table statement:

```
select 'drop table sr4uat.'||table_name||' cascade constraints;' from user_tables;
```

This procedure disables triggers, create it if you're unsure if it exists. Make sure you run this as SR4UAT.

## STEP 2 - Disable Any Triggers

```
CREATE OR REPLACE PROCEDURE ALTER_ALL_TRIGGERS(status VARCHAR2) IS
 CURSOR c_tr IS (SELECT 'ALTER TRIGGER ' || trigger_name AS stmnt FROM user_triggers);
BEGIN
 IF status NOT IN ('ENABLE', 'enable', 'DISABLE', 'disable') THEN
   DBMS_OUTPUT.PUT_LINE('ONLY ''ENABLEDISABLE'' ACCEPTED AS PARAMETERS');
   RAISE VALUE_ERROR;
 END IF;
 FOR tr IN c_tr LOOP
   EXECUTE IMMEDIATE tr.stmnt || ' ' || status;
 END LOOP;
END;
```

"Procedure ALTER_ALL_TRIGGERS compiled". Disable triggers:

```
EXEC ALTER_ALL_TRIGGERS('DISABLE');
```

## STEP 3 - Disable Any Constraints

The following generates the SQL for disabling and enabling constraints.
Do not enable constraints while replication is running. Ensure all constraints are disabled by running the below
and then copying the output into a new SQL worksheet (Or sublime, I recommend sublime.)
you can replace the word "disable" with "enable" once replication is OFF and it will generate the SQL for you to
re-enable constraints.

```
set serveroutput on;
select 'alter table sr4uat.'||table_name||' disable constraint '||constraint_name||';' from user_constraints;
```

(Then run that output on RDS to disable contraints.)

To list constraints for a table:

```
select * from user_cons_columns where table_name = 'SAA_FLIGHT' order by 'CONSTRAINT_NAME' asc;
```

And to get per-contraint details:

```
select * from user_constraints where table_name = 'SAA_FLIGHT' and constraint_name = 'SAA_FLIGHT';
```

If you are getting errors AT ANY POINT. you can login as root and do the following

```
-- ON THE FIRST LINE OF YOUR SCRIPT AS ROOT
alter session set current_schema = SR4UAT;
```

Constraints and trigggers always disabled during replication - this command enables triggers. After a full sync and you have *STOPPED* replication, you can run this:

```
EXEC ALTER_ALL_TRIGGERS('ENABLE');
```

## STEP 4 - Enable Replication

Wait for 100% load complete repl ongoing

Order of starting tasks:
Run main first
Misc misc
Then transactions and blobs
But really it doesn’t matter

## STEP 5 - Diff source + target DBs

SQL Developer -> Tools -> Diff Wizard
6 things
Triggers + Sequences go well together
Next next
Wait 20+ mins
Click the Green SQL icon when it's done to generate SQL from source to target - alter table statements

Diff analysis
Don't care about any "add suppplemental log data" lines
Ton of alter table with disables
Some tables are created - check it out on source - might have zero rows. so who cares
Create or replace are geneerally OK
Check for delete or drop
Split the diff out to alter tables, create tables

## STEP 6 - Stop replication

From AWS console

## STEP 7 - Run diff SQL using SQLDeveloper

STOP replication first
Run them, save all output, take note of failures, and save them separately
Create sequence commands (or any commands really) from diff are safe to run, oracle will just complain
Because replication is ongoing, changes still coming through, so diff sql may have errors
Note: diff will turn on triggers and constraints

## STEP 8 - Re-enable triggers and constraints

Invert the commands above - this ensures all triggers and constraints are on.
Note: Not all constraints will succeed in being turned back on - this is OK
Resources is busy = replication is still running
Table or view doesn't exist (between diff and running, table might not exist any more)

Triggers:
```
EXEC ALTER_ALL_TRIGGERS('ENABLE');
```

Constraints:
```
set serveroutput on;
select 'alter table sr4uat.'||table_name||' enable constraint '||constraint_name||';' from user_constraints;
```

## STEP 9 - Re-run diff

Do this just for extra-thoroughness

## STEP 9 - Check ALL sequences in rds are higher than onprem

Check sequences:
```
select sequence_name, min_value, increment_by, last_number from user_sequences order by sequence_name;
```

Working generator for sequence adjustment:

```
select 'ALTER SEQUENCE sr4uat.'||sequence_name||' INCREMENT BY 1000000;' || chr(10) ||'SELECT sr4uat.'||sequence_name||'.NEXTVAL FROM dual;' || chr(10) ||'ALTER SEQUENCE sr4uat.'||sequence_name||' INCREMENT BY 1;' from user_sequences where increment_by=1 order by sequence_name;
```

## Misc Notes

aws dms tables
2.5 - 3h to sync prod onprem to rds
3-6h to sync rds to sr4uat2

AMS - apps not working
slow queries will be indexes - run diff on indexes and apply to target
sequence problems will be sequences or triggers  - "things are out of order"

### Finding duplicate rows

Example:
```
select ID, count(ID) from SAA_EMAIL_FAILURE group by ID having count (ID) > 1;
select ID, count(ID) from SAA_FLIGHT group by ID having count (ID) > 1;
```

### Finding the latest ID

Example:
```
select max(id) from saa_booking;
```

Or this:
```
SELECT * FROM saa_booking ORDER BY last_modified_time desc FETCH NEXT 10 ROWS ONLY;
```

### Stop replication, wait 5 minutes, start again

Good way to ensure all records are replicated across to target.

### Duplicates in rds

```
--select ID, count(ID) from SAA_FLIGHT group by ID having count (ID) > 1;
--select * from SAA_FLIGHT where id=905448592;
--select ID, count(ID) from SAA_PASSENGER_PREFERENCES group by ID having count (ID) > 1;
--select * from SAA_PASSENGER_PREFERENCES where id=905448590;
--select ID, count(ID) from SAA_TICKET group by ID having count (ID) > 1;
--select * from SAA_TICKET where id=905448589;
--select ID, count(ID) from SAA_PASSENGER group by ID having count (ID) > 1;
--905448605, 905448606, 905448588
--select ID, count(ID) from SAA_BOOKED_SEAT group by ID having count (ID) > 1;
--905448608, 905448591, 905448609
```

Delete query:
```
delete SAA_FLIGHT where rowid not in (select min(rowid) from SAA_FLIGHT group by ID);
```
