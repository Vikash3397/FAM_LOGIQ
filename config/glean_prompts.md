# FAM LogIQ — Glean Prompt Templates

Templates and rules for searching BMC Helix ITSM knowledge via Glean MCP.

---

## Search Keyword Extraction

Glean `search` requires **short, discriminative keywords** — not full sentences.

### Steps

1. Take the first meaningful line from `error_message` (before stack trace / `at oracle...` lines).
2. Extract 3–6 high-signal tokens:
   - Oracle error codes: `ORA-01403`, `ORA-00942`, etc.
   - Application-specific terms from the error text.
   - Job name if relevant (short form, no paths).
3. Append scope terms: `FAM "Financial Accounting Manager" Helix ITSM`
4. Use quotes only for exact verbatim error phrases when needed.

### Examples

| error_message (excerpt) | Glean search query |
|-------------------------|-------------------|
| `ORA-01403: no data found` | `ORA-01403 FAM "Financial Accounting Manager" Helix` |
| `Job BATCH_INVOICE failed: invalid GL account` | `invalid GL account BATCH_INVOICE FAM Helix ITSM` |
| `Connection timeout to payment gateway` | `"payment gateway" timeout FAM Helix` |

### Do NOT

- Use boolean operators (OR, AND).
- Stuff synonyms or category words into the query.
- Pass the entire multi-line stack trace as the search query.

---

## Chat Resolution Template

Use with Glean `chat` after `search` and `read_document`. Replace placeholders with values from the error row.

```text
Context: Search BMC Helix ITSM and internal knowledge for CSG Financial
Accounting Manager (FAM) application incidents and resolutions.

Error from DM_JOB_LOG:
- JobLogId: {job_log_id}
- Job: {job_name}
- Timestamp: {log_date}
- Error: {error_message}

Find similar past Helix ITSM incidents for FAM. Summarize root cause patterns
and suggest concrete resolution steps. Cite document URLs from search results.
If no similar incidents exist, say so and suggest diagnostic next steps only.
Do not invent incidents or resolutions not supported by the indexed documents.
```

### Optional context for chat

When calling Glean `chat`, pass snippets from `read_document` results as the `context` array to improve synthesis quality.

---

## Tool Selection

| Goal | Glean tool |
|------|------------|
| Find similar incidents / KB articles | `search` |
| Read full incident or KB text | `read_document` (top 2–3 URLs from search) |
| Synthesize resolution from multiple sources | `chat` |

**Recommended flow:** `search` → `read_document` → `chat`

---

## Scope Terms Reference

Always include at least one FAM scope term in search queries:

- `FAM`
- `Financial Accounting Manager`
- `Helix ITSM` or `Helix`

These help Glean surface BMC Helix ITSM tickets and internal runbooks for the FAM application rather than unrelated CSG systems.
