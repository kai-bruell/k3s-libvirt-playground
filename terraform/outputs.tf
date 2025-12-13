# =============================================================================
# TERRAFORM OUTPUTS 
# =============================================================================
# Single output with complete cluster overview
# Run: terraform output cluster
#
# For raw values use:
#   terraform output -raw cluster
#   terraform output -json cluster | jq

output "cluster" {
  description = "Complete K3s cluster overview with all nodes and SSH access"
  value = {

    # Control Plane Node
    control_plane = {
      name     = "k3s-control-plane"
      ip       = var.control_plane_ip
      ssh      = "ssh -i ${abspath(path.module)}/../k3s_cluster_id_rsa -o StrictHostKeyChecking=no debian@${var.control_plane_ip}"
      memory   = "${var.control_plane_memory} MB"
      vcpus    = var.control_plane_vcpus
    }

    # Worker Nodes
    workers = [
      for i in range(var.worker_count) : {
        name     = "k3s-worker-${i + 1}"
        ip       = cidrhost("192.168.56.0/24", 11 + i)
        ssh      = "ssh -i ${abspath(path.module)}/../k3s_cluster_id_rsa -o StrictHostKeyChecking=no debian@${cidrhost("192.168.56.0/24", 11 + i)}"
        memory   = "${var.worker_memory} MB"
        vcpus    = var.worker_vcpus
      }
    ]

    # Quick Access
    quick_access = {
      ssh_key           = abspath("${path.module}/../k3s_cluster_id_rsa")
      kubernetes_api    = "https://${var.control_plane_ip}:6443"
      get_kubeconfig    = "ssh -i ${abspath(path.module)}/../k3s_cluster_id_rsa -o StrictHostKeyChecking=no debian@${var.control_plane_ip} 'sudo cat /etc/rancher/k3s/k3s.yaml' | sed 's/127.0.0.1/${var.control_plane_ip}/g' > k3s.yaml && export KUBECONFIG=$(pwd)/k3s.yaml"
    }

    # Cluster Summary
    summary = {
      total_nodes = 1 + var.worker_count
      network     = "192.168.56.0/24"
      node_count  = {
        control_plane = 1
        workers       = var.worker_count
      }
    }
  }
}
