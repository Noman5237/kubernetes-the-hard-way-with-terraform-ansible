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
