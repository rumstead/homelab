---
description: Live-upgrade Talos and Kubernetes on the homelab cluster without rebuilding.
agent: agent
tools:
  - run_in_terminal
---

Perform a live upgrade of Talos and Kubernetes on the homelab cluster. The cluster must not be rebuilt — all data must be preserved.

**Cluster details (from AGENTS.md)**
- Control plane: `192.168.1.245`
- Worker: `192.168.1.222`
- Repo root: determined from workspace

**Steps — complete each before moving to the next:**

1. **Find target versions**
   - Fetch the latest Talos release tag from `https://api.github.com/repos/siderolabs/talos/releases/latest`.
   - The Kubernetes version will be auto-detected by `talosctl upgrade-k8s` based on whichever Talos version is installed; no need to look it up in advance.

2. **Check current state**
   - Run `talosctl version --nodes 192.168.1.245,192.168.1.222` to see what is currently running on both nodes.
   - Run `kubectl get nodes -o wide` to capture the current Kubernetes version.
   - If both nodes are already at the target Talos version, skip steps 3–5.

3. **Upgrade the `talosctl` client**
   - Check the current client version with `talosctl version --client`.
   - If it is already at the target version, skip this step.
   - Otherwise download and install it:
     ```
     sudo curl -sL https://github.com/siderolabs/talos/releases/download/<VERSION>/talosctl-linux-amd64 \
       -o /usr/local/bin/talosctl && sudo chmod +x /usr/local/bin/talosctl
     ```
   - Verify with `talosctl version --client`.

4. **Upgrade Talos on the control plane**
   - Run: `talosctl upgrade --nodes 192.168.1.245 --image ghcr.io/siderolabs/installer:<VERSION> --preserve=true --wait=true`
   - The `--preserve` flag is required — it prevents data loss on the persistent disk.
   - Wait for `post check passed` before continuing.

5. **Upgrade Talos on the worker**
   - Run: `talosctl upgrade --nodes 192.168.1.222 --image ghcr.io/siderolabs/installer:<VERSION> --preserve=true --wait=true`
   - Wait for `post check passed` before continuing.

6. **Upgrade Kubernetes**
   - First do a dry run to preview the plan and confirm there are no removed API warnings:
     `talosctl upgrade-k8s --nodes 192.168.1.245 --dry-run`
   - If the plan looks clean, run the actual upgrade:
     `talosctl upgrade-k8s --nodes 192.168.1.245`
   - Wait for all components to report `successfully updated`.

7. **Verify final state**
   - Run `talosctl version --nodes 192.168.1.245,192.168.1.222` and confirm both nodes show the new Talos version.
   - Run `kubectl get nodes -o wide` and confirm both nodes show the new Kubernetes version and `Ready` status.

8. **Update repo version references**
   - Update the following files to reflect the new versions (Talos and Kubernetes):
     - `scripts/create-vms.sh` — `TALOS_VERSION`
     - `scripts/gen-talos.sh` — `TALOS_VERSION` and `KUBERNETES_VERSION`
     - `README.md` — version notes under "Environment notes"
     - `AGENTS.md` — versions under the "Versions" section
