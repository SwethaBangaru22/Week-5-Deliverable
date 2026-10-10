# Compliance Sentinel Agent — Build Plan

**Goal:** A LangGraph agent that scrapes regulatory sites every day, checks a target codebase against new or changed rules, and produces an audit-ready PDF report with citations. It sends a Slack or email alert when it finds critical violations.

**Deliverables:** a public GitHub repo, a deployment on Fly.io, and a Loom demo of 3–5 minutes.

---

## 1. Scope decisions (make these first)

| Decision | Choice | Why |
|---|---|---|
| Regulatory domain | **Data privacy and security** (GDPR, CCPA/CPRA, HIPAA Security Rule) | You can check these rules in code: PII in logs, encryption, retention, consent, access control |
| Sources (MVP) | Federal Register (HHS/FTC), EUR-Lex (GDPR + EDPB guidelines), California CPPA regulations page | One source of each kind: an API-backed site, a JS-heavy portal and a static HTML page |
| Target codebase | A small **deliberately non-compliant demo app** (`demo-target/`) plus any GitHub repo URL | Makes the demo predictable, with known violations to find |
| Language | **Python 3.12** throughout | LangGraph, Playwright, WeasyPrint and `bullmq` (Python port) all support it |
| LLM | Claude (`claude-sonnet-5-5` for auditing, `claude-haiku-5-5` for parsing/classification) | Good cost and quality balance; use the Opus model only for the final report summary if needed |
| Embeddings | Voyage `voyage-law-2` (1024-dim) | Built for legal text, which helps the "Legal RAG" part |
| Infra | Fly.io apps + Fly Postgres (pgvector) + Upstash Redis | Cheap and fits the stack you were given |

Keep these out of scope for the MVP: multi-tenant auth, a web UI beyond a basic status and report page, and jurisdictions outside the three sources above.

---

## 2. Architecture

```
            ┌──────────── Fly.io ─────────────────────────────────────┐
 BullMQ     │  scheduler (repeatable job, 06:00 UTC daily)            │
 (Redis) ──►│  worker:                                                │
            │   1. scrape_job   → Playwright → raw HTML/PDF           │
            │   2. ingest_job   → parse → chunk → embed → pgvector    │
            │   3. audit_job    → LangGraph agent over target repo    │
            │   4. report_job   → Jinja2 HTML → WeasyPrint PDF        │
            │   5. alert_job    → Slack webhook / SMTP                │
            │  api (FastAPI): /health /runs /reports/{id}.pdf /trigger│
            └───────────────┬─────────────────────────────────────────┘
                            ▼
                Postgres + pgvector (regulations, chunks, runs, findings)
```

### Data model (Postgres)
- `sources` (id, name, url, scraper_type, last_scraped_at)
- `documents` (id, source_id, url, title, published_at, content_hash, raw_text, version)
- `chunks` (id, document_id, section_ref e.g. "Art. 32(1)(a)", text, embedding vector(1024), is_new bool)
- `runs` (id, started_at, status, new_docs_count, repo_url, commit_sha)
- `findings` (id, run_id, rule_chunk_id, severity, file_path, line_start, line_end, evidence, explanation, remediation, confidence)
- `reports` (id, run_id, pdf_path/url, created_at)

Use `content_hash` to detect changes. When a document's hash changes, store a new version and diff it so the audit focuses on amendments only.

---

## 3. LangGraph agent design

State: `{run_id, new_rules[], repo_index, candidate_files[], findings[], report}`

Nodes:
1. **load_new_rules**: pulls chunks where `is_new = true` (or all of them on the first run).
2. **extract_requirements** (Haiku): turns each rule into checkable requirements, for example `{id, citation, requirement, code_signals: ["logger.*email", "bcrypt", "retention"], applies_if}`.
3. **index_repo**: clones the repo, builds a file tree, runs cheap static scans (ripgrep patterns, Semgrep rules for secrets/PII/crypto) and stores code chunks for retrieval.
4. **select_candidates**: for each requirement, ranks files by keyword/Semgrep hits plus embedding similarity, keeping the top N.
5. **audit_file** (Sonnet, fan-out with LangGraph `Send`): uses tools `read_file`, `grep_repo` and `retrieve_regulation(query)` (pgvector RAG). Returns structured findings validated with Pydantic, and each finding must cite a regulation chunk and a file:line.
6. **verify_findings**: a second pass that drops findings with missing evidence or confidence below 0.6, de-duplicates, and assigns severity (Critical / High / Medium / Low).
7. **human_review (optional)**: a LangGraph interrupt for Critical findings when running in interactive mode.
8. **compose_report**: writes the executive summary, the findings table and a remediation plan.
9. **route_alerts**: a conditional edge that runs the alert job if there are any Critical findings.

Use the LangGraph Postgres checkpointer so a failed run can resume.

---

## 4. Repo layout

```
compliance-sentinel/
├─ app/
│  ├─ scrapers/        base.py, federal_register.py, eurlex.py, cppa.py
│  ├─ ingest/          parse.py (HTML/PDF→sections), chunk.py, embed.py
│  ├─ agent/           graph.py, nodes/, tools.py, prompts/, schemas.py
│  ├─ report/          templates/report.html.j2, styles.css, render.py
│  ├─ alerts/          slack.py, email.py
│  ├─ queue/           scheduler.py, worker.py, jobs.py
│  ├─ api/             main.py (FastAPI)
│  └─ db/              models.py, migrations/ (Alembic)
├─ demo-target/        intentionally non-compliant Flask app
├─ evals/              golden findings for demo-target + eval script
├─ tests/
├─ Dockerfile          (Playwright base image + WeasyPrint deps)
├─ fly.toml           (processes: api, worker)
├─ docker-compose.yml (local Postgres+pgvector, Redis)
└─ README.md          (architecture diagram, setup, sample report, Loom link)
```

---

## 5. Milestones

### Phase 0: Setup (½ day)
- [ ] Create the repo, add `uv`/poetry, ruff and pytest, plus GitHub Actions CI
- [ ] Bring up local Postgres + pgvector and Redis with docker-compose
- [ ] Add a `.env.example` (ANTHROPIC_API_KEY, VOYAGE_API_KEY, DATABASE_URL, REDIS_URL, SLACK_WEBHOOK_URL, SMTP_*)

### Phase 1: Scraping (1 day)
- [ ] Write a `BaseScraper` interface: `discover() -> list[url]` and `fetch(url) -> RawDoc`
- [ ] Federal Register: use the API for discovery and Playwright for full text
- [ ] EUR-Lex / EDPB: use Playwright to handle JS rendering and cookie banners
- [ ] CPPA: static pages and PDF downloads
- [ ] Add polite crawling (respect robots.txt, rate limits, a user-agent), retries with backoff and HTML snapshots for debugging
- **Done when:** `python -m app.scrapers.run` stores documents and skips unchanged ones on a second run

### Phase 2: Legal RAG (1 day)
- [ ] Parse into sections that keep the legal structure (Article / Section / subsection becomes `section_ref`)
- [ ] Chunk by section with a size cap of about 800 tokens, keeping parent headings as context
- [ ] Embed with voyage-law-2 and add an HNSW index in pgvector
- [ ] Hybrid retrieval: pgvector cosine search plus Postgres full-text search, merged with RRF
- **Done when:** the query "encryption of personal data at rest" returns GDPR Art. 32 and HIPAA §164.312 in the top 3

### Phase 3: Demo target + audit agent (2 days)
- [ ] Build `demo-target/` with about 8 planted violations: plaintext passwords, PII in logs, no data-deletion endpoint, unencrypted health-data column, no consent check before tracking, hard-coded secrets, no retention policy, overly broad CORS
- [ ] Write the golden expected findings in `evals/golden.json`
- [ ] Implement the LangGraph nodes and tools from section 3
- [ ] Use structured outputs with Pydantic schemas and a retry when validation fails
- [ ] Write the eval script for precision/recall against the golden set. **Target: recall ≥ 75%, precision ≥ 80%**
- **Done when:** `python -m app.agent.run --repo ./demo-target` prints validated findings

### Phase 4: PDF report (½–1 day)
- [ ] Jinja2 template covering the cover page, run metadata (date, repo, commit SHA, sources checked), executive summary, severity breakdown, a findings table and per-finding detail (rule quote and citation link, code snippet with file:line, remediation)
- [ ] Appendix with the regulations reviewed and a methodology/disclaimer note ("AI-assisted, requires legal review")
- [ ] Render with WeasyPrint: page numbers, headers and a table of contents
- **Done when:** the report looks professional and every finding cites both a source URL and a code location

### Phase 5: Queue, alerts, API (1 day)
- [ ] BullMQ: a repeatable cron job (`0 6 * * *`) chaining scrape → ingest → audit → report → alert, with retries and a dead-letter queue
- [ ] Slack Block Kit alert (counts, top critical findings, PDF link) and an SMTP email with the PDF attached
- [ ] FastAPI: `POST /trigger`, `GET /runs`, `GET /reports/{id}.pdf`, `GET /health`

### Phase 6: Deploy to Fly.io (½ day)
- [ ] Dockerfile based on `mcr.microsoft.com/playwright/python` plus Pango/Cairo for WeasyPrint
- [ ] `fly.toml` with `api` and `worker` processes, Fly Postgres with `CREATE EXTENSION vector`, Upstash Redis
- [ ] Store secrets with `fly secrets set`, and use a volume or Tigris/S3 for PDFs
- [ ] Run one full cron cycle in production and confirm the Slack alert arrives

### Phase 7: Portfolio polish (½ day)
- [ ] README: problem, architecture diagram, stack, sample PDF (committed in `docs/sample-report.pdf`), eval results, cost per run, how to run locally, limitations
- [ ] Loom script (3–5 min):
  1. The problem: legal teams track rule changes by hand (20s)
  2. Architecture overview (40s)
  3. Trigger a run live, showing the scraper picking up a new rule (60s)
  4. LangGraph trace in LangSmith, showing the agent reasoning over the code (60s)
  5. The Slack alert, then a walkthrough of the PDF report (60s)
  6. Eval metrics, cost per run, what comes next (30s)

**Total estimate: about 7–8 working days**

---

## 6. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Site layouts change or bot blocking | One scraper per source, snapshot tests, the Federal Register API as a reliable fallback |
| LLM hallucinated violations | Require file:line evidence and a citation, run a verification pass and measure precision with the golden-set eval |
| Large repos blow up token costs | Pre-filter with static scans, top-N candidate files, Haiku for triage, prompt caching on regulation context |
| No new rules on demo day | A `--seed-amendment` flag that injects a fixture "new rule" so the demo always works |
| Overstated legal claims | Disclaimer in the report; describe it as "evidence collection for legal review", not legal advice |
| WeasyPrint system deps on Fly | Pin the Docker image and test the PDF render in CI |

---

## 7. Measuring the "40+ hours/week" claim

Document the claim in the README rather than just asserting it. Estimate the manual baseline (monitoring 3 portals, reading amendments, grepping the codebase, writing findings) against agent runtime and cost per run, and show the numbers from your eval runs.
