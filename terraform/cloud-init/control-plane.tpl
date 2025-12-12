#cloud-config

# System configuration
hostname: k3s-control
fqdn: k3s-control.k3s.local

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

# Write K3s systemd service
write_files:
  - path: /etc/systemd/system/k3s.service
    permissions: '0644'
    content: |
      [Unit]
      Description=Lightweight Kubernetes - K3s Control Plane
      Documentation=https://k3s.io
      After=network-online.target
      Wants=network-online.target

      [Service]
      Type=notify
      EnvironmentFile=-/etc/systemd/system/k3s.service.env
      ExecStartPre=-/sbin/modprobe br_netfilter
      ExecStartPre=-/sbin/modprobe overlay
      ExecStart=/usr/local/bin/k3s server \
        --write-kubeconfig-mode=0644 \
        --token=${k3s_token} \
        --node-name=k3s-control \
        --cluster-init
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
  - systemctl daemon-reload
  - systemctl enable k3s.service
  - systemctl start k3s.service
  - echo "K3s control plane started"

# Configure kernel modules for K3s
bootcmd:
  - modprobe br_netfilter
  - modprobe overlay
