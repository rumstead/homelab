## 1. Foundations
- [ ] 1.1 Add the node_exporter textfile collector directory in the `exporters` role and confirm a test metric reaches Prometheus from `192.168.1.234:9100`
- [ ] 1.2 Turn off Grafana usage reporting, update checks and Gravatar in the kube-prometheus-stack values
- [ ] 1.3 In the Hubble metrics, remove `any-drop` from `flows-to-world` and add `labelsContext=source_namespace,destination_namespace` to the flow, drop and flows-to-world metrics; confirm the LAN probe drops no longer appear
- [ ] 1.4 Add Alertmanager routes for the new alert groups with their `group_by` and `repeat_interval`, raise Alertmanager `retention` to 192h, and confirm the catch-all route neither swallows nor duplicates them

## 2. Cluster scanning
- [ ] 2.1 Add the Trivy Operator Argo CD app (`trivy-system`, chart pinned and tracked by Renovate, `aquasecurity.github.io` allowed for argocd-repo-server later) with the built-in Trivy server, `trivy.command: filesystem`, vulnerability, config audit, RBAC and image secret scanning, infra assessment and node collector off, one scan job at a time, ServiceMonitor and per-CVE metrics on
- [ ] 2.2 Confirm a report exists for every running image digest (compared with `kube_pod_container_info` from kube-state-metrics), init containers and `kube-system` included; note the real metric names and the fixed-version label; list any image that needs registry mode; confirm the scan jobs run without a token and with the expected mounts
- [ ] 2.3 Triage week: fix or accept, with reason, expiry and scope, every existing critical or high finding; add the Grafana dashboard
- [ ] 2.4 Add the vulnerability, configuration and scanner-health PrometheusRules
- [ ] 2.5 Prove each Trivy alert with its own fixture in a throwaway namespace (old image, privileged `sleep` pod, unbound wildcard Role, image with a dummy credential), each with a quiet negative; confirm no secret content appears in metrics or the email; delete the fixtures

## 3. Host scanning on crete
- [ ] 3.1 Add the `host_scanning` role: pinned Trivy release with checksum, daily per-directory scan with binary counts and per-binary report, weekly Lynis with report parsing and new-warning tracking, hourly update health per updater, freshness gauges, atomic writes
- [ ] 3.2 `--check --diff`, apply, run each timer once by hand, confirm the metrics and that every expected binary was discovered; the first Lynis run sets the baseline
- [ ] 3.3 Add the host scanning, missing-result and stale-scanner PrometheusRules
- [ ] 3.4 Prove each host alert: an old Go release binary in a test directory outside `PATH`; synthetic `test="true"` metrics for Lynis and update health; one scanner timer stopped for a test window for the absent and stale rules; then remove the test files and restart the timer

## 4. Cluster egress, audit week
- [ ] 4.1 Generate the in-cluster workload pairs from `hubble_flows_processed_total` and write the baseline `CiliumClusterwideNetworkPolicy` (only `kube-system` exempt) and one `egress` `CiliumNetworkPolicy` per application namespace with one spec per workload and `enableDefaultDeny` off, under `kubernetes/manifests/egress/`
- [ ] 4.2 Set `policyAuditMode: true` in the Cilium values, sync, and confirm `policy-audit-mode` in `cilium-config` and `PolicyAuditMode: Enabled` on both agents
- [ ] 4.3 Only then add the `egress` Argo CD app and sync the policies
- [ ] 4.4 Turn on Hubble's static flow exporter for `AUDIT` verdicts on both nodes; run one deliberate unlisted `curl` from a policed pod, confirm it lands in the export, and add an audit PrometheusRule if any series also records it
- [ ] 4.5 Run for at least 7 days, covering a golf-etl session, a sync of every Argo CD app, an AdGuard restart and filter refresh, an Alertmanager email, a Trivy database refresh, a forced test certificate renewal, a direct and a relayed Tailscale connection from the phone (each reaching the backend through the proxy), cold Git and Helm fetches after clearing the repo-server cache, and a restart of every workload
- [ ] 4.6 Add every legitimate destination the audit found and record the ones left out on purpose

## 5. Cluster egress, enforcing
- [ ] 5.1 Put every namespace but cert-manager on the baseline's exempt list; confirm the live policy and the endpoint policy revisions on both nodes show it
- [ ] 5.2 Add the policy-drop PrometheusRules while audit mode is still on, and a throwaway canary namespace (not exempt) with one pod
- [ ] 5.3 Turn audit mode off and confirm `PolicyAuditMode: Disabled` on both agents; prove each drop rule from the canary with a deliberate `curl` to an internet host, one to a LAN address, and a cross-namespace connection, each with a quiet negative; delete the canary
- [ ] 5.4 Test the break-glass once: deny, recover, deny on an existing pod on each node with fresh connections, through an Argo CD sync, from crete's kubeconfig; record the time to recovery
- [ ] 5.5 Enforce the remaining namespaces one at a time, at least a day apart: external-dns, lifting-data, golf-etl, trivy-system, tailscale, adguard, argocd; after each, restart its workloads and exercise them
- [ ] 5.6 Run the local alert-path check (all scrape targets up, Prometheus reaches Alertmanager, a test alert emails), enforce `monitoring`, and run the check again
- [ ] 5.7 All Argo CD apps Synced and Healthy, a golf-etl session processes, Tailscale ingresses load from the phone, AdGuard refreshes its filters after a restart

## 6. Host traffic detection
- [ ] 6.1 Add the `host_ids` role: Suricata on `eno2` in IDS mode, daily validated `suricata-update` with loaded-rules check, EVE logging with logrotate and restricted permissions, the metrics script with a rotation-safe cursor, the first-seen-name job, and the local test rule
- [ ] 6.2 Confirm no new listening ports on crete (`ss -lntu` before and after) and RAM use under 1 GB
- [ ] 6.3 Verify coverage: a request and its response from crete and from a pod on each node appear in EVE with the right addresses, matched against a short `tcpdump` on `eno2`
- [ ] 6.4 Add the Suricata alert and capture-health PrometheusRules
- [ ] 6.5 Prove them: the local test rule from crete; `testmynids.org` from crete and from a pod in a test namespace with a temporary allow; Suricata stopped for a test window for the capture-health rule; each with a quiet negative
- [ ] 6.6 Add the first-seen-name panels to Grafana; after 4 weeks, review the daily counts and either set an email threshold from them or leave it dashboard only
- [ ] 6.7 USB backup, add the HaGeZi Threat Intelligence Feeds list, confirm it blocks a test domain and that browsing and `apt update` on crete still work, USB backup again, and write the one-toggle undo into the README

## 7. Weekly health dashboard and reminder
- [ ] 7.1 Raise Prometheus retention to 15 days (keep the 9GB cap) and confirm disk use after two weeks
- [ ] 7.2 Add the "Homelab weekly" dashboard ConfigMap with this-week and last-week panels for crete, the cluster, security and the watchers
- [ ] 7.3 Create a separate Gmail app password and store it as a SOPS-encrypted Secret in `monitoring`
- [ ] 7.4 Add the reminder CronJob and its script ConfigMap, and its spec in the `monitoring` egress policy (Prometheus and `smtp.gmail.com:587` only); confirm it mounts only its own Secret
- [ ] 7.5 Run it once by hand: the email arrives with every headline figure (or marked incomplete), Alertmanager's delivery status and scrape health, and a working dashboard link from the phone

## 8. Wrap up
- [ ] 8.1 Update README.md and AGENTS.md: where the allowlists live, how to add a destination, the exempt list, the break-glass, scanning and acceptances, Suricata, the AdGuard list
- [ ] 8.2 `openspec validate add-egress-control-and-security-scanning --strict`
- [ ] 8.3 After two quiet weeks, count the alert emails against the anti-goal and tune
