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
