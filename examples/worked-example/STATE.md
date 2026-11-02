# Project State

<!-- continuum:stamp -->
- updated: 2026-11-01T17:42:11Z
- git: a86f053 on main (2 uncommitted files)
- checkpoints: 37
- next action: cap the backoff at 30s in src/webhook/retry.ts:88, then pnpm test src/webhook
<!-- /continuum:stamp -->

## Objective

Pulse ingests Stripe and GitHub webhooks, stores them, and emails a daily digest
to each workspace. Current phase is finished when webhook delivery survives a
provider outage without losing events and without duplicating digests.

## Current focus

Retry behaviour in `src/webhook/retry.ts`. The backoff is exponential but
uncapped, so a long outage schedules retries days out.

## State of play

- Ingest works for both providers: `POST /api/hooks/:provider` verified against
  Stripe CLI replay, 200 with `event_id` echoed.
- Events persist to `webhook_events` with a unique index on
  `(provider, external_id)`; replaying the same event is a no-op. Proven by
  `pnpm test src/webhook/dedupe`.
- Digest job runs at 06:00 UTC via `src/jobs/digest.ts`, idempotent per
  `(workspace_id, date)`.
- Retry exists but is uncapped. One event in staging is currently scheduled 3
  days out, id `evt_9f21`.
- 94 tests passing, 1 skipped (`digest.timezone.test.ts`, see pitfalls).

## Blockers

none

## Decisions in force

- Postgres, not Redis, for the retry queue. See D-004: operational simplicity
  beat latency at this volume.
- Digest email via Resend, not SES. See D-006.
- Webhook signature verification happens in middleware, never in handlers.

## Do not

- Do not run `pnpm db:reset` against staging; it drops `webhook_events`, which
  is the only record of replayed provider events.
- Do not add a second unique index to `webhook_events`; the partial index was
  tried and rejected, see D-005.
- Do not unskip `digest.timezone.test.ts` without reading pitfalls first.
