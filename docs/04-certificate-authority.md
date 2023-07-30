# Provisioning a CA and Generating TLS Certificates

In this lab you will provision a [PKI Infrastructure](https://en.wikipedia.org/wiki/Public_key_infrastructure) using CloudFlare's PKI toolkit, [cfssl](https://github.com/cloudflare/cfssl), then use it to bootstrap a Certificate Authority, and generate TLS certificates for the following components: etcd, kube-apiserver, kube-controller-manager, kube-scheduler, kubelet, and kube-proxy.

## Certificate Authority

In this section you will provision a Certificate Authority that can be used to generate additional TLS certificates.

Generate the CA configuration file, certificate, and private key:
> file: certificates/scripts/generate-ca-certificate.sh

```
mkdir -p $PROJECT_ROOT/certificates/ca
cd $PROJECT_ROOT/certificates/ca

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```

Results:

```
ca-key.pem
ca.pem
```

## Client and Server Certificates

In this section you will generate client and server certificates for each Kubernetes component and a client certificate for the Kubernetes `admin` user.

### The Admin Client Certificate

Generate the `admin` client certificate and private key:
> file: certificates/scripts/generate-admin-certificate.sh
```
mkdir -p $PROJECT_ROOT/certificates/admin
cd $PROJECT_ROOT/certificates/admin

cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
	-ca=$PROJECT_ROOT/certificates/ca/ca.pem \
	-ca-key=$PROJECT_ROOT/certificates/ca/ca-key.pem \
	-config=$PROJECT_ROOT/certificates/ca/ca-config.json \
	-profile=kubernetes \
	admin-csr.json | cfssljson -bare admin

```

Results:

```
admin-key.pem
admin.pem
```

### Scrap important terraform output json to yaml for ansible group_vars
> file: scripts/export-nodes-config-terraform-to-ansible.sh

```
cd $PROJECT_ROOT/infrastructures

mkdir -p $PROJECT_ROOT/automation/group_vars

terraform show -json | \
	jq -r '[.values.root_module.child_modules[] 
	| select(.address == "module.controller")] 
	| .[].resources[].values 
	| {
			(.name): {
				ip: { 
					internal: .network_interface[0].network_ip, 
					external: .network_interface[0].access_config[0].nat_ip
				},
				username: "anonyman637"
			}
		}' | \
	jq -s 'reduce .[] as $item ({}; . * $item) | { "control_plane": . }' | \
	awk '{ gsub("-", "_"); print }' | \
	yq -P > $PROJECT_ROOT/automation/group_vars/control_plane.yml

terraform show -json | \
	jq -r '[.values.root_module.child_modules[] 
	| select(.address == "module.worker")] 
	| .[].resources[].values 
	| {
			(.name): {
				ip: { 
					internal: .network_interface[0].network_ip, 
					external: .network_interface[0].access_config[0].nat_ip
				},
				username: "anonyman637"
			}
		}' | \
	jq -s 'reduce .[] as $item ({}; . * $item) | { "worker_plane": . }' | \
	awk '{ gsub("-", "_"); print }' | \
	yq -P > $PROJECT_ROOT/automation/group_vars/worker_plane.yml

```

### The Kubelet Client Certificates

Kubernetes uses a [special-purpose authorization mode](https://kubernetes.io/docs/admin/authorization/node/) called Node Authorizer, that specifically authorizes API requests made by [Kubelets](https://kubernetes.io/docs/concepts/overview/components/#kubelet). In order to be authorized by the Node Authorizer, Kubelets must use a credential that identifies them as being in the `system:nodes` group, with a username of `system:node:<nodeName>`. In this section you will create a certificate for each Kubernetes worker node that meets the Node Authorizer requirements. Here we will be using the `worker_plane` group_vars to generate the certificates.

Generate a certificate and private key for each Kubernetes worker node:

> file: certificates/scripts/generate-worker-certificates.sh
```
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
```

Results:

```
worker-0-key.pem
worker-0.pem
worker-1-key.pem
worker-1.pem
worker-2-key.pem
worker-2.pem
```

### The Controller Manager Client Certificate

Generate the `kube-controller-manager` client certificate and private key:

> file: certificates/scripts/generate-controller-manager-certificate.sh
```
mkdir -p $PROJECT_ROOT/certificates/controller-manager
cd $PROJECT_ROOT/certificates/controller-manager

cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
	-ca=$PROJECT_ROOT/certificates/ca/ca.pem \
	-ca-key=$PROJECT_ROOT/certificates/ca/ca-key.pem \
	-config=$PROJECT_ROOT/certificates/ca/ca-config.json \
	-profile=kubernetes \
	kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

```

Results:

```
kube-controller-manager-key.pem
kube-controller-manager.pem
```


### The Kube Proxy Client Certificate

Generate the `kube-proxy` client certificate and private key:

> file: certificates/scripts/generate-kube-proxy-certificate.sh
```
mkdir -p $PROJECT_ROOT/certificates/kube-proxy
cd $PROJECT_ROOT/certificates/kube-proxy

cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
	-ca=$PROJECT_ROOT/certificates/ca/ca.pem \
	-ca-key=$PROJECT_ROOT/certificates/ca/ca-key.pem \
	-config=$PROJECT_ROOT/certificates/ca/ca-config.json \
	-profile=kubernetes \
	kube-proxy-csr.json | cfssljson -bare kube-proxy

```

Results:

```
kube-proxy-key.pem
kube-proxy.pem
```

### The Scheduler Client Certificate

Generate the `kube-scheduler` client certificate and private key:

> file: certificates/scripts/generate-kube-scheduler-certificate.sh
```
mkdir -p $PROJECT_ROOT/certificates/kube-scheduler
cd $PROJECT_ROOT/certificates/kube-scheduler

cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
	-ca=$PROJECT_ROOT/certificates/ca/ca.pem \
	-ca-key=$PROJECT_ROOT/certificates/ca/ca-key.pem \
	-config=$PROJECT_ROOT/certificates/ca/ca-config.json \
	-profile=kubernetes \
	kube-scheduler-csr.json | cfssljson -bare kube-scheduler

```

Results:

```
kube-scheduler-key.pem
kube-scheduler.pem
```


### The Kubernetes API Server Certificate

The `kubernetes-the-hard-way` static IP address will be included in the list of subject alternative names for the Kubernetes API Server certificate. This will ensure the certificate can be validated by remote clients.

Generate the Kubernetes API Server certificate and private key:

> file: certificates/scripts/generate-kubernetes-api-server-certificate.sh
```
mkdir -p $PROJECT_ROOT/certificates/api-server

control_plane_internal_ip_addresses=$(cat $PROJECT_ROOT/automation/group_vars/control_plane.yml | yq '.control_plane | to_entries | .[].value.ip.internal' | tr '\n' ',' | sed 's/,$//g')
KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

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

cd $PROJECT_ROOT/certificates/api-server
cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
	-ca=$PROJECT_ROOT/certificates/ca/ca.pem \
	-ca-key=$PROJECT_ROOT/certificates/ca/ca-key.pem \
	-config=$PROJECT_ROOT/certificates/ca/ca-config.json \
	-hostname=10.32.0.1,${control_plane_internal_ip_addresses},${kubernetes_public_address},127.0.0.1,${KUBERNETES_HOSTNAMES} \
	-profile=kubernetes \
	kubernetes-csr.json | cfssljson -bare kubernetes

```

> The Kubernetes API server is automatically assigned the `kubernetes` internal dns name, which will be linked to the first IP address (`10.32.0.1`) from the address range (`10.32.0.0/24`) reserved for internal cluster services during the [control plane bootstrapping](08-bootstrapping-kubernetes-controllers.md#configure-the-kubernetes-api-server) lab.

Results:

```
kubernetes-key.pem
kubernetes.pem
```

## The Service Account Key Pair

The Kubernetes Controller Manager leverages a key pair to generate and sign service account tokens as described in the [managing service accounts](https://kubernetes.io/docs/admin/service-accounts-admin/) documentation.

Generate the `service-account` certificate and private key:

> file: certificates/scripts/generate-service-account-certificate.sh
```
mkdir -p $PROJECT_ROOT/certificates/service-account
cd $PROJECT_ROOT/certificates/service-account

cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
	-ca=$PROJECT_ROOT/certificates/ca/ca.pem \
	-ca-key=$PROJECT_ROOT/certificates/ca/ca-key.pem \
	-config=$PROJECT_ROOT/certificates/ca/ca-config.json \
	-profile=kubernetes \
	service-account-csr.json | cfssljson -bare service-account

```

Results:

```
service-account-key.pem
service-account.pem
```


## Distribute the Client and Server Certificates

Copy the appropriate certificates and private keys to each worker instance:

> file: automation/playbooks/installation/1-distribute-worker-certificates.sh
```
no_of_workers=$(cat $PROJECT_ROOT/automation/group_vars/worker_plane.yml | yq '.worker_plane | length')

echo "Copying certificates to workers..."
for i in $(seq 0 $((no_of_workers - 1))); do
	instance_name=$(cat $PROJECT_ROOT/automation/group_vars/worker_plane.yml | yq '.worker_plane | to_entries | .['"$i"'].key')
	# replace _ with - in instance_name
	instance_name=$(echo $instance_name | sed 's/_/-/g')

	EXTERNAL_IP=$(cat $PROJECT_ROOT/automation/group_vars/worker_plane.yml | yq '.worker_plane | to_entries | .['"$i"'].value.ip.external')

	echo "Copying certificates to ${instance_name}..."
	echo "external ip: ${EXTERNAL_IP}"
	scp -o StrictHostKeyChecking=no \
		-i ~/.ssh/gcloud \
		$PROJECT_ROOT/certificates/ca/ca.pem \
		$PROJECT_ROOT/certificates/worker/${instance_name}/${instance_name}-key.pem \
		$PROJECT_ROOT/certificates/worker/${instance_name}/${instance_name}.pem \
		anonyman637@${EXTERNAL_IP}:~/
done

```

Copy the appropriate certificates and private keys to each controller instance:

> file: automation/playbooks/installation/2-distribute-controller-certificates.sh
```
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
```

> The `kube-proxy`, `kube-controller-manager`, `kube-scheduler`, and `kubelet` client certificates will be used to generate client authentication configuration files in the next lab.

Next: [Generating Kubernetes Configuration Files for Authentication](05-kubernetes-configuration-files.md)
