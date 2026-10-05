## Context
golf-etl polls a Google Drive folder, processes swing videos with ffmpeg and MediaPipe on CPU, and writes results back to Drive. It has no inbound traffic. Its [design doc](https://github.com/rumstead/golf-etl/blob/main/docs/design.md) defines a runtime contract the scheduler has to meet: runs never overlap, a failed run is not restarted in place (startup recovery depends on this), about 10Gi of scratch, around 2GiB of memory for the process, and Drive credentials in the environment.

The worker has 6 vCPU and 9.7GiB with under 1 CPU and 1Gi requested today; Prometheus shows at least 5.5GiB available over the last 7 days. `lifting-data` already runs a CronJob from a separately built image with SOPS credentials, and this follows the same shape.

## Goals / Non-Goals
- Goals:
  - Run the pipeline every 3 minutes within the app's runtime contract
  - Always run the newest image without manifest bumps
  - Keep Drive credentials encrypted in git
- Non-Goals:
  - Exposing anything through `homelab-gateway`
  - Persistent volumes (Drive is the only store)
  - Alerting on failed runs (failures surface in Drive's `golf/failed/`)

## Decisions
- **CronJob shape.** `golf-etl-poll` on `*/3 * * * *`, `concurrencyPolicy: Forbid`, `restartPolicy: Never`, `backoffLimit: 0`, `activeDeadlineSeconds: 3600`, `successfulJobsHistoryLimit: 3`, `failedJobsHistoryLimit: 3`. Forbid plus no in-place restarts is what lets the app treat anything in `golf/processing/` at startup as orphaned. `timeZone` is not needed since the schedule is an interval.
- **Image.** `ghcr.io/rumstead/golf-etl:latest` with `imagePullPolicy: Always`, per owner preference. Each run re-checks the manifest and reuses cached layers. Renovate ignores `latest`, so nothing here needs a pin; the app repo runs Renovate for its own dependencies.
- **Resources.** Requests 1 CPU / 2Gi, limits 4 CPU / 6Gi, per owner preference. A live run on a 12 minute, 2.4GB session peaked at the old 3Gi limit because the download's page cache counts against the container; the process itself peaks around 1.8GiB. The 6Gi limit is above the worker's worst week of free memory (5.5GiB), so the low request keeps scheduling honest and the cache stays reclaimable. An `emptyDir` mounted at `/scratch` with `sizeLimit: 10Gi`.
- **Credentials.** golf-etl reaches Drive through the `rclone` binary in its image. Secret `golf-etl-rclone` holds `RCLONE_CONFIG_GDRIVE_TOKEN` (the JSON from `rclone authorize "drive"`), encrypted as `golf-etl-rclone.sops.yaml` and listed in `ksops-generator.yaml`. The non-secret rclone settings (`RCLONE_CONFIG_GDRIVE_TYPE=drive`, `RCLONE_CONFIG_GDRIVE_SCOPE=drive`, `RCLONE_DRIVE_USE_TRASH=false`) sit in the ConfigMap. A personal Google Cloud OAuth client was tried first; Google would not let the owner's Gmail account use it without publishing and branding verification.
- **Config.** ConfigMap `golf-etl-config` loaded with `envFrom` for `GOLF_REMOTE` (`gdrive:golf`), the rclone settings, and any threshold or TTL overrides, so tuning is a git change and not an image rebuild.
- **Argo CD.** Application `golf-etl` with automated sync, prune, self-heal, and `CreateNamespace=true`, matching `lifting-data`.

## Risks / Trade-offs
- A bad `latest` push breaks the next run → the app retries and parks failures in `golf/failed/` for 3 days; rollback is a revert in the app repo.
- Full `drive` scope rclone token in the cluster → only in the SOPS secret, scoped to the owner's account, readable only in the `golf-etl` namespace.
- A 4K session can briefly use 4 CPU on the worker → limits cap it, and the job runs rarely.

## Migration Plan
1. The app repo publishes `ghcr.io/rumstead/golf-etl:latest` with a working `poll-drive`.
2. Run `rclone authorize "drive"`, encrypt the token into the secret.
3. Merge the manifests and Application. Argo CD creates the namespace and CronJob.
4. Smoke test with a real upload.
5. Rollback: remove the Application. Drive contents are untouched.

## Open Questions
- None.
