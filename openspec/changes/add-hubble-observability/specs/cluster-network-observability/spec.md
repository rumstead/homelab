## ADDED Requirements

### Requirement: Cluster-Wide Flow Visibility
The cluster SHALL provide a single view of network flows from all nodes through Hubble Relay, reachable with the `hubble` CLI from the host.

#### Scenario: Observe flows from every node
- **WHEN** an operator runs `hubble observe` against Hubble Relay
- **THEN** flows from both `talos-controlplane` and `talos-worker` SHALL be returned
- **AND** each flow SHALL include source and destination identity, port, and verdict

#### Scenario: Recent flow history
- **WHEN** an operator inspects flows shortly after an event
- **THEN** each node SHALL retain at least 16383 recent flows in memory

### Requirement: Stable Hubble TLS
Hubble server and relay certificates SHALL be issued by cert-manager from `homelab-ca-issuer` and SHALL NOT change when Argo CD re-renders the Cilium chart.

#### Scenario: Chart re-render
- **WHEN** Argo CD refreshes or re-syncs the `cilium` application without a values change
- **THEN** the Hubble CA and server certificates SHALL remain unchanged
- **AND** Hubble Relay SHALL stay connected to every agent

### Requirement: Hubble UI Access
Hubble UI SHALL be reachable at `hubble.acemagic.lab` through `homelab-gateway` on the HTTP listener, without authentication.

#### Scenario: Open the UI from the LAN
- **WHEN** a LAN client resolves `hubble.acemagic.lab` and opens it in a browser
- **THEN** the Hubble UI SHALL load and show the service map and flows for the selected namespace

### Requirement: Egress Metrics
Hubble SHALL export metrics to Prometheus that identify which workload sent traffic to which external destination, labeled by source workload and destination hostname (falling back to IP when no hostname is known).

#### Scenario: Workload reaches the internet
- **WHEN** a pod sends traffic to a destination outside the cluster
- **THEN** `hubble_flows_to_world_total` SHALL increase for a series labeled with the source workload, destination hostname or IP, protocol, port, and verdict

#### Scenario: Pod DNS lookups
- **WHEN** a pod resolves a hostname through CoreDNS
- **THEN** a Hubble DNS metric SHALL record the query labeled with the source workload

### Requirement: DNS Visibility Without Enforcement
A cluster-wide policy SHALL route pod DNS through the Cilium DNS proxy so flows carry hostnames, and it SHALL NOT enable default deny for any endpoint.

#### Scenario: Existing traffic is unaffected
- **WHEN** the DNS visibility policy is applied
- **THEN** no flow that was previously forwarded SHALL be dropped
- **AND** pods SHALL continue to resolve cluster and external names

### Requirement: Network Dashboards
Grafana SHALL include the Cilium and Hubble dashboards and an Egress dashboard showing external destinations per workload.

#### Scenario: Review egress
- **WHEN** an operator opens the Egress dashboard
- **THEN** it SHALL show the top workloads sending traffic outside the cluster and their destinations over the selected time range
