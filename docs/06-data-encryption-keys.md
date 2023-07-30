# Generating the Data Encryption Config and Key

Kubernetes stores a variety of data including cluster state, application configurations, and secrets. Kubernetes supports the ability to [encrypt](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data) cluster data at rest.

In this lab you will generate an encryption key and an [encryption config](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#understanding-the-encryption-at-rest-configuration) suitable for encrypting Kubernetes Secrets.

## The Encryption Key

Generate an encryption key:

```
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
```

## The Encryption Config File

Create the `encryption-config.yaml` encryption config file:

> file: config/encryption/scripts/generate-encryption-config.sh
```
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cd $PROJECT_ROOT/config/encryption

cat >encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
```

Copy the `encryption-config.yaml` encryption config file to each controller instance:

> file: automation/playbooks/installation/5-distribute-controller-kubeconfig.sh
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

Next: [Bootstrapping the etcd Cluster](07-bootstrapping-etcd.md)
