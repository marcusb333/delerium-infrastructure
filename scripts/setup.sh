#!/bin/bash
# Delirium Infrastructure Setup Script
# File: delerium-infrastructure/scripts/setup.sh
# Version: 1.1.0
#
# This script automates the setup and deployment of Delirium components.
# It handles repository cloning, configuration, and service startup.

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Trap errors and cleanup
trap 'error_handler $? $LINENO' ERR
trap 'cleanup_on_exit' EXIT INT TERM

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
CLIENT_REPO="https://github.com/${GITHUB_USERNAME:-marcusb333}/delerium-client.git"
SERVER_REPO="https://github.com/${GITHUB_USERNAME:-marcusb333}/delerium-server.git"

# Track setup state for cleanup
SETUP_STATE=""
COMPOSE_FILES=""
SERVICES_STARTED=false

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

# Error handler
error_handler() {
    local exit_code=$1
    local line_number=$2
    print_error "Error occurred in script at line $line_number (exit code: $exit_code)"
    print_info "Setup failed. Cleaning up..."
    return $exit_code
}

# Cleanup function
cleanup_on_exit() {
    local exit_code=$?
    if [ $exit_code -ne 0 ] && [ "$SERVICES_STARTED" = true ]; then
        print_warning "Cleaning up started services due to error..."
        if [ -n "$COMPOSE_FILES" ]; then
            cd "$ROOT_DIR" 2>/dev/null || true
            docker compose $COMPOSE_FILES down 2>/dev/null || true
        fi
    fi
}

check_command() {
    if [ -z "${1:-}" ]; then
        print_error "check_command: No command specified"
        return 1
    fi
    
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
        if docker ps &> /dev/null; then
            print_success "Docker found and running: $(docker --version | head -n1)"
        else
            print_error "Docker is installed but not running. Please start Docker."
            all_good=false
        fi
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
    
    SETUP_STATE="environment"
    
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
    
    # Check if template exists
    if [ ! -f "$ROOT_DIR/docker-compose/.env.example" ]; then
        print_warning ".env.example not found, creating basic .env file"
        cat > "$ROOT_DIR/.env" << 'EOF'
# Delirium Environment Configuration
DELETION_TOKEN_PEPPER=change-me-in-production
LOG_LEVEL=INFO
WEB_PORT=8080
GITHUB_USERNAME=marcusb333
EOF
    else
        if ! cp "$ROOT_DIR/docker-compose/.env.example" "$ROOT_DIR/.env"; then
            print_error "Failed to create .env file"
            return 1
        fi
    fi
    
    # Generate secure pepper
    print_info "Generating secure DELETION_TOKEN_PEPPER..."
    if command -v openssl &> /dev/null; then
        if PEPPER=$(openssl rand -hex 32 2>/dev/null); then
            if sed -i.bak "s/DELETION_TOKEN_PEPPER=.*/DELETION_TOKEN_PEPPER=$PEPPER/" "$ROOT_DIR/.env" 2>/dev/null; then
                rm "$ROOT_DIR/.env.bak" 2>/dev/null || true
                print_success "Generated secure pepper"
            else
                print_warning "Failed to update pepper in .env file"
            fi
        else
            print_warning "Failed to generate random pepper"
        fi
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
    local name=${1:-}
    local url=${2:-}
    local dest=${3:-}
    
    if [ -z "$name" ] || [ -z "$url" ] || [ -z "$dest" ]; then
        print_error "clone_repository: Missing required parameters"
        return 1
    fi
    
    print_info "Cloning $name repository..."
    
    # Validate URL format
    if [[ ! "$url" =~ ^https?:// ]] && [[ ! "$url" =~ ^git@ ]]; then
        print_error "Invalid repository URL: $url"
        return 1
    fi
    
    # Create parent directory if needed
    local parent_dir=$(dirname "$dest")
    if [ ! -d "$parent_dir" ]; then
        if ! mkdir -p "$parent_dir" 2>/dev/null; then
            print_error "Failed to create directory: $parent_dir"
            return 1
        fi
    fi
    
    if git clone "$url" "$dest" 2>&1; then
        print_success "$name repository cloned"
        return 0
    else
        print_warning "Failed to clone $name repository from $url"
        print_info "You can clone it manually later: git clone $url $dest"
        return 1
    fi
}

# =============================================================================
# Client Build
# =============================================================================

build_client() {
    print_step "Building client application..."
    
    local client_dir="$ROOT_DIR/../delerium-client"
    
    # Check if client directory exists
    if [ ! -d "$client_dir" ]; then
        print_warning "Client directory not found at $client_dir"
        print_info "Skipping client build (will use pre-built images if available)"
        return 0
    fi
    
    # Check if Node.js is installed
    if ! command -v npm &> /dev/null; then
        print_warning "npm not found, skipping client build"
        print_info "Install Node.js from: https://nodejs.org/"
        print_info "Or the client will be served from the repository directly"
        return 0
    fi
    
    print_info "Node.js found: $(node --version 2>/dev/null || echo 'unknown')"
    
    # Change to client directory
    if ! cd "$client_dir" 2>/dev/null; then
        print_error "Failed to change to client directory: $client_dir"
        return 1
    fi
    
    # Check if package.json exists
    if [ ! -f "package.json" ]; then
        print_warning "package.json not found in client directory"
        cd "$ROOT_DIR" 2>/dev/null || true
        return 0
    fi
    
    # Install dependencies
    print_info "Installing client dependencies..."
    if npm install --no-audit --no-fund 2>&1 | grep -v "^npm WARN" | grep -v "^$" || true; then
        print_success "Dependencies installed"
    else
        print_warning "Some dependencies may have failed to install"
    fi
    
    # Build TypeScript to JavaScript
    print_info "Building TypeScript to JavaScript..."
    if npm run build 2>&1; then
        print_success "Client built successfully"
        
        # Verify js directory was created
        if [ -d "js" ]; then
            print_success "JavaScript files generated in js/ directory"
        else
            print_warning "js/ directory not found after build"
        fi
    else
        print_error "Client build failed"
        cd "$ROOT_DIR" 2>/dev/null || true
        return 1
    fi
    
    # Return to root directory
    cd "$ROOT_DIR" 2>/dev/null || true
    echo ""
    return 0
}

# =============================================================================
# Port Conflict Detection
# =============================================================================

check_port_conflicts() {
    local ports_to_check=("$@")
    local conflicts=()
    local conflict_details=()
    
    print_info "Checking for port conflicts..."
    
    for port in "${ports_to_check[@]}"; do
        # Check if port is in use
        if lsof -i ":$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
            conflicts+=("$port")
            
            # Get details about what's using the port
            local port_info=$(lsof -i ":$port" -sTCP:LISTEN 2>/dev/null | tail -n +2)
            conflict_details+=("Port $port is in use:")
            conflict_details+=("$port_info")
        fi
    done
    
    if [ ${#conflicts[@]} -gt 0 ]; then
        echo ""
        print_warning "Port conflicts detected!"
        echo ""
        
        # Display conflict details
        for detail in "${conflict_details[@]}"; do
            echo -e "${YELLOW}  $detail${NC}"
        done
        echo ""
        
        # Check if conflicts are from Docker containers
        local docker_containers=()
        local all_containers=$(docker ps --format "{{.Names}}" 2>/dev/null || true)
        
        # For each conflicting port, find which containers are using it
        for port in "${conflicts[@]}"; do
            # Get PIDs using the port
            local pids=$(lsof -i ":$port" -sTCP:LISTEN -t 2>/dev/null || true)
            
            for pid in $pids; do
                # Check if this PID belongs to a Docker container
                local container_id=$(docker ps -q --filter "pid=$pid" 2>/dev/null || true)
                if [ -n "$container_id" ]; then
                    local container_name=$(docker ps --format "{{.Names}}" --filter "id=$container_id" 2>/dev/null || true)
                    if [ -n "$container_name" ] && [[ ! " ${docker_containers[@]} " =~ " ${container_name} " ]]; then
                        docker_containers+=("$container_name")
                    fi
                fi
            done
        done
        
        # Also check by examining container port mappings
        if [ ${#docker_containers[@]} -eq 0 ]; then
            for port in "${conflicts[@]}"; do
                local containers_on_port=$(docker ps --format "{{.Names}}" --filter "publish=$port" 2>/dev/null || true)
                if [ -n "$containers_on_port" ]; then
                    while IFS= read -r container; do
                        if [[ ! " ${docker_containers[@]} " =~ " ${container} " ]]; then
                            docker_containers+=("$container")
                        fi
                    done <<< "$containers_on_port"
                fi
            done
        fi
        
        if [ ${#docker_containers[@]} -gt 0 ]; then
            print_info "The following Docker containers are using these ports:"
            for container in "${docker_containers[@]}"; do
                local container_ports=$(docker port "$container" 2>/dev/null | grep -E "$(IFS="|"; echo "${conflicts[*]}")" || echo "unknown ports")
                echo -e "  ${BLUE}- $container${NC} (${container_ports})"
            done
            echo ""
            
            read -p "$(echo -e ${YELLOW}Would you like to stop these containers? [Y/n]:${NC} )" -r
            echo
            
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                print_info "Stopping conflicting containers..."
                for container in "${docker_containers[@]}"; do
                    if docker stop "$container" 2>/dev/null; then
                        print_success "Stopped container: $container"
                    else
                        print_warning "Failed to stop container: $container"
                    fi
                done
                
                # Wait a moment for ports to be released
                sleep 2
                
                # Verify ports are now free
                local still_in_use=false
                for port in "${conflicts[@]}"; do
                    if lsof -i ":$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
                        still_in_use=true
                        print_warning "Port $port is still in use"
                    fi
                done
                
                if [ "$still_in_use" = true ]; then
                    print_error "Some ports are still in use. Please free them manually and try again."
                    return 1
                fi
                
                print_success "All port conflicts resolved"
            else
                print_error "Cannot proceed with port conflicts. Please stop the conflicting services."
                print_info "You can stop them manually with: docker stop <container-name>"
                return 1
            fi
        else
            print_warning "Ports are in use by non-Docker processes"
            print_info "Please stop the processes using these ports and try again:"
            for port in "${conflicts[@]}"; do
                echo -e "  ${BLUE}Port $port${NC}"
            done
            echo ""
            print_info "You can find and kill processes with:"
            echo -e "  ${BLUE}lsof -i :PORT${NC}  (to find the process)"
            echo -e "  ${BLUE}kill -9 PID${NC}    (to stop it)"
            echo ""
            
            read -p "$(echo -e ${YELLOW}Have you freed the ports? Continue anyway? [y/N]:${NC} )" -r
            echo
            
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_error "Setup aborted due to port conflicts"
                return 1
            fi
        fi
    else
        print_success "No port conflicts detected"
    fi
    
    echo ""
    return 0
}

# =============================================================================
# Docker Setup
# =============================================================================

setup_docker() {
    print_step "Setting up Docker services..."
    
    SETUP_STATE="docker"
    
    # Create necessary directories
    print_info "Creating data and log directories..."
    local dirs=("$ROOT_DIR/data/server" "$ROOT_DIR/logs/nginx" "$ROOT_DIR/logs/server")
    for dir in "${dirs[@]}"; do
        if ! mkdir -p "$dir" 2>/dev/null; then
            print_error "Failed to create directory: $dir"
            return 1
        fi
    done
    print_success "Created data and log directories"
    
    # Determine which compose files to use
    COMPOSE_FILES="-f $ROOT_DIR/docker-compose/docker-compose.yml"
    
    # Verify base compose file exists
    if [ ! -f "$ROOT_DIR/docker-compose/docker-compose.yml" ]; then
        print_error "Base docker-compose.yml not found at $ROOT_DIR/docker-compose/"
        return 1
    fi
    
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
    
    local ports_to_check=()
    
    case $choice in
        1)
            print_info "Using development configuration"
            if [ -f "$ROOT_DIR/docker-compose/docker-compose.dev.yml" ]; then
                COMPOSE_FILES="$COMPOSE_FILES -f $ROOT_DIR/docker-compose/docker-compose.dev.yml"
            else
                print_warning "docker-compose.dev.yml not found, using base configuration"
            fi
            # Dev mode uses ports 8080 (server) and 8081 (web)
            ports_to_check=(8080 8081)
            ;;
        2)
            print_info "Using production configuration with SSL"
            if [ ! -f "$ROOT_DIR/docker-compose/docker-compose.prod.yml" ]; then
                print_error "docker-compose.prod.yml not found"
                return 1
            fi
            COMPOSE_FILES="$COMPOSE_FILES -f $ROOT_DIR/docker-compose/docker-compose.prod.yml"
            
            # Check SSL certificates
            if [ ! -f "$ROOT_DIR/ssl/certs/cert.pem" ]; then
                print_warning "SSL certificates not found"
                print_info "Run ./scripts/setup-ssl.sh to generate certificates"
                read -p "$(echo -e ${YELLOW}Continue anyway? [y/N]:${NC} )" -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    print_error "Setup aborted. Run SSL setup first."
                    return 1
                fi
            fi
            # Production with SSL uses ports 80 and 443
            ports_to_check=(80 443)
            ;;
        3)
            print_info "Using production configuration (HTTP only)"
            if ! sed -i.bak 's/WEB_PORT=.*/WEB_PORT=80/' "$ROOT_DIR/.env" 2>/dev/null; then
                print_warning "Failed to update WEB_PORT in .env"
            fi
            rm "$ROOT_DIR/.env.bak" 2>/dev/null || true
            # Production HTTP only uses port 80
            ports_to_check=(80)
            ;;
        *)
            print_info "Invalid choice, using development configuration"
            if [ -f "$ROOT_DIR/docker-compose/docker-compose.dev.yml" ]; then
                COMPOSE_FILES="$COMPOSE_FILES -f $ROOT_DIR/docker-compose/docker-compose.dev.yml"
            fi
            # Default to dev ports
            ports_to_check=(8080 8081)
            ;;
    esac
    
    # Check for port conflicts before starting services
    echo ""
    if ! check_port_conflicts "${ports_to_check[@]}"; then
        return 1
    fi
    
    # Pull/build images
    print_info "Pulling/building Docker images (this may take a few minutes)..."
    
    if ! cd "$ROOT_DIR" 2>/dev/null; then
        print_error "Failed to change to directory: $ROOT_DIR"
        return 1
    fi
    
    # Try to pull images (non-fatal if it fails)
    if docker compose $COMPOSE_FILES pull 2>&1 | grep -v "WARNING" || true; then
        print_success "Images pulled/checked"
    else
        print_warning "Could not pull some images, will try to build locally"
    fi
    
    # Start services
    print_info "Starting services..."
    if docker compose $COMPOSE_FILES up -d --build 2>&1; then
        SERVICES_STARTED=true
        print_success "Services started"
    else
        print_error "Failed to start services"
        print_info "Check Docker logs for more details"
        return 1
    fi
    
    echo ""
}

# =============================================================================
# Health Check
# =============================================================================

wait_for_services() {
    print_step "Waiting for services to be healthy..."
    
    SETUP_STATE="health_check"
    
    local max_attempts=30
    local attempt=0
    local port=8080
    
    # Check if using production port
    if grep -q "WEB_PORT=80" "$ROOT_DIR/.env" 2>/dev/null; then
        port=80
    fi
    
    # Verify curl is available
    if ! command -v curl &> /dev/null; then
        print_warning "curl not available, skipping health check"
        return 0
    fi
    
    while [ $attempt -lt $max_attempts ]; do
        # Try multiple health check endpoints
        if curl -sf "http://localhost:$port/api/health" > /dev/null 2>&1 || \
           curl -sf "http://localhost:$port/api/pow" > /dev/null 2>&1 || \
           curl -sf "http://localhost:$port/" > /dev/null 2>&1; then
            echo ""
            print_success "Services are healthy!"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -ne "\r${BLUE}Waiting for services... ($attempt/$max_attempts)${NC}"
        sleep 2
    done
    
    echo ""
    print_error "Services failed to become healthy within timeout"
    print_info "This might be normal if services are still starting up."
    print_info "Check logs with: cd $ROOT_DIR && docker compose $COMPOSE_FILES logs"
    
    # Show container status
    if docker ps --filter "name=delirium" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null; then
        echo ""
    fi
    
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
    # Validate we're in the right directory
    if [ ! -f "$ROOT_DIR/docker-compose/docker-compose.yml" ]; then
        print_error "Cannot find docker-compose.yml. Are you in the right directory?"
        print_info "Expected location: $ROOT_DIR/docker-compose/docker-compose.yml"
        exit 1
    fi
    
    print_header
    
    # Run setup steps with error handling
    if ! check_prerequisites; then
        print_error "Prerequisites check failed"
        exit 1
    fi
    
    if ! setup_environment; then
        print_error "Environment setup failed"
        exit 1
    fi
    
    # Repository check is non-fatal
    check_repositories || print_warning "Repository check had issues, continuing..."
    
    # Build client (non-fatal, will skip if not available)
    build_client || print_warning "Client build had issues, continuing with unbuild source..."
    
    if ! setup_docker; then
        print_error "Docker setup failed"
        exit 1
    fi
    
    # Health check is non-fatal but we warn
    if wait_for_services; then
        print_summary
        exit 0
    else
        print_warning "Setup completed but services health check timed out"
        print_info "Services may still be starting. Check logs for details."
        print_summary
        exit 0
    fi
}

# Run main function
main "$@"
