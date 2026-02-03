# NOR Hytale Server

![Banner](https://i.ibb.co/NdsxQwB7/NOR-Hytale-Logo.png)

![Status](https://img.shields.io/badge/status-online-brightgreen)
![Docker](https://img.shields.io/badge/docker-ready-blue)
![Platform](https://img.shields.io/badge/platform-linux-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Como Jogar

```
norhytale.com
```

IP Reserva: `177.22.181.41:5520`

---

## Como Monitorar

https://status.norhytale.com

---

## Instalação (para admins)

### 1. Clonar

```bash
git clone https://github.com/rainzrz/hytale-server.git
cd hytale-server
```

### 2. Baixar o servidor

```bash
cd .server
../tools/hytale-downloader-linux-amd64 download
cd ..
```

### 3. Configurar

```bash
cp .env.example .env
nano .env
```

Preencha:
- `DISCORD_TOKEN` - Token do bot Discord
- `DISCORD_CHANNEL_ID` - ID do canal de notificações

### 4. Iniciar

```bash
docker compose up -d --build
```

---

## Comandos Úteis

| O que fazer | Comando |
|-------------|---------|
| Ver status | `docker compose ps` |
| Ver logs | `docker compose logs -f hytale-server` |
| Reiniciar tudo | `docker compose restart` |
| Parar tudo | `docker compose down` |
| Atualizar servidor | `./scripts/update-hytale.sh` |
| Fazer backup | `./scripts/backup.sh` |
| Manutenção | `./scripts/maintenance.sh` |

---

## Estrutura

```
hytale-server/
├── .server/          # Arquivos do servidor Hytale
├── data/             # Mundo, mods, configs (persistente)
├── backups/          # Backups automáticos
├── scripts/          # Scripts de manutenção
└── docker-compose.yml
```

---

## Portas

| Porta | Uso |
|-------|-----|
| 5520/UDP | Servidor Hytale |
| 3001/TCP | Dashboard de monitoramento |

---

## Problemas Comuns

**Servidor não inicia?**
```bash
docker compose logs -f hytale-server
```

**Bot Discord offline?**
- Verifica o `DISCORD_TOKEN` no `.env`
- Reinicia: `docker compose restart discord-bot`

**Players não conectam?**
- Verifica se a porta 5520/UDP está aberta no firewall/roteador

---

## Autor

NOR - Comunidade Hytale Brasil

https://github.com/rainzrz/hytale-server
