no_of_workers=$(cat $PROJECT_ROOT/automation/group_vars/worker_plane.yml | yq '.worker_plane | length')

cd $PROJECT_ROOT/infrastructures
kubernetes_public_address=$(
	terraform show -json |
		jq -r '[.values.root_module.child_modules[]
  	| select(.address == "module.network")] 
		| .[].resources[] 
		| select(.name == "kubernetes-the-hard-way") 
		| select(.values.address_type == "EXTERNAL") 
		| .values.address'
)

mkdir -p $PROJECT_ROOT/config/kubeconfig/workers
cd $PROJECT_ROOT/config/kubeconfig/workers

for i in $(seq 0 $((no_of_workers - 1))); do
	instance_name=$(cat $PROJECT_ROOT/automation/group_vars/worker_plane.yml | yq '.worker_plane | to_entries | .['"$i"'].key')
	# replace _ with - in instance_name
	instance_name=$(echo $instance_name | sed 's/_/-/g')

	kubectl config set-cluster kubernetes-the-hard-way \
		--certificate-authority=$PROJECT_ROOT/certificates/ca/ca.pem \
		--embed-certs=true \
		--server=https://${kubernetes_public_address}:6443 \
		--kubeconfig=${instance_name}.kubeconfig

	kubectl config set-credentials system:node:${instance_name} \
		--client-certificate=$PROJECT_ROOT/certificates/worker/${instance_name}/${instance_name}.pem \
		--client-key=$PROJECT_ROOT/certificates/worker/${instance_name}/${instance_name}-key.pem \
		--embed-certs=true \
		--kubeconfig=${instance_name}.kubeconfig

	kubectl config set-context default \
		--cluster=kubernetes-the-hard-way \
		--user=system:node:${instance_name} \
		--kubeconfig=${instance_name}.kubeconfig
done
