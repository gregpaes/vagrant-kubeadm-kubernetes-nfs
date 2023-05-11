#filename=nfs.sh

set -euxo pipefail

# Variable Declaration

# DNS Setting
echo "[TASK 1] DNS Setting"
if [ ! -d /etc/systemd/resolved.conf.d ]; then
	mkdir /etc/systemd/resolved.conf.d/
fi
cat <<EOF | tee /etc/systemd/resolved.conf.d/dns_servers.conf
[Resolve]
DNS=${DNS_SERVERS}
EOF

systemctl restart systemd-resolved

# # Update hosts file
# echo "[TASK 1] Update /etc/hosts file"
# cat >>/etc/hosts<<EOF
# 172.42.42.99 nfs-server.example.com nfs-server
# 172.42.42.100 lmaster.example.com lmaster
# 172.42.42.101 lworker1.example.com lworker1
# 172.42.42.102 lworker2.example.com lworker2
# EOF

echo "[TASK 2] Download and install NFS server"
# yes| pacman -S nfs-utils
apt-get update
apt-get install -y apt-transport-https ca-certificates curl nfs-kernel-server

echo "[TASK 3] Create a kubedata directory"
mkdir -p /srv/nfs/kubedata

# mkdir -p /srv/nfs/kubedata/db
# mkdir -p /srv/nfs/kubedata/storage
# mkdir -p /srv/nfs/kubedata/logs

echo "[TASK 4] Update the shared folder access"
chown nobody:nogroup /srv/nfs/kubedata

echo "[TASK 5] Make the kubedata directory available on the network"
cat >>/etc/exports<<EOF
/srv/nfs/kubedata    *(rw,sync,no_subtree_check,no_root_squash)
EOF

echo "[TASK 6] Export the updates"
exportfs -rav

echo "[TASK 7] Enable NFS Server"
systemctl enable nfs-kernel-server

echo "[TASK 8] Start NFS Server"
systemctl restart nfs-kernel-server
