# All in One Commands

All the commands has to be executed from the root of the repository in order to work.

```
bash

################################################################
#                   ENVIRONMENT VARIABLES                      #
################################################################

export PROJECT_ROOT=$(pwd)

################################################################
#                        INFRASTRUCTURE                        #
################################################################
cd $PROJECT_ROOT/infrastructures
terraform init
terraform apply --target=module.resource
terraform apply --target=module.network
echo yes | terraform apply -target=module.controller
echo yes | terraform apply -target=module.worker
terraform show

# EXPORTING NODES CONFIGURATION TO ANSIBLE
################################################################
cd $PROJECT_ROOT
./scripts/export-nodes-config-terraform-to-ansible.sh

################################################################
#                        GENERATE CERTS                        #
################################################################

cd $PROJECT_ROOT
./certificates/scripts/generate-ca-certificate.sh
./certificates/scripts/generate-admin-certificate.sh
./certificates/scripts/generate-worker-certificates.sh
./certificates/scripts/generate-controller-manager-certificate.sh
./certificates/scripts/generate-kube-proxy-certificate.sh
./certificates/scripts/generate-kube-scheduler-certificate.sh
./certificates/scripts/generate-api-server-certificate.sh
./certificates/scripts/generate-service-account-certificate.sh

# TRANSFER CERTS TO NODES
################################################################
./automation/playbooks/installation/1-distribute-worker-certificates.sh
./automation/playbooks/installation/2-distribute-controller-certificates.sh
```