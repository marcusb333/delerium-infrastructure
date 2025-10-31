# Delirium - Zero-Knowledge Paste System
# Makefile for local development and deployment

.PHONY: help setup start stop restart logs dev clean test build-client health-check quick-start

# Default target
help:
	@echo "Delirium - Zero-Knowledge Paste System"
	@echo ""
	@echo "Available commands:"
	@echo "  make setup         - 🔐 Interactive setup wizard (configure secrets)"
	@echo "  make start         - Start everything (build client + docker compose up)"
	@echo "  make stop          - Stop all containers"
	@echo "  make restart       - Restart services"
	@echo "  make logs          - Follow logs from all services"
	@echo "  make dev           - Development mode with hot-reload"
	@echo "  make clean         - Clean up everything (volumes, containers, etc.)"
	@echo "  make test          - Run all tests"
	@echo "  make build-client  - Build TypeScript only"
	@echo "  make health-check  - Verify services are running"
	@echo "  make quick-start   - First-time setup and start"
	@echo "  make quick-start-headless - First-time setup for headless environments"
	@echo "  make security-setup - Enhance security for headless environments"
	@echo "  make start-secure  - Start with security enhancements"
	@echo "  make security-check - Run security verification"
	@echo "  make monitor       - Start service monitoring"
	@echo "  make backup        - Create data backup"
	@echo ""

# Interactive setup wizard
setup:
	@echo "🔐 Starting interactive setup wizard..."
	@chmod +x scripts/setup.sh
	./scripts/setup.sh

# Start everything
start: build-client
	@echo "🚀 Starting Delirium stack..."
	docker compose up -d
	@echo "✅ Services started! Access at http://localhost:8080"
	@echo "📊 Check status: make logs"

# Stop all containers
stop:
	@echo "🛑 Stopping Delirium stack..."
	docker compose down
	@echo "✅ Services stopped"

# Restart services
restart: stop start

# Follow logs
logs:
	@echo "📋 Following logs (Ctrl+C to exit)..."
	docker compose logs -f

# Development mode with hot-reload
dev:
	@echo "🔧 Starting development mode..."
	@echo "📝 Backend will run in Docker, frontend will watch for changes"
	@echo "🌐 Access at http://localhost:8080"
	@echo ""
	@chmod +x scripts/dev.sh
	./scripts/dev.sh

# Clean up everything
clean:
	@echo "🧹 Cleaning up Delirium stack..."
	docker compose down -v
	docker system prune -f
	@echo "✅ Cleanup complete"

# Run all tests
test:
	@echo "🧪 Running test suite..."
	cd client && npm test
	@echo "✅ Tests completed"

# Build TypeScript client
build-client:
	@echo "📦 Building TypeScript client..."
	cd client && npm run build
	@echo "✅ Client built"

# Health check
health-check:
	@echo "🏥 Checking service health..."
	@chmod +x scripts/health-check.sh
	./scripts/health-check.sh

# Quick start for first-time users
quick-start:
	@echo "🚀 Quick start setup..."
	@chmod +x scripts/quick-start.sh
	./scripts/quick-start.sh

# Quick start for headless environments
quick-start-headless:
	@echo "🚀 Quick start setup (headless mode)..."
	@chmod +x scripts/quick-start.sh
	HEADLESS=1 ./scripts/quick-start.sh

# Security setup for headless environments
security-setup:
	@echo "🔒 Setting up security enhancements..."
	@chmod +x scripts/security-setup.sh
	./scripts/security-setup.sh

# Start with security enhancements
start-secure: security-setup
	@echo "🛡️  Starting with security enhancements..."
	docker compose -f docker-compose.yml -f docker-compose.secure.yml up -d

# Security check
security-check:
	@echo "🔍 Running security check..."
	@chmod +x scripts/security-check.sh
	./scripts/security-check.sh

# Monitor services
monitor:
	@echo "📊 Starting monitoring..."
	@chmod +x scripts/monitor.sh
	./scripts/monitor.sh

# Create backup
backup:
	@echo "💾 Creating backup..."
	@chmod +x scripts/backup.sh
	./scripts/backup.sh
