no_of_controllers=$(cat $PROJECT_ROOT/automation/group_vars/control_plane.yml | yq '.control_plane | length')

for i in $(seq 0 $((no_of_controllers - 1))); do
	EXTERNAL_IP=$(cat $PROJECT_ROOT/automation/group_vars/control_plane.yml | yq '.control_plane | to_entries | .['"$i"'].value.ip.external')

	echo "Copying kubeconfigs to ${instance_name}..."
	echo "external ip: ${EXTERNAL_IP}"

	scp -o StrictHostKeyChecking=no \
		-i ~/.ssh/gcloud \
		$PROJECT_ROOT/config/kubeconfig/admin/admin.kubeconfig \
		$PROJECT_ROOT/config/kubeconfig/controller-manager/kube-controller-manager.kubeconfig \
		$PROJECT_ROOT/config/kubeconfig/kube-scheduler/kube-scheduler.kubeconfig \
		anonyman637@${EXTERNAL_IP}:~/
done
