---
description: Live-upgrade Talos and Kubernetes on the homelab cluster without rebuilding.
agent: agent
tools:
  - run_in_terminal
---

Perform a live upgrade of Talos and Kubernetes on the homelab cluster. The cluster must not be rebuilt. All data must be preserved.

**Cluster details (from AGENTS.md)**
- Control plane: `192.168.1.245`
- Worker: `192.168.1.222`
- Repo root: determined from workspace. Run every `ansible-playbook` command from the repo root.

**Steps, complete each before moving to the next:**

1. **Find target versions**
   - Fetch the latest Talos release tag from `https://api.github.com/repos/siderolabs/talos/releases/latest`.
   - Pick the newest Kubernetes patch release that the target Talos version supports (see the Talos release notes).

2. **Set the versions**
   - Update `talos_version` and `kubernetes_version` in `ansible/group_vars/all.yml`.

3. **Install the matching talosctl and kubectl**
   - Run `ansible-playbook ansible/site.yml --tags base`.
   - Verify with `talosctl version --client` and `kubectl version --client`.

4. **Preview the upgrade**
   - Run `ansible-playbook ansible/upgrade.yml -e plan_only=true`.
   - It lists which nodes will upgrade and shows the `talosctl upgrade-k8s --dry-run` plan. Stop if the plan shows removed API warnings.

5. **Upgrade**
   - Run `ansible-playbook ansible/upgrade.yml -e confirm=true`.
   - It upgrades the control plane, then the worker (each with `--preserve` and `--wait`), then Kubernetes, then applies the new install image to both machine configs.

6. **Verify final state**
   - Run `talosctl version --nodes 192.168.1.245,192.168.1.222` and confirm both nodes show the new Talos version.
   - Run `kubectl get nodes -o wide` and confirm both nodes show the new Kubernetes version and `Ready` status.
   - Run `ansible-playbook ansible/site.yml --tags talos_config` and confirm it reports no drift.

7. **Update repo version references**
   - `README.md`: version notes under "Environment notes"
   - `AGENTS.md`: versions under the "Versions" section
