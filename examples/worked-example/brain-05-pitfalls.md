# Pitfalls

Symptom first, because the symptom is what the next session sees.

---

### Digest emails arrive twice for workspaces in UTC+13

- **Symptom:** two digests for the same date, timestamps about 11 hours apart.
- **Cause:** `digestDate()` used the server's local date, so a workspace past the
  dateline crossed midnight twice inside one UTC day.
- **Fix:** the date is computed in the workspace's timezone, in
  `src/jobs/digest.ts:34`. `digest.timezone.test.ts` is skipped because it needs
  a fake clock the suite does not have yet; do not unskip it without adding one,
  it fails for the wrong reason.
- **Added:** 2026-10-19. Fixed in `c71d204`, kept here because the test is still
  skipped.

---

### `pnpm test` passes locally and fails in CI with a connection error

- **Symptom:** `ECONNREFUSED 127.0.0.1:5432` in CI only.
- **Cause:** the test suite assumes a running Postgres. CI starts it as a
  service, and the step that waits for readiness was added after the test step.
- **Fix:** tests run after the `wait-for-postgres` step in
  `.github/workflows/ci.yml`. If you add a job, keep that ordering.
- **Added:** 2026-10-22.

---

### Webhook handler changes appear to do nothing

- **Symptom:** edits to `src/webhook/handlers/stripe.ts` have no effect on
  behaviour.
- **Cause:** two handler paths coexist. The router still resolves through
  `handlers/legacy/` for Stripe until the flag `PULSE_NEW_HANDLERS` is set.
- **Fix:** set the flag locally, or edit the legacy path knowingly. The seam is
  documented in `01-architecture.md`. Do not delete the legacy path; production
  still runs it.
- **Added:** 2026-10-26.
