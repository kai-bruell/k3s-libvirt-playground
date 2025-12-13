#!/bin/bash
# Alle VMs löschen
for vm in $(virsh list --all --name | grep -v '^$'); do
  echo "Lösche VM: $vm"
  virsh destroy "$vm" 2>/dev/null
  virsh undefine "$vm" --remove-all-storage 2>/dev/null
done

# Alle Pools löschen (außer default)
for pool in $(virsh pool-list --all --name | grep -v '^default$' | grep -v '^$'); do
  echo "Lösche Pool: $pool"
  virsh pool-destroy "$pool" 2>/dev/null
  virsh pool-undefine "$pool" 2>/dev/null
done

# Alle Networks löschen (außer default)
for net in $(virsh net-list --all --name | grep -v '^default$' | grep -v '^$'); do
  echo "Lösche Network: $net"
  virsh net-destroy "$net" 2>/dev/null
  virsh net-undefine "$net" 2>/dev/null
done

cd ..
sudo rm -rf libvirt-pool/
rm -rf k3s_cluster_id_rsa
rm -rf terraform/.terraform/
rm -rf terraform/terraform.tfstate

