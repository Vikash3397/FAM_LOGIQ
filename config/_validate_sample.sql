SET PAGESIZE 0 FEEDBACK OFF HEADING ON LINESIZE 4000 TRIMSPOOL ON
SELECT COUNT(*) AS distinct_errors FROM (
    SELECT ROW_NUMBER() OVER (
               PARTITION BY error_message, error_code, job_name
               ORDER BY id DESC
           ) AS rn
    FROM DM_JOB_LOG
    WHERE error_message IS NOT NULL
      AND TRIM(error_message) IS NOT NULL
      AND error_code < 0
      AND log_timestamp >= SYSTIMESTAMP - NUMTODSINTERVAL(365, 'DAY')
) WHERE rn = 1;
SELECT id || '|' || job_name || '|' || error_code || '|' || SUBSTR(error_message,1,80)
FROM (
    SELECT id, job_name, error_code, error_message,
           ROW_NUMBER() OVER (
               PARTITION BY error_message, error_code, job_name
               ORDER BY id DESC
           ) AS rn
    FROM DM_JOB_LOG
    WHERE error_message IS NOT NULL
      AND TRIM(error_message) IS NOT NULL
      AND error_code < 0
      AND log_timestamp >= SYSTIMESTAMP - NUMTODSINTERVAL(365, 'DAY')
) WHERE rn = 1
ORDER BY id DESC
FETCH FIRST 5 ROWS ONLY;
EXIT;
