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
