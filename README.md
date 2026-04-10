# Homelab

Kubernetes homelab on an Ubuntu mini PC using Talos Linux VMs, Argo CD GitOps, Cilium networking, Gateway API ingress, cert-manager PKI, AdGuard DNS, and Prometheus/Grafana monitoring.

Last updated: 2026-03-06

## Overview

- Host: ACEMAGICIAN Kron Mini K1 Mini PC (Ryzen 7 7730U, 32GB RAM, 512GB SSD)
- OS: Ubuntu
- Cluster: 2-node Talos Kubernetes
  - `talos-controlplane`
  - `talos-worker`
- GPU passthrough: host GPU exposed to the worker VM
- Domain: `acemagic.lab`

## What this repo manages

- VM provisioning and Talos bootstrap scripts
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
- Automation scripts: [scripts](scripts)
- OpenSpec docs: [openspec](openspec)

## Common workflow

1. Generate Talos configuration: [scripts/gen-talos.sh](scripts/gen-talos.sh)
2. Create VMs: [scripts/create-vms.sh](scripts/create-vms.sh)
3. Bootstrap cluster: [scripts/bootstrap-cluster.sh](scripts/bootstrap-cluster.sh)

## Environment notes

- Talos version: `v1.12.6`
- Kubernetes version: `1.35.2`
- Local-path storage root in nodes: `/var/lib/persistent`
- Cilium LB IP pool: `192.168.1.245`-`192.168.1.254`