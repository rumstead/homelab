## 1. Prerequisites
- [x] 1.1 Add `"tag:k8s-operator": []` and `"tag:k8s": ["tag:k8s-operator"]` to the tailnet policy `tagOwners` (proxies get `tag:k8s`, which the operator must own)
- [x] 1.2 MagicDNS and HTTPS certificates are on for the tailnet
- [x] 1.3 Create the operator OAuth client (write: `General/Services`, `Devices/Core`, `Keys/Auth Keys`, tag `tag:k8s-operator`)
- [x] 1.4 Install Tailscale on the owner's iPhone

## 2. Manifests
- [x] 2.1 Add `kubernetes/manifests/tailscale/namespace.yaml`, `kustomization.yaml`, and `ksops-generator.yaml`
- [x] 2.2 Add `operator-oauth.sops.yaml` (encrypted with `sops encrypt -i`)
- [x] 2.3 Add `kubernetes/argocd-apps/tailscale/tailscale-operator-app.yaml`
- [x] 2.4 `helm template` renders the chart, and the namespace and sops-decrypted Secret pass a client dry run
- [x] 2.5 Update `AGENTS.md` managed applications

## 3. Rollout and verification
- [x] 3.1 Argo CD `tailscale-operator` is Synced and Healthy
- [x] 3.2 The operator device appears tagged `tag:k8s-operator` and its logs show no auth errors
- [x] 3.3 A throwaway Ingress gets a running proxy pod and a `ts.net` name
- [x] 3.4 The iPhone on cell data reaches it over HTTPS with Tailscale on, and not with Tailscale off
- [x] 3.5 Deleting the throwaway Ingress removes its device from the tailnet
