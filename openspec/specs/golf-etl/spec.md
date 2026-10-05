# golf-etl Specification

## Purpose
Runs the golf-etl swing pipeline on a schedule: a CronJob that polls Google Drive through rclone, turns each uploaded swing video into a session of Claude-sized frames, and writes it back to Drive. The cluster only schedules and resources the job; what the pipeline does is specified in rumstead/golf-etl.

## Requirements

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
The rclone Google Drive token SHALL be stored in git only as `golf-etl-rclone.sops.yaml`, rendered by KSOPS, and exposed to the pipeline as an environment variable.

#### Scenario: Credentials at rest
- **WHEN** the manifests are committed
- **THEN** the rclone token SHALL appear only in encrypted form

#### Scenario: Credentials at runtime
- **WHEN** a run starts
- **THEN** `RCLONE_CONFIG_GDRIVE_TOKEN` SHALL be set from the `golf-etl-rclone` Secret

### Requirement: Bounded Run Resources
Each run SHALL request 1 CPU and 2Gi of memory and be limited to 4 CPU, 6Gi of memory, 10Gi of scratch disk, and 1 hour of wall time.

#### Scenario: Large session
- **WHEN** a run processes a long 4K video
- **THEN** the pod SHALL NOT exceed its CPU, memory, or `emptyDir` limits
- **AND** the Job SHALL be terminated if it runs longer than 3600 seconds
