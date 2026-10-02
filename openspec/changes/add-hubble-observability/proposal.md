# Change: Add Hubble network observability

## Why
Nothing in the cluster shows which workloads talk to the internet or to the LAN. Hubble already captures flows on each node, but there is no relay, UI, or metrics, the per-node ring buffer only holds about 8 minutes of flows, and outbound flows carry only IPs because DNS never passes through the Cilium DNS proxy. Visibility has to exist before egress can be locked down, since the allowlist is written from observed traffic.

## What Changes
- Hubble TLS certificates move from Helm-generated to cert-manager (`homelab-ca-issuer`), so Argo CD re-renders stop rotating the CA
- Enable Hubble Relay and Hubble UI in the Cilium chart
- Expose Hubble UI at `hubble.acemagic.lab` through `homelab-gateway` on the HTTP listener, without authentication (same exposure as Grafana and AdGuard)
- Enable Hubble metrics (`flows-to-world`, `dns`, `drop`, `flow`, `tcp`, `port-distribution`) with workload-level labels, scraped by Prometheus through a ServiceMonitor
- Add a cluster-wide DNS visibility policy that sends pod DNS through the Cilium DNS proxy with `enableDefaultDeny` off for egress, so flows to the internet are labeled with hostnames and nothing is blocked
- Ship the Cilium and Hubble Grafana dashboards, plus an Egress dashboard built on `hubble_flows_to_world_total`
- Raise the Hubble flow buffer from 4095 to 16383 flows per node
- Install the `hubble` CLI on the host

## Impact
- Affected specs: `cluster-network-observability` (new)
- Affected code:
  - `kubernetes/argocd-apps/cilium/cilium-app.yaml` (Hubble TLS, relay, UI, metrics, dashboards, buffer)
  - `kubernetes/manifests/cilium/` (Hubble UI HTTPRoute, DNS visibility policy)
  - `kubernetes/manifests/monitoring/` (Egress dashboard)
  - `AGENTS.md` (exposed hostnames, monitoring section)
- Breaking changes: none. No traffic is denied by this change
- Out of scope: alerting, egress enforcement, log storage (Loki), Kubernetes audit log shipping, authentication on Hubble UI
