## 1. Prerequisites
- [ ] 1.1 Add `tag:k8s-operator` and `tag:k8s` to the tailnet policy `tagOwners`
- [ ] 1.2 MagicDNS and HTTPS certificates are on for the tailnet
- [ ] 1.3 Create the operator OAuth client (write: `General/Services`, `Devices/Core`, `Keys/Auth Keys`, tag `tag:k8s-operator`)
- [ ] 1.4 Install Tailscale on the owner's iPhone

## 2. Manifests
- [ ] 2.1 Add `kubernetes/manifests/tailscale/namespace.yaml`, `kustomization.yaml`, and `ksops-generator.yaml`
- [ ] 2.2 Add `operator-oauth.sops.yaml` (encrypted with `sops encrypt -i`)
- [ ] 2.3 Add `kubernetes/argocd-apps/tailscale/tailscale-operator-app.yaml`
- [ ] 2.4 `kustomize build` with KSOPS and `helm template` render locally
- [ ] 2.5 Update `AGENTS.md` managed applications

## 3. Rollout and verification
- [ ] 3.1 Argo CD `tailscale-operator` is Synced and Healthy
- [ ] 3.2 The operator device appears tagged `tag:k8s-operator` and its logs show no auth errors
- [ ] 3.3 A throwaway Ingress gets a running proxy pod and a `ts.net` name
- [ ] 3.4 The iPhone on cell data reaches it over HTTPS with Tailscale on, and not with Tailscale off
- [ ] 3.5 Deleting the throwaway Ingress removes its device from the tailnet
