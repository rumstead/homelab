## 1. Prerequisites
- [x] 1.1 `golf-etl upload-server` and the github storage mode are published in `ghcr.io/rumstead/golf-etl:latest` (tracked in `rumstead/golf-etl`)
- [x] 1.2 The Tailscale operator is running (`add-tailscale-operator`)

## 2. Shared volume and upload pod
- [ ] 2.1 Add `pvc.yaml`, `upload.yaml`, and `upload-nginx.conf` with a `configMapGenerator` entry in `kustomization.yaml`
- [ ] 2.2 Client dry run of each new file and a rendered nginx ConfigMap
- [ ] 2.3 Argo CD `golf-etl` is Synced and Healthy, the upload pod is 3/3 Running, and `kubectl -n golf-etl get ingress golf-upload` shows `golf-upload.tailb4b203.ts.net`

## 3. iPhone check
- [ ] 3.1 Upload one short range video from Photos at `https://golf-upload.tailb4b203.ts.net` and note its size and resolution from the Info panel
- [ ] 3.2 Compare the file in `/data/inbox` (name, codec, resolution, 120 fps, byte size, `com.apple.quicktime.model`) with Photos, falling back to Save to Files then Browse if anything differs
- [ ] 3.3 Remove the test file from `/data/inbox` after the owner confirms it

## 4. Cutover
- [ ] 4.1 Add `golf-etl-deploy-key.sops.yaml` (encrypted with `sops encrypt -i`) and list it in `ksops-generator.yaml`
- [ ] 4.2 Set `GOLF_STORAGE: github` and `GOLF_INBOX_ROOT: /data` in `configmap.yaml`
- [ ] 4.3 Change the CronJob to `golf-etl poll`, pin it to `talos-hk3-kam`, mount `golf-etl-data` at `/data` and the deploy key at `/etc/golf-etl/ssh`
- [ ] 4.4 `openspec validate update-golf-etl-github-storage --strict`, merge, and sync
- [ ] 4.5 A manual Job from the CronJob exits 0 with a `poll:` line and no ssh permission or host key errors
- [ ] 4.6 Upload a short video from the phone: the page shows it waiting, processing, then published, and the session appears in `rumstead/golf-sessions`

## 5. Drive migration
- [ ] 5.1 The owner confirms nothing new is going to Drive
- [ ] 5.2 `golf-etl migrate-drive --dry-run` lists the five Drive sessions to copy and delete, with nothing blocked
- [ ] 5.3 The real run copies and deletes all five, `gdrive:golf/sessions/` is empty, and `rumstead/golf-sessions` lists them

## 6. Clean up
- [ ] 6.1 Delete the local plaintext deploy key and its `.pub`
- [ ] 6.2 Delete the `spike/golf-connector-test` branch in `rumstead/weekly-notes`
- [ ] 6.3 Archive this change in its own PR
