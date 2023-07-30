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
