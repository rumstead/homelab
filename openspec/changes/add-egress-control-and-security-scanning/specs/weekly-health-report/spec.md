## ADDED Requirements

### Requirement: Weekly Health Dashboard
Grafana SHALL have a "Homelab weekly" dashboard, provisioned from git, showing the last seven days next to the seven before (where retention allows) for crete (CPU, memory, disk use and growth, temperature, reboots, pending security updates, hardening index), the cluster (nodes, Argo CD app health, pod restarts, PVC and VM disk use), security (blocked egress by workload and destination, Suricata hits by signature, open fixable critical and high findings, accepted findings expiring within 30 days, count of new names observed from crete, threat-list blocks) and the watchers (stale scanners, firing alerts). Prometheus SHALL keep at least 15 days of data so the comparison is possible.

#### Scenario: Week-over-week view
- **WHEN** the owner opens the dashboard
- **THEN** each panel SHALL show this week's data with last week's alongside

### Requirement: Monday Reminder Email
A CronJob in the `monitoring` namespace SHALL email the owner every Monday morning (America/New_York) a short summary of headline figures (blocked egress, Suricata hits, open fixable findings, stale scanners, firing alerts, crete's disk use), each with last week's, whether Alertmanager's email notifications succeeded during the week, whether every scrape target is up, and a link to the dashboard. It SHALL reach only Prometheus and `smtp.gmail.com:587`, and SHALL use its own Gmail app password from a SOPS-encrypted Secret.

#### Scenario: Normal week
- **WHEN** the cluster, Prometheus and the Gmail path are working on Monday morning
- **THEN** the owner SHALL receive the reminder with this week's and last week's figures and the dashboard link

#### Scenario: Missing reminder
- **WHEN** crete, the cluster, Prometheus or the mail path is down at reminder time
- **THEN** no email SHALL arrive, and its absence SHALL be the signal that the alert path needs checking

#### Scenario: Data gap
- **WHEN** a figure has no data for part of the week
- **THEN** the email SHALL mark it incomplete instead of showing a misleading number

#### Scenario: Gmail credential revoked
- **WHEN** the Gmail app password shared by Alertmanager and the reminder is revoked
- **THEN** no reminder SHALL arrive that Monday, and the missing email is the signal
