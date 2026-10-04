# Change: Deploy the golf-etl pipeline

## Why
[golf-etl](https://github.com/rumstead/golf-etl) turns golf swing videos uploaded to Google Drive into per-swing frames that Claude can read. It needs somewhere to run on a schedule with Drive credentials, and this cluster has the spare CPU for MediaPipe and ffmpeg. The pipeline's behavior is specified in the app repo's [design doc](https://github.com/rumstead/golf-etl/blob/main/docs/design.md); this change covers only the deployment.

## What Changes
- New `golf-etl` namespace with a CronJob that runs `golf-etl poll-drive` every 3 minutes
- Image `ghcr.io/rumstead/golf-etl:latest` with `imagePullPolicy: Always`, so every push to the app repo's `main` is picked up on the next run
- Google Drive OAuth credentials as a SOPS encrypted Secret rendered through KSOPS
- New Argo CD Application `golf-etl` under the app-of-apps

## Impact
- Affected specs: `golf-etl` (new)
- Affected code:
  - `kubernetes/argocd-apps/golf-etl/golf-etl-app.yaml`
  - `kubernetes/manifests/golf-etl/` (namespace, ConfigMap, CronJob, `golf-etl-drive.sops.yaml`, KSOPS generator, kustomization)
  - `AGENTS.md` (managed applications)
- Breaking changes: none
- Out of scope: the pipeline itself (lives in `rumstead/golf-etl`), any HTTPRoute or exposed service
