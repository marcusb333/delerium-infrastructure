#!/bin/bash
set -e

# VPS Deployment Script for Delirium
# This script sets up Delirium on a fresh VPS with SSL support
# Usage: ./scripts/vps-deploy.sh YOUR_DOMAIN YOUR_EMAIL GIT_USERNAME

DOMAIN=${1:-}
EMAIL=${2:-}
GIT_USERNAME=${3:-}
REPO_URL="https://github.com/$GIT_USERNAME/delerium-paste.git"
INSTALL_DIR="$HOME/delirium"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo_error "Please do not run this script as root (use regular user with sudo access)"
    exit 1
fi

# Validate arguments
if [ -z "$DOMAIN" ]; then
    echo_error "Domain name is required"
    echo "Usage: $0 YOUR_DOMAIN YOUR_EMAIL"
    echo "Example: $0 example.com admin@example.com"
    exit 1
fi

if [ -z "$EMAIL" ]; then
    echo_error "Email address is required for Let's Encrypt"
    echo "Usage: $0 YOUR_DOMAIN YOUR_EMAIL"
    echo "Example: $0 example.com admin@example.com"
    exit 1
fi

if [ -z "$GIT_USERNAME" ]; then
    echo_error "Username is required for git clone"
    echo "Usage: $0 YOUR_DOMAIN YOUR_EMAIL GIT_USERNAME"
    echo "Example: $0 example.com admin@example.com GIT_USERNAME"
    exit 1
fi

echo_info "Starting Delirium deployment for domain: $DOMAIN"

# Step 1: Update system
echo_info "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Step 2: Install Docker
if ! command -v docker &> /dev/null; then
    echo_info "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    echo_warn "Docker installed. You may need to log out and back in for group changes to take effect."
else
    echo_info "Docker already installed"
fi

# Step 3: Install Docker Compose (if not present)
if ! docker compose version &> /dev/null; then
    echo_info "Installing Docker Compose..."
    sudo apt install docker-compose-plugin -y
fi

# Step 4: Install Certbot
if ! command -v certbot &> /dev/null; then
    echo_info "Installing Certbot..."
    sudo apt install certbot -y
else
    echo_info "Certbot already installed"
fi

# Step 5: Install Node.js (needed for building client)
if ! command -v node &> /dev/null; then
    echo_info "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
else
    echo_info "Node.js already installed (version $(node -v))"
fi

# Step 6: Configure firewall
echo_info "Configuring firewall..."
if command -v ufw &> /dev/null; then
    sudo ufw --force enable
    sudo ufw allow 22/tcp   # SSH
    sudo ufw allow 80/tcp   # HTTP
    sudo ufw allow 443/tcp  # HTTPS
    sudo ufw status
else
    echo_warn "UFW not found, skipping firewall configuration"
fi

# Step 7: Clone or update repository
if [ -d "$INSTALL_DIR" ]; then
    echo_info "Repository already exists, pulling latest changes..."
    cd "$INSTALL_DIR"
    git pull origin main || git pull origin master || true
else
    echo_info "Cloning repository..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Step 8: Create .env file
echo_info "Creating .env file with secure pepper..."
PEPPER=$(openssl rand -hex 32)
cat > .env << EOF
# Delirium Production Configuration
DELETION_TOKEN_PEPPER=$PEPPER
EOF
echo_info ".env file created with secure random pepper"

# Step 9: Stop any running containers
echo_info "Stopping any existing containers..."
docker compose -f docker-compose.prod.yml down 2>/dev/null || true

# Step 10: Get SSL certificate
echo_info "Obtaining SSL certificate from Let's Encrypt..."
if [ ! -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    sudo certbot certonly --standalone \
        -d "$DOMAIN" \
        --non-interactive \
        --agree-tos \
        --email "$EMAIL" \
        || {
            echo_error "Failed to obtain SSL certificate"
            echo_error "Make sure:"
            echo_error "  1. DNS is pointing to this server"
            echo_error "  2. Port 80 is accessible from the internet"
            echo_error "  3. No other service is using port 80"
            exit 1
        }
    echo_info "SSL certificate obtained successfully"
else
    echo_info "SSL certificate already exists for $DOMAIN"
fi

# Step 11: Copy SSL certificates
echo_info "Copying SSL certificates to project..."
mkdir -p ssl
sudo cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ssl/
sudo cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ssl/
sudo chown $(id -un):$(id -gn) ssl/*.pem
chmod 644 ssl/fullchain.pem
chmod 600 ssl/privkey.pem

# Step 12: Configure nginx with domain
echo_info "Configuring nginx for domain $DOMAIN..."
cp reverse-proxy/nginx-ssl.conf reverse-proxy/nginx.conf
sed -i "s/YOUR_DOMAIN_HERE/$DOMAIN/g" reverse-proxy/nginx.conf

# Step 13: Build client
echo_info "Building frontend client..."
cd client
npm ci
npm run build
cd ..

# Step 14: Build and start containers
echo_info "Building and starting Docker containers..."
docker compose -f docker-compose.prod.yml build --parallel
docker compose -f docker-compose.prod.yml up -d

# Step 15: Wait for services to start
echo_info "Waiting for services to start..."
sleep 15

# Step 16: Check service health
echo_info "Checking service health..."
if docker compose -f docker-compose.prod.yml ps | grep -q "Up"; then
    echo_info "✅ Services are running!"
else
    echo_error "Some services failed to start. Check logs with:"
    echo_error "  docker compose -f docker-compose.prod.yml logs"
    exit 1
fi

# Step 17: Set up certificate auto-renewal
echo_info "Setting up automatic SSL certificate renewal..."
CRON_JOB="0 3 * * * certbot renew --quiet --post-hook 'cp /etc/letsencrypt/live/$DOMAIN/*.pem $INSTALL_DIR/ssl/ && chown \$(id -un):\$(id -gn) $INSTALL_DIR/ssl/*.pem && cd $INSTALL_DIR && docker compose -f docker-compose.prod.yml restart web' >> /var/log/certbot-renew.log 2>&1"

# Remove old cron job if exists
(crontab -l 2>/dev/null | grep -v "certbot renew") | crontab - 2>/dev/null || true

# Add new cron job
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo_info "Certificate auto-renewal configured (daily at 3 AM)"

# Step 18: Display deployment info
echo ""
echo_info "================================================"
echo_info "🎉 Deployment Complete!"
echo_info "================================================"
echo ""
echo_info "Your Delirium instance is now running at:"
echo_info "  🔒 https://$DOMAIN"
echo ""
echo_info "Useful commands:"
echo_info "  View logs:      cd $INSTALL_DIR && docker compose -f docker-compose.prod.yml logs -f"
echo_info "  Restart:        cd $INSTALL_DIR && docker compose -f docker-compose.prod.yml restart"
echo_info "  Stop:           cd $INSTALL_DIR && docker compose -f docker-compose.prod.yml down"
echo_info "  Status:         cd $INSTALL_DIR && docker compose -f docker-compose.prod.yml ps"
echo ""
echo_info "SSL certificate will auto-renew daily at 3 AM"
echo ""
echo_info "Next steps:"
echo_info "  1. Visit https://$DOMAIN to verify it's working"
echo_info "  2. Check logs to ensure no errors"
echo_info "  3. Set up backups (see docs/DEPLOYMENT.md)"
echo ""
echo_info "================================================"