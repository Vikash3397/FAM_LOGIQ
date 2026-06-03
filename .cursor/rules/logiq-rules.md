# FAM LogIQ — Monitoring Rules

Single source of truth for the **logiq-monitor** agent. Read this file at the start of every invocation.

---

## Purpose

Monitor distinct `DM_JOB_LOG` error records on FAM dev database (`INTDEVFAM@DWMSDEV`) where `error_message` is not null, `error_code < 0`, and `log_timestamp` is within a configurable lookback window (default **365 days** via `--days N`). Search Glean for similar BMC Helix ITSM incidents for the Financial Accounting Manager (FAM) application, and suggest resolutions. Write results to console (chat summary) and daily log files.

---

## MCP Tools (mandatory)

| MCP server | Tools | Use |
|------------|-------|-----|
| `oracle-sqlcl` | `run-sql`, `schema-information` | DB queries only |
| `glean_default` | `search`, `read_document`, `chat` | Helix ITSM / FAM knowledge |

Do **not** embed database credentials in this repo. Auth is handled by global MCP configuration.

---

## Invocation Flags

Parse these from the user prompt when present:

| Flag | Behavior |
|------|----------|
| `--reset-watermark` | Set `last_job_log_id` to `0` in watermark file before polling |
| `--limit N` | Process at most N error rows (use `FETCH FIRST N ROWS ONLY` in poll SQL) |
| `--days N` | Only include errors with `log_timestamp` within the past N days (default **365**) |

If no flags are provided, use default behavior (incremental poll from watermark, no limit, 365-day lookback).

---

## Workflow (every invocation)

### Phase 1 — Initialize

1. Read this rules file.
2. Read `config/glean_prompts.md` for search and chat templates.
3. Load watermark from `state/last_watermark.json`:
   - If file missing, create it: `{"last_job_log_id": 0, "last_updated": "<ISO8601>"}`
   - If `--reset-watermark`, set `last_job_log_id` to `0` and save.
4. Determine today's log path: `logs/logiq-YYYY-MM-DD.log` (UTC date).
5. Parse `--days N` from the prompt; if omitted, use **365**. Validate N is a positive integer.

### Phase 2 — Schema discovery (first run or on column errors)

If poll query fails with unknown column errors, or if `state/last_watermark.json` has no `schema_confirmed` flag:

1. Run schema discovery from `config/dm_job_log.sql` section 1 via `run-sql` (SYNCHRONOUS).
2. Run sample error rows query.
3. Map actual column names to: `job_log_id` (PK/watermark), `job_name`, `error_message`, `log_date`.
4. Update poll SQL inline if column names differ; note mapping in log.
5. Set `"schema_confirmed": true` in watermark file after successful discovery.

### Phase 3 — Poll for new errors

1. Substitute `last_job_log_id` from watermark and `:days` lookback value into poll query (section 2 of `config/dm_job_log.sql`).
2. Apply `--limit N` if specified (section 3).
3. Execute via `oracle-sqlcl` `run-sql` with `executionType: SYNCHRONOUS`.
4. If DB connection fails → stop immediately; report error clearly; do not advance watermark.

Log the lookback window at scan start, e.g. `[timestamp] LogIQ scan started. Watermark: {id}. Lookback: {days} days.`

**If zero rows returned:**

- Append a single line to today's log: `[timestamp] No new errors since watermark {id} (lookback: {days} days).`
- Return chat summary: "No new errors in DM_JOB_LOG since last scan."
- Do not advance watermark.

### Phase 4 — Process each error row

For each row returned (in ascending `job_log_id` order):

#### 4a. Extract search keywords

Follow `config/glean_prompts.md`:

- Use first meaningful error line (strip stack traces).
- Build 3–6 keyword query + `FAM "Financial Accounting Manager" Helix ITSM`.

#### 4b. Glean search

Call `glean_default` `search` with the keyword query. Request up to 10 results.

If empty results:

- Log "No Glean matches" for this error.
- Skip to 4e with diagnostic-only resolution note.
- Optionally retry with broader keywords (drop job name, keep ORA code + FAM + Helix).

#### 4c. Glean read_document

Select top 2–3 result URLs with highest relevance to the error. Call `read_document` with all URLs in one call.

#### 4d. Glean chat

Build message from chat template in `config/glean_prompts.md` (fill placeholders from error row). Pass `read_document` snippets as `context` if available.

#### 4e. Write log entry

Append to `logs/logiq-YYYY-MM-DD.log`:

```
=== LogIQ Entry ===
Time: {ISO8601 UTC}
JobLogId: {job_log_id}
Job: {job_name}
Timestamp: {log_date}
Error: {error_message — truncate to 2000 chars if longer}
GleanSearchQuery: {query used}
SimilarIncidents:
- {title}: {url}
  ...
SuggestedResolution:
{chat response summary}
===
```

Use the Write tool to append (read existing file first, then write combined content) or Shell append on Windows: `Add-Content`.

### Phase 5 — Advance watermark

After all rows processed successfully:

1. Set `last_job_log_id` to the **highest** `job_log_id` processed this run.
2. Set `last_updated` to current ISO8601 timestamp.
3. Save `state/last_watermark.json`.

Do **not** advance watermark if processing aborted mid-run due to DB failure.

### Phase 6 — Chat summary

Return a concise summary:

- Lookback days used
- Errors found and processed count
- Highest watermark ID
- Per-error: JobLogId, job name, error excerpt (first line), resolution headline
- Log file path
- Cited URLs for top matches

---

## Watermark File Format

`state/last_watermark.json`:

```json
{
  "last_job_log_id": 0,
  "last_updated": "2026-05-30T00:00:00Z",
  "schema_confirmed": false
}
```

---

## Error Handling

| Situation | Action |
|-----------|--------|
| DB connection / SQL error | Stop; report error; do not advance watermark |
| Glean auth error | Stop; report auth issue; log partial results if any |
| Glean empty search | Log entry with "No similar incidents found"; suggest diagnostic steps only |
| Long error_message | Full text in chat prompt; truncate to 2000 chars in log file |
| Column name mismatch | Run schema discovery; remap columns; retry poll |

---

## Validation Fallback

If poll returns zero rows and user has not specified `--reset-watermark`, optionally run historical lookup (section 4 of `config/dm_job_log.sql`) **only when explicitly requested** or when `--validate` flag is passed. Substitute the same `:days` lookback as the poll query. Process that row through Glean pipeline without advancing watermark past its ID unless it exceeds current watermark.

---

## Do Not

- Invent Helix ITSM incidents or resolutions not returned by Glean tools.
- Skip watermark update after successful processing.
- Use raw SQL credentials or connection strings in repo files.
- Reprocess the same `job_log_id` unless `--reset-watermark` is set.
