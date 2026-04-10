# Talos Cluster Management

## ADDED Requirements

### Requirement: In-Place Talos Configuration Updates
The cluster bootstrap process SHALL support applying Talos machine configuration updates without VM recreation (VMs may reboot to apply changes).

#### Scenario: Update Talos config with VM reboot
- **WHEN** a machine configuration file is modified (e.g., updated Talos kernel parameters, network settings)
- **THEN** administrators SHALL apply the updated config using `talosctl apply-config --mode=reboot`
- **AND** the VMs SHALL reboot to apply the configuration changes
- **AND** the Kubernetes cluster SHALL become unavailable briefly during the reboot
- **AND** persistent volumes stored in persistent mount points SHALL remain intact after reboot
- **AND** the VMs and cluster SHALL come back online with the new configuration applied

#### Scenario: Cluster recovery after Talos configuration update
- **WHEN** a Talos configuration update causes a VM to reboot
- **THEN** the reboot SHALL be in-place (VM preserved, not recreated)
- **AND** PV data stored in persistent mount points SHALL be preserved through the reboot
- **AND** workloads SHALL resume once the Kubernetes cluster is ready
- **AND** no manual VM recreation or PV restoration SHALL be required

### Requirement: Selective Node Update Capability
The bootstrap process SHALL support updating individual nodes without affecting the entire cluster.

#### Scenario: Update single node configuration
- **WHEN** an administrator needs to update a single node (e.g., worker node only)
- **THEN** the bootstrap script SHALL support targeting specific nodes via `talosctl apply-config --nodes <IP>`
- **AND** the Kubernetes cluster control plane SHALL remain responsive during single-node updates
- **AND** workloads on unaffected nodes SHALL continue running

## MODIFIED Requirements

### Requirement: Bootstrap Script Configuration Application
**OLD**: `bootstrap-cluster.sh` always applies configuration with `--mode=reboot`, forcing immediate VM reboots

**NEW**: `bootstrap-cluster.sh` applies configuration with `--mode=reboot` to enable VM reboots with persistent storage protection

**Reason**: Allows VMs to reboot and apply configuration changes while ensuring persistent volumes survive the reboot.

#### Scenario: Apply config with VM reboot
- **WHEN** running `bootstrap-cluster.sh`
- **THEN** machine configurations SHALL be applied with `--mode=reboot`
- **AND** VMs SHALL reboot to apply changes
- **AND** Kubernetes cluster downtime SHALL occur during the reboot
- **AND** persistent volumes in `/mnt/persistent` mount points SHALL be preserved across the reboot
- **AND** cluster and workloads SHALL resume once nodes come back online

### Requirement: Talos Machine Config Generation
**OLD**: `gen-talos.sh` patches configs with Cilium CNI set to "none"

**NEW**: `gen-talos.sh` patches configs and includes local-path-provisioner storage path configuration

**Reason**: Ensures the generated Talos configs reference the new persistent storage paths.

#### Scenario: Generated config includes storage path
- **WHEN** running `gen-talos.sh`
- **THEN** the generated controlplane and worker configs SHALL reference `/mnt/persistent/local-path-provisioner/{node-name}` as the local path provisioner storage location
- **AND** the configs SHALL include the necessary volume mounts or extra mounts to make this path available to the provisioner
- **AND** the script SHALL document which paths are being used in the generated configuration
