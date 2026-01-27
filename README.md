<div align="center">

# 🎮 Nor Hytale Server

### Servidor Hytale Profissional com Monitoramento e Notificações

[![Status](https://img.shields.io/badge/status-online-brightgreen?style=for-the-badge)](https://norhytale.com)
[![Docker](https://img.shields.io/badge/docker-ready-blue?style=for-the-badge&logo=docker)](https://www.docker.com/)
[![Uptime](https://img.shields.io/badge/uptime-99.9%25-success?style=for-the-badge)](https://norhytale.com)
[![Discord](https://img.shields.io/badge/discord-notificações-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://discord.com)

[Jogar Agora](#conectar) • [Monitorar Status](#monitoramento) • [Suporte](#suporte)

</div>

---

## 🚀 O que é isso?

Um servidor Hytale completo e pronto para uso, com:

- **🎮 Servidor Hytale** - Jogue com seus amigos 24/7
- **📊 Uptime Kuma** - Monitore o status do servidor em tempo real
- **💬 Bot Discord** - Receba notificações quando o servidor cair ou voltar
- **🐳 Docker** - Tudo containerizado, fácil de gerenciar

Tudo funciona junto, no mesmo ambiente, sem complicação.

---

## ⚡ Início Rápido

### 1️⃣ Clone e Configure

```bash
git clone https://github.com/yourusername/hytale-server.git
cd hytale-server
```

### 2️⃣ Baixe os Arquivos do Jogo

```bash
chmod +x hytale-downloader-linux-amd64
./hytale-downloader-linux-amd64
```

### 3️⃣ Configure as Variáveis

Edite o arquivo `.env` e adicione suas credenciais:

```bash
nano .env
```

```env
# Discord (obtenha em https://discord.com/developers/applications)
DISCORD_TOKEN=seu_token_aqui
DISCORD_CHANNEL_ID=seu_canal_id_aqui

# Uptime Kuma (configure depois de iniciar)
KUMA_API_KEY=sua_api_key_aqui
```

### 4️⃣ Inicie Tudo

```bash
docker-compose up -d --build
```

Pronto! Seu servidor está online. 🎉

---

## 🎮 Conectar

### Para Jogar

```
norhytale.com:25565
```

Ou localmente:

```
192.168.1.13:25565
```

### Para Monitorar

**Online:** https://norhytale.com

**Local:** http://192.168.1.13:3001

---

## 📊 Monitoramento

### Uptime Kuma

Acesse o painel em `http://seu-servidor:3001` e configure:

1. **Crie uma conta** de administrador
2. **Adicione um monitor** para o servidor Hytale:
   - Tipo: **UDP (Port)**
   - Hostname: `hytale-server`
   - Porta: `25565`
   - Intervalo: `30 segundos`
3. **Gere uma API Key** em Settings > API Keys
4. **Adicione no `.env`** a chave `KUMA_API_KEY`
5. **Reinicie o bot:** `docker-compose restart discord-bot`

### Bot do Discord

O bot envia notificações automáticas quando:

- 🟢 Servidor fica **online**
- 🔴 Servidor fica **offline**
- ⏸️ Monitor é **pausado**

<div align="center">
  <img src="https://i.imgur.com/YourImageHere.png" alt="Discord Notification" width="400">
</div>

---

## 🛠️ Comandos Úteis

### Gerenciar Containers

```bash
# Ver status de todos os serviços
docker-compose ps

# Ver logs do servidor
docker-compose logs -f hytale-server

# Ver logs do bot
docker-compose logs -f discord-bot

# Ver logs do Kuma
docker-compose logs -f uptime-kuma

# Reiniciar tudo
docker-compose restart

# Parar tudo
docker-compose down

# Atualizar e reiniciar
docker-compose up -d --build --force-recreate
```

### Verificar Status

```bash
# Status de todos os containers
docker ps

# Uso de recursos
docker stats

# Espaço em disco
df -h
```

---

## 📂 O que tem aqui?

```
hytale-server/
│
├── 🐳 .docker/                # Configurações Docker
│   ├── hytale/                # Container do servidor Hytale
│   │   ├── Dockerfile
│   │   ├── entrypoint.sh
│   │   └── .dockerignore
│   └── discord-bot/           # Container do bot Discord
│       ├── Dockerfile
│       ├── bot.py
│       ├── requirements.txt
│       └── .env.example
│
├── 🎮 .server/                # Arquivos do servidor Hytale
│   ├── HytaleServer.jar       # (não commitado - muito grande)
│   ├── HytaleServer.aot       # (não commitado - muito grande)
│   └── Assets.zip             # (não commitado - muito grande)
│
├── 📁 data/                   # Dados persistentes
│   ├── universe/              # Mundo do jogo
│   ├── mods/                  # Mods instalados
│   ├── logs/                  # Logs do servidor
│   └── uptime-kuma/           # Dados do Kuma
│
├── 🔧 scripts/                # Scripts de manutenção
│   └── maintenance.sh         # Painel interativo de gerenciamento
│
├── 🛠️ tools/                  # Ferramentas e binários
│   ├── hytale-downloader      # Downloader oficial do Hytale
│   ├── cloudflared.deb        # Cloudflare Tunnel
│   └── .hytale-credentials    # Credenciais (não commitado)
│
├── 📚 docs/                   # Documentação
│   ├── README.md              # Este arquivo
│   ├── LICENSE                # Licença MIT
│   └── OfficialDocumentation.md
│
├── 💾 backups/                # Backups automáticos
│
├── 🐳 docker-compose.yml      # Orquestração de todos os serviços
├── 📝 .env                    # Configurações (não commitado)
└── 🔒 .gitignore              # Arquivos ignorados pelo Git
```

---

## ⚙️ Configuração

### Memória do Servidor

Ajuste baseado na sua RAM disponível:

| RAM do Servidor | Configuração |
|----------------|--------------|
| 8GB  | `-Xms2G -Xmx4G` |
| 16GB | `-Xms6G -Xmx12G` ⭐ |
| 32GB | `-Xms12G -Xmx24G` |

Edite no arquivo `.env`:

```env
JAVA_OPTS=-Xms6G -Xmx12G
```

### Porta do Servidor

```env
SERVER_PORT=25565
```

### Argumentos Extras

```env
EXTRA_ARGS=--disable-sentry --backup --backup-frequency 30
```

| Opção | O que faz |
|-------|-----------|
| `--disable-sentry` | Desativa relatórios de crash |
| `--backup` | Ativa backups automáticos |
| `--backup-frequency 30` | Faz backup a cada 30 minutos |
| `--auth-mode offline` | Modo offline (sem login) |

---

## 🔧 Solução de Problemas

### Bot não funciona

**Problema:** Bot não conecta ao Discord

**Solução:**
```bash
# Verifique se o token está correto
nano .env

# Veja os logs do bot
docker-compose logs discord-bot

# Reinicie o bot
docker-compose restart discord-bot
```

### Servidor não inicia

**Problema:** Container fica reiniciando

**Solução:**
```bash
# Veja os logs
docker-compose logs -f hytale-server

# Verifique se os arquivos existem
ls -lh HytaleServer.jar Assets.zip

# Desative o cache AOT se necessário
nano .env
# USE_AOT_CACHE=false
```

### Kuma não monitora

**Problema:** Monitor mostra offline mesmo com servidor rodando

**Solução:**
- Verifique se o hostname está como `hytale-server` (nome do container)
- Porta deve ser `25565` (ou a que você configurou)
- Tipo deve ser **UDP (Port)**

---

## 🎯 Portas Utilizadas

| Porta | Serviço | Protocolo |
|-------|---------|-----------|
| **25565** | Servidor Hytale | UDP |
| **3001** | Uptime Kuma | TCP |

### Configurar Firewall

```bash
sudo ufw allow 25565/udp comment "Hytale Server"
sudo ufw allow 3001/tcp comment "Uptime Kuma"
```

---

## 💾 Backup & Restauração

### Fazer Backup

```bash
# Criar backup com data
tar -czvf backup-$(date +%Y%m%d).tar.gz data/

# Ou copiar para outro lugar
cp -r data/ /caminho/do/backup/
```

### Restaurar Backup

```bash
# Parar o servidor
docker-compose down

# Restaurar dados
tar -xzvf backup-20260127.tar.gz

# Iniciar novamente
docker-compose up -d
```

### Backups Automáticos

Ative no `.env`:

```env
EXTRA_ARGS=--backup --backup-frequency 30
```

---

## 🆘 Suporte

### Problemas Comuns

- **Bot não envia mensagens:** Verifique as permissões do bot no Discord
- **Kuma não acessa API:** Certifique-se de que a API Key está correta no `.env`
- **Servidor lento:** Aumente a memória no `JAVA_OPTS`
- **Erro de permissão:** Execute `sudo chmod -R 777 data/`

### Logs

Sempre verifique os logs quando algo der errado:

```bash
docker-compose logs -f [nome-do-serviço]
```

---

## 🌟 Recursos

- ✅ Servidor Hytale dedicado 24/7
- ✅ Monitoramento em tempo real
- ✅ Notificações no Discord
- ✅ Backups automáticos
- ✅ Fácil gerenciamento com Docker
- ✅ Acesso HTTPS seguro via Cloudflare
- ✅ Dashboard de status público

---

## 📜 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

---

<div align="center">

**Feito com ❤️ para a comunidade Hytale**

[⬆ Voltar ao Topo](#-nor-hytale-server)

</div>
