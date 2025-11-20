# Changelog

All notable changes to the Delirium Infrastructure project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1-alpha] - 2025-11-20

### Server Release
- **Docker Image Release**: v1.0.1-alpha release of delerium-server Docker image
- Multi-architecture support (AMD64, ARM64, ARMv7)
- JDK 21 runtime
- Automated build and publish workflow enabled

### Notes
- This is an alpha release for the server component
- Images available on both Docker Hub and GitHub Container Registry
- Supports all architectures: linux/amd64, linux/arm64, linux/arm/v7

## [2.0.0] - 2025-11-18

### Added
- **Multi-Architecture Support**: Full support for AMD64, ARM64, and ARMv7 architectures
  - Updated Dockerfile with multi-platform build arguments
  - Created automated multi-arch build script (`docker-build.sh`)
  - Added GitHub Actions workflow for automated multi-arch builds
  - New comprehensive documentation in `MULTI_ARCH.md`
- Platform specifications in docker-compose files for better architecture control
- Health checks in Dockerfile for better container monitoring
- Non-root user support in Dockerfile for enhanced security
- OCI image labels for better metadata

### Changed
- **BREAKING**: Upgraded from JDK 17 to JDK 21 in all Docker images
  - Builder stage: `gradle:8.11.1-jdk21` (was `gradle:8.10.2-jdk17`)
  - Runtime stage: `eclipse-temurin:21-jre-jammy` (unchanged, but now consistent)
- Updated all GitHub Actions to latest versions:
  - `actions/checkout@v4.2.2` (was `v4`)
  - `actions/upload-artifact@v4.5.0` (was `v4`)
  - `actions/setup-node@v4.1.0` (new)
  - `docker/setup-qemu-action@v3.2.0` (was `v3`)
  - `docker/setup-buildx-action@v3.7.1` (was `v3`)
  - `docker/login-action@v3.3.0` (was `v3`)
  - `docker/build-push-action@v6.9.0` (was `v5`)
- Updated base images in docker-compose:
  - Nginx: `1.27.3-alpine` (was `1.27-alpine`)
  - Node.js: `22-alpine` (was `20-alpine`)
- Enhanced docker-build.sh with multi-architecture capabilities:
  - Support for custom platform selection
  - Automatic buildx builder creation
  - Better error handling and validation
  - Comprehensive build summaries
- Improved Dockerfile with security best practices:
  - Non-root user execution
  - Proper file permissions
  - Health check integration

### Fixed
- Docker Compose platform compatibility issues across different architectures
- Build performance on non-native architectures using QEMU emulation

### Documentation
- Added comprehensive `MULTI_ARCH.md` guide covering:
  - Supported architectures and devices
  - Building and deploying multi-arch images
  - GitHub Actions CI/CD setup
  - Platform-specific deployment
  - Troubleshooting guide
  - Performance considerations
- Updated `README.md` with:
  - Multi-architecture support information
  - Updated prerequisites (Docker 24.0+, QEMU)
  - Links to new documentation

### Infrastructure
- GitHub Actions workflow (`docker-multiarch.yml`) for automated builds:
  - Builds for AMD64, ARM64, and ARMv7
  - Pushes to both Docker Hub and GitHub Container Registry
  - Tests images on different architectures
  - Generates comprehensive build summaries
  - Supports manual triggers with custom parameters
- Updated integration test workflow with Node.js 22 support

### Security
- Non-root user execution in Docker containers
- Proper file ownership and permissions
- Enhanced OCI image metadata for better traceability

## [1.0.0] - 2024-11-17

### Added
- Initial release of Delirium Infrastructure
- Docker Compose configurations for development, production, and secure deployments
- Nginx reverse proxy configuration
- Automated setup scripts
- Health monitoring and backup scripts
- CI/CD integration test workflows
- Comprehensive documentation

---

## Migration Guide: 1.x to 2.0

### Breaking Changes

#### JDK Version Upgrade
The server now requires **JDK 21** instead of JDK 17. If you're building locally:

```bash
# Update your local JDK (if building outside Docker)
# macOS with Homebrew:
brew install openjdk@21

# Ubuntu/Debian:
sudo apt install openjdk-21-jdk

# Or just use Docker (recommended)
docker compose build
```

#### Docker Requirements
- Minimum Docker version is now **24.0+** (for better Buildx support)
- Docker Compose v2+ is required

### New Features

#### Multi-Architecture Support
You can now deploy on ARM devices (Raspberry Pi, Apple Silicon, AWS Graviton):

```bash
# Images automatically work on any architecture
docker pull marcusb333/delerium-server:latest

# Or force a specific architecture
docker pull --platform linux/arm64 marcusb333/delerium-server:latest
```

#### Updated Build Process
```bash
# Old way (still works for local builds)
docker compose build

# New way (multi-arch builds)
cd delerium-server
./docker-build.sh latest dockerhub your-username "linux/amd64,linux/arm64" push
```

### Recommended Actions

1. **Update Docker**: Ensure you're running Docker 24.0+
   ```bash
   docker --version
   ```

2. **Pull Latest Images**: Get the new multi-arch images
   ```bash
   docker compose pull
   ```

3. **Rebuild Local Images**: If building from source
   ```bash
   docker compose build --no-cache
   ```

4. **Review Documentation**: Check `MULTI_ARCH.md` for new capabilities

### No Action Required For

- Existing deployments using Docker Compose (will auto-update on next pull)
- Environment variables and configuration
- Data persistence and volumes
- Network configuration
- SSL/TLS setup

---

**For detailed information about multi-architecture support, see [MULTI_ARCH.md](MULTI_ARCH.md)**
