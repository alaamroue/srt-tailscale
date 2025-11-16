#!/usr/bin/env bash

###################################
#        VPS Setup Script         #
###################################
# Don't run this script, simply copy and paste and work through it

### Update de.archive (Because ipv6)
sudo sed -i 's/de\.archive/archive/g' /etc/apt/sources.list.d/ubuntu.sources

### Update and upgrade system packages
echo 'GRUB_INSTALL_DEVICES="/dev/sda"' | sudo tee /etc/default/grub-installer > /dev/null && sudo update-grub
sudo apt-get update -y
sudo apt-get upgrade -y -o Dpkg::Options::="--force-confnew"

### Reboot the system to apply updates
sudo reboot

### User creation
adduser alaa
usermod -aG sudo alaa

### Add SSH key for the new user
mkdir -p /home/alaa/.ssh
touch /home/alaa/.ssh/authorized_keys
chmod 700 /home/alaa/.ssh
chmod 600 /home/alaa/.ssh/authorized_keys
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGjwWxQJH+1CZLlRKnH5kuP0hDCoT2NsaWHZaUcaMSQ6 alaaMain" >> /home/alaa/.ssh/authorized_keys

### SSH hardening
# Disable root login
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
# Disable password authentication
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
# Change default SSH port
sudo sed -i 's/^#\?Port .*/Port 1023/' /etc/ssh/sshd_config
# Override to ensure passwords are disabled
cat <<EOF | sudo tee /etc/ssh/sshd_config.d/10-disable-passwords.conf > /dev/null
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no
EOF
# Restart
sudo systemctl restart ssh

### Firewall setup
sudo apt install ufw -y
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 1023/tcp
sudo ufw enable
sudo ufw status

### Docker setup
# Follow https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
# Check is running:
sudo systemctl status docker
# Add user to docker group
sudo usermod -aG docker alaa
#NOTE: exit and re-login to apply
