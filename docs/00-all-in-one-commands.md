# All in One Commands

All the commands has to be executed from the root of the repository in order to work.
```
sh

cd infrastructures
terraform init
terraform apply --target=module.resource
terraform apply --target=module.network
echo yes | terraform apply -target=module.controller
echo yes | terraform apply -target=module.worker
terraform show


```
