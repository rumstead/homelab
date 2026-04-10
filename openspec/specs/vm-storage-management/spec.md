# VM Storage Management

## ADDED Requirements

### Requirement: Persistent Mount Point Setup During VM Creation
The VM creation process SHALL set up persistent mount points from the host to guest VMs.

#### Scenario: Create persistent mount during VM initialization
- **WHEN** a new VM is created using the VM creation script
- **THEN** the script SHALL create a persistent directory on the host at a configured location (e.g., `/mnt/persistent/node-{name}`)
- **AND** the script SHALL attach this directory to the guest VM via a mount point (e.g., `/mnt/persistent`)
- **AND** the mount SHALL be configured to survive VM reboots without requiring reconfiguration
- **AND** the mount permissions SHALL allow the Talos system user to read and write PV data

#### Scenario: Configure mount point for local path provisioner
- **WHEN** VMs are created with persistent mounts
- **THEN** the mount location within the guest SHALL be at `/mnt/persistent`
- **AND** the local path provisioner SHALL configure its storage path to point to `/mnt/persistent/local-path-provisioner`
- **AND** the mount setup script SHALL accept an optional parameter for the host path (`-host-path` or `PERSISTENT_HOST_PATH` env var)

### Requirement: VM Specification Flexibility
The VM creation script SHALL support both disk-based and mount-based storage approaches.

#### Scenario: Preserve existing VM configurations
- **WHEN** an administrator runs the VM creation script
- **THEN** the script MAY use libvirt disk volumes for the root VM filesystem (as currently done)
- **AND** the script MAY independently attach persistent host directories as additional mounts
- **AND** the script configuration SHALL allow toggling the persistent mount setup via an optional parameter

## MODIFIED Requirements

### Requirement: VM Creation Script Parameters
**OLD**: `create-vms.sh` only accepts GPU PCI address as interactive input

**NEW**: `create-vms.sh` accepts environment variables or command-line parameters for:
- Host persistent storage path (default: `/mnt/persistent`)
- VM persistent mount path (default: `/mnt/persistent`)
- Enable/disable persistent mounts (default: enabled)

**Reason**: Allows scripting and automation of VM creation with flexible storage configuration.

#### Scenario: Automated VM creation with persistent storage
- **WHEN** running `create-vms.sh` in a CI/CD pipeline or automated script
- **THEN** the script SHALL respect environment variables `PERSISTENT_HOST_PATH` and `PERSISTENT_MOUNT_PATH`
- **AND** the script SHALL not require interactive GPU address input if `GPU_PCI` is set
- **AND** the script SHALL create VMs with persistent mount setup automatically
