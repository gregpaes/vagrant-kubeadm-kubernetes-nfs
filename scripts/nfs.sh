#filename=nfs.sh

set -euxo pipefail

# Variable Declaration

# DNS Setting
echo "[TASK 1] DNS Setting"
if [ ! -d /etc/systemd/resolved.conf.d ]; then
	sudo mkdir /etc/systemd/resolved.conf.d/
fi
cat <<EOF | sudo tee /etc/systemd/resolved.conf.d/dns_servers.conf
[Resolve]
DNS=${DNS_SERVERS}
EOF

sudo systemctl restart systemd-resolved

# # Update hosts file
# echo "[TASK 1] Update /etc/hosts file"
# cat >>/etc/hosts<<EOF
# 172.42.42.99 nfs-server.example.com nfs-server
# 172.42.42.100 lmaster.example.com lmaster
# 172.42.42.101 lworker1.example.com lworker1
# 172.42.42.102 lworker2.example.com lworker2
# EOF

echo "[TASK 2] Download and install NFS server"
# yes| sudo pacman -S nfs-utils
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl nfs-kernel-server

echo "[TASK 3] Create a kubedata directory"
mkdir -p /srv/nfs/kubedata

# mkdir -p /srv/nfs/kubedata/db
# mkdir -p /srv/nfs/kubedata/storage
# mkdir -p /srv/nfs/kubedata/logs

echo "[TASK 4] Update the shared folder access"
sudo chown nobody:nogroup /srv/nfs/kubedata

echo "[TASK 5] Make the kubedata directory available on the network"
cat >>/etc/exports<<EOF
/srv/nfs/kubedata    *(rw,sync,no_subtree_check,no_root_squash)
EOF

echo "[TASK 6] Export the updates"
sudo exportfs -rav

echo "[TASK 7] Enable NFS Server"
sudo systemctl enable nfs-kernel-server

echo "[TASK 8] Start NFS Server"
sudo systemctl restart nfs-kernel-server
