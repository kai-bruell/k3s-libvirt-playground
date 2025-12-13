# =============================================================================
# TERRAFORM VARIABLES
# =============================================================================
# These variables define the configurable parameters for the K3s cluster.
# They control networking, cluster size, and resource allocation for VMs.
# Override defaults using terraform.tfvars or -var flags.

# -----------------------------------------------------------------------------
# NETWORK CONFIGURATION
# -----------------------------------------------------------------------------

variable "control_plane_ip" {
  description = "Static IP address for K3s control plane node"
  type        = string
  default     = "192.168.56.10"

  # Validation ensures the IP stays within the defined network range
  # The cluster network is configured as 192.168.56.0/24 in main.tf
  # Worker nodes automatically get IPs starting from .11, .12, etc.
  validation {
    condition     = can(regex("^192\\.168\\.56\\.", var.control_plane_ip))
    error_message = "Control plane IP must be in 192.168.56.0/24 subnet"
  }
}

# -----------------------------------------------------------------------------
# CLUSTER CONFIGURATION
# -----------------------------------------------------------------------------

variable "worker_count" {
  description = "Number of K3s worker nodes to create"
  type        = number
  default     = 2

  # Worker IPs are assigned sequentially: 192.168.56.11, .12, .13, etc.
  # /24 subnet provides 254 usable IPs, control plane uses .10, workers start at .11
  # Set to 0 for a single-node cluster (control plane only)
  validation {
    condition     = var.worker_count >= 0 && var.worker_count <= 240
    error_message = "Worker count must be between 0 and 240"
  }
}

# -----------------------------------------------------------------------------
# VM RESOURCES - CPU AND MEMORY
# -----------------------------------------------------------------------------
# These values determine the virtual hardware allocated to each VM.
# Adjust based on your host's available resources and workload requirements.

variable "control_plane_memory" {
  description = "Memory allocation for control plane (MB)"
  type        = number
  default     = 2048 # 2 GB - Minimal for K3s control plane

  # Recommended minimum: 2048 MB (2 GB)
  # Increase for larger clusters or heavier workloads
}

variable "control_plane_vcpus" {
  description = "vCPU count for control plane"
  type        = number
  default     = 1

  # Recommended minimum: 1 vCPU
  # K3s control plane handles scheduling, API requests, and controller processes
}

variable "worker_memory" {
  description = "Memory allocation per worker node (MB)"
  type        = number
  default     = 1024 # 1 GB per worker

  # Adjust based on expected pod workloads
  # More memory allows running more/larger containers
}

variable "worker_vcpus" {
  description = "vCPU count per worker node"
  type        = number
  default     = 1

  # Workers run application pods, so CPU requirements depend on workload
  # More vCPUs = better performance for CPU-intensive applications
}

# -----------------------------------------------------------------------------
# VM RESOURCES - DISK STORAGE
# -----------------------------------------------------------------------------
# Disk sizes for the VM root filesystems (cloned from k3s-base-image.qcow2)
# Values are in bytes. Use powers of 1024 for GiB: 1 GiB = 1073741824 bytes

variable "control_plane_disk_size" {
  description = "Disk size for control plane VM (bytes)"
  type        = number
  default     = 21474836480 # 20 GiB

  # Control plane needs space for:
  # - Container images for system components
  # - etcd database (cluster state)
  # - Logs and temporary files
  # Minimum recommended: 20 GiB
}

variable "worker_disk_size" {
  description = "Disk size for each worker node VM (bytes)"
  type        = number
  default     = 21474836480 # 20 GiB

  # Workers store:
  # - Container images for application pods
  # - Ephemeral pod storage (emptyDir volumes)
  # - Logs
  # Increase if running image-heavy workloads or persistent volumes
  # Minimum recommended: 20 GiB
}
