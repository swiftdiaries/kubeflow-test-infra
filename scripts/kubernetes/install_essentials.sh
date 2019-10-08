#!/bin/bash
#usage: ./setupkubernetes.sh
echo "######################### INSTALL DOCKER ##########################################"
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
# Check Docker version
apt-cache policy docker-ce
# Install Docker
apt-get update && apt-get install docker-ce=18.06.2~ce~3-0~ubuntu
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

# Restart docker.
systemctl daemon-reload
systemctl restart docker

# Run docker without sudo, uncomment these lines
# sudo groupadd docker
# sudo usermod -aG docker ${USER}
# su - ${USER}
echo 'You might need to reboot / relogin to make docker work correctly'

echo "######################### KUBERNETES ##########################################"
KUBERNETES_VERSION=1.15.0
KUBERNETES_CNI=0.7.5
sudo bash -c 'apt-get update && apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get -y update'
sudo apt-get install -yf \
  socat \
  ebtables \
  apt-transport-https \
  kubelet=${KUBERNETES_VERSION}-00 \
  kubeadm=${KUBERNETES_VERSION}-00 \
  kubernetes-cni=${KUBERNETES_CNI}-00 \
  kubectl=${KUBERNETES_VERSION}-00

echo "######################### NVIDIA-DOCKER ##########################################"
# If you have nvidia-docker 1.0 installed: we need to remove it and all existing GPU containers
docker volume ls -q -f driver=nvidia-docker | xargs -r -I{} -n1 docker ps -q -a -f volume={} | xargs -r docker rm -f
sudo apt-get purge -y nvidia-docker
# Add the package repositories
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | \
  sudo apt-key add -
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update
# Install nvidia-docker2 and reload the Docker daemon configuration
sudo apt-get install -y nvidia-docker2
sudo pkill -SIGHUP dockerd
# NOTE: Check nvidia-docker runtime in /etc/docker/daemon.json
sudo mv daemon.json /etc/docker/daemon.json
sudo systemctl restart docker
sudo systemctl daemon-reload
sudo systemctl restart kubelet
sudo swapoff -a

echo "######################### Golang ##########################################"
wget https://dl.google.com/go/go1.10.3.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.10.3.linux-amd64.tar.gz
PATH=$PATH:/usr/local/go/bin
mkdir -p ~/go
mkdir -p ~/go/src
mkdir -p ~/go/bin
GOPATH=~/go

echo "######################### Ksonnet ##########################################"
go get github.com/ksonnet/ksonnet
cd $GOPATH/src/github.com/ksonnet/ksonnet
go build -o ./bin/ks -ldflags="-X main.version=dev-2018-08-31T20:36:26-0700 -X main.apimachineryVersion=kubernetes-1.10.4 -X generator.revision=c7b94fe55153ce9f24f8e4c346fa424e70ddcf06  "  ./cmd/ks
sudo mv bin/ks /bin/ks
cd
which ks
ks version
echo "######################### Clean-up ##########################################"
sudo rm -rf *.tgz *.deb
