## 1. Cilium chart
- [x] 1.1 Switch `hubble.tls.auto` to `certmanager` with `homelab-ca-issuer`
- [x] 1.2 Enable `hubble.relay` and `hubble.ui`
- [x] 1.3 Enable Hubble metrics with the label contexts from design.md, a ServiceMonitor labeled `release: kube-prometheus-stack`, and dashboards in `monitoring`
- [x] 1.4 Set `hubble.eventBufferCapacity` to `16383`
- [x] 1.5 Render the chart locally and confirm the Certificate, relay, UI, ServiceMonitor, and dashboard ConfigMaps

## 2. Manifests
- [x] 2.1 Add the DNS visibility `CiliumClusterwideNetworkPolicy` with `enableDefaultDeny` off
- [x] 2.2 Add the `hubble.acemagic.lab` HTTPRoute on the gateway `http` listener
- [x] 2.3 Add the Egress Grafana dashboard
- [x] 2.4 Server-side dry run the new manifests against the cluster

## 3. Host tooling and docs
- [x] 3.1 Install the `hubble` CLI in `~/.local/bin`
- [x] 3.2 Update `AGENTS.md` (exposed hostnames, monitoring section)

## 4. Rollout and verification
- [x] 4.1 Merge and confirm all Argo CD applications are Synced and Healthy
- [x] 4.2 `hubble observe` through relay shows flows from both nodes
- [x] 4.3 `hubble_flows_to_world_total` has series with hostname destinations
- [x] 4.4 No new dropped flows (`hubble observe --verdict DROPPED`), LAN DNS and gateway routes still work
- [x] 4.5 `hubble.acemagic.lab` resolves and loads the UI
- [x] 4.6 Hubble and Egress dashboards render in Grafana
