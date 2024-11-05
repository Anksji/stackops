#!/bin/bash

# Exit on any error
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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
apt install -y nginx \
    ufw \
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
        try_files \$uri \$uri/ =404;
    }
    
    # Deny access to hidden files
    location ~ /\. {
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
