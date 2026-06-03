SET PAGESIZE 0 FEEDBACK OFF HEADING ON LINESIZE 4000 TRIMSPOOL ON
SELECT column_name || '|' || data_type || '|' || nullable
FROM all_tab_columns
WHERE table_name = 'DM_JOB_LOG'
ORDER BY column_id;
EXIT;
