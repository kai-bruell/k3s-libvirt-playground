#!/bin/bash
cd ..
cd virt-customize/
./build-image.sh
cd ..
cd terraform/
terraform init
terraform apply
terraform output cluster
