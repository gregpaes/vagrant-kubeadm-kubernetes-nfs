#!/bin/bash
#
# Common setup for all servers (Control Plane and Nodes)

set -euxo pipefail

# Variable Declaration

# DNS Setting
if [ ! -d /etc/systemd/resolved.conf.d ]; then
	 mkdir /etc/systemd/resolved.conf.d/
fi
cat > /etc/systemd/resolved.conf.d/dns_servers.conf <<EOF
[Resolve]
DNS=${DNS_SERVERS}
EOF

 systemctl restart systemd-resolved

# disable swap
 swapoff -a

# keeps the swap off during reboot
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab - || true
 apt-get update -y
# Install CRI-O Runtime

VERSION="$(echo ${KUBERNETES_VERSION} | grep -oE '[0-9]+\.[0-9]+')"

# Create the .conf file to load the modules at bootup
cat > /etc/modules-load.d/crio.conf <<EOF
overlay
br_netfilter
EOF

 modprobe overlay
 modprobe br_netfilter

# Set up required sysctl params, these persist across reboots.
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

 sysctl --system

cat > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list <<EOF
deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /
EOF
cat > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list <<EOF
deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /
EOF

curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/Release.key |  apt-key --keyring /etc/apt/trusted.gpg.d/libcontainers.gpg add -
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key |  apt-key --keyring /etc/apt/trusted.gpg.d/libcontainers.gpg add -

 apt-get update
 apt-get install cri-o cri-o-runc -y

cat >> /etc/default/crio << EOF
${ENVIRONMENT}
EOF
 systemctl daemon-reload
 systemctl enable crio --now

echo "CRI runtime installed susccessfully"

 apt-get update
 apt-get install -y apt-transport-https ca-certificates curl nfs-common
 curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" |  tee /etc/apt/sources.list.d/kubernetes.list
 apt-get update -y
 apt-get install -y kubelet="$KUBERNETES_VERSION" kubectl="$KUBERNETES_VERSION" kubeadm="$KUBERNETES_VERSION"
 apt-get update -y
 apt-get install -y jq

curl https://baltocdn.com/helm/signing.asc | gpg --dearmor |  tee /usr/share/keyrings/helm.gpg > /dev/null
 apt-get install apt-transport-https -y
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" |  tee /etc/apt/sources.list.d/helm-stable-debian.list
 apt-get update -y
 apt-get install helm -y

local_ip="$(ip --json a s | jq -r '.[] | if .ifname == "eth1" then .addr_info[] | if .family == "inet" then .local else empty end else empty end')"
cat > /etc/default/kubelet << EOF
KUBELET_EXTRA_ARGS=--node-ip=$local_ip
${ENVIRONMENT}
EOF
