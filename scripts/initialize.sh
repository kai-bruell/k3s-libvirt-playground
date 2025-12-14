#!/bin/bash
cd ..
cd virt-customize/
./build-image.sh
cd ..
cd terraform/
terraform init
terraform apply
terraform output cluster

echo ""
echo "Setting KUBECONFIG..."
export KUBECONFIG=$(pwd)/../kubeconfig
echo "KUBECONFIG set to: $KUBECONFIG"
echo "It can take up to 60 seconds for all three nodes to be fully operational. You can run [kubectl get nodes] a few times in succession to monitor the process live."
