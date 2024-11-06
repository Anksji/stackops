# src/server_setup/utils.py
import os
from pathlib import Path
from typing import Dict

def install_scripts(scripts_dir: Path) -> bool:
    """
    Install required shell scripts to the scripts directory
    
    Args:
        scripts_dir: Directory to install scripts to
    """
    # Ensure directory exists
    scripts_dir.mkdir(parents=True, exist_ok=True)
    
    # Define scripts content
    scripts: Dict[str, str] = {
        'initial_setup.sh': '''#!/bin/bash

# Exit on any error
set -e

# Colors for output
GREEN='\\033[0;32m'
RED='\\033[0;31m'
NC='\\033[0m' # No Color

# Logger function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    error "Please run as root or with sudo"
    exit 1
fi

# Update system (only essential updates)
log "Updating system packages..."
apt update
apt upgrade -y --only-upgrade

# Install only essential packages
log "Installing essential packages..."
apt install -y nginx \\
    ufw \\
    fail2ban

# Remove unnecessary services and packages
log "Removing unnecessary services..."
apt remove --purge -y snapd
apt autoremove -y
systemctl disable apache2 2>/dev/null || true
systemctl stop apache2 2>/dev/null || true

# Configure UFW with minimal rules
log "Configuring firewall (UFW)..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 'Nginx HTTP'
echo "y" | ufw enable

# Basic fail2ban configuration (minimal)
log "Configuring fail2ban..."
cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 3600
EOF

systemctl enable fail2ban
systemctl restart fail2ban

# Optimize Nginx for t2.micro
log "Configuring Nginx with minimal resource usage..."
cat > /etc/nginx/nginx.conf <<EOF
user www-data;
worker_processes 1;
pid /run/nginx.pid;

events {
    worker_connections 512;
    multi_accept off;
}

http {
    # Basic settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    # Buffer size settings
    client_body_buffer_size 8k;
    client_header_buffer_size 1k;
    client_max_body_size 1m;
    large_client_header_buffers 2 1k;

    # Mime types
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging - only error logs to save disk I/O
    access_log off;
    error_log /var/log/nginx/error.log crit;

    # Gzip Settings
    gzip off;  # Disable gzip to save CPU

    # Include virtual host configs
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# Create minimal server block
cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.html;
    
    server_name _;
    
    # Basic security headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    
    location / {
        try_files \\$uri \\$uri/ =404;
    }
    
    # Deny access to hidden files
    location ~ /\\. {
        deny all;
    }

    # Disable access logs at location level
    access_log off;
}
EOF

# Create a simple index page
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome</title>
</head>
<body>
    <h1>Server is running</h1>
</body>
</html>
EOF

# Set proper permissions
log "Setting proper permissions..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# Enable and restart services
log "Starting services..."
systemctl enable nginx
systemctl restart nginx
systemctl restart fail2ban

# Final check
log "Checking Nginx configuration..."
nginx -t

# Print status and resource usage
log "Installation completed!"
echo "Current resource usage:"
echo "----------------------"
free -m
df -h
top -bn1 | head -n 5

log "Important notes:"
echo "1. Access logs are disabled to reduce disk I/O"
echo "2. Gzip is disabled to save CPU"
echo "3. Worker processes set to 1 for t2.micro"
echo "4. Monitor resource usage with: htop or top"
echo "5. Check error logs at: /var/log/nginx/error.log"
''',
        'docker_setup.sh': '''#!/bin/bash

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
echo \\
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \\
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \\
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
''',
        'setup.sh': '''#!/bin/bash

# Variables from environment
DOMAIN="${DOMAIN}"    # Will be set from Python
EMAIL="${EMAIL}"      # Will be set from Python

echo "Starting setup..."

# Install Certbot and Nginx plugin
echo "Installing Certbot..."
sudo apt install -y certbot python3-certbot-nginx

# Create application directory structure
echo "Creating application directories..."

sudo mkdir -p /var/www/app/scripts
sudo mkdir -p /var/www/app/logs
sudo mkdir -p /tmp/ffmpeg

# Set proper permissions
echo "Setting up permissions..."
sudo chmod 1777 /tmp/ffmpeg
sudo chown -R ubuntu:ubuntu /var/www/app
sudo chmod -R 755 /var/www/app

# Create Nginx configuration for the application
echo "Setting up Nginx configuration..."
sudo tee /etc/nginx/sites-available/nextjs-app << EOL
server {
    listen 80;
    server_name ${DOMAIN};

    # Access and error logs
    access_log /var/log/nginx/nextjs-access.log;
    error_log /var/log/nginx/nextjs-error.log;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Proxy settings
    location / {
        proxy_pass http://localhost:3002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \\$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \\$host;
        proxy_set_header X-Real-IP \\$remote_addr;
        proxy_set_header X-Forwarded-For \\$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \\$scheme;
          proxy_buffering off;
        proxy_read_timeout 86400;
        
        # Large client_max_body_size for file uploads
        client_max_body_size 50M;
    }

    # Health check endpoint
    location /api/health {
        proxy_pass http://localhost:3002;
        proxy_http_version 1.1;
        proxy_set_header Host \\$host;
        proxy_cache_bypass \\$http_upgrade;
    }

    # Static files caching
    location /_next/static {
        proxy_pass http://localhost:3002;
        proxy_cache_bypass \\$http_upgrade;
        proxy_set_header Host \\$host;
        proxy_cache_use_stale error timeout http_500 http_502 http_503 http_504;
        proxy_cache_valid 200 60m;
        expires 1y;
        add_header Cache-Control "public, no-transform";
    }
}
EOL

# Enable the site
sudo ln -sf /etc/nginx/sites-available/nextjs-app /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
echo "Testing Nginx configuration..."
sudo nginx -t && sudo systemctl restart nginx

# Obtain SSL certificate
echo "Obtaining SSL certificate..."
sudo certbot --nginx \\
    --non-interactive \\
    --agree-tos \\
    --email ${EMAIL} \\
    --domains ${DOMAIN} \\
    --redirect

# Set up automatic renewal
echo "Setting up automatic SSL renewal..."
sudo tee /etc/cron.d/certbot-renewal << EOL
0 */12 * * * root certbot renew --quiet --deploy-hook "systemctl reload nginx"
EOL

# Create SSL renewal test script
echo "Creating SSL renewal test script..."
sudo tee /var/www/app/scripts/test-ssl-renewal.sh << EOL
#!/bin/bash
sudo certbot renew --dry-run
EOL
sudo chmod +x /var/www/app/scripts/test-ssl-renewal.sh

echo "Setup completed successfully!"
echo "SSL certificate has been installed for ${DOMAIN}"
echo "Certificate will automatically renew when needed"
echo ""
echo "Next steps:"
echo "1. Verify HTTPS is working: https://${DOMAIN}"
echo "2. Test SSL renewal: ./test-ssl-renewal.sh"
echo "3. Deploy your application using the deploy script"
''',
        'runner-setup.sh': '''#!/bin/bash

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
curl -o actions-runner-linux-x64.tar.gz -L \\
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
'''
    }
    
    try:
        # Write scripts
        for name, content in scripts.items():
            script_path = scripts_dir / name
            script_path.write_text(content)
            script_path.chmod(0o755)  # Make executable
        
        return True
    except Exception as e:
        print(f"Error installing scripts: {e}")
        return False