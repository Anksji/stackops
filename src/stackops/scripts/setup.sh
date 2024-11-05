#!/bin/bash

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
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
          proxy_buffering off;
        proxy_read_timeout 86400;
        
        # Large client_max_body_size for file uploads
        client_max_body_size 50M;
    }

    # Health check endpoint
    location /api/health {
        proxy_pass http://localhost:3002;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    # Static files caching
    location /_next/static {
        proxy_pass http://localhost:3002;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header Host \$host;
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
sudo certbot --nginx \
    --non-interactive \
    --agree-tos \
    --email ${EMAIL} \
    --domains ${DOMAIN} \
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
