# Evernear (`evernear.erai.vn`) Production Deployment & Operations Guide

## 1. Domain & Routing Topology (`evernear.erai.vn`)

```
                       [ https://evernear.erai.vn (Nginx / SSL) ]
                                            |
        +-----------------------+-----------+-----------+-----------------------+
        |                       |                       |                       |
   [ /landing, /privacy,   [ /, /login, /register, [ /api/v1/* ]      [ /ws & /realtime/* ]
     /terms, /delete-account ] /dashboard, /invite ]    |                       |
        |                       |                       v                       v
  Static Landing          Flutter Web App      [ NestJS Backend :3000 (REST + WS + SSE) ]
 (/opt/evernear/landing) (/opt/evernear/flutter)        |
                                            +-----------+-----------+
                                            |                       |
                                  [ PostgreSQL 16 ]          [ Redis 7 ]
```

### Quick Deploy to `evernear.erai.vn`
1. Point DNS `A` / `CNAME` record for `evernear.erai.vn` to your VPS IP (or Cloudflare Tunnel).
2. Issue SSL certificate on VPS (if not using Cloudflare Tunnel):
   ```bash
   sudo certbot certonly --webroot -w /var/www/certbot -d evernear.erai.vn
   ```
3. Run the automated deployment script:
   ```bash
   ./scripts/deploy_evernear.sh
   ```
   - Builds Flutter Web with `--dart-define=BASE_URL=https://evernear.erai.vn/api/v1` and `--dart-define=WEB_LANDING_URL=https://evernear.erai.vn`
   - Syncs `mobile/build/web/` -> `/opt/evernear/flutter` and `landing/` -> `/opt/evernear/landing`
   - Launches `docker-compose.prod.yml` (`postgres`, `redis`, `backend` on `127.0.0.1:3000`)
   - Installs `nginx/evernear.erai.vn.conf` and reloads Nginx.

---

## 2. Environment Variables Specification

Create `backend/.env` based on the production checklist:

```bash
# Application Environment
NODE_ENV=production
PORT=3000

# Database Configuration (PostgreSQL 16)
DATABASE_HOST=postgres-primary.carely.internal
DATABASE_PORT=5432
DATABASE_USER=carely_user
DATABASE_PASSWORD=SuperSecureRandomPassword123!
DATABASE_NAME=carely_db

# Redis Configuration (Redis 7)
REDIS_HOST=redis-master.carely.internal
REDIS_PORT=6379
REDIS_PASSWORD=SecureRedisAuthToken!

# Security & Secrets
JWT_SECRET=production_jwt_secret_min_64_bytes_entropy_key_carely
JWT_EXPIRES_IN=15m
REFRESH_TOKEN_EXPIRES_IN=7d

# Push Notification (Firebase Admin SDK)
FIREBASE_PROJECT_ID=carely-production
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@carely-production.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIEvgIBA...-----END PRIVATE KEY-----\n"

# SMS Gateway Configuration
SMS_GATEWAY_URL=https://api.sms-provider.com/v1/send
SMS_API_KEY=sms_prod_key_xyz
```

---

## 3. Docker Compose Production Manifest

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    container_name: carely_postgres_prod
    restart: always
    environment:
      POSTGRES_USER: ${DATABASE_USER}
      POSTGRES_PASSWORD: ${DATABASE_PASSWORD}
      POSTGRES_DB: ${DATABASE_NAME}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DATABASE_USER} -d ${DATABASE_NAME}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: carely_redis_prod
    restart: always
    command: redis-server --requirepass ${REDIS_PASSWORD} --appendonly yes
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: carely_backend_prod
    restart: always
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/v1/health"]
      interval: 15s
      timeout: 5s
      retries: 3

volumes:
  postgres_data:
  redis_data:
```

---

## 4. Multi-Replica Scaling & Worker Coordination

Carely is horizontally scalable out of the box:
* **Stateless API Replicas**: All HTTP handlers extract session state from JWT tokens and write directly to PostgreSQL.
* **Non-Conflicting Workers**: The background monitoring evaluator uses `FOR UPDATE OF config SKIP LOCKED` in PostgreSQL combined with Redis Redlock locks. Even if 10 API instances execute the cron simultaneously, no relationship is processed by more than one worker thread.

---

## 5. Health Probes & Monitoring

### Liveness & Readiness Endpoint:
`GET /api/v1/health`
* Returns `200 OK` with JSON status when both PostgreSQL and Redis respond.
* If Redis goes down, returns degraded status (`"redis": "degraded"`) while maintaining API availability via fallback mode.
* If PostgreSQL is down, returns `503 Service Unavailable`.

### Database Backup & Disaster Recovery:
1. **Continuous WAL Archiving**: Ship Write-Ahead Logs to Amazon S3 / Google Cloud Storage.
2. **Automated Daily Snapshot**: Run `pg_dump -Fc` cron job stored with 30-day lifecycle retention.
