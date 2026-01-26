# Hytale Dedicated Server

Servidor dedicado Hytale pronto para produção, rodando em Docker com Cloudflare Tunnel para acesso HTTPS seguro.

## Arquitetura

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

## Links Rápidos

| Serviço | URL | Protocolo |
|---------|-----|-----------|
| Servidor de Jogo | `norhytale.com:25565` | UDP/QUIC |
| Dashboard de Status | `https://norhytale.com` | HTTPS |
| Dashboard Local | `http://192.168.1.13:3001` | HTTP |

## Pré-requisitos

- Ubuntu Server 22.04+ (ou distribuição Linux similar)
- Docker & Docker Compose
- 16GB RAM (mínimo 8GB)
- Conta Hytale válida com acesso ao servidor
- Nome de domínio (opcional, para acesso público)

## Início Rápido

### 1. Clonar o Repositório

```bash
git clone https://github.com/yourusername/hytale-server.git
cd hytale-server
```

### 2. Baixar Arquivos do Servidor

Baixe os arquivos do servidor Hytale usando o downloader oficial:

```bash
chmod +x hytale-downloader-linux-amd64
./hytale-downloader-linux-amd64
```

Isso vai baixar:
- `HytaleServer.jar` - Executável principal do servidor
- `HytaleServer.aot` - Cache Ahead-of-Time (opcional)
- `Assets.zip` - Assets do jogo

### 3. Configurar Ambiente

```bash
cp .env.example .env
nano .env
```

Ajuste as configurações baseado no seu servidor:

```env
# Para servidor com 16GB RAM
JAVA_OPTS=-Xms6G -Xmx12G

# Porta do servidor
SERVER_PORT=25565

# Desabilite AOT se tiver erros de cache
USE_AOT_CACHE=false
```

### 4. Definir Permissões

```bash
chmod -R 777 data/
```

### 5. Iniciar o Servidor

```bash
docker compose up -d
```

### 6. Autenticar

```bash
docker compose logs -f hytale-server
```

Siga a URL de autenticação para vincular sua conta Hytale.

## Configuração

### Variáveis de Ambiente

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `JAVA_OPTS` | `-Xms2G -Xmx4G` | Alocação de memória JVM |
| `SERVER_PORT` | `5520` | Porta do servidor (UDP) |
| `USE_AOT_CACHE` | `true` | Usar cache AOT para inicialização mais rápida |
| `EXTRA_ARGS` | - | Argumentos adicionais do servidor |

### Recomendações de Memória

| RAM do Servidor | JAVA_OPTS |
|-----------------|-----------|
| 8GB | `-Xms2G -Xmx4G` |
| 16GB | `-Xms6G -Xmx12G` |
| 32GB | `-Xms12G -Xmx24G` |

### Argumentos Extras

```env
EXTRA_ARGS=--disable-sentry --backup --backup-frequency 30
```

| Argumento | Descrição |
|-----------|-----------|
| `--disable-sentry` | Desabilitar relatório de crashes |
| `--backup` | Habilitar backups automáticos |
| `--backup-frequency N` | Backup a cada N minutos |
| `--auth-mode offline` | Modo offline (sem autenticação) |

## Estrutura de Diretórios

```
hytale-server/
├── Dockerfile              # Definição da imagem do container
├── docker-compose.yml      # Orquestração do container
├── entrypoint.sh           # Script de inicialização
├── .env.example            # Template de ambiente
├── .env                    # Sua configuração (ignorado pelo git)
├── HytaleServer.jar        # Executável do servidor (ignorado pelo git)
├── HytaleServer.aot        # Cache AOT (ignorado pelo git)
├── Assets.zip              # Assets do jogo (ignorado pelo git)
└── data/
    ├── universe/           # Dados do mundo
    ├── mods/               # Mods do servidor
    ├── logs/               # Logs do servidor
    ├── .cache/             # Cache do servidor
    ├── config.json         # Configuração do servidor
    ├── permissions.json    # Permissões dos jogadores
    ├── whitelist.json      # Jogadores na whitelist
    └── bans.json           # Jogadores banidos
```

## Gerenciamento Docker

### Ver Logs

```bash
docker compose logs -f hytale-server
```

### Reiniciar Servidor

```bash
docker compose restart hytale-server
```

### Parar Servidor

```bash
docker compose down
```

### Reconstruir Após Mudanças

```bash
docker compose up -d --build
```

### Acessar Shell do Container

```bash
docker compose exec hytale-server /bin/bash
```

## Configuração do Cloudflare Tunnel

Para acesso HTTPS seguro sem abrir as portas 80/443.

### 1. Instalar Cloudflared

```bash
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb
```

### 2. Autenticar

```bash
cloudflared tunnel login
```

### 3. Criar Tunnel

```bash
cloudflared tunnel create norhytale
```

### 4. Configurar Tunnel

Criar `/root/.cloudflared/config.yml`:

```yaml
tunnel: SEU_TUNNEL_ID
credentials-file: /root/.cloudflared/SEU_TUNNEL_ID.json

ingress:
  - hostname: norhytale.com
    service: http://localhost:3001
    originRequest:
      httpHostHeader: "localhost:3001"
  - service: http_status:404
```

### 5. Criar Rota DNS

```bash
cloudflared tunnel route dns norhytale norhytale.com
```

### 6. Instalar como Serviço

```bash
sudo cloudflared service install
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
```

### 7. Verificar Status

```bash
sudo systemctl status cloudflared
```

## Monitoramento com Uptime Kuma

### Instalar Uptime Kuma

```bash
docker run -d \
  --name uptime-kuma \
  --restart unless-stopped \
  -p 3001:3001 \
  -v uptime-kuma:/app/data \
  louislam/uptime-kuma:1
```

### Configurar Monitor

1. Acesse `http://IP_DO_SEU_SERVIDOR:3001`
2. Crie uma conta
3. Adicione monitor:
   - **Tipo:** TCP Port
   - **Hostname:** localhost
   - **Porta:** 25565
   - **Intervalo:** 60 segundos

## Configuração de Rede

### Portas Necessárias

| Porta | Protocolo | Serviço | Direção |
|-------|-----------|---------|---------|
| 25565 | UDP | Servidor Hytale | Entrada |
| 3001 | TCP | Uptime Kuma | Entrada (opcional) |

### Firewall (UFW)

```bash
sudo ufw allow 25565/udp comment "Servidor Hytale"
sudo ufw allow 3001/tcp comment "Uptime Kuma"
```

### Port Forwarding

Configure seu roteador para encaminhar:
- Porta externa `25565` UDP → Interna `192.168.1.13:25565`
- Porta externa `3001` TCP → Interna `192.168.1.13:3001` (opcional)

## Solução de Problemas

### Erros de Cache AOT

Se você ver o erro "Unable to map shared spaces":

```bash
# Desabilite o cache AOT no .env
USE_AOT_CACHE=false
```

### Permissão Negada

```bash
sudo chmod -R 777 data/
docker compose down && docker compose up -d
```

### Servidor Não Inicia

```bash
# Verificar logs
docker compose logs -f hytale-server

# Verificar se os arquivos existem
ls -la HytaleServer.jar Assets.zip
```

### Problemas de Autenticação

```bash
# Reiniciar e re-autenticar
docker compose down
docker compose up -d
docker compose logs -f hytale-server
```

### Cloudflare Tunnel Não Funciona

```bash
# Verificar status do tunnel
sudo systemctl status cloudflared

# Ver logs do tunnel
sudo journalctl -u cloudflared -f

# Reiniciar tunnel
sudo systemctl restart cloudflared
```

## Backup & Restauração

### Backup Manual

```bash
tar -czvf backup-$(date +%Y%m%d).tar.gz data/
```

### Restaurar

```bash
docker compose down
rm -rf data/
tar -xzvf backup-YYYYMMDD.tar.gz
docker compose up -d
```

### Backups Automáticos

Habilite no `.env`:

```env
EXTRA_ARGS=--backup --backup-frequency 30
```

## Considerações de Segurança

- Servidor roda como usuário não-root dentro do container
- Arquivos sensíveis (`.env`, credenciais) são ignorados pelo git
- Cloudflare fornece proteção DDoS e terminação SSL
- Atualizações regulares recomendadas para imagens Docker e cloudflared

## Status dos Serviços

Verificar todos os serviços:

```bash
# Containers Docker
docker ps

# Tunnel Cloudflared
sudo systemctl status cloudflared

# Uptime Kuma
docker logs uptime-kuma
```

## Contribuindo

1. Faça um fork do repositório
2. Crie uma branch de feature
3. Commit suas mudanças
4. Push para a branch
5. Crie um Pull Request

## Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

## Agradecimentos

- [Hytale](https://hytale.com) - Jogo da Hypixel Studios
- [Eclipse Temurin](https://adoptium.net) - Runtime Java
- [Cloudflare](https://cloudflare.com) - Tunnel e CDN
- [Uptime Kuma](https://github.com/louislam/uptime-kuma) - Monitoramento

---

**Status do Servidor:** https://norhytale.com
