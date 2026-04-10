# Local Path Provisioner Storage Configuration

## ADDED Requirements

### Requirement: Persistent Storage Path Configuration
The local path provisioner SHALL support configurable persistent storage paths that survive VM reboot cycles.

#### Scenario: Configure persistent storage location
- **WHEN** a system administrator deploys the local path provisioner
- **THEN** the provisioner shall mount storage from a host-level persistent location (outside libvirt pool)
- **AND** all created PVs shall be stored at `/mnt/persistent/local-path-provisioner/{node-name}` or a configured alternative path
- **AND** the path SHALL be mounted read-write with appropriate permissions for the provisioner to manage

#### Scenario: PV data persistence across VM reboot
- **WHEN** a VM is rebooted using `virsh reboot` or `virsh reset`
- **THEN** any PVs created by the local path provisioner SHALL remain accessible after the reboot
- **AND** applications with persistent storage SHALL continue to function without data loss (except on host reboot)

### Requirement: Configurable Storage Path Per Node
The local path provisioner configuration SHALL allow different nodes to use different persistent storage paths.

#### Scenario: Multiple node storage paths
- **WHEN** configuring the local path provisioner for a multi-node cluster
- **THEN** each node MAY have a distinct storage path configured via the `nodePathMap` configuration
- **AND** a `DEFAULT_PATH_FOR_NON_LISTED_NODES` fallback path SHALL be available for unconfigured nodes
- **AND** the system SHALL validate that all configured paths are accessible and writable before provisioning starts

### Requirement: Storage Path Validation
The local path provisioner deployment process SHALL validate persistent storage configuration.

#### Scenario: Validate storage paths during deployment
- **WHEN** the local path provisioner deploys
- **THEN** the system SHALL check that all configured storage paths are mounted and writable
- **AND** if a path is inaccessible, the provisioner SHALL emit a warning but continue operation (allowing retry)
- **AND** administrators SHALL be able to verify path configuration via logs and status

## MODIFIED Requirements

### Requirement: Default Storage Path
**OLD**: The local path provisioner uses `/var/local-path-provisioner` for all nodes

**NEW**: The local path provisioner uses `/mnt/persistent/local-path-provisioner/{node-name}` for all nodes

**Reason**: The old path is ephemeral on VM systems; the new path is on persistent host storage mounted into the VM.

**Migration**: Existing PVs at the old location will not be migrated. Administrators MUST back up any critical data before updating. After update, a one-time PV recreation is required, which will provision new storage at the new location.

#### Scenario: Upgrade from old path to new path
- **WHEN** upgrading local path provisioner to support persistent paths
- **THEN** existing PVs using the old path shall become unavailable
- **AND** administrators MUST either back up PV data or accept data loss
- **AND** after upgrade, new PVs shall be created at the new persistent path
