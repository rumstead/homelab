## Context
Cilium 1.20.2 runs with `kubeProxyReplacement`, the L7 proxy enabled, and Hubble enabled in each agent with TLS on `:4244`. Hubble metrics are disabled, there is no relay or UI, and `hubble.tls.auto.method` is `helm`. Under Argo CD the chart is re-rendered on every refresh, so Helm generates a new CA and server certificate each time (`hubble-server-certs` was reissued on 2026-10-02 without any intended change).

Prometheus selects ServiceMonitors labeled `release: kube-prometheus-stack` from any namespace. The Grafana dashboard sidecar only watches the `monitoring` namespace for ConfigMaps labeled `grafana_dashboard: "1"`.

This is the first phase of egress control. Later phases add default-deny egress with an allowlist, admission policy, and a host-level egress filter outside the cluster.

## Goals / Non-Goals
- Goals:
  - See every flow from both nodes in one place (CLI and UI)
  - Know which workload talks to which external hostname, and when that set changes
  - Keep the data in Prometheus so it can drive the Phase 2 allowlist
- Non-Goals:
  - Blocking any traffic
  - Per-connection history beyond the in-memory buffer (Loki is a later decision)
  - Authentication on Hubble UI (accepted: LAN-only, read-only)

## Decisions
- **Hubble TLS via cert-manager.** `hubble.tls.auto.method: certmanager` with `certManagerIssuerRef` pointing at the `homelab-ca-issuer` ClusterIssuer. Certificates become stable across renders and renew automatically. Alternatives: `cronJob` (adds a Job and still rotates on its own schedule), keeping `helm` (relay would intermittently fail TLS when agents and relay pick up different CAs).
- **Metrics and label context.** Workload-level labels keep cardinality bounded while still answering "who talked to what":
  - `flows-to-world:any-drop;port;sourceContext=workload-name|reserved-identity;destinationContext=dns|ip`
  - `dns:query;ignoreAAAA;sourceContext=workload-name|reserved-identity`
  - `drop:sourceContext=workload-name|reserved-identity;destinationContext=workload-name|reserved-identity`
  - `flow:sourceContext=workload-name|reserved-identity;destinationContext=workload-name|reserved-identity`
  - `tcp`, `port-distribution`
  - `destinationContext=dns|ip` uses the hostname when the DNS proxy saw the lookup and falls back to the IP otherwise.
- **DNS visibility without enforcement.** One `CiliumClusterwideNetworkPolicy` selecting all endpoints, with `enableDefaultDeny: {egress: false, ingress: false}` and a single egress rule to `k8s-app=kube-dns` on port 53 with `dns: [{matchPattern: "*"}]`. Because default deny is off, every other flow keeps its current behavior. Alternative: `policyAuditMode` plus a real default-deny policy, which is Phase 2 and changes more at once.
- **Hubble UI exposure.** An `HTTPRoute` for `hubble.acemagic.lab` on the `http` listener of `homelab-gateway`, backed by the `hubble-ui` Service in `kube-system`. external-dns publishes the record to AdGuard like the other routes. No authentication, per owner decision.
- **Dashboards.** `hubble.metrics.dashboards` and the top-level `dashboards` value with `namespace: monitoring`, so the sidecar picks them up. A custom Egress dashboard is added under `kubernetes/manifests/monitoring/`.
- **New destination alert.** Fires when a `(source, destination)` pair in `hubble_flows_to_world_total` has traffic in the last 15 minutes but no series in the 7 days before that. Severity `warning`. It will be noisy for the first week while the baseline fills in.
- **Flow buffer.** `hubble.eventBufferCapacity: "16383"` (must be 2^n - 1). About 4x the current window, roughly 30 minutes at the current flow rate, for a few tens of MB per agent.

## Risks / Trade-offs
- Pod DNS now goes through the Cilium agent's DNS proxy, so an agent restart briefly interrupts pod DNS on that node → acceptable, it is standard Cilium operation; restarts are rare and short.
- Hubble UI exposes a live map of services and per-pod DNS lookups to anyone on the LAN → accepted by the owner; revisit when Tailscale lands.
- Metric cardinality from `dns:query` and `destinationContext=dns|ip` → bounded to queries made by pods (AdGuard's LAN clients go through its own upstreams, not the proxy). Watch `prometheus_tsdb_head_series` after rollout.
- New-destination alert noise from CDNs with rotating hostnames → start at `warning`, tune with `destination` regex exclusions after the first week.
- Changing Hubble TLS and metrics restarts the Cilium agents (rolling). The eBPF datapath keeps forwarding during the restart.

## Migration Plan
1. Merge the Cilium chart change. Argo CD rolls the agents, creates the cert-manager `Certificate` resources, and starts relay and UI.
2. Merge the manifests (policy, route, dashboard, alert) in the same PR. The policy only takes effect once the agents are up.
3. Verify: relay sees both nodes, flows-to-world shows hostnames, no new drops, all Argo apps healthy, LAN DNS works.
4. Rollback: revert the PR. Agents return to Helm certificates and no policy; nothing is enforced either way.

## Open Questions
- Should `kube-system` be excluded from the DNS visibility policy to keep CoreDNS's own path untouched? Default: include it, since the rule only adds proxying for pod-to-CoreDNS traffic.
