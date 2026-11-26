# Change: Block unexpected cluster egress, watch crete's traffic, and scan the cluster and host

## Why
The homelab can see where pods connect (Hubble `flows-to-world`, the egress dashboard) but nothing acts on it: any pod can reach any address, and nobody is told. Crete's own traffic is not recorded anywhere, and neither the container images nor the host are checked for known vulnerabilities or weak settings. The goal is to catch malicious or compromised behaviour and fixable security holes, and to hear about them by email only when there is something to act on.

## What Changes
- **Cluster egress default deny.** A cluster-wide `CiliumClusterwideNetworkPolicy` denies pod egress in every namespace except `kube-system`, allowing only DNS, so new namespaces are covered automatically.
- **Per-workload allowlists.** Each application namespace gets a `CiliumNetworkPolicy` with one spec per workload that allows only its own destinations: named hosts, named in-cluster peers, the Kubernetes API where needed, and port-bounded rules for traffic that goes by IP (AdGuard upstreams, Tailscale relays). Built from the Hubble flows already recorded.
- **Rollout.** One bounded week in Cilium policy audit mode, then enforcement one namespace at a time with `monitoring` last, and a tested break-glass (Cilium's runtime audit switch) that works from crete without git or Argo CD.
- **Egress alerts** email the source workload and destination when policy blocks a connection, using Hubble's policy-denied drop counts, and the alert path is checked end to end before the monitoring namespace is enforced.
- **Grafana phones home less.** Usage reporting, update checks and Gravatar are turned off; its policy allows no internet destinations.
- **Trivy Operator** scans every image in the cluster (filesystem mode with its built-in server, so scan jobs need no registry access), audits workload configuration and RBAC, and finds secrets baked into images, exporting to Prometheus. After a one-time triage, with accepted findings recorded in the repo with a reason, scope and expiry, it emails on fixable critical and high vulnerabilities and on critical or high configuration findings, and alerts when scanning itself stalls.
- **Host scanning on crete.** A daily Trivy scan covers the Go binaries apt does not manage (`/usr/local/bin`, `~/.local/bin`, `~/go/bin`), a weekly Lynis audit reports new warnings, and update health alerts when security updates sit unapplied or the update run fails. Every scanner reports a last-success time, and stale scanners alert.
- **Host traffic detection on crete.** Suricata watches the physical uplink `eno2` in detection-only mode with the Emerging Threats Open rules, covering crete's own traffic and the Talos VMs'. Selected high-priority alerts email, grouped per signature, and capture health is monitored. A daily job lists the names crete looked up or contacted for the first time, on a dashboard; email is added only once four weeks of data show a useful threshold.
- **AdGuard threat intelligence list.** AdGuard Home adds the HaGeZi Threat Intelligence Feeds blocklist, which blocks known-malicious domains for every device that resolves through it, crete included (via the router), with a one-toggle undo.
- **Alertmanager routes** with explicit grouping and repeat intervals aim for a handful of emails a week.
- **Weekly health dashboard and reminder.** A Grafana "Homelab weekly" dashboard shows crete, the cluster and the week's security events next to the week before (Prometheus retention rises from 7 to 15 days). A Monday email gives a few headline figures and the link. A missing email is the signal that the alert path is down.
- Every alert class is fired once on a safe known positive, and shown quiet on a negative, before the work counts as done.

## Impact
- New specs: `cluster-egress-control`, `security-scanning`, `host-network-detection`, `weekly-health-report`
- Modified spec: `cluster-network-observability` (the DNS visibility requirement no longer forbids default deny)
- Affected code:
  - `kubernetes/manifests/egress/` (new: the baseline `CiliumClusterwideNetworkPolicy` and per-namespace `CiliumNetworkPolicy` files) and an Argo CD app for it
  - `kubernetes/argocd-apps/cilium/cilium-app.yaml` (`policyAuditMode` during the audit week; `flows-to-world` without `any-drop` and `labelsContext` on the Hubble metrics)
  - `kubernetes/argocd-apps/monitoring/kube-prometheus-stack-app.yaml` (Grafana settings, Prometheus retention 15 days)
  - `kubernetes/manifests/monitoring/weekly-report/` (new CronJob, ConfigMap script and SOPS Secret) and a new `dashboard-homelab-weekly.yaml`, `kubernetes/argocd-apps/trivy-operator/` (new Argo CD app and ignore file), `kubernetes/manifests/monitoring/` (new PrometheusRules) and `kubernetes/manifests/monitoring/sops/alertmanager-config.sops.yaml` (routes)
  - `ansible/roles/exporters` (textfile collector directory), new `ansible/roles/host_scanning` and `ansible/roles/host_ids`, `ansible/site.yml`, `ansible/group_vars/all.yml` (pinned versions)
  - AdGuard Home settings (live on its volume, changed in the UI and saved by the USB backup, `~/.local/bin/homelab-usb-backup`)
- Breaking changes: after enforcement, a pod that needs a destination missing from its allowlist fails until the allowlist is updated
- Out of scope: blocking on crete, egress policies for `kube-system` and host-network pods (Cilium agent, kube-apiserver, etcd), scanning the Talos OS (patched through Renovate), git secret scanning, Tetragon, rootkit and antivirus scanning, file integrity monitoring, an inventory of listening services, backups (Garage, Velero), Pod Security Admission
