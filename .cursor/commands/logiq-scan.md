# logiq-scan

Run the FAM LogIQ monitoring agent.

## Instructions

Invoke the **logiq-monitor** agent and execute a full scan:

1. Read `.cursor/rules/logiq-rules.md` and `config/glean_prompts.md`.
2. Load watermark from `state/last_watermark.json` (create with `last_job_log_id: 0` if missing).
3. Poll `DM_JOB_LOG` on INTDEVFAM@DWMSDEV for new distinct error rows where `error_message` is not null, `error_code < 0`, `log_timestamp` is within the lookback window (`--days N`, default 365), and `id` exceeds the watermark.
4. For each new error:
   - Search Glean for similar FAM / BMC Helix ITSM incidents
   - Read top matching documents
   - Synthesize a suggested resolution via Glean chat
5. Append structured results to `logs/logiq-YYYY-MM-DD.log`.
6. Advance the watermark to the highest processed `job_log_id`.
7. Return a concise summary in chat with cited URLs.

Use `oracle-sqlcl` (`run-sql`, SYNCHRONOUS) for all SQL.
Use `glean_default` (`search`, `read_document`, `chat`) for all knowledge lookups.

SQL templates: `config/dm_job_log.sql`

## Optional flags

Pass these in your message if needed:

- `--reset-watermark` — reprocess from job_log_id 0
- `--limit N` — process at most N errors this run
- `--days N` — search for errors within the past N days (default 365)
- `--validate` — if no new errors, test pipeline with one historical error row (read-only)

## Prompt

Run the LogIQ monitor: scan DM_JOB_LOG for new errors since last watermark, search Glean for similar FAM Helix ITSM incidents, and suggest resolutions. Write results to today's log file and summarize in chat.
