#!/bin/bash
#
# Setup for Control Plane (Master) servers

set -euxo pipefail

NODENAME=$(hostname -s)

kubeadm config images pull

echo "Preflight Check Passed: Downloaded All Required Images"

kubeadm init --apiserver-advertise-address=$CONTROL_IP --apiserver-cert-extra-sans=$CONTROL_IP --pod-network-cidr=$POD_CIDR --service-cidr=$SERVICE_CIDR --node-name "$NODENAME" --ignore-preflight-errors=all --upload-certs

mkdir -p "$HOME"/.kube
/bin/cp -rf /etc/kubernetes/admin.conf "$HOME"/.kube/config
chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

# Save Configs to shared /Vagrant location

# For Vagrant re-runs, check if there is existing configs in the location and delete it for saving new configuration.

config_path="/vagrant/configs"

if [ -d $config_path ]; then
  rm -f $config_path/*
else
  mkdir -p $config_path
fi

/bin/cp -rf /etc/kubernetes/admin.conf $config_path/config
touch $config_path/join.sh
chmod +x $config_path/join.sh

kubeadm token create --print-join-command > $config_path/join.sh

mkdir -p /home/vagrant/.kube
/bin/cp -rf $config_path/config /home/vagrant/.kube/
chown -R vagrant:vagrant /home/vagrant/.kube/config
chown -R vagrant:vagrant $config_path
sleep 60

# Install Calico Network Plugin

kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/calico.yaml

# Install nfs-provider
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

helm upgrade --install nfs-subdir-external-provisioner \
nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
--namespace nfs-provisioner \
--create-namespace \
--set nfs.server=$CONTROL_IP \
--set nfs.path=/srv/nfs/kubedata \
--set storageClass.defaultClass=true

sleep 60

# Install Metrics Server

#kubectl apply -f https://raw.githubusercontent.com/techiescamp/kubeadm-scripts/main/manifests/metrics-server.yaml

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/

helm upgrade --install metrics-server metrics-server/metrics-server \
--namespace kube-system \
--set containerPort=4443 \
--set hostNetwork.enabled=true \
--set defaultArgs[0]="--cert-dir=/tmp" \
--set defaultArgs[1]="--kubelet-preferred-address-types=InternalIP" \
--set defaultArgs[2]="--kubelet-use-node-status-port" \
--set defaultArgs[3]="--metric-resolution=15s" \
--set defaultArgs[4]="--kubelet-insecure-tls" \
--set readinessProbe.initialDelaySeconds=300 \
--set readinessProbe.periodSeconds=30
