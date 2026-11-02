# Next - resume contract

## Resume here

1. Open `src/webhook/retry.ts:88`. `nextDelay()` doubles without a ceiling. Cap
   it at 30s and stop retrying after 12 attempts, marking the event `dead`.
2. Add the two cases to `src/webhook/__tests__/retry.test.ts`: attempt 12 caps at
   30s, attempt 13 marks `dead` and does not reschedule. Watch them fail first.
3. Backfill the one staging event scheduled too far out:
   `pnpm tsx scripts/reschedule-stuck.ts --max-delay 30s`. It is written and
   untested; read it before running it.

## Verify first

```sh
pnpm test src/webhook
```

Pass is 94 passing, 1 skipped. Anything below 94 means something regressed since
the last checkpoint, and that comes first.

## Context the next session will need

- `nextDelay()` is also called from `src/jobs/digest.ts:51` for failed sends, so
  the cap applies there too. Check the digest tests, not only the webhook ones.
- Stripe's own retry window is 3 days, so a cap above that is pointless; 30s with
  12 attempts was chosen to stay well inside it.
- The two uncommitted files are `src/webhook/retry.ts` (the half-written cap) and
  `scripts/reschedule-stuck.ts` (new, untested). Neither is abandoned work.

## Explicitly not next

- Do not start the Slack digest channel work. It is specced in
  `DECISIONS.md` D-007 but blocked on an app review that has not come back.
- Do not refactor `src/webhook/handlers/`. It reads badly and works; the
  retry change does not need it.
