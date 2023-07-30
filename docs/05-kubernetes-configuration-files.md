# Generating Kubernetes Configuration Files for Authentication

In this lab you will generate [Kubernetes configuration files](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/), also known as kubeconfigs, which enable Kubernetes clients to locate and authenticate to the Kubernetes API Servers.

## Client Authentication Configs

In this section you will generate kubeconfig files for the `controller manager`, `kubelet`, `kube-proxy`, and `scheduler` clients and the `admin` user.

### Kubernetes Public IP Address

Each kubeconfig requires a Kubernetes API Server to connect to. To support high availability the IP address assigned to the external load balancer fronting the Kubernetes API Servers will be used.

Retrieve the `kubernetes-the-hard-way` static IP address:

```
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
```

### The kubelet Kubernetes Configuration File

When generating kubeconfig files for Kubelets the client certificate matching the Kubelet's node name must be used. This will ensure Kubelets are properly authorized by the Kubernetes [Node Authorizer](https://kubernetes.io/docs/admin/authorization/node/).

> The following commands must be run in the same directory used to generate the SSL certificates during the [Generating TLS Certificates](04-certificate-authority.md) lab.

Generate a kubeconfig file for each worker node:

> file: config/kubeconfig/scripts/generate-worker-kubeconfigs.sh
```
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
```

Results:

```
worker-0.kubeconfig
worker-1.kubeconfig
worker-2.kubeconfig
```

### The kube-proxy Kubernetes Configuration File

Generate a kubeconfig file for the `kube-proxy` service:

> file: config/kubeconfig/scripts/generate-kube-proxy-kubeconfig.sh
```
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

mkdir -p $PROJECT_ROOT/config/kubeconfig/kube-proxy
cd $PROJECT_ROOT/config/kubeconfig/kube-proxy

kubectl config set-cluster kubernetes-the-hard-way \
	--certificate-authority=$PROJECT_ROOT/certificates/ca/ca.pem \
	--embed-certs=true \
	--server=https://${kubernetes_public_address}:6443 \
	--kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
	--client-certificate=$PROJECT_ROOT/certificates/kube-proxy/kube-proxy.pem \
	--client-key=$PROJECT_ROOT/certificates/kube-proxy/kube-proxy-key.pem \
	--embed-certs=true \
	--kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
	--cluster=kubernetes-the-hard-way \
	--user=system:kube-proxy \
	--kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
```

Results:

```
kube-proxy.kubeconfig
```

### The kube-controller-manager Kubernetes Configuration File

Generate a kubeconfig file for the `kube-controller-manager` service:

> file: config/kubeconfig/scripts/generate-controller-manager-kubeconfig.sh
```
mkdir -p $PROJECT_ROOT/config/kubeconfig/controller-manager
cd $PROJECT_ROOT/config/kubeconfig/controller-manager

kubectl config set-cluster kubernetes-the-hard-way \
	--certificate-authority=$PROJECT_ROOT/certificates/ca/ca.pem \
	--embed-certs=true \
	--server=https://127.0.0.1:6443 \
	--kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
	--client-certificate=$PROJECT_ROOT/certificates/controller-manager/kube-controller-manager.pem \
	--client-key=$PROJECT_ROOT/certificates/controller-manager/kube-controller-manager-key.pem \
	--embed-certs=true \
	--kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
	--cluster=kubernetes-the-hard-way \
	--user=system:kube-controller-manager \
	--kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig

```

Results:

```
kube-controller-manager.kubeconfig
```


### The kube-scheduler Kubernetes Configuration File

Generate a kubeconfig file for the `kube-scheduler` service:

> file: config/kubeconfig/scripts/generate-scheduler-kubeconfig.sh
```
mkdir -p $PROJECT_ROOT/config/kubeconfig/kube-scheduler
cd $PROJECT_ROOT/config/kubeconfig/kube-scheduler

kubectl config set-cluster kubernetes-the-hard-way \
	--certificate-authority=$PROJECT_ROOT/certificates/ca/ca.pem \
	--embed-certs=true \
	--server=https://127.0.0.1:6443 \
	--kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
	--client-certificate=$PROJECT_ROOT/certificates/kube-scheduler/kube-scheduler.pem \
	--client-key=$PROJECT_ROOT/certificates/kube-scheduler/kube-scheduler-key.pem \
	--embed-certs=true \
	--kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
	--cluster=kubernetes-the-hard-way \
	--user=system:kube-scheduler \
	--kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig
```

Results:

```
kube-scheduler.kubeconfig
```

### The admin Kubernetes Configuration File

Generate a kubeconfig file for the `admin` user:

> file: config/kubeconfig/scripts/generate-admin-kubeconfig.sh
```
mkdir -p $PROJECT_ROOT/config/kubeconfig/admin
cd $PROJECT_ROOT/config/kubeconfig/admin

kubectl config set-cluster kubernetes-the-hard-way \
	--certificate-authority=$PROJECT_ROOT/certificates/ca/ca.pem \
	--embed-certs=true \
	--server=https://127.0.0.1:6443 \
	--kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
	--client-certificate=$PROJECT_ROOT/certificates/admin/admin.pem \
	--client-key=$PROJECT_ROOT/certificates/admin/admin-key.pem \
	--embed-certs=true \
	--kubeconfig=admin.kubeconfig

kubectl config set-context default \
	--cluster=kubernetes-the-hard-way \
	--user=admin \
	--kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig
```

Results:

```
admin.kubeconfig
```

## Distribute the Kubernetes Configuration Files

Copy the appropriate `kubelet` and `kube-proxy` kubeconfig files to each worker instance:

> file: automation/playbooks/installation/3-distribute-worker-kubeconfig.sh
```
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
```

Copy the appropriate `kube-controller-manager` and `kube-scheduler` kubeconfig files to each controller instance:

> file: automation/playbooks/installation/4-distribute-controller-kubeconfig.sh
```
no_of_controllers=$(cat $PROJECT_ROOT/automation/group_vars/control_plane.yml | yq '.control_plane | length')

for i in $(seq 0 $((no_of_controllers - 1))); do
	EXTERNAL_IP=$(cat $PROJECT_ROOT/automation/group_vars/control_plane.yml | yq '.control_plane | to_entries | .['"$i"'].value.ip.external')

	echo "Copying encryption config to ${EXTERNAL_IP}..."

	scp -o StrictHostKeyChecking=no \
		-i ~/.ssh/gcloud \
		$PROJECT_ROOT/config/encryption/encryption-config.yaml \
		anonyman637@${EXTERNAL_IP}:~/
done
```

Next: [Generating the Data Encryption Config and Key](06-data-encryption-keys.md)
