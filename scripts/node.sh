#!/bin/bash
#
# Setup for Node servers

set -euxo pipefail

sleep 60

config_path="/vagrant/configs"

if [ -d $config_path ]; then
  rm -f $config_path/*
  chown -R vagrant:vagrant $config_path
else
  mkdir -p $config_path
  chown -R vagrant:vagrant $config_path
fi


# Join worker nodes to the Kubernetes cluster
echo "Join node to Kubernetes Cluster"

apt-get install -q -y sshpass
sshpass -p "vagrant" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no vagrant@master-node:$config_path/join.sh $config_path/join.sh
sshpass -p "vagrant" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no vagrant@master-node:$config_path/config $config_path/config

/bin/bash $config_path/join.sh -v

sleep 30

mkdir -p "$HOME"/.kube
/bin/cp -rf $config_path/config "$HOME"/.kube/config
chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

mkdir -p /home/vagrant/.kube
/bin/cp -rf $config_path/config /home/vagrant/.kube/
chown -R vagrant:vagrant /home/vagrant/.kube/config
NODENAME=$(hostname -s)
kubectl label node $(hostname -s) node-role.kubernetes.io/worker=worker