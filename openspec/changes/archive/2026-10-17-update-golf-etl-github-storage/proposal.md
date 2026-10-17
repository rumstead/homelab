# Change: Move golf-etl to GitHub storage with a phone upload page

## Why
Google Drive has run out of quota for the session frames, the Drive connector for Claude limits how many images it returns, and rclone's Drive client is being retired. [golf-etl](https://github.com/rumstead/golf-etl) now has a github storage mode: videos arrive in a local inbox folder and sessions are committed to the private repo `rumstead/golf-sessions`. The cluster needs a shared volume for that inbox, a way for the phone to put original videos into it, and credentials to push to the sessions repo.

## What Changes
- New PVC `golf-etl-data` (50Gi, ReadWriteOnce) mounted at `/data` by both the upload pod and the CronJob, so both are pinned to the worker `talos-hk3-kam`
- New Deployment `golf-etl-upload` with three containers: nginx (public face and path routing), tusd (resumable uploads into `/data/uploads`), and `golf-etl upload-server` (the page, status, and moving finished uploads into `/data/inbox`)
- New Service `golf-etl-upload` and Tailscale Ingress `golf-upload`, reachable only on the tailnet at `https://golf-upload.tailb4b203.ts.net`
- New SOPS encrypted Secret `golf-etl-deploy-key` holding an SSH deploy key with write access to `rumstead/golf-sessions` only
- The CronJob runs `golf-etl poll` in github mode (`GOLF_STORAGE=github`, `GOLF_INBOX_ROOT=/data`) instead of `poll-drive`
- The rclone Secret stays, so `GOLF_STORAGE=drive` remains a rollback
- The existing Drive sessions are copied to `golf-sessions` with `golf-etl migrate-drive` from the owner's machine, then removed from Drive

## Impact
- Affected specs: `golf-etl` (adds Upload Page, Shared Volume, Deploy Key; modifies Scheduled Pipeline Runs and Drive Credentials)
- Affected code:
  - `kubernetes/manifests/golf-etl/` (`pvc.yaml`, `upload.yaml`, `upload-nginx.conf`, `golf-etl-deploy-key.sops.yaml`, `configmap.yaml`, `cronjob.yaml`, `ksops-generator.yaml`, `kustomization.yaml`)
- Breaking changes: the CronJob stops reading Drive once it switches to github mode; `GOLF_STORAGE=drive` restores it
- Out of scope: the pipeline and upload server themselves (live in `rumstead/golf-etl`), exposing the page outside the tailnet
