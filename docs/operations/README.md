# Operations, deployment, monitoring, and troubleshooting

## Release sequence

1. Review and apply new D1 migrations with `npm run db:migrate:remote`.
2. Type-check the Worker with `npm run check`.
3. Deploy with `npm run deploy`.
4. Run shared tests and build both mobile apps.
5. Smoke-test health, place search/detail, auth, contribution/photo upload, save, and account deletion.
6. Publish mobile builds through the relevant store process.

The repository has no CI/CD, staged rollout, or automated rollback. Mobile signing/distribution procedure
is **Unknown**.

## Configuration

| Name | Purpose | Storage |
|---|---|---|
| `API_BASE_URL` | public canonical Worker URL | Wrangler variable |
| `BETTER_AUTH_SECRET` | Better Auth signing | Wrangler secret |
| Apple IDs/team/key/private key | Apple identity provider | variable + secrets |
| Google iOS/Android/Web IDs and secret | Google identity | public IDs + backend secret |
| `RESEND_API_KEY`, `EMAIL_FROM` | transactional email | secret + variable |
| `ADMIN_TOKEN` | manual sync authorization | secret |
| `DB`, `MEDIA` | D1/R2 bindings | Wrangler config |

## Observability

Verified signals:

- `GET /health` returns process liveness.
- Worker logs unexpected 5xx, sync tile errors, and a scheduled-run summary.
- D1 `sync_regions`/`sync_tiles` contains freshness/status fields.

Not implemented in repository: traces, metrics, dashboards, alert rules, request IDs, external uptime
checks, crash reporting, analytics, or structured request logs.

## Runbooks

### Place search is empty or stale

1. Call `/health`.
2. Check Worker scheduled logs and D1 due/status fields.
3. Verify Overpass is responding; 429/502/503/504 intentionally stop a run.
4. Run `POST /v1/admin/sync-places?region=bali&tiles=<n>` with the admin bearer token.
5. If only Android's map background is blank, test OpenFreeMap separately; directory/list data may still work.

### Sign-in fails

1. Test `/v1/auth/email-registered` and Better Auth session endpoint.
2. Determine whether all methods or one provider fails.
3. Verify Apple/Google client IDs, Apple key material, callback origins, and Resend sender status.
4. For iOS Google failure, confirm the Info.plist placeholders were replaced.
5. Do not log identity tokens or bearer tokens.

### Review/photo submission fails

1. Preserve and reuse the same `submissionId` and `fileId`.
2. Check the first failed media PUT before the review POST.
3. Inspect Worker validation error code/message and verify the place key exists.
4. Retry explicitly; writes are not automatically retried.
5. If D1 failed after R2 upload, record potential orphan cleanup; no automated reconciler exists.

### Shared links fail

1. iOS: fetch the AASA, verify JSON content type/app ID, associated-domain entitlement, and `/place*`.
2. Android: custom scheme requires `place_id`; HTTPS App Links are not implemented.
3. Compare deployed Pages content with tracked `web/`; deployment drift was observed.

### Deployment or migration failure

1. Stop before deploying incompatible code.
2. Inspect Wrangler migration output and remote migration list.
3. There are no down migrations: restore/forward-fix decisions require an operator and backup knowledge.
4. Worker rollback does not revert D1.

### Account deletion partially fails

D1 deletion can succeed before R2 cleanup fails. Re-authentication may no longer be possible although
orphaned objects remain. Confirm the account is deleted, collect affected object keys from logs if
available, and remove only verified orphaned objects.

## Recovery limitations

Backup locations, RPO/RTO, D1 restore rehearsal, R2 versioning/lifecycle, store rollback, and incident
escalation contacts are not defined in the repository.
