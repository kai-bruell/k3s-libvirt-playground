# k3s-libvirt-playground

Multi-node K3s Kubernetes cluster using Terraform and libvirt.

---

**⚠️ FOR LOCAL DEVELOPMENT AND LEARNING ONLY!**

- **NOT production-ready**
- **NOT security-hardened**
- **NOT optimized for k3s**

For production use cases, see [Kairos](https://github.com/kairos-io)

**Why libvirt instead of KinD?**

- KinD abstracts everything away (blackbox approach)
- Real world: k3s runs on real machines/KVMs
- This project shows reality more directly
- Closer to IaC approach via Terraform

---

## How it works

- Creates K3s Kubernetes cluster:
  - 1× Control Plane (2 GB RAM, 1 vCPU, 20 GB disk)
  - 2× Workers (1 GB RAM, 1 vCPU, 20 GB disk) - configurable
- **Terraform** with **libvirt provider** for IaC
- **virt-customize** for image prep
- **Cloud-Init** for VM provisioning

---

## Prerequisites

**System Requirements:**
- Linux with virtualization support (KVM)
- CPU with VT-x/AMD-V enabled
- Some RAM

**Software:**

This project uses [Devbox](https://www.jetify.com/devbox) for reproducible environments.

```bash
curl -fsSL https://get.jetify.com/devbox | bash
```

Devbox auto-installs: Terraform, libvirt, QEMU, git, go-task, sshpass

---

## Quick Start

### 1. Clone & Enter

```bash
git clone <your-repo-url>
cd k3s-libvirt-lab
devbox shell
```

### 2. Create Cluster

**Automated (recommended):**

```bash
./scripts/initialize.sh
```

This script: builds K3s base image, initializes Terraform, creates cluster, and displays cluster info.

**Manual:**

```bash
cd virt-customize && ./build-image.sh && cd ../terraform
terraform init
terraform apply
terraform output cluster  # View cluster info
```

### 3. SSH Access

```bash
# Control plane
terraform output -json cluster | jq -r '.control_plane.ssh' | bash

# Worker 1
terraform output -json cluster | jq -r '.workers[0].ssh' | bash
```

### 4. Configure kubectl

```bash
ssh -i ../k3s_cluster_id_rsa -o StrictHostKeyChecking=no debian@192.168.56.10 \
  'sudo cat /etc/rancher/k3s/k3s.yaml' > k3s.yaml
sed -i 's/127.0.0.1/192.168.56.10/g' k3s.yaml
export KUBECONFIG=$(pwd)/k3s.yaml
kubectl get nodes
```

---

## Configuration

**Cluster size** - Edit `terraform/terraform.tfvars`:

```hcl
worker_count = 3
control_plane_memory = 2048  # MB
control_plane_vcpus  = 1
worker_memory = 1024          # MB
worker_vcpus  = 1
```

**K3s version** - Edit `virt-customize/build-image.sh`:

```bash
K3S_VERSION="${K3S_VERSION:-v1.28.5+k3s1}"
```

---

## Destroy Cluster

**Terraform resources:**

```bash
cd terraform && terraform destroy
```

**Complete cleanup (WARNING!):**

```bash
./scripts/clean.sh
```

Deletes: all VMs, pools (except `default`), networks (except `default`), `libvirt-pool/`, SSH keys, Terraform state

---

## Tech Stack

| Component | Purpose |
|-----------|---------|
| **Devbox** | Reproducible dev environment |
| **Terraform** | Infrastructure-as-Code |
| **libvirt** | KVM/QEMU virtualization |
| **virt-customize** | Image modification |
| **Cloud-Init** | VM provisioning |
| **K3s** | Lightweight Kubernetes |
| **Debian 12** | Base OS |

---

## Troubleshooting

**VM won't start:**

```bash
virsh list --all
virsh dominfo k3s-control-plane
virsh console k3s-control-plane
```

**Network issues:**

```bash
virsh net-list --all
virsh net-info k3s-network
virsh net-dhcp-leases k3s-network
```

**Cloud-init debugging:**

```bash
ssh -i k3s_cluster_id_rsa debian@192.168.56.10
sudo cat /var/log/cloud-init.log
sudo cloud-init status --long
```

**K3s won't start:**

```bash
systemctl status k3s        # Control plane
systemctl status k3s-agent  # Worker
journalctl -u k3s -f
journalctl -u k3s-agent -f
```

---

## Resources

- [K3s Docs](https://docs.k3s.io/)
- [Terraform Libvirt Provider](https://github.com/dmacvicar/terraform-provider-libvirt)
- [Cloud-Init Docs](https://cloudinit.readthedocs.io/)
- [Devbox Docs](https://www.jetify.com/devbox/docs/)
- [libvirt/KVM](https://libvirt.org/)

---
