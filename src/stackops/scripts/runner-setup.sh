#!/bin/bash

# Variables will be set from Python
GITHUB_TOKEN="${GITHUB_TOKEN}"

# Stop the service
sudo systemctl stop actions-runner || true

# Remove the service
sudo systemctl disable actions-runner || true
sudo rm -f /etc/systemd/system/actions-runner.service

# Clean up old runner
cd /home/ubuntu/actions-runner || exit
sudo ./svc.sh uninstall || true
cd /home/ubuntu
sudo rm -rf actions-runner

# Create new runner directory
mkdir -p /home/ubuntu/actions-runner
cd /home/ubuntu/actions-runner

# Download latest runner
curl -o actions-runner-linux-x64.tar.gz -L \
    https://github.com/actions/runner/releases/download/v2.314.1/actions-runner-linux-x64-2.314.1.tar.gz

# Extract runner
tar xzf ./actions-runner-linux-x64.tar.gz

# Install dependencies
./bin/installdependencies.sh

# Configure runner with token
./config.sh --url https://github.com/your-repo --token ${GITHUB_TOKEN} --unattended

# Create service file
sudo tee /etc/systemd/system/actions-runner.service << 'EOF'
[Unit]
Description=GitHub Actions Runner
After=network.target

[Service]
ExecStart=/home/ubuntu/actions-runner/run.sh
User=ubuntu
WorkingDirectory=/home/ubuntu/actions-runner
KillMode=process
KillSignal=SIGTERM
TimeoutStopSec=5min
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
sudo chown -R ubuntu:ubuntu /home/ubuntu/actions-runner
sudo chmod +x /home/ubuntu/actions-runner/run.sh

# Configure systemd
sudo systemctl daemon-reload
sudo systemctl enable actions-runner
sudo systemctl start actions-runner

echo "GitHub Actions Runner setup completed!"
