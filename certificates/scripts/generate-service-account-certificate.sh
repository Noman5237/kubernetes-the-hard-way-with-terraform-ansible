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
