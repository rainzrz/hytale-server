# Hytale Dedicated Server

Production-ready Hytale dedicated server running on Docker with Cloudflare Tunnel for secure HTTPS access.

## Architecture

```
                                    Internet
                                        │
                                        ▼
                              ┌─────────────────┐
                              │   Cloudflare    │
                              │   (CDN + SSL)   │
                              └────────┬────────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    │                  │                  │
                    ▼                  ▼                  ▼
            ┌──────────────┐  ┌──────────────┐   ┌──────────────┐
            │    HTTPS     │  │     UDP      │   │   Tunnel     │
            │   :443       │  │   :25565     │   │  (cloudflared)│
            └──────┬───────┘  └──────┬───────┘   └──────┬───────┘
                   │                 │                  │
                   │                 │                  │
                   └────────────┬────┴──────────────────┘
                                │
                       ┌────────▼────────┐
                       │  Ubuntu Server  │
                       │  192.168.1.13   │
                       └────────┬────────┘
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                 │
              ▼                 ▼                 ▼
      ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
      │    Docker    │  │   Uptime     │  │  Cloudflared │
      │   Hytale     │  │    Kuma      │  │   Tunnel     │
      │   :25565     │  │   :3001      │  │   Service    │
      └──────────────┘  └──────────────┘  └──────────────┘
```

## Quick Links

| Service | URL | Protocol |
|---------|-----|----------|
| Game Server | `norhytale.com:25565` | UDP/QUIC |
| Status Dashboard | `https://norhytale.com` | HTTPS |
| Local Dashboard | `http://192.168.1.13:3001` | HTTP |

## Prerequisites

- Ubuntu Server 22.04+ (or similar Linux distribution)
- Docker & Docker Compose
- 16GB RAM (minimum 8GB)
- Valid Hytale account with server access
- Domain name (optional, for public access)

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/hytale-server.git
cd hytale-server
```

### 2. Download Server Files

Download the Hytale server files using the official downloader:

```bash
chmod +x hytale-downloader-linux-amd64
./hytale-downloader-linux-amd64
```

This will download:
- `HytaleServer.jar` - Main server executable
- `HytaleServer.aot` - Ahead-of-Time cache (optional)
- `Assets.zip` - Game assets

### 3. Configure Environment

```bash
cp .env.example .env
nano .env
```

Adjust settings based on your server:

```env
# For 16GB RAM server
JAVA_OPTS=-Xms6G -Xmx12G

# Server port
SERVER_PORT=25565

# Disable AOT if you get cache errors
USE_AOT_CACHE=false
```

### 4. Set Permissions

```bash
chmod -R 777 data/
```

### 5. Start the Server

```bash
docker compose up -d
```

### 6. Authenticate

```bash
docker compose logs -f hytale-server
```

Follow the authentication URL to link your Hytale account.

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `JAVA_OPTS` | `-Xms2G -Xmx4G` | JVM memory allocation |
| `SERVER_PORT` | `5520` | Server port (UDP) |
| `USE_AOT_CACHE` | `true` | Use AOT cache for faster startup |
| `EXTRA_ARGS` | - | Additional server arguments |

### Memory Recommendations

| Server RAM | JAVA_OPTS |
|------------|-----------|
| 8GB | `-Xms2G -Xmx4G` |
| 16GB | `-Xms6G -Xmx12G` |
| 32GB | `-Xms12G -Xmx24G` |

### Extra Arguments

```env
EXTRA_ARGS=--disable-sentry --backup --backup-frequency 30
```

| Argument | Description |
|----------|-------------|
| `--disable-sentry` | Disable crash reporting |
| `--backup` | Enable automatic backups |
| `--backup-frequency N` | Backup every N minutes |
| `--auth-mode offline` | Offline mode (no authentication) |

## Directory Structure

```
hytale-server/
├── Dockerfile              # Container image definition
├── docker-compose.yml      # Container orchestration
├── entrypoint.sh           # Server startup script
├── .env.example            # Environment template
├── .env                    # Your configuration (git ignored)
├── HytaleServer.jar        # Server executable (git ignored)
├── HytaleServer.aot        # AOT cache (git ignored)
├── Assets.zip              # Game assets (git ignored)
└── data/
    ├── universe/           # World data
    ├── mods/               # Server mods
    ├── logs/               # Server logs
    ├── .cache/             # Server cache
    ├── config.json         # Server configuration
    ├── permissions.json    # Player permissions
    ├── whitelist.json      # Whitelisted players
    └── bans.json           # Banned players
```

## Docker Management

### View Logs

```bash
docker compose logs -f hytale-server
```

### Restart Server

```bash
docker compose restart hytale-server
```

### Stop Server

```bash
docker compose down
```

### Rebuild After Changes

```bash
docker compose up -d --build
```

### Access Container Shell

```bash
docker compose exec hytale-server /bin/bash
```

## Cloudflare Tunnel Setup

For secure HTTPS access without opening ports 80/443.

### 1. Install Cloudflared

```bash
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb
```

### 2. Authenticate

```bash
cloudflared tunnel login
```

### 3. Create Tunnel

```bash
cloudflared tunnel create norhytale
```

### 4. Configure Tunnel

Create `/root/.cloudflared/config.yml`:

```yaml
tunnel: YOUR_TUNNEL_ID
credentials-file: /root/.cloudflared/YOUR_TUNNEL_ID.json

ingress:
  - hostname: norhytale.com
    service: http://localhost:3001
    originRequest:
      httpHostHeader: "localhost:3001"
  - service: http_status:404
```

### 5. Create DNS Route

```bash
cloudflared tunnel route dns norhytale norhytale.com
```

### 6. Install as Service

```bash
sudo cloudflared service install
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
```

### 7. Verify Status

```bash
sudo systemctl status cloudflared
```

## Monitoring with Uptime Kuma

### Install Uptime Kuma

```bash
docker run -d \
  --name uptime-kuma \
  --restart unless-stopped \
  -p 3001:3001 \
  -v uptime-kuma:/app/data \
  louislam/uptime-kuma:1
```

### Configure Monitor

1. Access `http://YOUR_SERVER_IP:3001`
2. Create account
3. Add monitor:
   - **Type:** TCP Port
   - **Hostname:** localhost
   - **Port:** 25565
   - **Interval:** 60 seconds

## Network Configuration

### Required Ports

| Port | Protocol | Service | Direction |
|------|----------|---------|-----------|
| 25565 | UDP | Hytale Server | Inbound |
| 3001 | TCP | Uptime Kuma | Inbound (optional) |

### Firewall (UFW)

```bash
sudo ufw allow 25565/udp comment "Hytale Server"
sudo ufw allow 3001/tcp comment "Uptime Kuma"
```

### Port Forwarding

Configure your router to forward:
- External port `25565` UDP → Internal `192.168.1.13:25565`
- External port `3001` TCP → Internal `192.168.1.13:3001` (optional)

## Troubleshooting

### AOT Cache Errors

If you see "Unable to map shared spaces" error:

```bash
# Disable AOT cache in .env
USE_AOT_CACHE=false
```

### Permission Denied

```bash
sudo chmod -R 777 data/
docker compose down && docker compose up -d
```

### Server Won't Start

```bash
# Check logs
docker compose logs -f hytale-server

# Verify files exist
ls -la HytaleServer.jar Assets.zip
```

### Authentication Issues

```bash
# Restart and re-authenticate
docker compose down
docker compose up -d
docker compose logs -f hytale-server
```

### Cloudflare Tunnel Not Working

```bash
# Check tunnel status
sudo systemctl status cloudflared

# View tunnel logs
sudo journalctl -u cloudflared -f

# Restart tunnel
sudo systemctl restart cloudflared
```

## Backup & Restore

### Manual Backup

```bash
tar -czvf backup-$(date +%Y%m%d).tar.gz data/
```

### Restore

```bash
docker compose down
rm -rf data/
tar -xzvf backup-YYYYMMDD.tar.gz
docker compose up -d
```

### Automatic Backups

Enable in `.env`:

```env
EXTRA_ARGS=--backup --backup-frequency 30
```

## Security Considerations

- Server runs as non-root user inside container
- Sensitive files (`.env`, credentials) are git ignored
- Cloudflare provides DDoS protection and SSL termination
- Regular updates recommended for Docker images and cloudflared

## Services Status

Check all services:

```bash
# Docker containers
docker ps

# Cloudflared tunnel
sudo systemctl status cloudflared

# Uptime Kuma
docker logs uptime-kuma
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Hytale](https://hytale.com) - Game by Hypixel Studios
- [Eclipse Temurin](https://adoptium.net) - Java runtime
- [Cloudflare](https://cloudflare.com) - Tunnel and CDN
- [Uptime Kuma](https://github.com/louislam/uptime-kuma) - Monitoring

---

**Server Status:** https://norhytale.com
