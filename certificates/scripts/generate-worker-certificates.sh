mkdir -p $PROJECT_ROOT/certificates/worker
cd $PROJECT_ROOT/certificates/worker

no_of_workers=$(cat $PROJECT_ROOT/automation/group_vars/worker_plane.yml | yq '.worker_plane | length')

for i in $(seq 0 $((no_of_workers-1))); do
	instance_name=$(cat $PROJECT_ROOT/automation/group_vars/worker_plane.yml | yq '.worker_plane | to_entries | .['"$i"'].key')
	# replace _ with - in instance_name
	instance_name=$(echo $instance_name | sed 's/_/-/g')

	mkdir -p $PROJECT_ROOT/certificates/worker/${instance_name}
	cd $PROJECT_ROOT/certificates/worker/${instance_name}

	cat > ${instance_name}-csr.json <<EOF
{
	"CN": "system:node:${instance_name}",
	"key": {
		"algo": "rsa",
		"size": 2048
	},
	"names": [
		{
			"C": "US",
			"L": "Portland",
			"O": "system:nodes",
			"OU": "Kubernetes The Hard Way",
			"ST": "Oregon"
		}
	]
}
EOF

	EXTERNAL_IP=$(cat $PROJECT_ROOT/automation/group_vars/worker_plane.yml | yq '.worker_plane | to_entries | .['"$i"'].value.ip.external')
	INTERNAL_IP=$(cat $PROJECT_ROOT/automation/group_vars/worker_plane.yml | yq '.worker_plane | to_entries | .['"$i"'].value.ip.internal')

	cfssl gencert \
		-ca=$PROJECT_ROOT/certificates/ca/ca.pem \
		-ca-key=$PROJECT_ROOT/certificates/ca/ca-key.pem \
		-config=$PROJECT_ROOT/certificates/ca/ca-config.json \
		-hostname=${instance_name},${EXTERNAL_IP},${INTERNAL_IP} \
		-profile=kubernetes \
		${instance_name}-csr.json | cfssljson -bare ${instance_name}
done
