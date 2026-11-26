## Context
- Cluster: two Talos VMs on crete, Cilium 1.20.5 with kube-proxy replacement, Hubble metrics labeled by workload, and a cluster-wide `dns-visibility` policy that sends all pod DNS through the Cilium DNS proxy without default deny. The only other network policies are the ingress NetworkPolicies Argo CD ships for its own components.
- Observed pod egress to the internet over 7 days (Hubble `hubble_flows_to_world_total`):

  | Workload | Destinations |
  |---|---|
  | argocd-repo-server | github.com, raw.githubusercontent.com, release-assets.githubusercontent.com, helm.cilium.io, charts.jetstack.io, prometheus-community.github.io, kubernetes-sigs.github.io, pkgs.tailscale.com (443) |
  | alertmanager | smtp.gmail.com:587 |
  | lifting-data-ingest | imap.gmail.com:993 |
  | grafana | grafana.com, stats.grafana.org, secure.gravatar.com (443) |
  | adguard-home | upstream DNS 9.9.9.10, 149.112.112.10, 94.140.14.14, 94.140.15.15 (53, 443, 853); filter lists on 185.199.108.153:443 (GitHub). All of it by IP: AdGuard resolves through its own upstreams, never through kube-dns. |
  | prometheus | 192.168.1.234:9100 and :9256 |
  | tailscale operator and the `ts-*` proxies | hundreds of DERP and STUN IPs on UDP 3478 and 41641; TCP 443 about two-thirds by IP (DERP map addresses), the rest by name |
  | golf-etl-poll | not seen this week (no video was processed): github.com over SSH for `golf-sessions`, plus whatever the pipeline needs |

- Verified on the running cluster and in the pinned versions:
  - `hubble_flows_to_world_total` has `source`, `destination` (hostname or IP), `port`, `protocol` and `verdict`. It counts non-reply flows to `reserved:world`, and without the `any-drop` option it counts a drop only when the reason is "Policy denied". The current config sets `any-drop`, which is why LAN clients probing the load balancer IPs show up as drops today.
  - `hubble_drop_total` has `source`, `destination` and `reason`, and covers both directions. `hubble_flows_processed_total` has `verdict`, `type` and `subtype`. Cilium 1.20.5 has no Hubble policy-verdict metric.
  - Each Cilium agent can switch policy audit mode on at runtime with `cilium-dbg config PolicyAuditMode=Enabled` (currently `Disabled`). The setting lasts until the agent restarts and does not involve Argo CD.
  - The `app-of-apps` Application syncs every Application under `kubernetes/argocd-apps` with `prune` and `selfHeal`, so a change made to a child Application by hand is reverted.
  - The Trivy Operator chart defaults to `trivy.command: image` in `Standalone` mode, which pulls each image from its registry inside the scan job.
- Crete is also a workstation (Claude Code, VS Code tunnel, Chrome, apt, snaps), so its egress is broad and changes often. Its DNS goes to the router, which forwards to AdGuard, so AdGuard attributes crete's lookups to the router. `eno2` is the only wired NIC and the only member of `br0` besides the VM taps.
- Crete is patched by unattended-upgrades (enabled, allowed origins: the release, `-security`, ESM Apps and ESM Infra security), which installs security updates including new kernel packages, and by `host-auto-update` (`apt-get upgrade`, daily) for everything else. Livepatch fixes the running kernel until the Sunday reboot window loads a new one. Binaries outside apt (`/usr/local/bin`: talosctl, sops, age, hubble, node_exporter, process-exporter; `~/.local/bin`; `~/go/bin`) are not patched by either.
- node_exporter on crete runs without a textfile collector directory today.
- The USB backup is `~/.local/bin/homelab-usb-backup` (not in the repo). It saves AdGuard Home's config from the cluster as `manifests/AdGuardHome.yaml` in the encrypted archive.
- Alerting is Alertmanager emailing through Gmail, configured by the SOPS secret `kubernetes/manifests/monitoring/sops/alertmanager-config.sops.yaml`. Prometheus keeps 7 days or 9GB of data on a 10Gi volume; a week is about 2.4GB. The owner wants email only for things to act on; everything else belongs on a dashboard.

## Goals / Non-Goals
- Goals:
  - Block pod egress that is not on a reviewed allowlist, and email naming the workload and destination when something is blocked.
  - Detect known-malicious traffic from crete and the VMs, and unusual new destinations from crete, without blocking it on crete.
  - Find fixable known vulnerabilities in cluster images and in crete's non-apt Go binaries, and weak settings in the cluster and on crete. Vulnerabilities in crete's Ubuntu packages and snaps are handled by patching and the update-health alerts, not by a separate package CVE inventory.
  - Notice when crete's security updates stop being applied.
  - Notice when any scanner, detector or the alert path itself stops working.
- Non-Goals:
  - Blocking on crete.
  - Egress policies for `kube-system` and host-network pods (Cilium agent, kube-apiserver, etcd).
  - Scanning the Talos OS itself: Talos is immutable and its patch releases arrive as Renovate PRs. Trivy's node collector is off because its CIS file checks are written for kubeadm-style layouts, not because Talos has nothing to check.
  - Secret scanning of the git repository (secrets are SOPS-encrypted by convention), runtime process monitoring (Tetragon), rootkit or antivirus scanning, file integrity monitoring, an inventory of listening services.
  - Visibility of traffic that never crosses `eno2` (crete to its own VMs, VM to VM, pod to pod on one node, loopback), or of the contents of encrypted traffic.
- Anti-goals (the change fails if these happen, even if it works on paper):
  - Alert fatigue: more than a handful of emails a week in steady state.
  - A legitimate app broken by enforcement without an email naming the workload and destination.
  - This change itself adding a listening service on crete or a credential in plaintext, or putting secret material in a metric or an email.

## Decisions

### Cluster egress: one owner of default deny, additive allowlists
- **Baseline** `CiliumClusterwideNetworkPolicy` `egress-baseline` is the only policy that turns on egress default deny. It selects every pod whose namespace is not on its exempt list (`kube-system` permanently, plus namespaces not yet enforced during rollout). It allows only DNS to `kube-dns` with the `dns` rule `matchPattern: "*"`. New namespaces are covered automatically. `enableDefaultDeny.ingress: false`.
- **Per-namespace** `CiliumNetworkPolicy` named `egress`, with `enableDefaultDeny: {egress: false, ingress: false}` so it only adds allows and never isolates on its own. It has one entry in `specs:` per workload, each with its own `endpointSelector` on the pod labels: a rule cannot be scoped to some of the pods a policy selects, so per-workload allowlists need separate specs. Allows are additive across every policy that selects a pod, so the existing `dns-visibility` policy (DNS to kube-dns only) adds nothing beyond the baseline, and no policy here uses `egressDeny`.
- Each spec allows only what that workload needs:
  - `toEntities: [kube-apiserver]` for controllers and operators
  - `toEndpoints` for named in-cluster peers with ports, in the same namespace or another one by `k8s:io.kubernetes.pod.namespace`. Known pairs to cover: Prometheus to every scrape target and to Alertmanager, Grafana to Prometheus, the Argo CD components to each other and to Redis, external-dns to AdGuard's API, the Tailscale proxies to their backend Services, and the Trivy scan jobs to the Trivy server. The full list comes from `hubble_flows_processed_total` workload pairs, not only the internet table above.
  - `toFQDNs` with exact names, adding the apex name wherever a wildcard is used. A `*` matches within one DNS label, so multi-level names are listed explicitly.
  - `toCIDR` or `toEntities: [world]` with ports where traffic is by IP (below)
- **Prometheus** also reaches `host` and `remote-node` for node and kubelet metrics, and `toCIDR: 192.168.1.234/32` on 9100 and 9256.
- **By-IP destinations:**
  - AdGuard upstream DNS: `toCIDR` for the configured resolvers on 53, 443 and 853.
  - AdGuard filter lists: `toCIDR: 185.199.108.0/22` on 443, where the lists it uses are hosted. AdGuard faces the whole LAN, so it does not get 443 to any address. A filter refresh after a cold start is part of the tests, and a list that moves is a drop alert, not a silent failure.
  - Tailscale proxies (`ts-*`): UDP to `world` on any port (direct peer connections land on whatever port a peer's NAT maps, not only 41641) and TCP 443 to `world` (DERP relays by IP). The operator gets only TCP 443 to `tailscale.com` and `*.tailscale.com` names and the Kubernetes API. These are deliberate broad exceptions for the proxy pods, not a statement that the traffic is safe. Cilium's `world` identity is everything outside the cluster, LAN included, which direct connections from devices on the LAN need.
- **Trivy** (`trivy-system`): the built-in Trivy server (`builtInTrivyServer: true`) is the only component that downloads the vulnerability database (`mirror.gcr.io`, plus the host it redirects blob downloads to). Config audit uses the operator's embedded checks, so nothing downloads a checks bundle. Image scans use `trivy.command: rootfs` (filesystem mode turns off the Go binary and language package analyzers): the scan job runs the target image as its container, so kubelet pulls it at the node level and the job needs no registry access, only the in-cluster Trivy server. Rootfs mode runs the scan container as root with no service account token; that is accepted for a short-lived job with no egress beyond the Trivy server. Scan jobs also try `check.trivy.dev` (Trivy's version check and telemetry), which the operator cannot turn off; it stays blocked and is excluded from the egress alert. Images used only by CronJobs are not scanned in this mode (today only `lifting-data`), so they are left out of the coverage alert and noted as a gap. Rootfs mode also turns on the jar analyzer: an image containing jars makes its scan job fetch `mirror.gcr.io/aquasec/trivy-java-db`, which needs an allowlist entry for scan jobs if such an image is ever added (none runs today).
- **Argo CD** repo-server also needs the new Trivy chart source (`aquasecurity.github.io`, whose chart files are downloaded from `github.com` and `release-assets.githubusercontent.com`).
- **Residual access, accepted:** `toFQDNs` allows the IPs a name resolved to while Cilium keeps them (at least the DNS TTL, longer for open connections), so another site on the same CDN address is reachable on the allowed port. It does not check the TLS SNI or HTTP Host. DNS itself is allowed to any name through kube-dns for every pod. The allowlist limits addresses and ports, not hostnames end to end.

### Rollout: a bounded audit week, then enforce one namespace at a time
- **Before any policy is applied:** set `policyAuditMode: true` in the Cilium values, confirm the rendered `cilium-config` has `policy-audit-mode: "true"` and that `cilium-dbg config` shows `PolicyAuditMode: Enabled` on both agents, and only then add the `egress` Argo CD app. A sync wave or a separate PR keeps the policies from arriving first.
- **Audit week:** the baseline (only `kube-system` exempt) and every namespace policy are applied. Flows that would be dropped are forwarded and carry the verdict `AUDIT`. Global audit mode also stops Argo CD's ingress NetworkPolicies from enforcing for the week, which is accepted for this one bounded window. Audit mode reports L3 and L4 decisions; it does not turn a DNS proxy rejection into an audit, so the DNS rule allows every name.
- The week covers a golf-etl session, a sync of every Argo CD app, an AdGuard filter refresh after an AdGuard restart, an Alertmanager email, a Trivy database refresh, a forced test certificate renewal (`cmctl renew`), a direct and a relayed Tailscale connection from the phone, and a restart of every workload. Restarts and fresh connections matter: existing connections and cached DNS answers can hide a missing rule.
- **Enforcement, staged:** first put every namespace except cert-manager on the baseline's exempt list, confirm the live CCNP and endpoint policy revisions on both nodes show that, and only then turn audit mode off. The rest follow one at a time, at least a day apart, low risk first: external-dns, lifting-data, golf-etl, trivy-system, tailscale, adguard, argocd, monitoring. `monitoring` is last because it carries the alert path, and it is enforced only after a local check (below) passes. After each, restart the namespace's workloads and exercise them.
- **Later changes** to the allowlists do not use global audit mode again. A new destination is added to the workload's spec and verified by exercising the workload with the drop alert watching. A brand-new workload starts in a namespace on the exempt list until its spec is written.
- **Break-glass, local:** from crete, `kubectl -n kube-system exec` into each Cilium agent and run `cilium-dbg config PolicyAuditMode=Enabled`. Egress drops stop within seconds on that node, with no git change and no outside network, and nothing in Argo CD reverts it. It also relaxes every other policy until the agent restarts, so it is for emergencies: the fix goes into git (an allowlist entry or an exempt-list entry), then `cilium-dbg config PolicyAuditMode=Disabled`. Tested once on a quiet day as deny, recover, deny on an existing pod on each node with fresh connections, from crete's kubeconfig (which reaches the API at the control plane IP without cluster DNS, the gateway or Tailscale), with the time to recovery recorded.

### Egress alerts
- **External egress blocked by policy:** remove `any-drop` from the `flows-to-world` metric so it counts only policy-denied drops, and alert on its `DROPPED` series. Each alert names the source workload, destination hostname or IP, and port.
- **In-cluster drops by policy:** `hubble_drop_total{reason="POLICY_DENIED"}` with the destination not `reserved:world` (so it does not repeat the external alert), naming source and destination workloads. It also counts ingress denials (Argo CD's NetworkPolicies), which are worth knowing about; the alert text says the direction is not known.
- **Audit week:** Hubble's static flow exporter writes every `AUDIT` policy verdict to a file on each node for the week (filter on the verdict), so nothing is lost to Hubble's in-memory buffer; the files are read with `kubectl exec` and drive the allowlist additions. A deliberate unlisted `curl` also shows whether any Prometheus series records the verdict, and if one does an alert is added on it.
- Add `labelsContext=source_namespace,destination_namespace` to the Hubble flow, drop and flows-to-world metrics so alerts filter by namespace and group by `source_namespace` and `source`.
- Rules catch the first event of a new series (a counter that appears at 1 has no `increase()`), for example `increase(x[10m]) > 0 or ((x > 0) unless x offset 10m)`, tested against a new zero-valued series and a scrape gap. Scrape, evaluation and `group_wait` together put delivery within about ten minutes.
- Prometheus detects drops from scraped counters, so it reports that a workload was denied a destination within a few minutes; the exact event detail lives in Hubble (`hubble observe --verdict DROPPED --from-pod ...`), named in the alert text. Destination labels exist only on denied series, which keeps them small on the 10Gi volume.

### The alert path itself
- Before `monitoring` is enforced, a local check from crete confirms: Prometheus scrapes all targets (`up == 1`), Prometheus reaches Alertmanager, and a test alert produces an email. The same check runs after enforcement.
- The Monday reminder email (below) is the heartbeat for the case where the whole path is down, including crete itself: if Monday's reminder does not arrive, something in the chain is broken.

### Weekly health dashboard and reminder
- **Prometheus retention** goes from 7 to 15 days, keeping the 9GB size cap. A week of data is about 2.4GB today, so two weeks plus the new metrics fit on the 10Gi volume, and every panel can compare with the week before (`offset 7d`).
- **Grafana dashboard "Homelab weekly"**, provisioned from a ConfigMap like the existing dashboards, with this week and last week overlaid:
  - **crete:** CPU average and peak, memory, disk use and growth rate, temperature peak, reboots and whether they were clean, pending security updates, Lynis hardening index
  - **cluster:** node readiness, Argo CD app health, pod restarts, PVC use, the qcow2 sizes on crete
  - **security:** blocked egress by workload and destination, Suricata hits by signature, open fixable critical and high findings, accepted findings expiring within 30 days, new names observed from crete, threat-list blocks in AdGuard
  - **watchers:** stale or missing scanner results, alerts currently firing
- **Monday reminder email:** a CronJob in `monitoring` runs early every Monday (America/New_York). A small Python script, kept in a ConfigMap and run on a pinned `python:3-slim` image, queries Prometheus for about six headline figures (blocked egress, Suricata hits, open fixable findings, stale scanners, firing alerts, crete's disk use), each with last week's, plus whether Alertmanager's email notifications succeeded or failed during the week and whether every scrape target is up, since the reminder itself bypasses Alertmanager, and sends a short plain email with a link to the dashboard at `https://grafana.tailb4b203.ts.net`. A figure with gaps in its data is marked incomplete.
- The job needs no Kubernetes API access. Its egress spec allows only Prometheus and `smtp.gmail.com:587`, and it uses its own Gmail app password in a SOPS-encrypted Secret, so one revoked credential cannot silence both the alerts and the reminder.
- The reminder doubles as the heartbeat: it arrives only if crete, the cluster, Prometheus and the mail path all work. A dead crete is therefore noticed within a week, not within the hour; an outside heartbeat service can be added later if that matters.

### Alertmanager
- New routes with stable `group_by` labels: egress by `source_namespace` and `source`; Trivy by namespace and workload (not pod or tag); host scanning by scanner; Suricata by signature ID. Every rule carries a `summary` and a `description` naming what to look at or run.
- `repeat_interval` is 24h for egress and Suricata and 7d for vulnerabilities. Alertmanager's notification log keeps 120h today, so a 7d repeat would re-send after five days; its `retention` goes to 192h. A test confirms the existing catch-all route neither swallows nor duplicates the new ones. Grouping and repeat intervals shape the email volume; they are not a hard cap, because a new member of a group or a resolve-then-fire cycle sends another email. The anti-goal is measured after two weeks (task 7.3) and tuned from real numbers.

### Grafana
Set `analytics.reporting_enabled: false`, `analytics.check_for_updates: false`, `analytics.check_for_plugin_updates: false` and `security.disable_gravatar: true`. Grafana's egress spec allows DNS and its in-cluster data sources and no internet destinations; the policy is what guarantees it.

### Cluster scanning: Trivy Operator
- Helm chart `aquasecurity/trivy-operator` in namespace `trivy-system`, as an Argo CD app with Renovate tracking the chart.
- Scanners on: vulnerabilities, config audit, RBAC assessment, and secrets baked into images. Infra assessment and the node collector off.
- All namespaces are scanned, `kube-system` included, and init containers too. One scan job at a time (`scanJobsConcurrentLimit: 1`); reports for new images arrive as the queue allows, typically within an hour.
- ServiceMonitor on, with the per-CVE metrics enabled. The pinned chart's metric names, and the label that carries the fixed version, are confirmed before any rule is written. Metrics and alerts carry the finding's ID and the affected resource, never matched secret content.
- **Triage before alerting:** the first week is dashboard only. Each existing critical or high finding is either fixed (usually a Renovate bump) or accepted. Acceptances live in the repo with a reason and an expiry date, scoped to the finding and the affected image or resource, using the mechanism each report type supports (Trivy's ignore policy for vulnerabilities and secrets, the operator's per-check exclusions for config and RBAC). A plain global CVE ignore is not used, so the same CVE in a new image still alerts. After triage, any finding present is new, so the rules alert on presence:
  - a fixable critical or high vulnerability, as soon as it is reported, grouped per workload, `repeat_interval: 7d`
  - a critical or high config audit, RBAC or baked-in secret finding, `for: 15m`
- **Scanner health:** alerts for a running workload with no report after 24 hours, a report older than its rescan interval, failed scan jobs, and a Trivy database older than 3 days, so a quiet dashboard cannot mean a stopped scanner.

### Host scanning on crete
- New Ansible role `host_scanning`. Every script:
  - writes its `.prom` file through a temporary file outside the `*.prom` pattern in the same directory, then renames it
  - exports `<name>_last_success_timestamp_seconds` as a gauge value (Unix seconds) and keeps the previous value when a run fails
  - exports `<name>_last_run_status`
- node_exporter gets `--collector.textfile.directory=/var/lib/node_exporter/textfile` (in the `exporters` role).
- **Trivy:**
  - Installed from a pinned GitHub release with checksum verification, with Renovate tracking the version in `ansible/group_vars/all.yml`.
  - A daily timer runs `trivy rootfs --scanners vuln` once per directory, with absolute paths, following symlinks to the real binaries: `/usr/local/bin`, `/home/rumstead/.local/bin` and `/home/rumstead/go/bin`.
  - Trivy reads the Go module and standard library versions embedded in Go binaries (talosctl, sops, age, hubble, the exporters). Non-Go binaries (the Claude Code and Copilot CLIs, mise) are not covered and update themselves.
  - The script exports how many binaries it found per directory, so a scan that discovers nothing is visible.
  - It also exports `host_trivy_vulnerabilities{severity,fixable,binary}` and keeps a local per-binary report (binary, installed version, CVE, fixed version) in `/var/lib/host-scanning/`. A fixed module version does not always mean upstream has shipped a new binary, so the report says which.
- **Lynis:**
  - A weekly timer runs a full `lynis audit system`.
  - The script parses `/var/log/lynis-report.dat` and compares the run's warning IDs, with their text, against the previous completed run. The first valid run is the baseline and sends nothing.
  - It exports `host_lynis_hardening_index`, `host_lynis_warnings` and a counter `host_lynis_new_warnings_total`, and writes the new warnings to `/var/lib/host-scanning/lynis-new-warnings.txt`.
  - It notes a Lynis version change, since that can add warnings.
- **Update health:**
  - An hourly script exports, separately for unattended-upgrades and for `host-auto-update`, the last run that completed successfully (a successful no-op counts).
  - It also exports the age of the package lists, and the packages whose candidate version comes from the security or ESM origins and is not installed, from `apt-cache policy` and `pro security-status --format json`.
  - First-seen times live in its state file, which it updates only after a successful check.
  - It records when `reboot-required` first appeared in that state, not from the file's mtime.
- Alerts:
  - a fixable critical or high in the host scan, as soon as it is found, `repeat_interval: 7d`
  - `increase(host_lynis_new_warnings_total[2h]) > 0`, so it fires once right after the run that found the warnings, with the annotation pointing to that run's dated warnings file (kept, not overwritten), or the hardening index 5 or more below the previous completed run. Partial audits are rejected and do not replace the previous run.
  - a security update first seen 3 or more days ago, either updater without a successful run in 2 days, package lists older than 2 days, or `reboot-required` older than 8 days
- **Stale or missing results:** an alert when any expected `_last_success_timestamp_seconds` series is absent (`absent()`), older than twice its schedule, when `node_textfile_scrape_error` is 1, or when the node_exporter target is down.

### Host traffic detection: Suricata on eno2
- New Ansible role `host_ids`: Suricata from the Ubuntu archive in IDS mode with af-packet. It captures on `eno2`, the physical uplink, which carries every frame between the LAN or internet and either crete or the VMs, in both directions, once. A capture on `br0` is not used: what the bridge device sees of frames forwarded between its ports depends on promiscuous handling, and it double-counts. Pod traffic that stays on one node, and VM-to-VM traffic, never reach `eno2` and are out of scope.
- Coverage is tested, not assumed: a known request and its response from crete and from a pod on each node appear in EVE with the right addresses, compared against a short `tcpdump` on `eno2`. Pod traffic appears with the node's address after masquerade; the pod is identified through Hubble. Offloads are tuned only if the tests miss traffic.
- EVE JSON logs alerts, DNS, TLS and QUIC, with logrotate bounding disk use and the log readable only by root and the metrics script, since it describes workstation activity. No listening ports.
- **Rules:** `suricata-update` on a daily timer with the Emerging Threats Open set. New rules are validated with `suricata -T` and loaded with a reload. The running engine's loaded-rules count and rule set timestamp, from Suricata's own stats, are compared against the new set; the last good set stays when validation fails.
- **Health:** a metrics script (every minute, atomic writes) exports Suricata's packet and kernel-drop counters, so a stalled capture shows up as packets not increasing, alongside alerts per signature ID with priority and category, rule set age, and its own last-success time. It reads EVE with a persistent cursor that survives rotation.
- **First-seen names (observed names, not proven connections):**
  - A daily job takes DNS queries and TLS and QUIC names from EVE whose source is one of crete's addresses, IPv4 and IPv6 as currently assigned to `br0`.
  - It normalizes them (lowercase, no trailing dot, IDN to ASCII) and reduces them to registrable domains with the Public Suffix List from the `publicsuffix` package.
  - It compares them with the baseline in `/var/lib/egress-baseline/`, writes the day's new ones to a dated file kept 90 days, then adds them to the baseline.
  - A completed day's count is exported until the next day completes. The job catches up on missed days after downtime and records which days were valid.
  - Encrypted DNS, ECH and connections straight to an IP produce no name, and are not covered.
- Alerts:
  - a Suricata alert of priority 1, or of priority 2 in a reviewed list of categories kept in the role, grouped per signature with `repeat_interval: 24h`. Signatures that prove noisy go in a suppression list in the role.
  - packets not increasing for 10 minutes (crete's link always carries some traffic, from NTP and the cluster), kernel drops above 1% over the last hour when at least 10,000 packets arrived, the Suricata engine's stats not advancing, rules older than 3 days, or a stale metrics or names job; each also fires when its series is missing. Alerts include the direction and the EVE command to investigate, not only the signature ID.
- New names are **dashboard only** at first: Grafana shows the daily count, and the list stays on crete in the dated files (the panel description has the command to read it), so browsing history never becomes Prometheus labels. Days whose EVE data rotated away before the job ran are marked incomplete. An email threshold is set only once 4 weeks of real data show a level that separates an unusual day from a normal one, so it does not start as noise.

### AdGuard threat intelligence (LAN-wide blocking)
- Adding the HaGeZi Threat Intelligence Feeds list makes AdGuard refuse to resolve known-malicious domains for every client that uses it, crete included through the router. That is blocking, separate from the detection-only stance on crete.
- Steps: take a USB backup first, add the list in the UI, check it shows a recent update time and blocks a test domain from the list, confirm ordinary browsing and `apt update` on crete still work, then take another USB backup so the setting is saved.
- Quick undo: disable the list in AdGuard's DNS blocklists page (one toggle, takes effect immediately). A single false positive goes on AdGuard's allowlist instead.
- AdGuard's settings live on its volume, not in git, and this change does not alter that. While the cluster is down the list cannot be toggled, but the router's secondary DNS keeps the LAN resolving; that fallback stays until a later change removes it.

### Proving the alerts
Each alert class gets one received positive and one quiet negative before it counts as working, with test series under a distinct `test="true"` label so they never mix with real ones:
- egress: a deliberate `curl` to an unlisted host from a policed pod (positive) and a listed host (negative); a deliberate cross-namespace connection for the in-cluster rule
- Trivy vulnerabilities: a throwaway pod in a throwaway namespace running an old image with a known fixed critical CVE, with no service account token, a deny-all egress policy, and a short test rule
- Trivy config, RBAC and secrets: separate harmless fixtures in the same throwaway namespace, with nothing privileged run on the live nodes: an unprivileged pod missing hardening settings (proved with a test copy of the config rule that also matches medium severity), a Role with a wildcard verb bound to nothing, and an image containing a dummy, never-valid credential
- host Trivy: an old Go release binary in a test directory outside `PATH`, scanned by a test run of the script
- Lynis, update health and staleness: synthetic metrics in a test file in the textfile directory; one scanner's timer stopped for a test window proves the stale rule, and that scanner's `.prom` file moved aside for a test window proves the absent rule. No real setting is weakened and updates are never stopped.
- Suricata: a local test rule in the role matching a unique string, triggered by `curl` from crete to a LAN address (proves capture and the mail path without the external feed), then `curl http://testmynids.org/uid/index.html` from crete and from a pod in a test namespace with a temporary allow for that host (proves the ET rule is loaded and qualifies for email). Capture health is proven by stopping Suricata for a test window.

## Approaches considered (host traffic detection)
- **Suricata IDS on the uplink (chosen: recommended when the owner asked for a suggestion).** Covers crete and the VMs, catches known-bad traffic including connections straight to IPs, and its DNS and TLS logs feed the first-seen-name report. It costs around 0.5 to 1 GB of RAM and some rule tuning.
- Route crete's DNS through AdGuard for per-client logs. Cheap, but it makes crete depend on a service running inside its own VMs (a slow cluster start would leave the host without DNS) and it misses traffic that skips DNS.
- Connection-tracking baselines (log new outbound flows from conntrack and alert on new destinations). Catches unknown destinations but not known-bad patterns, and means maintaining custom code.

## Risks / Trade-offs
- A destination missed by the audit week breaks one app after enforcement. Mitigated by staged enforcement, the drop alert naming the workload and destination, the tested break-glass, and the allowlist living in one directory.
- Break-glass relaxes every policy on the node until the agent restarts or it is switched back. Accepted for emergencies only.
- A pod that connects to a hard-coded IP not in its allowlist is blocked, which is intended.
- The Tailscale proxies' rules are broad (any UDP, TCP 443 to any address). Accepted for those pods only.
- Trivy rootfs scans run each target image as a short-lived root container without a token or outside egress.
- Suricata false positives. Mitigated by the category list, per-signature grouping and the suppression list.
- The first-seen baseline adds every new domain after one day, so a one-off malicious domain stops being "new" the next day. The dated daily files keep the full history for review.
- The HaGeZi list can block a legitimate domain for the whole LAN; the undo is one toggle or an allowlist entry.
- AdGuard's blocklist setting is not in git and depends on the USB backup.

## Rollback
- Egress: the break-glass for an emergency, then the exempt list or an allowlist entry in git. Removing every policy means removing the `egress` app from `kubernetes/argocd-apps` in git (the app-of-apps would recreate a hand-deleted app) with Argo CD's prune deleting the policies, then confirming none are left with `kubectl get ccnp,cnp -A`.
- Scanning and detection: disable the Argo CD app or stop the host timers and Suricata. Nothing else depends on them.
- AdGuard list: one toggle in AdGuard.

## Decisions Made With The Owner
- Crete's update scripts stay as they are: unattended-upgrades already installs security updates, kernels included.
- Vulnerability emails cover fixable critical and high findings, sent as soon as they are found and repeated at most weekly per workload or binary.
- Broad TCP 443 for the Tailscale proxies; AdGuard limited to its upstream resolvers and GitHub's `185.199.108.0/22`.
- The HaGeZi Threat Intelligence list is added to AdGuard: blocking known-malicious domains for the whole LAN is wanted, with the one-toggle undo documented.
- A Grafana "Homelab weekly" dashboard holds the full picture, and a short Monday email points to it with headline figures. The email, not an outside heartbeat service, covers a dead alert path: its absence is the signal. Prometheus retention rises to 15 days for the week-over-week view.
