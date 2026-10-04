## 1. Prerequisites
- [ ] 1.1 `ghcr.io/rumstead/golf-etl:latest` is published with a working `poll-drive` (tracked in `rumstead/golf-etl`)
- [ ] 1.2 Create the GCP OAuth Desktop client (Production status, `drive` scope) and mint a refresh token

## 2. Manifests
- [ ] 2.1 Add `kubernetes/manifests/golf-etl/namespace.yaml` and `configmap.yaml`
- [ ] 2.2 Add `golf-etl-drive.sops.yaml` (encrypted with `sops encrypt -i`) and `ksops-generator.yaml`
- [ ] 2.3 Add `cronjob.yaml` per design.md
- [ ] 2.4 Add `kustomization.yaml`
- [ ] 2.5 Add `kubernetes/argocd-apps/golf-etl/golf-etl-app.yaml`
- [ ] 2.6 `kustomize build` with KSOPS locally and a server-side dry run
- [ ] 2.7 Update `AGENTS.md` managed applications

## 3. Rollout and verification
- [ ] 3.1 Argo CD `golf-etl` is Synced and Healthy
- [ ] 3.2 A scheduled Job completes and its logs show a Drive poll
- [ ] 3.3 Upload a known range clip: session appears, original is gone from Drive and from trash
- [ ] 3.4 Re-upload the same clip: the session is replaced, no second folder
