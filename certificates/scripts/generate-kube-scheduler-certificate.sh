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
