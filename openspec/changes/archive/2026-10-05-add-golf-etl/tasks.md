## 1. Prerequisites
- [x] 1.1 `ghcr.io/rumstead/golf-etl:latest` is published with a working `poll-drive` (tracked in `rumstead/golf-etl`)
- [x] 1.2 Run `rclone authorize "drive"` for the owner's account

## 2. Manifests
- [x] 2.1 Add `kubernetes/manifests/golf-etl/namespace.yaml` and `configmap.yaml`
- [x] 2.2 Add `golf-etl-rclone.sops.yaml` (encrypted with `sops encrypt -i`) and `ksops-generator.yaml`
- [x] 2.3 Add `cronjob.yaml` per design.md
- [x] 2.4 Add `kustomization.yaml`
- [x] 2.5 Add `kubernetes/argocd-apps/golf-etl/golf-etl-app.yaml`
- [x] 2.6 `kustomize build` with KSOPS locally and a server-side dry run
- [x] 2.7 Update `AGENTS.md` managed applications

## 3. Rollout and verification
- [x] 3.1 Argo CD `golf-etl` is Synced and Healthy
- [x] 3.2 A scheduled Job completes and its logs show a Drive poll
- [x] 3.3 Upload a known range clip: session appears, original is gone from Drive and from trash
- [x] 3.4 Re-upload the same clip: the session is replaced, no second folder
