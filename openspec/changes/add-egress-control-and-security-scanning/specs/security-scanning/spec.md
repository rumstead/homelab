## ADDED Requirements

### Requirement: Cluster Image Scanning
Trivy Operator SHALL scan every container image running in the cluster for known vulnerabilities and export the results to Prometheus, running at most one scan job at a time.

#### Scenario: New image
- **WHEN** a workload starts with an image not scanned before
- **THEN** a VulnerabilityReport for it SHALL exist within 24 hours, and an alert SHALL be sent if it does not

#### Scenario: Scanner stalls
- **WHEN** scan jobs fail or the vulnerability database is older than three days
- **THEN** an alert email SHALL be sent

#### Scenario: Fixable vulnerability
- **WHEN** an image has a fixable critical or high vulnerability that is not in the ignore file
- **THEN** an alert email SHALL be sent, grouped per workload and repeated at most weekly

### Requirement: Accepted Findings In The Repo
Findings that are accepted rather than fixed SHALL be recorded in the repo with a reason and an expiry date, scoped to the finding and the affected image or resource, and alerts SHALL start only after the existing findings have been triaged. Metrics and emails SHALL NOT contain matched secret content.

#### Scenario: Accepted finding
- **WHEN** an accepted finding is reported for the image or resource it was accepted for
- **THEN** it SHALL NOT send email

#### Scenario: Same CVE in a new image
- **WHEN** an accepted CVE appears in a different image
- **THEN** it SHALL alert

### Requirement: Cluster Configuration Audit
Trivy Operator SHALL audit workload configuration and RBAC and look for secrets baked into images, and SHALL email when a critical or high finding not in the ignore file appears.

#### Scenario: New finding
- **WHEN** a critical or high config audit, RBAC or baked-in secret finding appears
- **THEN** an alert email SHALL be sent

### Requirement: Host Vulnerability Scanning
Crete SHALL be scanned daily for known vulnerabilities in the Go binaries not managed by apt (`/usr/local/bin`, `/home/rumstead/.local/bin`, `/home/rumstead/go/bin`), exporting how many binaries were found and keeping a per-binary report.

#### Scenario: Fixable vulnerability on crete
- **WHEN** a scanned binary has a fixable critical or high vulnerability
- **THEN** an alert email SHALL be sent, repeated at most weekly

### Requirement: Host Hardening Audit
Crete SHALL run a weekly Lynis audit, compare each completed run's warnings with the previous completed run, and email when a new warning appears or the hardening index drops by five or more. The first run SHALL only set the baseline.

#### Scenario: New warning
- **WHEN** a weekly audit has a warning the previous run did not
- **THEN** an alert email SHALL be sent naming where to find the warning IDs

### Requirement: Host Update Health
Crete SHALL export, separately for unattended-upgrades and `host-auto-update`, when each last completed successfully, plus the age of the package lists, the security and ESM updates whose candidate version is not installed with when each was first seen, and how long a reboot has been required. It SHALL email when a security update has been pending for three days, either updater has not succeeded for two days, the package lists are older than two days, or a required reboot is older than eight days.

#### Scenario: Updates stop applying
- **WHEN** the daily update run fails two days in a row
- **THEN** an alert email SHALL be sent

### Requirement: Scanner Freshness
Every host scanner and detector SHALL export its last successful run time as a gauge, keep it when a run fails, and write its metrics atomically. An alert SHALL fire when a result is older than twice its schedule, when an expected result is missing, or when the textfile collector or node_exporter fails.

#### Scenario: Scanner stops
- **WHEN** a scanner's timer stops running
- **THEN** a stale-results alert SHALL be sent instead of the last results being trusted

#### Scenario: Result never produced
- **WHEN** a scanner's metrics file is missing
- **THEN** an alert SHALL be sent

### Requirement: Alerts Proven On Known Positives
Every alert class SHALL be fired once on a deliberate, safe test case and shown quiet on a negative case before the capability is considered working, using test series that cannot mix with real ones, without weakening a real setting or stopping updates.

#### Scenario: New alert rule
- **WHEN** an alert rule is added
- **THEN** it SHALL be triggered once by a test case and the email SHALL be received
