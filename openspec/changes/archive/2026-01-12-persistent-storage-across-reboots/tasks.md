# Implementation Tasks

## Phase 1: Core Storage Infrastructure (Blocks Phase 2)

### 1.1 Update create-vms.sh for Persistent Storage
- [x] Add environment variable support:
  - [x] `PERSISTENT_HOST_PATH` (default: `/mnt/persistent`)
  - [x] `PERSISTENT_MOUNT_PATH` (default: `/mnt/persistent`)
  - [x] `ENABLE_PERSISTENT_STORAGE` (default: true)
  - [x] `GPU_PCI` (allow non-interactive if set)
- [x] Auto-create persistent host directories if they don't exist:
  - [x] Create `/mnt/persistent/node-controlplane` with `mkdir -p` and `chmod 755`
  - [x] Create `/mnt/persistent/node-worker` with `mkdir -p` and `chmod 755`
  - [x] Log creation status to inform administrator
- [x] Use virsh attach-device or XML patch to mount directories into VMs
- [x] Update script documentation with storage configuration options
- [ ] Test: Verify persistent mounts survive VM reboot

### 1.2 Add Host Storage Path Validation
- [x] Validate that `PERSISTENT_HOST_PATH` is on a persistent filesystem:
  - [x] Use `findmnt -n -o FSTYPE -T <path>` to get filesystem type (preferred method)
  - [x] Fallback to `df -T <path>` if findmnt unavailable
  - [x] Check if path is under `/tmp` or `/run` (fail with error)
  - [x] Check if filesystem type is tmpfs (fail with error)
  - [x] Verify path is writable (fail with error if not)
  - [x] Check available disk space (warn if < 10GB, fail if < 1GB)
- [x] Provide helpful error messages with example validation commands
- [x] Suggest alternative paths if issues are detected (e.g., `/data/k8s-storage`, `/home/k8s-storage`)
- [x] Document recommended storage paths in script comments
- [ ] Add `--skip-validation` flag for advanced users (with warning)
- [x] Ensure Talos system user can read/write to mounted directory
- [ ] Test file creation and persistence in mounted directory
- [ ] Document any special mount options needed (uid/gid mapping)
- [x] Add permission validation to create-vms.sh

## Phase 2: Talos Configuration (Blocks Phase 3)

### 2.1 Update gen-talos.sh for Storage Configuration
- [x] Add documentation comments to generated configs about persistent paths
- [x] Include nodePathMap configuration in Talos patches (for future local-path-provisioner)
- [x] Document expected mount point location in comments
- [ ] Test config generation with mock paths
- [x] Verify generated configs reference persistent storage locations

### 2.2 Verify bootstrap-cluster.sh Configuration Application
- [x] Verify that `bootstrap-cluster.sh` uses `--mode=reboot` (already the default)
- [x] Confirm reboot mode is appropriate for Talos configuration updates
- [x] Update script documentation to clarify that VMs will reboot during updates
- [x] Document that persistent storage survives the reboot

## Phase 3: Local Path Provisioner Configuration (Blocks Phase 4)

### 3.1 Update Local Path Provisioner ArgoCD App Configuration
- [x] Update `kubernetes/argocd-apps/local-path-provisioner/local-path-provisioner-app.yaml`:
  - [x] Change nodePathMap default path to `/mnt/persistent/local-path-provisioner`
  - [x] Configure node-specific paths for controlplane and worker
  - [x] Set appropriate reclaim policy (Retain is good)
  - [x] Set volumeBindingMode (WaitForFirstConsumer is good)
- [x] Update Helm values in ArgoCD app for new storage paths
- [ ] Test ArgoCD sync with new configuration

### 3.2 Create Persistent Volume Test
- [ ] Create test PVC to verify storage works
- [ ] Write data to PV and verify persistence across VM reboot
- [ ] Document test procedure for verification

## Phase 4: Documentation and Testing (Blocks Release)

### 4.1 Update README and Documentation
- [ ] Document new environment variables and their defaults
- [ ] Add section on persistent storage setup
- [ ] Explain the storage directory structure
- [ ] Document both new and legacy (destructive) deployment paths
- [ ] Add troubleshooting guide for storage issues

### 4.2 Create Deployment Instructions
- [ ] Write step-by-step guide for fresh deployment
- [ ] Write optional guide for in-place updates to existing deployments
- [ ] Document VM reboot procedure with persistent storage
- [ ] Document how to verify storage is working

### 4.3 Update Script Help Text
- [ ] Add usage documentation to each script
- [ ] Document all environment variables
- [ ] Add examples of common usage patterns
- [ ] Include troubleshooting tips

### 4.4 Integration Testing
- [ ] Test full deployment flow (create VMs → bootstrap → deploy apps)
- [ ] Test VM reboot cycle preserves PVs (virsh reboot)
- [ ] Test host reboot preserves PVs (verify host path is persistent filesystem)
- [ ] Test Talos config update with VM reboot
- [ ] Test storage path validation (tmpfs detection, space checks)
- [ ] Test error cases (missing host path, permission errors, ephemeral storage)

### 4.5 Validate Against Specs
- [ ] Verify all spec requirements are met:
  - [ ] Local path provisioner stores in persistent location
  - [ ] PVs survive VM reboot
  - [ ] PVs survive host reboot (host path is on persistent filesystem)
  - [ ] Talos config can be updated with VM reboot
  - [ ] VMs don't require recreation for config updates
  - [ ] Scripts validate host storage path is persistent
  - [ ] Scripts accept environment variables for automation
- [ ] Run `openspec validate persistent-storage-across-reboots --strict`

## Phase 5: Deployment and Archival (Post-Approval)

### 5.1 Merge and Deploy
- [ ] Submit PR with all changes
- [ ] Get review and approval
- [ ] Merge to main branch
- [ ] Deploy to production environment

### 5.2 Archive Change Proposal
- [ ] Run `openspec archive persistent-storage-across-reboots --yes`
- [ ] Move change directory to `openspec/changes/archive/YYYY-MM-DD-persistent-storage-across-reboots/`
- [ ] Update `openspec/specs/` with permanent capability specs:
  - [ ] `openspec/specs/local-path-provisioner/spec.md`
  - [ ] `openspec/specs/vm-storage-management/spec.md`
  - [ ] `openspec/specs/talos-cluster-management/spec.md`
- [ ] Verify archival passes validation

## Dependency Notes
- Phase 1 blocks Phase 2 (need persistent storage before Talos can use it)
- Phase 2 blocks Phase 3 (need Talos config pointing to persistent paths before local-path-provisioner deploys)
- Phase 3 blocks Phase 4 (integration testing requires all components working)
- Phase 4 blocks Phase 5 (need comprehensive validation before release)
