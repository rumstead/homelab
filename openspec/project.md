# Project Context

## Purpose
This is a homelab Kubernetes cluster for learning, experimentation, and running personal infrastructure services. The primary goals are:
- Build and maintain a production-like Kubernetes environment at home
- Deploy and manage self-hosted applications (DNS, monitoring, ingress)
- Learn GitOps practices using ArgoCD for declarative infrastructure
- Run on bare metal using Talos Linux for secure, minimal OS footprint
- Implement proper observability with Prometheus and Grafana

## Tech Stack
- **Cluster OS**: Talos Linux (immutable, minimal Kubernetes-focused OS)
- **Kubernetes**: K8s cluster (version managed by Talos)
- **GitOps**: ArgoCD (declarative continuous deployment)
- **Networking**: Cilium (CNI with L2 announcements)
- **Gateway**: Gateway API with cert-manager for TLS
- **DNS**: AdGuard Home with external-dns integration
- **Monitoring**: kube-prometheus-stack (Prometheus, Grafana, Alertmanager)
- **Storage**: local-path-provisioner for persistent volumes
- **VM Platform**: KVM/QEMU (libvirt) on host machine

## Project Conventions

### Code Style
- **YAML**: 2-space indentation, prefer explicit over implicit
- **Kubernetes manifests**: Follow standard Kubernetes resource structure
- **Scripts**: Bash scripts should be executable with proper shebangs
- **Documentation**: Keep inline comments for complex configurations

### Architecture Patterns
- **GitOps**: All cluster state defined declaratively in Git
- **App of Apps**: ArgoCD manages itself and other applications using the app-of-apps pattern
- **Namespace isolation**: Each application in its own namespace
- **Bootstrap sequence**: Core infrastructure (Cilium, cert-manager) before apps
- **Certificate hierarchy**: Self-signed CA for internal services
- **Service exposure**: Use Gateway API with HTTPS routes for external access
- **Monitoring**: ServiceMonitors for Prometheus scraping

### Testing Strategy
- **Manifest validation**: Ensure YAML is valid and follows K8s schema
- **Bootstrap testing**: Verify cluster can be bootstrapped from scratch
- **Application health**: Check ArgoCD sync status and pod health
- **Network testing**: Validate L2 IP announcements and DNS resolution
- **Certificate validation**: Ensure TLS certificates are issued and valid

### Git Workflow
- **Commit messages**: Conventional Commits style
  - Format: `<type>(<scope>): <subject>`
  - Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
  - Example: `feat(monitoring): add AdGuard Home dashboard`
  - Example: `fix(argocd): correct app sync policy`
- **Change management**: Use OpenSpec change proposals for significant changes

## Domain Context

### Talos Linux
- Immutable OS designed specifically for Kubernetes
- Configured via machine configs (controlplane.yaml, worker.yaml)
- No SSH access - managed via talosctl API
- Ephemeral root filesystem by default

### ArgoCD Structure
- Bootstrap ArgoCD using kubectl apply on bootstrap/argocd/
- App-of-apps pattern: argocd/app-of-apps.yaml manages all other apps
- Applications in kubernetes/argocd-apps/ reference manifests in kubernetes/manifests/
- Sync policy: Generally manual sync to control when changes apply

### Network Architecture
- Cilium provides pod networking and L2 service announcements
- Gateway API for HTTP/HTTPS ingress (replaces traditional Ingress)
- AdGuard Home provides cluster DNS and ad-blocking
- external-dns updates AdGuard with service DNS records
- Certificates managed by cert-manager with self-signed CA

### Storage
- local-path-provisioner creates PVs from host directories
- Default storage class for dynamic provisioning
- Persistent data must survive pod restarts and rescheduling

## Important Constraints

### Infrastructure
- **Single node or small cluster**: Limited resources (CPU, RAM, storage)
- **Home network**: Consumer-grade networking, not enterprise
- **No cloud dependencies**: Everything runs locally
- **VM-based nodes**: Running on KVM/libvirt VMs on a host machine

### Kubernetes
- **PV locality**: local-path volumes are node-local, not replicated
- **LoadBalancer limitation**: Using Cilium L2 announcements instead of cloud LB
- **DNS integration**: Must coordinate with AdGuard Home for service discovery

### Security
- **Self-signed certificates**: Not trusted by external browsers without importing CA
- **Internal network only**: Services not exposed to internet
- **No external auth**: No OIDC or enterprise SSO integration

## External Dependencies

### Host System
- KVM/libvirt for VM management
- Sufficient disk space for VM images and persistent volumes
- Network bridge for VM connectivity

### Bootstrap Requirements
- kubectl for initial ArgoCD deployment
- talosctl for Talos cluster management
- virsh for VM lifecycle management

### Optional Services
- Container registry (if not using public registries)
- NFS or other network storage (if moving beyond local-path)
