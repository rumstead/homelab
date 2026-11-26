# Change: Remove golf-etl Google Drive storage

## Why
golf-etl runs in GitHub storage mode and the Drive rollback path is no longer wanted. The rclone Drive token is a credential the pipeline no longer needs, and a separate change in `rumstead/golf-etl` removes the Drive code from the image.

## What Changes
- Delete the SOPS Secret `golf-etl-rclone` and its entry in `ksops-generator.yaml`
- Remove the `golf-etl-rclone` `secretRef` from the CronJob
- Remove `GOLF_REMOTE` and the `RCLONE_*` settings from the `golf-etl-config` ConfigMap
- Remove the Drive Credentials requirement from the `golf-etl` spec

## Impact
- Affected specs: `golf-etl` (removes Drive Credentials)
- Affected code: `kubernetes/manifests/golf-etl/` (`golf-etl-rclone.sops.yaml`, `ksops-generator.yaml`, `configmap.yaml`, `cronjob.yaml`)
- Breaking changes: `GOLF_STORAGE=drive` no longer works
- Follow-up at archive: drop the Google Drive sentence from the spec Purpose
