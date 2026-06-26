<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# Agent Operating Reference

Last updated: 2026-03-06

Use this file as the operational context for repository changes.

## Scope and intent

- This repository manages a Talos-based Kubernetes homelab on an Ubuntu host.
- Infrastructure and workloads are managed through Argo CD GitOps.
- Prefer updating manifests and automation scripts over ad-hoc manual instructions.

## Environment baseline

- Host: ACEMAGICIAN Kron Mini K1 Mini PC
- CPU: AMD Ryzen 7 7730U (8C/16T)
- Memory: 32GB DDR4
- Storage: 512GB SSD
- Host OS: Ubuntu

### Cluster topology

- Talos VM names:
  - `talos-controlplane`
  - `talos-worker`
- Node roles: 1 control plane, 1 worker

## Key provisioning and bootstrap paths

- VM creation: [scripts/create-vms.sh](scripts/create-vms.sh)
- Talos config generation: [scripts/gen-talos.sh](scripts/gen-talos.sh)
- Cluster bootstrap: [scripts/bootstrap-cluster.sh](scripts/bootstrap-cluster.sh)
- Talos/Kubernetes in-place upgrade: [scripts/upgrade-cluster.sh](scripts/upgrade-cluster.sh)
- Optional app bootstrap helper: [scripts/deploy-apps.sh](scripts/deploy-apps.sh)
- Graceful VM shutdown config: [scripts/configure-libvirt-guests.sh](scripts/configure-libvirt-guests.sh)
- Prometheus cleanup helper: [scripts/cleanup-prometheus.sh](scripts/cleanup-prometheus.sh)
- Desktop environment install: [scripts/install-desktop.sh](scripts/install-desktop.sh)

## Canonical configuration values

### Versions

- Talos: `v1.13.5`
- Kubernetes: `1.35.6`

### Network and node identity

- Bridge name: `br0`
- Host interface name in config: `enp2s0`
- Control plane IP: `192.168.1.245`
- Worker IP: `192.168.1.222`
- Gateway IP: `192.168.1.1`
- Domain: `acemagic.lab`

### VM resources

- Control plane: 2 vCPU, 5120 MiB RAM, 10GB primary disk + 50GB persistent disk
- Worker: 6 vCPU, 10240 MiB RAM, 150GB primary disk + 100GB persistent disk
- Persistent host path default: `/mnt/persistent`
- Persistent guest path default: `/var/lib/persistent`

### Talos machine patch behavior

- Install disk: `/dev/vda`
- Secondary disk: `/dev/vdb`
- Secondary disk mount path: `/var/lib/persistent`
- CNI is disabled in Talos machine config (`none`) to allow Cilium installation

## GitOps layout

- App-of-apps root: [kubernetes/argocd-apps/argocd/app-of-apps.yaml](kubernetes/argocd-apps/argocd/app-of-apps.yaml)
- Argo CD app definitions: [kubernetes/argocd-apps](kubernetes/argocd-apps)
- Workload/platform manifests: [kubernetes/manifests](kubernetes/manifests)
- Argo CD bootstrap overlay: [bootstrap/argocd](bootstrap/argocd)

### Managed Argo CD applications

- `argocd`
- `app-of-apps`
- `cilium`
- `cilium-l2-config`
- `gateway-api`
- `homelab-gateway`
- `cert-manager`
- `cert-manager-config`
- `metrics-server`
- `local-path-provisioner`
- `external-dns`
- `adguard-home`
- `kube-prometheus-stack`

## Networking and ingress details

- Gateway object: [kubernetes/manifests/gateway/homelab-gateway.yaml](kubernetes/manifests/gateway/homelab-gateway.yaml)
  - HTTP listener on `80`
  - TLS passthrough listener on `443`
- Cilium L2/LB policy: [kubernetes/manifests/cilium/l2-config.yaml](kubernetes/manifests/cilium/l2-config.yaml)
  - `loadBalancerIPs: true`
  - `externalIPs: true`
  - LB pool range: `192.168.1.245`-`192.168.1.254`

## TLS, DNS, and endpoints

- CA and issuers: [kubernetes/manifests/cert-manager/self-signed-ca.yaml](kubernetes/manifests/cert-manager/self-signed-ca.yaml)
- Gateway wildcard certificate: [kubernetes/manifests/cert-manager/gateway-cert.yaml](kubernetes/manifests/cert-manager/gateway-cert.yaml)
- Argo CD certificate: [kubernetes/manifests/cert-manager/argocd-cert.yaml](kubernetes/manifests/cert-manager/argocd-cert.yaml)
- Exposed hostnames:
  - `argocd.acemagic.lab`
  - `grafana.acemagic.lab`
  - `adguard.acemagic.lab`

## Host desktop environment

- Desktop: XFCE4 (lightweight)
- Display manager: LightDM
- Remote desktop: xrdp on port `3389`
- SSH X11 forwarding: enabled
- Setup script: [scripts/install-desktop.sh](scripts/install-desktop.sh)

## VM lifecycle management

- Graceful shutdown: `libvirt-guests` service with `ON_SHUTDOWN=shutdown` and 120s timeout
- Setup script: [scripts/configure-libvirt-guests.sh](scripts/configure-libvirt-guests.sh)
- VMs autostart after host reboot via libvirt autostart

## Monitoring and DNS workloads

- AdGuard Home manifest: [kubernetes/manifests/adguard-home/adguard-home.yaml](kubernetes/manifests/adguard-home/adguard-home.yaml)
  - Image: `adguard/adguardhome:v0.107.77`
  - DNS LoadBalancer requested IP: `192.168.1.246`
- AdGuard exporter manifest: [kubernetes/manifests/adguard-home/adguard-exporter.yaml](kubernetes/manifests/adguard-home/adguard-exporter.yaml)
  - Image: `ebrianne/adguard-exporter:v1.14`
  - Metrics port: `9617`
- Monitoring stack values: [kubernetes/argocd-apps/monitoring/kube-prometheus-stack-app.yaml](kubernetes/argocd-apps/monitoring/kube-prometheus-stack-app.yaml)
  - Chart: `87.2.1`
  - Prometheus retention: `7d` (time) / `9GB` (size)
  - Prometheus WAL compression: enabled
  - Prometheus PVC: `10Gi`
  - Grafana persistence: `1Gi`
  - AlertManager: enabled with email receiver
  - Storage alerts: [kubernetes/manifests/monitoring/prometheus-alerts.yaml](kubernetes/manifests/monitoring/prometheus-alerts.yaml)
  - Prometheus cleanup: [scripts/cleanup-prometheus.sh](scripts/cleanup-prometheus.sh)
  - Host scrape targets:
    - `192.168.1.234:9100`
    - `192.168.1.234:9256`

## Change guardrails for agents

- Keep OpenSpec managed block intact.
- Do not change hostnames, IP ranges, or node names unless explicitly requested.
- Preserve app-of-apps structure unless a migration is requested.
- Prefer minimal, scoped edits; avoid unrelated formatting churn.
- If a request involves architecture/spec/proposal work, consult [openspec/AGENTS.md](openspec/AGENTS.md) first.

## Live-state checks before declaring success

- Confirm host LAN IP currently used for host scrape targets.
- Confirm host interface naming matches configured bridge parent.
- Confirm Argo CD application sync and health status in the live cluster.