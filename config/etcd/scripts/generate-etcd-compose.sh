no_of_controllers=$(cat $PROJECT_ROOT/automation/group_vars/control_plane.yml | yq '.control_plane | length')

REGISTRY=quay.io/coreos/etcd
VERSION=v3.5.9

# declare an array
docker_compose_array=()
docker_compose_template=$(cat $PROJECT_ROOT/config/etcd/scripts/docker-compose-template.yaml)

INITIAL_CLUSTER=""
for i in $(seq 0 $((no_of_controllers - 1))); do
	instance_name=$(cat $PROJECT_ROOT/automation/group_vars/control_plane.yml | yq '.control_plane | to_entries | .['"$i"'].key')
	# replace _ with - in instance_name
	instance_name=$(echo $instance_name | sed 's/_/-/g')

	INTERNAL_IP=$(cat $PROJECT_ROOT/automation/group_vars/control_plane.yml | yq '.control_plane | to_entries | .['"$i"'].value.ip.internal')

	ETCD_NAME=${instance_name}
	INITIAL_CLUSTER_TOKEN="etcd-cluster-$i"
	INITIAL_CLUSTER="${INITIAL_CLUSTER}${instance_name}=https://${INTERNAL_IP}:2380,"

	# replace variables in template
	docker_compose=$(
		echo "$docker_compose_template" |
			awk -v ETCD_NAME="$ETCD_NAME" \
				-v INTERNAL_IP="$INTERNAL_IP" \
				-v INITIAL_CLUSTER_TOKEN="$INITIAL_CLUSTER_TOKEN" \
				'{ 
					gsub(/\${ETCD_NAME}/, ETCD_NAME);
					gsub(/\${INTERNAL_IP}/, INTERNAL_IP);
					gsub(/\${INITIAL_CLUSTER_TOKEN}/, INITIAL_CLUSTER_TOKEN);
					print 
				}'
	)

	# add to array
	docker_compose_array+=("$docker_compose")
done

# remove the last comma
INITIAL_CLUSTER=$(echo $INITIAL_CLUSTER | sed 's/,$//g')

# replace initial cluster in templates
for i in $(seq 0 $((no_of_controllers - 1))); do
	docker_compose_array[$i]=$(
		echo "${docker_compose_array[$i]}" |
			awk -v INITIAL_CLUSTER="$INITIAL_CLUSTER" \
				-v REGISTRY="$REGISTRY" \
				-v VERSION="$VERSION" \
				'{ 
					gsub(/\${INITIAL_CLUSTER}/, INITIAL_CLUSTER);
					gsub(/\${REGISTRY}/, REGISTRY);
					gsub(/\${VERSION}/, VERSION);
					print 
				}'
	)
done

for i in $(seq 0 $((no_of_controllers - 1))); do
	mkdir -p $PROJECT_ROOT/config/etcd/controller-$i
	echo "${docker_compose_array[$i]}" >$PROJECT_ROOT/config/etcd/controller-$i/etcd-docker-compose.yaml
done
