# All in One Commands

All the commands has to be executed from the root of the repository in order to work.
```
sh
export PROJECT_ROOT=$(pwd)

cd $PROJECT_ROOT/infrastructures
terraform init
terraform apply --target=module.resource
terraform apply --target=module.network
echo yes | terraform apply -target=module.controller
echo yes | terraform apply -target=module.worker
terraform show

cd $PROJECT_ROOT
./scripts/export-nodes-config-terraform-to-ansible.sh
```
