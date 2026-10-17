## 1. Prerequisites
- [x] 1.1 `golf-etl upload-server` and the github storage mode are published in `ghcr.io/rumstead/golf-etl:latest` (tracked in `rumstead/golf-etl`)
- [x] 1.2 The Tailscale operator is running (`add-tailscale-operator`)

## 2. Shared volume and upload pod
- [x] 2.1 Add `pvc.yaml`, `upload.yaml`, and `upload-nginx.conf` with a `configMapGenerator` entry in `kustomization.yaml`
- [x] 2.2 Client dry run of each new file and a rendered nginx ConfigMap
- [x] 2.3 Argo CD `golf-etl` is Synced and Healthy, the upload pod is 3/3 Running behind the Tailscale Ingress `golf-upload.tailb4b203.ts.net` (homelab PR #22), and in the pod the page returns 200, `/status` 200, `/hooks` 404, and a tusd OPTIONS 200

## 3. iPhone check
- [x] 3.1 Upload one short range video from Photos at `https://golf-upload.tailb4b203.ts.net` and note its size and resolution from the Info panel
- [x] 3.2 Compare the file in `/data/inbox` with Photos: picking from Photos made iOS upload a re-encoded H.264 copy with `creation_time` rewritten, so the fallback was used: saving to Files then Choose File uploaded the original byte for byte (sha256 matched the Drive copy). The page now tells the owner to use Files (golf-etl PR #9)
- [ ] 3.3 Remove the test file from `/data/inbox` after the owner confirms it

## 4. Cutover
- [x] 4.1 Add `golf-etl-deploy-key.sops.yaml` (encrypted with `sops encrypt -i`) and list it in `ksops-generator.yaml`
- [x] 4.2 Set `GOLF_STORAGE: github` and `GOLF_INBOX_ROOT: /data` in `configmap.yaml`
- [x] 4.3 Change the CronJob to `golf-etl poll`, pin it to `talos-hk3-kam`, mount `golf-etl-data` at `/data` and the deploy key at `/etc/golf-etl/ssh`
- [x] 4.4 `openspec validate update-golf-etl-github-storage --strict`, merge (homelab PR #23), and sync
- [x] 4.5 A manual Job from the CronJob published to `golf-sessions` over ssh (commit 79d5faf) with no ssh permission or host key errors
- [x] 4.6 Upload a short video from the phone through the page: the cronjob published session 2026-10-16-1246-7b829c88 to `rumstead/golf-sessions` (commit af01ad5)

## 5. Drive migration
- [x] 5.1 The owner confirms nothing new is going to Drive
- [x] 5.2 `golf-etl migrate-drive --dry-run` lists the Drive sessions to copy and delete, with nothing blocked
- [x] 5.3 `golf-etl migrate-drive` from the owner's machine: one session already on GitHub (2026-10-03-1240-19a836d2) was deleted from Drive directly, the other three were copied and deleted (3 copied, 3 deleted, 0 kept), and `gdrive:golf/sessions/` is empty

## 6. Clean up
- [ ] 6.1 Delete the local plaintext deploy key and its `.pub`
- [ ] 6.2 Delete the `spike/golf-connector-test` branch in `rumstead/weekly-notes`
- [x] 6.3 Archive this change in its own PR
