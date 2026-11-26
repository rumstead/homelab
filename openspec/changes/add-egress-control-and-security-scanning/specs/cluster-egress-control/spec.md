## ADDED Requirements

### Requirement: Egress Default Deny
A cluster-wide baseline policy SHALL be the only policy that enables egress default deny. It SHALL select every pod outside `kube-system` and the namespaces on its exempt list, allowing only DNS to `kube-dns` through the Cilium DNS proxy. Namespaces created later SHALL be covered without a new policy.

#### Scenario: New namespace
- **WHEN** a pod starts in a namespace that has no egress allowlist and is not exempt
- **THEN** it SHALL resolve names but its other egress SHALL be dropped

#### Scenario: kube-system
- **WHEN** a pod in `kube-system` opens a connection
- **THEN** the egress default deny SHALL NOT apply to it

#### Scenario: Ingress unchanged
- **WHEN** a client reaches a service through `homelab-gateway` or a Tailscale ingress
- **THEN** the egress policies SHALL NOT drop the request or its response

### Requirement: Per-Workload Allowlists
Each application namespace SHALL have one egress policy with a separate spec per workload that only adds allows (it SHALL NOT enable default deny itself), and each workload SHALL be allowed only its own destinations. In-cluster egress SHALL be limited to the named peers and ports a workload needs and the Kubernetes API where required. The allowlists SHALL live in `kubernetes/manifests/egress/`.

#### Scenario: Listed destination
- **WHEN** `argocd-repo-server` connects to `github.com` on 443
- **THEN** the connection SHALL be forwarded

#### Scenario: Another workload's destination
- **WHEN** a workload connects to a destination allowed only for a different workload in the same namespace
- **THEN** the connection SHALL be dropped

#### Scenario: Lateral probe
- **WHEN** a pod connects to a pod or port in another namespace that is not in its allowlist
- **THEN** the connection SHALL be dropped

#### Scenario: Hostname visibility kept
- **WHEN** a policed pod resolves a name through `kube-dns`
- **THEN** the query SHALL pass through the Cilium DNS proxy and the flow SHALL carry the hostname

### Requirement: Staged Enforcement
The initial rollout SHALL run in Cilium policy audit mode for at least seven days, with audit mode confirmed on both agents before any policy is applied, then SHALL enforce one namespace at a time at least a day apart, with `monitoring` last. Later allowlist changes SHALL NOT use global audit mode. A break-glass procedure that needs no git change, no Argo CD action and no outside network access SHALL be documented and tested once.

#### Scenario: Audit mode
- **WHEN** audit mode is on and a pod connects to an unlisted destination
- **THEN** the connection SHALL be forwarded and recorded with the verdict `AUDIT`

#### Scenario: Break-glass
- **WHEN** an enforced namespace's app is broken by a missing rule
- **THEN** switching audit mode on at runtime in the Cilium agents from crete SHALL restore its egress within five minutes, and Argo CD SHALL NOT revert it

### Requirement: Egress Alerts
Prometheus SHALL email an alert naming the source workload and the destination when a policed pod's egress to the internet is dropped by policy, and naming source and destination workloads when an in-cluster connection is dropped by policy. Only policy-denied drops SHALL count toward the internet egress alert, so LAN clients probing load balancer addresses do not alert. The alert path SHALL be checked end to end before the `monitoring` namespace is enforced.

#### Scenario: Blocked external connection
- **WHEN** a policed pod's connection to an outside host is dropped by policy
- **THEN** an alert naming the workload and the destination hostname or IP SHALL be sent within ten minutes

#### Scenario: First drop of a new destination
- **WHEN** a workload is denied a destination it has never been denied before
- **THEN** the alert SHALL fire on that first drop

#### Scenario: Repeated drops
- **WHEN** one workload keeps hitting the same drop
- **THEN** its alert group SHALL repeat at most once a day

### Requirement: Grafana Without Egress
Grafana SHALL NOT send usage reports, check for updates, or load Gravatar images, and its egress policy SHALL allow no internet destinations.

#### Scenario: Grafana running
- **WHEN** Grafana runs for a day
- **THEN** Hubble SHALL record no Grafana egress to the internet
