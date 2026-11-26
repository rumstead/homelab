## 1. Manifests
- [x] 1.1 Delete `golf-etl-rclone.sops.yaml` and remove it from `ksops-generator.yaml`
- [x] 1.2 Remove the `golf-etl-rclone` `secretRef` and the Drive comment from `cronjob.yaml`
- [x] 1.3 Remove `GOLF_REMOTE` and the `RCLONE_*` settings from `configmap.yaml`
- [x] 1.4 `grep -rn golf-etl-rclone kubernetes/` returns nothing and each changed manifest passes `kubectl apply --dry-run=server`

## 2. Spec
- [x] 2.1 Add the spec delta removing Drive Credentials
