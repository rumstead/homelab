## ADDED Requirements

### Requirement: Intrusion Detection On The Uplink
Suricata SHALL inspect traffic on crete's physical uplink `eno2`, which carries traffic between the LAN or internet and both crete and the Talos VMs, in detection-only mode with the Emerging Threats Open rules updated daily. It SHALL keep the last valid rule set when an update fails validation, and SHALL NOT block traffic or listen on any network port.

#### Scenario: Known-bad traffic from crete
- **WHEN** crete requests `http://testmynids.org/uid/index.html`
- **THEN** Suricata SHALL log an alert and an alert email SHALL be sent

#### Scenario: Traffic from a VM
- **WHEN** a pod on either Talos node requests the same URL
- **THEN** Suricata SHALL log an alert for it

#### Scenario: No blocking
- **WHEN** Suricata raises an alert
- **THEN** the traffic SHALL still be forwarded

#### Scenario: Unhealthy capture
- **WHEN** captured packets stop increasing for 10 minutes, kernel drops exceed 1% over an hour, or the rules are older than three days
- **THEN** an alert email SHALL be sent

### Requirement: Alert Email Policy
Suricata alerts SHALL email only for priority 1, or priority 2 in a reviewed list of categories, grouped per signature and repeated at most daily, with noisy signatures suppressed in the host role.

#### Scenario: Low-priority alert
- **WHEN** Suricata logs an alert outside the emailing set
- **THEN** no email SHALL be sent and the alert SHALL be counted in Prometheus

### Requirement: First-Seen Names
Crete SHALL record each day's DNS, TLS and QUIC names from its own IPv4 and IPv6 addresses that it has never observed before, reduced to registrable domains with the Public Suffix List, keep each day's list on crete for 90 days, and show the daily count in Grafana without exporting the names themselves. An email threshold SHALL be added only after four weeks of data show a level that separates an unusual day from a normal one.

#### Scenario: Before a threshold exists
- **WHEN** no threshold has been set from real data
- **THEN** no new-name email SHALL be sent and the count SHALL be visible on the dashboard

#### Scenario: Traffic from the VMs
- **WHEN** a pod or Talos node contacts a new domain
- **THEN** it SHALL NOT count toward crete's new domains

#### Scenario: Missed day
- **WHEN** the job did not run for a day
- **THEN** it SHALL catch up on the next run and record which days are valid

### Requirement: Threat Intelligence Blocklist
AdGuard Home SHALL block domains on the HaGeZi Threat Intelligence Feeds list for every client that resolves through it, with a one-step way to disable the list.

#### Scenario: Known malicious domain
- **WHEN** a device on the LAN, including crete through the router, resolves a domain on the list
- **THEN** AdGuard SHALL block the answer and count it as blocked
