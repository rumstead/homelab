# Change: Run the Tailscale operator

## Why
The owner's phone and laptop need to reach cluster services from off the LAN, and the cluster has no public ingress. The Tailscale Kubernetes operator puts individual services on the owner's tailnet with HTTPS on their `ts.net` names, so nothing is opened to the internet. golf-etl's upload page is the first service that needs it.

## What Changes
- New Argo CD Application `tailscale-operator` under the app-of-apps, with two sources: the official `tailscale-operator` Helm chart at `1.104.1`, and `kubernetes/manifests/tailscale/`
- New `tailscale` namespace labeled `privileged`, since the proxy pods the operator creates need privileges the cluster's `baseline` default rejects
- The operator's OAuth client ID and secret as a SOPS encrypted Secret `operator-oauth` rendered through KSOPS
- Services join the tailnet through an `Ingress` with `ingressClassName: tailscale`
- The tailnet policy tags, HTTPS certificates, and the OAuth client are one-time steps in the Tailscale admin console, so nothing in git or CI can change who reaches the homelab

## Impact
- Affected specs: `tailscale` (new)
- Affected code:
  - `kubernetes/argocd-apps/tailscale/tailscale-operator-app.yaml`
  - `kubernetes/manifests/tailscale/` (namespace, `operator-oauth.sops.yaml`, KSOPS generator, kustomization)
  - `AGENTS.md` (managed applications)
- Breaking changes: none
- Out of scope: exposing a real service, a subnet router or exit node, Funnel
