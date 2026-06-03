-- =============================================================================
-- FAM LogIQ — DM_JOB_LOG queries
-- Database: INTDEVFAM@DWMSDEV (FAM dev)
-- =============================================================================
-- Confirmed schema (INTDEVFAM@DWMSDEV):
--   ID (PK), JOB_ID, LOG_LEVEL_ID, LOG_TIMESTAMP, JOB_NAME, JOB_PROCESS,
--   MESSAGE, THREAD_ID, ERROR_CODE, ERROR_MESSAGE, APPLICATION
--
-- Filter criteria (all poll/lookup queries):
--   - error_message IS NOT NULL (non-blank)
--   - error_code < 0
--   - log_timestamp within the past :days days (default 365; set via --days N flag)
--   - distinct errors (most recent row per error_message + error_code + job_name)
--
-- Time window predicate (substitute :days with integer day count before execution):
--   log_timestamp >= SYSTIMESTAMP - NUMTODSINTERVAL(:days, 'DAY')
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. SCHEMA DISCOVERY
-- Run this first on a new environment to confirm DM_JOB_LOG structure.
-- -----------------------------------------------------------------------------

-- Column metadata
SELECT column_name, data_type, nullable
FROM all_tab_columns
WHERE table_name = 'DM_JOB_LOG'
ORDER BY column_id;

-- Sample distinct error rows (most recent occurrence per unique error)
SELECT id,
       job_id,
       job_name,
       error_code,
       error_message,
       log_timestamp,
       application
FROM (
    SELECT id,
           job_id,
           job_name,
           error_code,
           error_message,
           log_timestamp,
           application,
           ROW_NUMBER() OVER (
               PARTITION BY error_message, error_code, job_name
               ORDER BY id DESC
           ) AS rn
    FROM DM_JOB_LOG
    WHERE error_message IS NOT NULL
      AND TRIM(error_message) IS NOT NULL
      AND error_code < 0
      AND log_timestamp >= SYSTIMESTAMP - NUMTODSINTERVAL(:days, 'DAY')
)
WHERE rn = 1
ORDER BY id DESC
FETCH FIRST 5 ROWS ONLY;

-- -----------------------------------------------------------------------------
-- 2. POLL QUERY — new distinct errors since watermark
-- Replace :last_id with last_job_log_id from state/last_watermark.json
-- Replace :days with lookback window from --days N flag (default 365)
-- (maps to DM_JOB_LOG.ID). Default starting watermark is 0.
-- Returns the latest row for each distinct error not yet processed.
-- -----------------------------------------------------------------------------

SELECT id,
       job_id,
       job_name,
       error_code,
       error_message,
       log_timestamp,
       application
FROM (
    SELECT id,
           job_id,
           job_name,
           error_code,
           error_message,
           log_timestamp,
           application,
           ROW_NUMBER() OVER (
               PARTITION BY error_message, error_code, job_name
               ORDER BY id DESC
           ) AS rn
    FROM DM_JOB_LOG
    WHERE error_message IS NOT NULL
      AND TRIM(error_message) IS NOT NULL
      AND error_code < 0
      AND log_timestamp >= SYSTIMESTAMP - NUMTODSINTERVAL(:days, 'DAY')
      AND id > :last_id
)
WHERE rn = 1
ORDER BY id ASC;

-- Example with watermark 0 and 365-day lookback (first run):
-- SELECT id, job_id, job_name, error_code, error_message, log_timestamp, application
-- FROM (
--     SELECT id, job_id, job_name, error_code, error_message, log_timestamp, application,
--            ROW_NUMBER() OVER (
--                PARTITION BY error_message, error_code, job_name
--                ORDER BY id DESC
--            ) AS rn
--     FROM DM_JOB_LOG
--     WHERE error_message IS NOT NULL
--       AND TRIM(error_message) IS NOT NULL
--       AND error_code < 0
--       AND log_timestamp >= SYSTIMESTAMP - NUMTODSINTERVAL(365, 'DAY')
--       AND id > 0
-- )
-- WHERE rn = 1
-- ORDER BY id ASC;

-- -----------------------------------------------------------------------------
-- 3. POLL QUERY WITH LIMIT (optional — cap rows per run; uses :days and :limit)
-- -----------------------------------------------------------------------------

SELECT id,
       job_id,
       job_name,
       error_code,
       error_message,
       log_timestamp,
       application
FROM (
    SELECT id,
           job_id,
           job_name,
           error_code,
           error_message,
           log_timestamp,
           application,
           ROW_NUMBER() OVER (
               PARTITION BY error_message, error_code, job_name
               ORDER BY id DESC
           ) AS rn
    FROM DM_JOB_LOG
    WHERE error_message IS NOT NULL
      AND TRIM(error_message) IS NOT NULL
      AND error_code < 0
      AND log_timestamp >= SYSTIMESTAMP - NUMTODSINTERVAL(:days, 'DAY')
      AND id > :last_id
)
WHERE rn = 1
ORDER BY id ASC
FETCH FIRST :limit ROWS ONLY;

-- -----------------------------------------------------------------------------
-- 4. HISTORICAL ERROR LOOKUP (read-only — for pipeline validation)
-- Use when no new errors exist but you need to test the Glean workflow.
-- Returns the most recent distinct error within the past :days (default 365).
-- -----------------------------------------------------------------------------

SELECT id,
       job_id,
       job_name,
       error_code,
       error_message,
       log_timestamp,
       application
FROM (
    SELECT id,
           job_id,
           job_name,
           error_code,
           error_message,
           log_timestamp,
           application,
           ROW_NUMBER() OVER (
               PARTITION BY error_message, error_code, job_name
               ORDER BY id DESC
           ) AS rn
    FROM DM_JOB_LOG
    WHERE error_message IS NOT NULL
      AND TRIM(error_message) IS NOT NULL
      AND error_code < 0
      AND log_timestamp >= SYSTIMESTAMP - NUMTODSINTERVAL(:days, 'DAY')
)
WHERE rn = 1
ORDER BY id DESC
FETCH FIRST 1 ROW ONLY;

-- -----------------------------------------------------------------------------
-- 5. ALTERNATE POLL — timestamp-based watermark
-- Use if PK-based watermark is unsuitable. Update state/last_watermark.json
-- to use last_log_timestamp (ISO 8601 string) instead of last_job_log_id.
-- -----------------------------------------------------------------------------

-- SELECT id, job_id, job_name, error_code, error_message, log_timestamp, application
-- FROM (
--     SELECT id, job_id, job_name, error_code, error_message, log_timestamp, application,
--            ROW_NUMBER() OVER (
--                PARTITION BY error_message, error_code, job_name
--                ORDER BY id DESC
--            ) AS rn
--     FROM DM_JOB_LOG
--     WHERE error_message IS NOT NULL
--       AND TRIM(error_message) IS NOT NULL
--       AND error_code < 0
--       AND log_timestamp >= SYSTIMESTAMP - NUMTODSINTERVAL(:days, 'DAY')
--       AND log_timestamp > TO_TIMESTAMP(:last_ts, 'YYYY-MM-DD"T"HH24:MI:SS')
-- )
-- WHERE rn = 1
-- ORDER BY log_timestamp ASC;
