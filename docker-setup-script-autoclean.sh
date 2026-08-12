#!/bin/bash
set -e

# Remove old versions
sudo apt remove -y docker docker-engine docker.io containerd runc docker-compose docker-doc podman-docker 2>/dev/null || true

# Update system & install prerequisites
sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg lsb-release unattended-upgrades apt-listchanges

# Add Docker’s official GPG key & repo
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine + plugins
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable services
sudo systemctl enable --now docker containerd

# Configure daemon.json for log rotation & default network pool
sudo mkdir -p /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-address-pools": [
    {"base":"172.30.0.0/16","size":24}
  ]
}
EOF

# Reload daemon
sudo systemctl daemon-reexec
sudo systemctl restart docker

# Add current user to docker group
sudo usermod -aG docker $USER

# Configure unattended upgrades for Docker
sudo dpkg-reconfigure -plow unattended-upgrades
cat <<EOF | sudo tee /etc/apt/apt.conf.d/51unattended-upgrades-docker
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
    "Docker:${distro_codename}";
}
EOF

# Setup automatic cleanup of unused Docker resources
sudo tee /etc/cron.weekly/docker-cleanup <<'CLEANUP'
#!/bin/bash
/usr/bin/docker system prune -af --volumes
CLEANUP
sudo chmod +x /etc/cron.weekly/docker-cleanup

# Verify installation
docker --version
docker compose version
sudo docker run --rm hello-world
