# =============================================================================
# TERRAFORM CONFIG: K3S CLUSTER WITH LIBVIRT
# =============================================================================

terraform {
  required_version = "~> 1.14.0"

  required_providers {
    # https://github.com/dmacvicar/terraform-provider-libvirt
    # This provider allows managing libvirt resources 
    # It communicates with libvirt using its API to define, configure, and manage virtualization resources.
    # For Example (virtual machines, storage pools, networks)
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8.3"
    }
    # https://github.com/hashicorp/terraform-provider-tls
    # (EXPLAIN)
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.1.0"
    }
    # https://github.com/hashicorp/terraform-provider-random
    # (EXPLAIN)
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7.0"
    }
    # https://github.com/hashicorp/terraform-provider-local
    # Used to manage local resources, such as creating files 
    local = {
      source  = "hashicorp/local"
      version = "~> 2.6.0"
    }
  }
}

# -----------------------------------------------------------------------------
# PROVIDER
# -----------------------------------------------------------------------------

provider "libvirt" {
  uri = "qemu:///system"
}

# -----------------------------------------------------------------------------
# SECURITY RESOURCES
# -----------------------------------------------------------------------------

# Generate random K3s token (secure, sensitive)
resource "random_password" "k3s_token" {
  length  = 64
  special = false
}

# Generate SSH keypair for cluster access
resource "tls_private_key" "cluster_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key locally with proper permissions
resource "local_sensitive_file" "ssh_private_key" {
  content         = tls_private_key.cluster_ssh_key.private_key_pem
  filename        = "${path.module}/../k3s_cluster_id_rsa"
  file_permission = "0600"
}

# -----------------------------------------------------------------------------
# STORAGE AND NETWORK
# -----------------------------------------------------------------------------

# Storage pool for VM disks and cloud-init ISOs with type dir
resource "libvirt_pool" "k3s_storage" {
  name = "k3s-project-pool"
  type = "dir"
  target {
    path = abspath("${path.module}/../libvirt-pool")
  }
}

# Private network for K3s cluster
# Creates a libvirt virtual network with:
# - NAT mode (VMs have outbound internet access, no inbound)
# - Custom DNS domain "k3s.local"
# - Subnet 192.168.56.0/24
# - DHCP disabled (static IPs via cloud-init)
# - DNS enabled for internal hostname resolution

resource "libvirt_network" "k3s_network" {
  name      = "k3s-network"
  mode      = "nat"
  domain    = "k3s.local"
  addresses = ["192.168.56.0/24"]

  dhcp {
    enabled = false # Using static IPs via cloud-init
  }

  dns {
    enabled = true
  }
}

# -----------------------------------------------------------------------------
# CONTROL PLANE NODE
# -----------------------------------------------------------------------------
# The base image (k3s-base-image.qcow2) must already exist in the storage pool.
# Terraform does NOT create or manage this base image to avoid accidental deletion.

# Cloud-init ISO for the control plane node
resource "libvirt_cloudinit_disk" "control_plane" {
  name = "k3s-control-plane-cloudinit.iso"
  pool = libvirt_pool.k3s_storage.name

  # User-data template: SSH key + K3s token injection
  user_data = templatefile("${path.module}/cloud-init/control-plane.tpl", {
    ssh_public_key = tls_private_key.cluster_ssh_key.public_key_openssh
    k3s_token      = random_password.k3s_token.result
  })

  # Static network configuration for the control plane VM
  network_config = templatefile("${path.module}/cloud-init/network-config.tpl", {
    ip_address = var.control_plane_ip
    gateway    = "192.168.56.1"
    netmask    = "24"
  })

  # Metadata: instance ID and hostname
  meta_data = templatefile("${path.module}/cloud-init/meta-data.tpl", {
    instance_id = "k3s-control-plane"
    hostname    = "k3s-control"
  })
}

# Root disk for the control plane VM (cloned from base image)
resource "libvirt_volume" "control_plane" {
  name             = "k3s-control-plane.qcow2"
  pool             = libvirt_pool.k3s_storage.name
  base_volume_pool = libvirt_pool.k3s_storage.name
  base_volume_name = "k3s-base-image.qcow2"
  size             = var.control_plane_disk_size
}

# Control plane virtual machine
resource "libvirt_domain" "control_plane" {
  name   = "k3s-control-plane"
  memory = var.control_plane_memory
  vcpu   = var.control_plane_vcpus

  # Attach cloud-init ISO
  cloudinit = libvirt_cloudinit_disk.control_plane.id

  # Attach cloned disk
  disk {
    volume_id = libvirt_volume.control_plane.id
  }

  # Network interface with static MAC and static IP
  network_interface {
    network_id = libvirt_network.k3s_network.id
    mac        = "52:54:00:56:00:10"
    addresses  = [var.control_plane_ip]
    hostname   = "k3s-control"
  }

  # Provide a standard serial console (useful for debugging)
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  # VirtIO console for additional logging / advanced debugging
  console {
    type        = "pty"
    target_port = "1"
    target_type = "virtio"
  }
}

# -----------------------------------------------------------------------------
# WORKER NODES
# -----------------------------------------------------------------------------

# Cloud-init ISOs for worker nodes (one per worker)
resource "libvirt_cloudinit_disk" "worker" {
  count = var.worker_count
  name  = "k3s-worker-${count.index + 1}-cloudinit.iso"
  pool  = libvirt_pool.k3s_storage.name

  # User-data: SSH key, K3s token, and server join URL
  user_data = templatefile("${path.module}/cloud-init/worker.tpl", {
    ssh_public_key   = tls_private_key.cluster_ssh_key.public_key_openssh
    k3s_token        = random_password.k3s_token.result
    k3s_server_url   = "https://${var.control_plane_ip}:6443"
    worker_node_name = "k3s-worker-${count.index + 1}"
  })

  # Per-worker static network configuration
  network_config = templatefile("${path.module}/cloud-init/network-config.tpl", {
    ip_address = cidrhost("192.168.56.0/24", 11 + count.index)
    gateway    = "192.168.56.1"
    netmask    = "24"
  })

  # Metadata: instance ID and hostname
  meta_data = templatefile("${path.module}/cloud-init/meta-data.tpl", {
    instance_id = "k3s-worker-${count.index + 1}"
    hostname    = "k3s-worker-${count.index + 1}"
  })
}

# Root disks for each worker node, cloned from same base image
resource "libvirt_volume" "worker" {
  count            = var.worker_count
  name             = "k3s-worker-${count.index + 1}.qcow2"
  pool             = libvirt_pool.k3s_storage.name
  base_volume_pool = libvirt_pool.k3s_storage.name
  base_volume_name = "k3s-base-image.qcow2"
  size             = var.worker_disk_size
}

# Worker VM definitions
resource "libvirt_domain" "worker" {
  count  = var.worker_count
  name   = "k3s-worker-${count.index + 1}"
  memory = var.worker_memory
  vcpu   = var.worker_vcpus

  # Attach worker-specific cloud-init ISO
  cloudinit = libvirt_cloudinit_disk.worker[count.index].id

  # Attach cloned worker disk
  disk {
    volume_id = libvirt_volume.worker[count.index].id
  }

  # Static MAC + static IP per worker node
  network_interface {
    network_id = libvirt_network.k3s_network.id
    mac        = format("52:54:00:56:00:%02x", 11 + count.index)
    addresses  = [cidrhost("192.168.56.0/24", 11 + count.index)]
    hostname   = "k3s-worker-${count.index + 1}"
  }

  # Standard serial console
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  # VirtIO console
  console {
    type        = "pty"
    target_port = "1"
    target_type = "virtio"
  }

  # Ensure worker VMs are created only after control plane is up
  depends_on = [libvirt_domain.control_plane]
}
