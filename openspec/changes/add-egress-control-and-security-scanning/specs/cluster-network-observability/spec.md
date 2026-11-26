## MODIFIED Requirements

### Requirement: DNS Visibility Without Enforcement
A cluster-wide policy SHALL route pod DNS through the Cilium DNS proxy so flows carry hostnames. This policy itself SHALL NOT enable default deny for any endpoint and SHALL allow nothing beyond DNS to `kube-dns`. Egress default deny comes only from the baseline policy in `cluster-egress-control`.

#### Scenario: Exempt namespace
- **WHEN** a pod runs in a namespace on the egress baseline's exempt list
- **THEN** no flow that was previously forwarded SHALL be dropped
- **AND** the pod SHALL continue to resolve cluster and external names

#### Scenario: Policed namespace
- **WHEN** a pod runs in a namespace covered by the egress baseline
- **THEN** its DNS queries SHALL still pass through the Cilium DNS proxy and its flows SHALL carry hostnames
