# Change: Persistent Storage Across VM Reboots and In-Place Cluster Updates

## Why
Local path provisioner uses host machine directories to store Kubernetes persistent volumes. Currently, PV data is stored in VM-local ephemeral storage (`/var/local-path-provisioner`), which is lost when VMs reboot via `virsh reboot`. By mounting persistent host directories into the VMs, PV data will survive both VM reboots and host system reboots. Additionally, the current cluster management approach requires destroying and recreating VMs when updating Talos configurations, preventing in-place cluster updates.

## What Changes
- **Local path provisioner** storage paths will be moved to persistent locations outside of temporary VM storage
- **VM creation** scripts will set up persistent mount points that survive reboot cycles
- **Bootstrap scripts** will be updated to apply Talos configuration updates while ensuring storage persists through VM reboots
- **Update model** changes from destructive (recreate VMs) to sustainable (reboot VMs in-place with persistent data)

## Impact
- **Affected specs**: 
  - Local Path Provisioner Storage Configuration (new spec)
  - Talos Cluster Management (new spec)
  - VM Storage Management (new spec)
- **Affected code**: 
  - `scripts/create-vms.sh` - Add persistent storage mount setup
  - `scripts/bootstrap-cluster.sh` - Add in-place update capability
  - `scripts/gen-talos.sh` - Configure local-path-provisioner paths
  - `kubernetes/argocd-apps/local-path-provisioner/local-path-provisioner-app.yaml` - Reference persistent paths
- **Breaking changes**: None; existing deployments will continue to work with PV data loss on reboot (acceptable per requirements)
- **Constraints**:
  - Host directory must be on persistent filesystem (not tmpfs or ephemeral storage)
  - Scripts will validate that the host storage path is on a persistent mount point
  - Cluster and VMs must not be recreated/destroyed during updates
  - Host system must have persistent storage available (outside libvirt pool)

## Deployment Notes
- Administrators should choose persistent storage path on a regular filesystem (e.g., `/data/k8s-storage` on a dedicated partition, or `/home/k8s-storage` on root filesystem)
- Avoid using tmpfs, ephemeral mounts, or directories under `/tmp` or `/run`
- Default `/mnt/persistent` should be verified as persistent storage before use
- Scripts will check if the host path is on persistent storage and warn if not
- Existing PVs will be lost on initial deployment (expected behavior per requirements)
- VM resources (CPU, RAM, disk) can be changed with `virsh setvcpus`, `virsh setmem`, and `virsh blockresize` without VM recreation
