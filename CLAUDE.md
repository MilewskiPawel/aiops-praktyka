# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Training repo for the Sages course "AIOps w praktyce" (3 days). Participants fork it and work through labs that use AI tools (Claude Code, k8sgpt, kubectl-ai, Robusta/HolmesGPT, Trivy, LiteLLM) against **Kantyna**, a microservice lunch-ordering app running on a shared AWS EKS cluster (`eu-central-1`), one namespace per participant (namespace = login).

All prose (READMEs, labs, docs) is written in **Polish** — keep new learner-facing content in Polish. Runbooks in `app/runbooks/` are in English.

| Dir | Contents |
|---|---|
| `app/` | Kantyna source, Helm chart, runbooks, docker-compose (see `app/README.md` for full detail) |
| `labs/` | One dir per lab: `README.md` with goal, steps and a `SUKCES` condition |
| `docs/` | Topic write-ups (`NN-topic/*.md`) + standalone `architektura.html` diagrams; `docs/prompts/` holds reusable prompt templates (diagnoza, post-mortem, …) that labs copy into `.claude/commands/` |
| `setup/` | Workstation setup; `check.sh` verifies a participant's deployment (`SUKCES: 11/11`) |

## Commands

All app commands run from `app/`:

```bash
docker compose up -d --build          # local stack: UI :8088, orders-api :8000, payments :8080
docker compose down -v                # stop + wipe DB
docker compose --profile loadgen up -d loadgen   # synthetic traffic (PEAK_RPS=…)

make test                             # orders-api (pytest via uv) + payments (go test in golang:1.23 container)
make test-orders-api                  # = cd orders-api && uv run pytest -q
cd orders-api && uv run pytest tests/test_flags.py::<test_name>   # single Python test
docker run --rm -v "$PWD/payments:/src" -w /src golang:1.23 go test -run <TestName> ./...   # single Go test

make helm-lint
make helm-template REGISTRY=<registry> VERSION=1.0.0
make build push VERSION=1.0.0 [VARIANT=receipt-v2]   # images to ECR (needs make ecr-login)
```

Cluster health check (from repo root): `setup/check.sh [namespace]`.

## Kantyna architecture (big picture)

- `web` (nginx + static SPA) proxies `/api/*` → `orders-api` (FastAPI, psycopg 3 pool) → synchronous HTTP to `payments` (Go, `POST /pay`). Payment refusal aborts the order before any DB write; then order is written to Postgres in one transaction and, only if `QUEUE_URL` is set, published to SQS.
- `worker` long-polls SQS and writes JSON receipts to S3; failures return the message, DLQ after 5 attempts. Locally there is no SQS/S3, so worker just idles.
- `loadgen` produces a daily traffic curve (Europe/Warsaw, lunch peak 11:30–13:30).
- orders-api creates the schema and seeds the menu on startup; tests set `SKIP_DB_INIT=1` (`tests/conftest.py`) and use FastAPI `TestClient` without a DB.
- Observability: every service exposes `/metrics`; logs are single-line JSON with `trace_id`/`span_id`; orders-api exports OTLP traces. `PrometheusRule` alerts (`Kantyna*`) each have a matching runbook in `app/runbooks/` linked via `runbook_url`.

### Fault-injection flags (central to the labs)

Each service has a `flags.py`/`flags.go` that reads a per-service section of `flags.json` (path from `FLAGS_FILE`, default `/etc/kantyna/flags/flags.json`) and re-reads it every ~15s, falling back to env vars. These flags deliberately cause incidents (error_rate, memory leak, CPU burn, DB pool leak, slow menu query, log noise, payments latency, worker fail rate). Sources:
- local: `app/deploy/local/flags.json` (mounted by compose)
- cluster: `flags:` block in `app/deploy/helm/kantyna/values.yaml` → ConfigMap `kantyna-flags`

When adding a flag, update: the service's flag spec, `deploy/local/flags.json`, Helm `values.yaml`, and `FLAG_DEFAULTS` in `labs/lab06-agent-runbook/agent.py` (mirrors chart defaults).

Build variants (`APP_VARIANT`, baked in at image build) also inject faults: `menu-v2` enables the N+1 menu query, `receipt-v2` fails receipt rendering ~7% of the time (see `orders-api/app/runtime.py`).

### Intentionally "bad" artifacts — do not "fix" unprompted

- `app/.env` contains **fake** secrets used for exercises.
- `orders-api/Dockerfile.legacy` + `requirements-legacy.txt` (python:3.9, old pins) exist as a vulnerable target for the Trivy lab (`make legacy-build`).
- `labs/lab06-agent-runbook/alerts/injected.json` is a prompt-injection test case; `zepsuj.sh` breaks a deployment on purpose.
- `feedback_text` + `log_noise` make orders-api log attacker-controlled "customer feedback" text — a vector for prompt injection via logs into AI tooling.

## Repo conventions

- `.claude/settings.json` is part of the teaching material: read-only `kubectl get/describe/logs/top` and `k8sgpt analyze` are allowed; mutating kubectl is `ask`; secrets, `delete`, `exec` are denied. Don't loosen it.
- Labs call LLMs through the course LiteLLM gateway (OpenAI-compatible, `OPENAI_API_KEY`/`OPENAI_ENDPOINT`), e.g. `labs/lab06-agent-runbook/agent.py` is stdlib-only Python by design ("nic nie instalujesz").
- Lab READMEs follow a fixed shape: **Zasada**, **Po labie masz**, **Zanim zaczniesz**, numbered steps with ✅ checkpoints, success condition. Root `README.md` plan table and `docs/README.md` index must be updated when labs/topics are added.
