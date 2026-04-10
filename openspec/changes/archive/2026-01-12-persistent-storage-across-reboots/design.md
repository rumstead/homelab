# Design Document: Persistent Storage and In-Place Cluster Updates

## Context
This project manages a Talos Kubernetes cluster running on two KVM virtual machines (control plane and worker) using libvirt and virsh. The local path provisioner provides simple persistent storage by using host directories.

**Current Problem**: 
- Local path provisioner stores PVs in `/var/local-path-provisioner`, which is ephemeral in the VM environment
- Running `virsh reboot` causes data loss because the directory is not on persistent storage
- VM recreation is required for any Talos configuration changes, preventing cluster updates

**Requirements**:
- PV data must survive VM reboot cycles (via `virsh reboot` or `virsh reset`)
- PV data must survive host system reboots (by using persistent host filesystem)
- Talos cluster can reboot during configuration updates (in-place upgrade, not VM recreation)
- All automation scripts must be updated to support these changes

## Goals / Non-Goals

### Goals
- Enable persistent storage across VM reboot cycles
- Enable persistent storage across host system reboot cycles
- Support Talos configuration updates with VM reboots (eliminating destructive VM recreation)
- Automate persistent storage mount setup in VM creation scripts
- Validate that host storage paths are on persistent filesystems
- Document the new storage paths and configuration in generated configs

### Non-Goals
- Data replication or high-availability storage (local path provisioner limitation)
- Automatic failover or disaster recovery
- Changes to Kubernetes networking or service discovery
- Modifications to external dependencies (Cilium, ArgoCD, etc.)
- Supporting ephemeral storage with automatic cleanup
- Zero-downtime updates or rolling node upgrades (VMs can reboot)

## Decisions

### Decision 1: Use Host-Level Persistent Filesystem Directories
**What**: Mount host directories from persistent filesystem into VMs at `/mnt/persistent/` and configure local path provisioner to use `/mnt/persistent/local-path-provisioner/{node-name}`

**Why**: 
- Simple to implement with libvirt virsh (directory mounts are straightforward)
- If the host directory is on a regular persistent filesystem (ext4, xfs, btrfs, etc.), data survives both VM reboots AND host reboots
- No additional complexity to the Talos configuration
- Directly addresses the requirement: data persists across all reboot scenarios
- Aligns with local path provisioner's design (directory-based storage)

**Alternatives Considered**:
- **NFS mounts from host**: Adds network complexity; overkill for single-host setup
- **iSCSI or block device sharing**: Adds storage complexity; not suitable for local path provisioner
- **tmpfs/ramdisk**: Would NOT survive host reboot; does not meet requirements

### Decision 2: Separate Mount Configuration from VM Definition
**What**: Configure persistent mounts as a separate step after VM disk creation, using virsh attach-device or libvirt XML

**Why**:
- Keeps the VM creation script modular (core VM setup + optional persistent storage)
- Allows administrators to retrofit persistent storage to existing VMs if needed
- Easier to debug and test storage configuration independently
- Simpler to rollback storage changes without affecting VM definition

**Alternatives Considered**:
- **Embed mounts in virt-install command**: Would require complex XML generation in the script
- **Use QEMU/KVM domain XML templates**: Less portable; harder to maintain

### Decision 3: Use Standard Reboot Mode for Configuration Updates
**What**: Bootstrap script applies Talos configuration with `--mode=reboot`, allowing VMs to reboot with persistent storage

**Why**:
- VM reboots during Talos updates are acceptable and expected
- Simplifies the bootstrap process (no need for staged or no-reboot modes)
- Ensures configuration changes are fully applied and active after reboot
- Persistent storage survives the reboot, protecting PV data
- Aligns with standard Talos cluster update procedures

**Alternatives Considered**:
- **No-reboot mode**: Adds complexity without addressing core requirement (persistent data survives reboots)
- **Staged updates**: Requires additional manual intervention; not needed

### Decision 4: Document Storage Paths in Talos Config Generation
**What**: Update `gen-talos.sh` to include comments or configuration snippets documenting the expected storage paths

**Why**:
- Ensures consistency between what the script sets up and what Talos expects
- Makes configuration changes auditable and reviewable
- Helps administrators understand the storage architecture
- Supports future migration to different storage backends

### Decision 5: Validate Host Storage Path Persistence
**What**: Scripts validate that `PERSISTENT_HOST_PATH` is on a persistent filesystem, not tmpfs or ephemeral storage

**Why**:
- Prevents accidental data loss if administrator misconfigures storage path
- Provides early warning if the selected path won't survive host reboot
- Documents best practices for storage configuration
- Supports both new and existing deployments

**Validation Checks**:
- Check if path is under `/tmp` or `/run` (ephemeral)
- Check if mount point is tmpfs using `findmnt` or `df -T`
- Commands to verify:
  ```bash
  # Method 1: Using findmnt (preferred)
  findmnt -n -o FSTYPE -T /mnt/persistent
  # Returns: ext4, xfs, btrfs (good) or tmpfs (bad)
  
  # Method 2: Using df
  df -T /mnt/persistent | tail -n1 | awk '{print $2}'
  # Returns: ext4, xfs, btrfs (good) or tmpfs (bad)
  
  # Method 3: Parse /proc/mounts
  grep "$(df /mnt/persistent | tail -n1 | awk '{print $1}')" /proc/mounts | awk '{print $3}'
  ```
- Warn if available disk space is below threshold (e.g., 10GB)
- Suggest alternative paths if issues are detected

## Risks / Trade-offs

### Risk 1: Host Storage Path Configuration
**Issue**: If host path is misconfigured (tmpfs, ephemeral mount, or under `/tmp`), PV data will be lost on host reboot despite correct VM mount setup.

**Mitigation**: 
- Add validation in scripts to check if path is on persistent filesystem  
- Use `findmnt -n -o FSTYPE -T <path>` to get filesystem type
- Use `df -T <path>` as fallback method
- Emit errors if path is under `/tmp`, `/run`, or on tmpfs
- Document recommended paths (e.g., `/data/k8s-storage`, `/home/k8s-storage`, or dedicated partitions)
- Verify available disk space (warn if < 10GB)
- Test actual file creation/deletion in the path before VM creation

**Example validation**:
```bash
FSTYPE=$(findmnt -n -o FSTYPE -T /mnt/persistent 2>/dev/null || df -T /mnt/persistent | tail -n1 | awk '{print $2}')
if [[ "$FSTYPE" == "tmpfs" ]]; then
  echo "ERROR: /mnt/persistent is on tmpfs (ephemeral storage)"
  exit 1
fi
```

### Risk 2: VM-to-Host Mount Point Semantics
**Issue**: Mount point permissions and user mappings could cause permission errors.
**Mitigation**:
- Ensure Talos system user has read/write access to mounted directories
- Use appropriate mount options (uid/gid mapping if needed)
- Test permission configuration before declaring ready

### Risk 3: Talos Configuration Compatibility
**Issue**: Some Talos configuration changes might still require reboots (e.g., kernel parameters).
**Mitigation**:
- Document which changes require reboots (most do, and that's acceptable)
- Bootstrap script uses standard `--mode=reboot` 
- VMs rebooting is expected and normal in this update model

### Risk 4: Migration Path for Existing PVs
**Issue**: Existing PVs at old location (`/var/local-path-provisioner`) won't migrate.
**Mitigation**:
- Clearly document that old PVs will be lost
- Recommend backing up critical data before upgrade
- Provide manual migration instructions if needed (copy PV data)

### Risk 5: Concurrent Persistent Mounts
**Issue**: If multiple nodes try to access the same host directory, race conditions could occur.
**Mitigation**:
- Each node gets its own persistent directory: `/mnt/persistent/node-controlplane` and `/mnt/persistent/node-worker`
- Local path provisioner isolates per-node storage automatically
- No concurrent access between nodes

## Migration Plan

### For New Deployments
1. Run `create-vms.sh` with persistent storage enabled (default)
2. VMs will have `/mnt/persistent` mounted from host
3. Run `gen-talos.sh` to generate configs with persistent paths
4. Run `bootstrap-cluster.sh` (no-reboot mode is default)
5. Local path provisioner deploys and uses `/mnt/persistent/local-path-provisioner/{node}`

### For Existing Deployments
1. **Option A (Destructive - Not Recommended)**:
   - Destroy existing VMs and cluster
   - Follow "For New Deployments" path
   - *Note: This option is not viable for existing production clusters*

2. **Option B (In-Place Update - REQUIRED)**:
   
   **Step 1: Create persistent directories on the host**
   ```bash
   sudo mkdir -p /mnt/persistent/node-controlplane
   sudo mkdir -p /mnt/persistent/node-worker
   sudo chmod 755 /mnt/persistent/node-controlplane
   sudo chmod 755 /mnt/persistent/node-worker
   ```

   **Step 2: Attach persistent mounts to running VMs using virsh**
   ```bash
   # Get VM domain XMLs and backup
   virsh dumpxml talos-controlplane > /tmp/controlplane-backup.xml
   virsh dumpxml talos-worker > /tmp/worker-backup.xml
   
   # Create XML snippets for filesystem mounts
   cat > /tmp/mount-controlplane.xml << 'EOF'
   <filesystem type='mount' accessmode='passthrough'>
     <driver type='path' wrpolicy='immediate'/>
     <source dir='/mnt/persistent/node-controlplane'/>
     <target dir='/mnt/persistent'/>
   </filesystem>
   EOF
   
   cat > /tmp/mount-worker.xml << 'EOF'
   <filesystem type='mount' accessmode='passthrough'>
     <driver type='path' wrpolicy='immediate'/>
     <source dir='/mnt/persistent/node-worker'/>
     <target dir='/mnt/persistent'/>
   </filesystem>
   EOF
   
   # Attach mounts to running VMs (requires VM to be running)
   virsh attach-device talos-controlplane /tmp/mount-controlplane.xml --live
   virsh attach-device talos-worker /tmp/mount-worker.xml --live
   ```

   **Step 3: Verify mounts are attached**
   ```bash
   # Check VM configuration
   virsh dumpxml talos-controlplane | grep -A 3 '<filesystem'
   virsh dumpxml talos-worker | grep -A 3 '<filesystem'
   
   # Verify from inside VMs (if accessible via talosctl or console)
   talosctl -n 192.168.1.10 get machineconfig
   talosctl -n 192.168.1.11 get machineconfig
   ```

   **Step 4: Update local path provisioner configuration via ArgoCD**
   ```bash
   # Edit the local-path-provisioner ArgoCD app values
   kubectl patch application -n argocd local-path-provisioner \
     --type merge -p '
     spec:
       source:
         helm:
           parameters:
             - name: storageClass.defaultClass
               value: "true"
           valuesObject:
             storageClass:
               reclaimPolicy: Retain
               volumeBindingMode: WaitForFirstConsumer
             nodePathMap:
               - node: talos-controlplane
                 paths:
                   - /mnt/persistent/local-path-provisioner
               - node: talos-worker
                 paths:
                   - /mnt/persistent/local-path-provisioner
               - node: DEFAULT_PATH_FOR_NON_LISTED_NODES
                 paths:
                   - /mnt/persistent/local-path-provisioner
     '
   
   # Trigger ArgoCD sync
   argocd app sync local-path-provisioner
   ```

   **Step 5: Verify persistent storage is working**
   ```bash
   # Create test PVC
   kubectl create pvc test-pvc \
     --size=1Gi \
     --storageclass=local-path \
     --claim-name=test-claim
   
   # Create pod that uses the PVC
   kubectl run test-pod --image=busybox -it -- sh -c \
     'mount | grep persistent; echo "data" > /mnt/test; sleep 300'
   
   # Reboot a VM to verify data persists
   virsh reboot talos-worker
   
   # Wait for VM to come back online
   watch 'virsh domstate talos-worker'
   
   # Verify PV data survived
   kubectl exec test-pod -- cat /mnt/test
   ```

   **Step 6: Make mount configuration persistent**
   ```bash
   # VMs need to be defined with mounts in their XML for persistence across daemon restarts
   # Extract current VM XML with mounts
   virsh dumpxml talos-controlplane > /var/lib/libvirt/qemu/talos-controlplane.xml
   virsh dumpxml talos-worker > /var/lib/libvirt/qemu/talos-worker.xml
   
   # Undefine and redefine VMs to save mount configuration
   virsh undefine talos-controlplane
   virsh define /var/lib/libvirt/qemu/talos-controlplane.xml
   
   virsh undefine talos-worker
   virsh define /var/lib/libvirt/qemu/talos-worker.xml
   ```

   **Post-Migration Notes**:
   - Old PVs at `/var/local-path-provisioner` inside VMs will no longer be accessible
   - Back up critical data from old PVs before proceeding
   - New PVs will be created at `/mnt/persistent/local-path-provisioner` after local-path-provisioner updates
   - Existing workloads may need to be redeployed to use new storage paths

## Open Questions
- Should there be a dry-run mode in scripts to show what would be changed? (Recommendation: Not in scope for initial implementation)
- Should the system support multiple persistent storage backends (NFS, S3, etc.)? (Answer: No, out of scope for this change)
- Should we support automatic backup/snapshot functionality? (Answer: Out of scope; administrators can implement using host-level tools)

## Future Work: Enhanced Storage Features
After this change provides full persistence (VM + host reboots), optional follow-up work could include:
1. **Data redundancy**: Backup/snapshot strategy for critical persistent volumes using host-level tools
2. **HA storage**: Multi-host replication if cluster scales beyond single host
3. **Storage monitoring**: Dashboard/alerts for disk space usage in persistent paths
4. **Migration tools**: Automated PV data migration between storage backends

Note: The primary requirement (persistence across VM and host reboots) is achieved in this phase by using host filesystem directories on persistent storage.
