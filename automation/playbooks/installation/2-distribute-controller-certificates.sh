no_of_controllers=$(cat $PROJECT_ROOT/automation/group_vars/control_plane.yml | yq '.control_plane | length')

echo "Copying certificates to controllers..."
for i in $(seq 0 $((no_of_controllers - 1))); do
	EXTERNAL_IP=$(cat $PROJECT_ROOT/automation/group_vars/control_plane.yml | yq '.control_plane | to_entries | .['"$i"'].value.ip.external')

	echo "Copying certificates to ${instance_name}..."
	echo "external ip: ${EXTERNAL_IP}"

	scp -o StrictHostKeyChecking=no \
		-i ~/.ssh/gcloud \
		$PROJECT_ROOT/certificates/ca/ca.pem \
		$PROJECT_ROOT/certificates/ca/ca-key.pem \
		$PROJECT_ROOT/certificates/api-server/kubernetes.pem \
		$PROJECT_ROOT/certificates/api-server/kubernetes-key.pem \
		$PROJECT_ROOT/certificates/service-account/service-account.pem \
		$PROJECT_ROOT/certificates/service-account/service-account-key.pem \
		anonyman637@${EXTERNAL_IP}:~/
done
