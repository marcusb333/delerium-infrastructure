# Delerium Deployment Status

## Deployment Information
- **Date**: 2025-11-18
- **Domain**: your-domain.com
- **VPS IP**: 92.113.149.25
- **Status**: ✅ DEPLOYED AND RUNNING

## Services Running

### Backend Server (delirium-server-prod)
- **Image**: ghcr.io/marcusb333/delerium-server:v1.0.0
- **Status**: Healthy
- **Port**: 8080 (internal)
- **Health Check**: /api/pow

### Frontend Web (delirium-web-prod)
- **Image**: nginx:1.27.3-alpine
- **Status**: Running
- **Ports**: 
  - 80 (HTTP - redirects to HTTPS)
  - 443 (HTTPS)
  - 8080 (HTTP)

## SSL/TLS Configuration
- **Certificate**: Let's Encrypt
- **Domain**: your-domain.com
- **Expiry**: 2026-01-17
- **Auto-renewal**: Configured via certbot

## Access URLs
- **Main Site**: https://your-domain.com
- **API Endpoint**: https://your-domain.com/api/pow

## Configuration Files
- **Environment**: `<install-dir>/delerium-infrastructure/.env`
- **SSL Certificates**: `<install-dir>/delerium-infrastructure/ssl/`
- **Data Volume**: Docker managed volume `docker-compose_server-data`
- **Logs**: `<install-dir>/delerium-infrastructure/logs/`

## Security Features
- ✅ HTTPS with TLS 1.2/1.3
- ✅ Security headers configured
- ✅ HSTS enabled
- ✅ Content Security Policy
- ✅ Rate limiting on API endpoints
- ✅ Secure deletion token pepper configured

## Useful Commands

### View Logs
```bash
cd delerium-infrastructure/docker-compose
docker compose -f docker-compose.yml -f docker-compose.prod.yml logs -f
```

### Check Status
```bash
cd delerium-infrastructure/docker-compose
docker compose -f docker-compose.yml -f docker-compose.prod.yml ps
```

### Restart Services
```bash
cd delerium-infrastructure/docker-compose
docker compose -f docker-compose.yml -f docker-compose.prod.yml restart
```

### Stop Services
```bash
cd delerium-infrastructure/docker-compose
docker compose -f docker-compose.yml -f docker-compose.prod.yml down
```

### Start Services
```bash
cd delerium-infrastructure/docker-compose
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### Update Deployment
```bash
cd delerium-infrastructure
git pull

# Update and rebuild client
cd ../delerium-client
git pull
npm install
npm run build

# Restart services
cd ../delerium-infrastructure/docker-compose
docker compose -f docker-compose.yml -f docker-compose.prod.yml pull
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### Quick Client Rebuild
If you only need to rebuild the client (after code changes):
```bash
./delerium-infrastructure/scripts/build-client.sh
cd delerium-infrastructure/docker-compose
docker compose -f docker-compose.yml -f docker-compose.prod.yml restart web
```

## Backup Recommendations
1. Backup the database volume regularly
2. Backup the `.env` file securely
3. Keep SSL certificates backed up

### Manual Backup
```bash
# Backup database
docker run --rm -v docker-compose_server-data:/data -v $(pwd):/backup alpine tar czf /backup/server-data-$(date +%Y%m%d).tar.gz /data

# Backup configuration
tar czf config-backup-$(date +%Y%m%d).tar.gz .env ssl/
```

## Monitoring
- Check service health: `docker ps`
- View resource usage: `docker stats`
- Check logs: `docker compose logs -f`

## Next Steps
1. Set up automated backups
2. Configure monitoring/alerting
3. Review and adjust resource limits if needed
4. Consider setting up log rotation

---
Deployed successfully on 2025-11-18
