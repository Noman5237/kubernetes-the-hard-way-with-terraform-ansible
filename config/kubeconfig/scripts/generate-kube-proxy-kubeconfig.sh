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
