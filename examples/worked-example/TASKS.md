# Tasks

| ID | Status | Task | Evidence |
|---|---|---|---|
| T-001 | DONE | Verify Stripe webhook signatures in middleware | stripe listen replay: 200 on valid, 401 on tampered body |
| T-002 | DONE | Dedupe events by (provider, external_id) | pnpm test src/webhook/dedupe: 11 passed; replayed evt_8812 twice, one row |
| T-003 | DONE | Daily digest job, idempotent per workspace per day | pnpm test src/jobs/digest: 22 passed; ran job twice for 2026-10-28, one email in Resend log |
| T-004 | DOING | Cap the retry backoff and kill events after 12 attempts | - |
| T-005 | BLOCKED | Slack digest channel delivery | Slack app review pending since 2026-10-24, nothing to do until it returns |
| T-006 | TODO | Reschedule the stuck staging event evt_9f21 | - |
| T-007 | DROPPED | Move the retry queue to Redis | superseded by D-004, Postgres is sufficient at this volume |

Note the shape of the evidence column: a command and a result, not an adjective.
`T-004` is DOING rather than DONE because the cap is written but no test has been
watched failing and then passing.
