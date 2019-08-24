#!/bin/bash
set -ex

apt update && apt upgrade -y
apt install -y awscli make
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
/etc/init.d/ssh restart

# Change this later if you don't want to rely on just the ssh key
echo "ubuntu:ubuntu" | chpasswd

apt install -y xrdp xfce4 xfce4-goodies tightvncserver
echo xfce4-session > /home/ubuntu/.xsession
cp /home/ubuntu/.xsession /etc/skel
chown ubuntu:ubuntu /home/ubuntu/.xsession

# Install VS Code
wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | apt-key add -
add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main"
apt update
apt install -y code

# Install docker for ubuntu user
snap install docker
snap disable docker
sudo addgroup --system docker
sudo adduser ubuntu docker
newgrp docker
snap enable docker
