# golf-etl Specification

## Purpose
Runs the golf-etl swing pipeline on a schedule: a CronJob that polls a folder on a shared volume fed by the phone upload page, turns each uploaded swing video into a session of Claude-sized frames, and publishes it to the private rumstead/golf-sessions repo over a deploy key. Google Drive through rclone stays available as `GOLF_STORAGE=drive`. The cluster only schedules and resources the job; what the pipeline does is specified in rumstead/golf-etl.

## Requirements

### Requirement: Scheduled Pipeline Runs
The cluster SHALL run `golf-etl poll` from an Argo CD managed CronJob in the `golf-etl` namespace every 3 minutes, never overlapping, with a failed run not restarted in place.

#### Scenario: Poll is due
- **WHEN** 3 minutes have passed since the last scheduled run and no run is active
- **THEN** a new Job SHALL start `golf-etl poll`

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
The rclone Google Drive token, used only when `GOLF_STORAGE=drive`, SHALL be stored in git only as `golf-etl-rclone.sops.yaml`, rendered by KSOPS, and exposed to the pipeline as an environment variable.

#### Scenario: Credentials at rest
- **WHEN** the manifests are committed
- **THEN** the rclone token SHALL appear only in encrypted form

#### Scenario: Credentials at runtime
- **WHEN** a run starts
- **THEN** `RCLONE_CONFIG_GDRIVE_TOKEN` SHALL be set from the `golf-etl-rclone` Secret

#### Scenario: Github mode
- **WHEN** the CronJob runs with `GOLF_STORAGE=github`
- **THEN** the pipeline SHALL NOT read the rclone token and SHALL authenticate to GitHub with the deploy key

### Requirement: Bounded Run Resources
Each run SHALL request 1 CPU and 2Gi of memory and be limited to 4 CPU, 6Gi of memory, 10Gi of scratch disk, and 2 hours of wall time.

#### Scenario: Large session
- **WHEN** a run processes a long 4K video
- **THEN** the pod SHALL NOT exceed its CPU, memory, or `emptyDir` limits
- **AND** the Job SHALL be terminated if it runs longer than 7200 seconds

### Requirement: Upload Page
The cluster SHALL serve a resumable upload page for swing videos from the `golf-etl-upload` Deployment, reachable only on the tailnet over HTTPS, and only finished uploads SHALL reach the pipeline inbox.

#### Scenario: Reached from the tailnet
- **WHEN** a device on the tailnet opens `https://golf-upload.tailb4b203.ts.net`
- **THEN** the upload page SHALL load over HTTPS

#### Scenario: Reached from outside the tailnet
- **WHEN** a device that is not on the tailnet requests the same name
- **THEN** the request SHALL NOT reach the upload pod

#### Scenario: Interrupted upload
- **WHEN** a connection drops partway through an upload
- **THEN** the upload SHALL resume from where it stopped instead of restarting

#### Scenario: Unfinished upload
- **WHEN** an upload has not completed
- **THEN** its file SHALL NOT appear in `/data/inbox`

#### Scenario: Hook endpoint
- **WHEN** a client requests `/hooks` through the Ingress
- **THEN** nginx SHALL answer 404 and the request SHALL NOT reach the upload server

### Requirement: Shared Volume
The upload pod and the CronJob SHALL share one PersistentVolumeClaim `golf-etl-data` mounted at `/data`, and both SHALL run on the node `talos-hk3-kam`.

#### Scenario: Upload becomes work
- **WHEN** an upload finishes
- **THEN** the video SHALL be in `/data/inbox`, where the next scheduled run reads it

#### Scenario: Pod restarts
- **WHEN** the upload pod is recreated
- **THEN** the contents of `/data` SHALL remain

### Requirement: Deploy Key
The SSH deploy key used to push sessions SHALL be stored in git only as `golf-etl-deploy-key.sops.yaml`, rendered by KSOPS, and SHALL have write access to `rumstead/golf-sessions` only.

#### Scenario: Key at rest
- **WHEN** the manifests are committed
- **THEN** the private key SHALL appear only in encrypted form

#### Scenario: Key scope
- **WHEN** the key is used against any repository other than `rumstead/golf-sessions`
- **THEN** GitHub SHALL reject it
