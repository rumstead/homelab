## ADDED Requirements

### Requirement: Scheduled Pipeline Runs
The cluster SHALL run `golf-etl poll-drive` from an Argo CD managed CronJob in the `golf-etl` namespace every 3 minutes, never overlapping, with a failed run not restarted in place.

#### Scenario: Poll is due
- **WHEN** 3 minutes have passed since the last scheduled run and no run is active
- **THEN** a new Job SHALL start `golf-etl poll-drive`

#### Scenario: Previous run still active
- **WHEN** a run is due while the previous Job is still running
- **THEN** no new Job SHALL start

#### Scenario: Run fails
- **WHEN** the pipeline container exits non-zero or is killed
- **THEN** the Job SHALL NOT restart the container or create a replacement pod
- **AND** the next scheduled run SHALL start normally

### Requirement: Latest Image
The CronJob SHALL use `ghcr.io/rumstead/golf-etl:latest` with `imagePullPolicy: Always`.

#### Scenario: New image pushed
- **WHEN** a new `latest` image is pushed to GHCR
- **THEN** the next scheduled run SHALL use it without a manifest change

### Requirement: Drive Credentials
Google Drive OAuth credentials SHALL be stored in git only as `golf-etl-drive.sops.yaml`, rendered by KSOPS, and exposed to the pipeline as environment variables.

#### Scenario: Credentials at rest
- **WHEN** the manifests are committed
- **THEN** the client ID, client secret, and refresh token SHALL appear only in encrypted form

#### Scenario: Credentials at runtime
- **WHEN** a run starts
- **THEN** `GOLF_DRIVE_CLIENT_ID`, `GOLF_DRIVE_CLIENT_SECRET`, and `GOLF_DRIVE_REFRESH_TOKEN` SHALL be set from the `golf-etl-drive` Secret

### Requirement: Bounded Run Resources
Each run SHALL be limited to 4 CPU, 3Gi of memory, 10Gi of scratch disk, and 1 hour of wall time.

#### Scenario: Large session
- **WHEN** a run processes a long 4K video
- **THEN** the pod SHALL NOT exceed its CPU, memory, or `emptyDir` limits
- **AND** the Job SHALL be terminated if it runs longer than 3600 seconds
