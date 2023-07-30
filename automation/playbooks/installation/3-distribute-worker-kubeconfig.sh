no_of_workers=$(cat $PROJECT_ROOT/automation/group_vars/worker_plane.yml | yq '.worker_plane | length')

echo "Copying certificates to workers..."
for i in $(seq 0 $((no_of_workers - 1))); do
	instance_name=$(cat $PROJECT_ROOT/automation/group_vars/worker_plane.yml | yq '.worker_plane | to_entries | .['"$i"'].key')
	# replace _ with - in instance_name
	instance_name=$(echo $instance_name | sed 's/_/-/g')

	EXTERNAL_IP=$(cat $PROJECT_ROOT/automation/group_vars/worker_plane.yml | yq '.worker_plane | to_entries | .['"$i"'].value.ip.external')

	echo "Copying kubeconfigs to ${instance_name}..."
	echo "external ip: ${EXTERNAL_IP}"
	scp -o StrictHostKeyChecking=no \
		-i ~/.ssh/gcloud \
		$PROJECT_ROOT/config/kubeconfig/workers/${instance_name}.kubeconfig \
		$PROJECT_ROOT/config/kubeconfig/kube-proxy/kube-proxy.kubeconfig \
		anonyman637@${EXTERNAL_IP}:~/
done
