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
