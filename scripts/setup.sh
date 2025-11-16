#!/bin/bash
# Delirium Infrastructure Setup Script
# File: delerium-infrastructure/scripts/setup.sh
# Version: 1.0.0
#
# This script automates the setup and deployment of Delirium components.
# It handles repository cloning, configuration, and service startup.

set -e  # Exit on any error

# =============================================================================
# Colors and Formatting
# =============================================================================
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# =============================================================================
# Configuration
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CLIENT_REPO="https://github.com/${GITHUB_USERNAME:-delirium}/delerium-client.git"
SERVER_REPO="https://github.com/${GITHUB_USERNAME:-delirium}/delerium-server.git"

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo -e "${BLUE}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║      🔐 Delirium Setup - Zero-Knowledge Paste System      ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}${BOLD}▸ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 is not installed. Please install it first."
        return 1
    fi
    return 0
}

# =============================================================================
# Prerequisite Checks
# =============================================================================

check_prerequisites() {
    print_step "Checking prerequisites..."
    
    local all_good=true
    
    # Check Docker
    if check_command docker; then
        print_success "Docker found: $(docker --version | head -n1)"
    else
        all_good=false
    fi
    
    # Check Docker Compose
    if docker compose version &> /dev/null; then
        print_success "Docker Compose found: $(docker compose version --short)"
    else
        print_error "Docker Compose (v2) not found"
        print_info "Install from: https://docs.docker.com/compose/install/"
        all_good=false
    fi
    
    # Check curl
    if check_command curl; then
        print_success "curl found"
    else
        all_good=false
    fi
    
    # Check git (for cloning repos)
    if check_command git; then
        print_success "git found"
    else
        all_good=false
    fi
    
    if [ "$all_good" = false ]; then
        print_error "Some prerequisites are missing. Please install them and try again."
        exit 1
    fi
    
    echo ""
}

# =============================================================================
# Environment Configuration
# =============================================================================

setup_environment() {
    print_step "Setting up environment configuration..."
    
    if [ -f "$ROOT_DIR/.env" ]; then
        print_info "Found existing .env file"
        read -p "$(echo -e ${YELLOW}Do you want to regenerate it? [y/N]:${NC} )" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Using existing .env file"
            return 0
        fi
    fi
    
    print_info "Creating .env file from template..."
    cp "$ROOT_DIR/docker-compose/.env.example" "$ROOT_DIR/.env"
    
    # Generate secure pepper
    print_info "Generating secure DELETION_TOKEN_PEPPER..."
    if command -v openssl &> /dev/null; then
        PEPPER=$(openssl rand -hex 32)
        sed -i.bak "s/DELETION_TOKEN_PEPPER=.*/DELETION_TOKEN_PEPPER=$PEPPER/" "$ROOT_DIR/.env"
        rm "$ROOT_DIR/.env.bak" 2>/dev/null || true
        print_success "Generated secure pepper"
    else
        print_warning "openssl not found, using default pepper (CHANGE IN PRODUCTION!)"
    fi
    
    # Set GitHub username if available
    if [ -n "$GITHUB_USERNAME" ]; then
        sed -i.bak "s/GITHUB_USERNAME=.*/GITHUB_USERNAME=$GITHUB_USERNAME/" "$ROOT_DIR/.env"
        rm "$ROOT_DIR/.env.bak" 2>/dev/null || true
    fi
    
    print_success "Environment configuration created"
    echo ""
}

# =============================================================================
# Repository Management
# =============================================================================

check_repositories() {
    print_step "Checking repository structure..."
    
    local need_client=false
    local need_server=false
    
    # Check for client
    if [ ! -d "$ROOT_DIR/../delerium-client" ]; then
        print_warning "Client repository not found"
        need_client=true
    else
        print_success "Client repository found"
    fi
    
    # Check for server
    if [ ! -d "$ROOT_DIR/../delerium-server" ]; then
        print_warning "Server repository not found"
        need_server=true
    else
        print_success "Server repository found"
    fi
    
    # If any repos missing, ask to clone
    if [ "$need_client" = true ] || [ "$need_server" = true ]; then
        echo ""
        print_info "Missing repositories can be cloned automatically for local development."
        print_info "For production deployment, pre-built images will be used instead."
        echo ""
        
        read -p "$(echo -e ${YELLOW}Clone missing repositories for local development? [Y/n]:${NC} )" -n 1 -r
        echo
        
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            if [ "$need_client" = true ]; then
                clone_repository "client" "$CLIENT_REPO" "$ROOT_DIR/../delerium-client"
            fi
            
            if [ "$need_server" = true ]; then
                clone_repository "server" "$SERVER_REPO" "$ROOT_DIR/../delerium-server"
            fi
        else
            print_info "Skipping repository clones. Pre-built images will be used."
        fi
    fi
    
    echo ""
}

clone_repository() {
    local name=$1
    local url=$2
    local dest=$3
    
    print_info "Cloning $name repository..."
    
    if git clone "$url" "$dest" 2>/dev/null; then
        print_success "$name repository cloned"
    else
        print_warning "Failed to clone $name repository from $url"
        print_info "You can clone it manually later: git clone $url $dest"
    fi
}

# =============================================================================
# Docker Setup
# =============================================================================

setup_docker() {
    print_step "Setting up Docker services..."
    
    # Create necessary directories
    mkdir -p "$ROOT_DIR/data/server"
    mkdir -p "$ROOT_DIR/logs/nginx"
    mkdir -p "$ROOT_DIR/logs/server"
    print_success "Created data and log directories"
    
    # Determine which compose files to use
    local compose_files="-f $ROOT_DIR/docker-compose/docker-compose.yml"
    
    # Ask for deployment type
    echo ""
    print_info "Select deployment type:"
    echo "  1) Development (local, port 8080)"
    echo "  2) Production (HTTPS, ports 80/443)"
    echo "  3) Production without SSL (HTTP, port 80)"
    echo ""
    
    read -p "$(echo -e ${YELLOW}Enter choice [1-3]:${NC} )" -n 1 -r choice
    echo
    echo ""
    
    case $choice in
        1)
            print_info "Using development configuration"
            compose_files="$compose_files -f $ROOT_DIR/docker-compose/docker-compose.dev.yml"
            ;;
        2)
            print_info "Using production configuration with SSL"
            compose_files="$compose_files -f $ROOT_DIR/docker-compose/docker-compose.prod.yml"
            
            # Check SSL certificates
            if [ ! -f "$ROOT_DIR/ssl/certs/cert.pem" ]; then
                print_warning "SSL certificates not found"
                print_info "Run ./scripts/setup-ssl.sh to generate certificates"
                read -p "$(echo -e ${YELLOW}Continue anyway? [y/N]:${NC} )" -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    print_error "Setup aborted. Run SSL setup first."
                    exit 1
                fi
            fi
            ;;
        3)
            print_info "Using production configuration (HTTP only)"
            sed -i.bak 's/WEB_PORT=.*/WEB_PORT=80/' "$ROOT_DIR/.env"
            rm "$ROOT_DIR/.env.bak" 2>/dev/null || true
            ;;
        *)
            print_info "Invalid choice, using development configuration"
            compose_files="$compose_files -f $ROOT_DIR/docker-compose/docker-compose.dev.yml"
            ;;
    esac
    
    # Pull/build images
    print_info "Pulling/building Docker images (this may take a few minutes)..."
    cd "$ROOT_DIR"
    
    if docker compose $compose_files pull 2>/dev/null || true; then
        print_success "Images pulled"
    fi
    
    # Start services
    print_info "Starting services..."
    if docker compose $compose_files up -d --build; then
        print_success "Services started"
    else
        print_error "Failed to start services"
        exit 1
    fi
    
    echo ""
}

# =============================================================================
# Health Check
# =============================================================================

wait_for_services() {
    print_step "Waiting for services to be healthy..."
    
    local max_attempts=30
    local attempt=0
    local port=8080
    
    # Check if using production port
    if grep -q "WEB_PORT=80" "$ROOT_DIR/.env" 2>/dev/null; then
        port=80
    fi
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -sf "http://localhost:$port/api/health" > /dev/null 2>&1; then
            print_success "Services are healthy!"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -ne "\r${BLUE}Waiting for services... ($attempt/$max_attempts)${NC}"
        sleep 2
    done
    
    echo ""
    print_error "Services failed to become healthy"
    print_info "Check logs with: docker compose -f docker-compose/docker-compose.yml logs"
    return 1
}

# =============================================================================
# Final Steps
# =============================================================================

print_summary() {
    local port=8080
    if grep -q "WEB_PORT=80" "$ROOT_DIR/.env" 2>/dev/null; then
        port=80
    fi
    
    echo ""
    echo -e "${GREEN}${BOLD}╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║                  ✓ Setup Complete!                        ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}🌐 Access Delirium:${NC}"
    echo -e "   ${BLUE}http://localhost:$port${NC}"
    echo ""
    echo -e "${BOLD}📊 Useful Commands:${NC}"
    echo -e "   ${BLUE}docker compose -f docker-compose/docker-compose.yml logs -f${NC}  - View logs"
    echo -e "   ${BLUE}docker compose -f docker-compose/docker-compose.yml ps${NC}       - Service status"
    echo -e "   ${BLUE}./scripts/health-check.sh${NC}                                    - Health check"
    echo -e "   ${BLUE}./scripts/backup.sh${NC}                                          - Backup data"
    echo -e "   ${BLUE}docker compose -f docker-compose/docker-compose.yml down${NC}     - Stop services"
    echo ""
    echo -e "${BOLD}📚 Documentation:${NC}"
    echo -e "   ${BLUE}https://github.com/${GITHUB_USERNAME:-delirium}/delerium${NC}"
    echo ""
    
    # Open browser (if not in headless environment)
    if [ -z "$HEADLESS" ] && [ -z "$NO_BROWSER" ]; then
        if command -v open &> /dev/null; then
            open "http://localhost:$port" 2>/dev/null || true
        elif command -v xdg-open &> /dev/null; then
            xdg-open "http://localhost:$port" 2>/dev/null || true
        fi
    fi
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    print_header
    check_prerequisites
    setup_environment
    check_repositories
    setup_docker
    
    if wait_for_services; then
        print_summary
        exit 0
    else
        print_error "Setup completed but services are not healthy"
        print_info "Check logs and troubleshooting guide"
        exit 1
    fi
}

# Run main function
main "$@"
