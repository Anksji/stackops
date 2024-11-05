#!/bin/bash

# setup.sh - Run this once when setting up the EC2 instance
set -e

# Update system
sudo apt update && sudo apt upgrade -y

# Remove any old Docker installations
echo "Removing old Docker installations..."
sudo apt remove -y docker docker.io containerd runc || true

# Install prerequisites
echo "Installing prerequisites..."
sudo apt install -y ca-certificates curl gnupg software-properties-common

# Add Docker's official GPG key
echo "Adding Docker's GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "Adding Docker repository..."
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update apt after adding Docker repository
sudo apt update

# Install Docker
echo "Installing Docker..."
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker
echo "Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Add ubuntu user to docker group
echo "Adding user to docker group..."
sudo usermod -a -G docker ubuntu
