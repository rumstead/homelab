# Homelab

Kubernetes homelab on an Ubuntu mini PC using Talos Linux VMs, Argo CD GitOps, Cilium networking, Gateway API ingress, cert-manager PKI, AdGuard DNS, and Prometheus/Grafana monitoring.

Last updated: 2026-11-09

## Overview

- Host: ACEMAGICIAN Kron Mini K1 Mini PC (Ryzen 7 5825U, 32GB RAM, 512GB SSD)
- OS: Ubuntu
- Cluster: 2-node Talos Kubernetes
  - `talos-controlplane`
  - `talos-worker`
- Domain: `acemagic.lab`

## What this repo manages

- Host setup, VM provisioning, Talos bootstrap and upgrades with Ansible
- Argo CD app-of-apps GitOps structure
- Cilium networking with L2 announcements and LB IP pool
- Gateway API gateway and routes
- cert-manager CA and service certificates
- DNS stack (AdGuard Home + external-dns)
- Monitoring stack (kube-prometheus-stack + dashboards + service monitors)

## Core platform components

- Argo CD
- Cilium
- Gateway API
- cert-manager
- external-dns
- AdGuard Home
- metrics-server
- local-path-provisioner
- kube-prometheus-stack

Argo CD `Application` manifests are located in [kubernetes/argocd-apps](kubernetes/argocd-apps).

## Access endpoints

- Argo CD: `argocd.acemagic.lab`
- Grafana: `grafana.acemagic.lab`
- AdGuard: `adguard.acemagic.lab`

Gateway configuration: [kubernetes/manifests/gateway/homelab-gateway.yaml](kubernetes/manifests/gateway/homelab-gateway.yaml)

## Repository layout

- Bootstrap resources: [bootstrap](bootstrap)
- Argo CD applications: [kubernetes/argocd-apps](kubernetes/argocd-apps)
- Kubernetes manifests: [kubernetes/manifests](kubernetes/manifests)
- Ansible playbooks and roles: [ansible](ansible)
- Talos secrets bundle (sops) and machine config patches: [talos](talos)
- Operational scripts: [scripts](scripts)
- OpenSpec docs: [openspec](openspec)

## Set up or rebuild the host

[ansible/site.yml](ansible/site.yml) configures the host, creates the Talos VMs, bootstraps the cluster and installs Cilium and Argo CD. Every step checks the current state first, so running it against a working host changes nothing. Run it from the repo root.

1. Install Ubuntu 24.04 over Ethernet.
2. Restore `~/.config/sops/age/keys.txt` and `~/.ssh` from the backup. The age key decrypts [talos/secrets.sops.yaml](talos/secrets.sops.yaml) and every `*.sops.yaml` secret.
3. Check DNS with `resolvectl query github.com`. The router forwards DNS to AdGuard, which runs in the cluster, and falls back to its public secondary while AdGuard is down. If the lookup fails, use `sudo resolvectl dns <nic> 1.1.1.1` until the cluster is up.
4. Install Ansible, clone the repo and run the playbook in `tmux`:

   ```bash
   sudo apt install -y ansible git
   git clone git@github.com:rumstead/homelab.git && cd homelab
   ansible-playbook ansible/site.yml -K
   ```

5. If the run stops naming an installer netplan file (such as `/etc/netplan/50-cloud-init.yaml`) that also configures the NIC, delete that file and run it again. The run then writes the `br0` bridge to netplan and stops: reboot, then run the playbook again.
6. Log the VS Code tunnel in once: `code tunnel user login`.

`ansible-playbook ansible/site.yml --tags <role> --check --diff` previews one role. Each role is tagged with its name; the cluster roles are `talos_config`, `cluster` and `apps`.

## Upgrade Talos and Kubernetes

1. Set `talos_version` and `kubernetes_version` in [ansible/group_vars/all.yml](ansible/group_vars/all.yml) (Renovate opens these PRs).
2. `ansible-playbook ansible/site.yml --tags base` installs the matching `talosctl` and `kubectl`.
3. `ansible-playbook ansible/upgrade.yml -e plan_only=true` shows the plan.
4. `ansible-playbook ansible/upgrade.yml` upgrades the control plane, then the worker, then Kubernetes.

## Environment notes

- Talos version: `v1.14.2`
- Kubernetes version: `1.36.5`
- Local-path storage root in nodes: `/var/lib/persistent`
- Cilium LB IP pool: `192.168.1.246`-`192.168.1.254` (excludes control plane node IP `192.168.1.245`)