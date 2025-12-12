#cloud-config

# System configuration
hostname: ${worker_node_name}
fqdn: ${worker_node_name}.k3s.local

# User setup
users:
  - name: debian
    groups: [sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${ssh_public_key}
    lock_passwd: true

# Disable password authentication
ssh_pwauth: false

# Write K3s agent systemd service
write_files:
  - path: /etc/systemd/system/k3s-agent.service
    permissions: '0644'
    content: |
      [Unit]
      Description=Lightweight Kubernetes - K3s Agent
      Documentation=https://k3s.io
      After=network-online.target
      Wants=network-online.target

      [Service]
      Type=notify
      EnvironmentFile=-/etc/systemd/system/k3s-agent.service.env
      ExecStartPre=-/sbin/modprobe br_netfilter
      ExecStartPre=-/sbin/modprobe overlay
      ExecStart=/usr/local/bin/k3s agent \
        --server=${k3s_server_url} \
        --token=${k3s_token} \
        --node-name=${worker_node_name}
      KillMode=process
      Delegate=yes
      LimitNOFILE=1048576
      LimitNPROC=infinity
      LimitCORE=infinity
      TasksMax=infinity
      TimeoutStartSec=0
      Restart=always
      RestartSec=5s

      [Install]
      WantedBy=multi-user.target

# System configuration commands
runcmd:
  # Wait for control plane to be ready (simple retry loop)
  - |
    while ! curl -k ${k3s_server_url}/ping 2>/dev/null; do
      echo "Waiting for control plane..."
      sleep 5
    done
  - systemctl daemon-reload
  - systemctl enable k3s-agent.service
  - systemctl start k3s-agent.service
  - echo "K3s agent started and joined cluster"

# Configure kernel modules for K3s
bootcmd:
  - modprobe br_netfilter
  - modprobe overlay
