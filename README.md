# NOR Hytale Server

Servidor Hytale dedicado com sistema completo de monitoramento e notificações automáticas via Discord.

---

## Visão Geral

Este projeto fornece uma infraestrutura completa para hospedar um servidor Hytale com monitoramento em tempo real e notificações automáticas. Todos os componentes são executados em containers Docker, facilitando a implantação, manutenção e escalabilidade.

### Componentes Principais

O projeto é composto por três serviços principais que trabalham de forma integrada:

**Hytale Server**
Servidor dedicado do jogo Hytale configurado para rodar 24/7. Utiliza o protocolo QUIC (UDP) na porta 25565 e suporta configurações customizadas de memória, mods e mundo persistente.

**Uptime Kuma**
Sistema de monitoramento que verifica continuamente o status do servidor Hytale e outros serviços. Fornece um dashboard web acessível para visualização de métricas e histórico de uptime.

**Discord Bot**
Bot personalizado que monitora a infraestrutura e envia notificações automáticas para um canal do Discord quando detecta mudanças de status (servidor online, offline ou problemas de conectividade).

---

## Arquitetura

```
Internet
    |
    +-- norhytale.com (Cloudflare Tunnel) --> Uptime Kuma Dashboard (porta 3001)
    |
    +-- 186.219.130.224:25565 (Direto) --> Hytale Server (UDP)
    |
Docker Network (hytale-network)
    |
    +-- hytale-server (container)
    |   |-- Porta: 25565/UDP
    |   |-- Volumes: universe, mods, logs, config
    |   |-- Memória: 6-12GB (configurável)
    |
    +-- uptime-kuma (container)
    |   |-- Porta: 3001/TCP
    |   |-- Volume: dados persistentes
    |   |-- Monitora: Cloudflare, Docker Host, Network, Hytale Server
    |
    +-- discord-bot (container)
        |-- Verifica: DNS Cloudflare, Docker Host (SSH), Network (HTTP), Hytale (Docker)
        |-- Intervalo: 30 segundos
        |-- Notifica: Canal Discord configurado
```

### Fluxo de Funcionamento

1. **Servidor Hytale** roda em um container isolado, expondo a porta 25565/UDP
2. **Uptime Kuma** monitora o servidor via conexão UDP interna na rede Docker
3. **Discord Bot** verifica múltiplos pontos da infraestrutura:
   - Resolução DNS do domínio (norhytale.com)
   - Conectividade do Docker Host (porta 22)
   - Conectividade de rede externa (porta 80)
   - Status do container Hytale via Docker API
4. Quando detecta mudanças, o bot atualiza uma mensagem fixa no Discord com o status atual
5. **Cloudflare Tunnel** roteia tráfego HTTPS do domínio para o dashboard do Uptime Kuma

---

## Estrutura de Diretórios

```
hytale-server/
|
|-- .docker/
|   |-- hytale/
|   |   |-- Dockerfile              # Imagem do servidor Hytale
|   |   |-- entrypoint.sh           # Script de inicialização
|   |   |-- .dockerignore
|   |
|   |-- discord-bot/
|       |-- Dockerfile              # Imagem do bot Discord
|       |-- bot.py                  # Código principal do bot
|       |-- requirements.txt        # Dependências Python
|
|-- .server/
|   |-- HytaleServer.jar            # Executável do servidor (80MB)
|   |-- HytaleServer.aot            # Cache de otimização AOT (118MB)
|   |-- Assets.zip                  # Recursos do jogo (3.3GB)
|
|-- data/
|   |-- universe/                   # Mundo do jogo (persistente)
|   |-- mods/                       # Mods instalados
|   |-- logs/                       # Logs do servidor
|   |-- .cache/                     # Cache temporário
|   |-- config.json                 # Configuração do servidor
|   |-- permissions.json            # Permissões de jogadores
|   |-- whitelist.json              # Lista de jogadores permitidos
|   |-- bans.json                   # Jogadores banidos
|   |-- uptime-kuma/                # Dados do Uptime Kuma
|
|-- scripts/
|   |-- maintenance.sh              # Painel interativo de manutenção
|   |-- update-hytale.sh            # Script de atualização automática
|
|-- tools/
|   |-- hytale-downloader-linux-amd64  # Downloader oficial
|   |-- cloudflared.deb             # Cloudflare Tunnel daemon
|   |-- .hytale-downloader-credentials.json
|
|-- docs/
|   |-- OfficialDocumentation.md    # Documentação oficial Hytale
|
|-- docker-compose.yml              # Orquestração de serviços
|-- .env                            # Variáveis de ambiente (não versionado)
|-- .gitignore
|-- README.md
```

---

## Requisitos do Sistema

- **Sistema Operacional:** Linux (testado em Ubuntu/Debian)
- **Docker:** versão 20.10 ou superior
- **Docker Compose:** versão 1.29 ou superior
- **RAM:** Mínimo 8GB, recomendado 16GB+
- **Disco:** Mínimo 10GB livres (para servidor + backups)
- **Rede:** Porta 25565/UDP aberta no firewall

---

## Instalação

### 1. Clonar o Repositório

```bash
git clone https://github.com/rainzrz/hytale-server.git
cd hytale-server
```

### 2. Baixar Arquivos do Servidor

```bash
cd .server
../tools/hytale-downloader-linux-amd64 download
cd ..
```

Isso baixará:
- HytaleServer.jar (executável principal)
- HytaleServer.aot (cache de otimização)
- Assets.zip (recursos do jogo)

### 3. Configurar Variáveis de Ambiente

Copie o arquivo de exemplo e edite com suas credenciais:

```bash
cp .env.example .env
nano .env
```

Configurações obrigatórias:

```env
# Discord Bot
DISCORD_TOKEN=seu_token_aqui
DISCORD_CHANNEL_ID=id_do_canal_aqui

# Uptime Kuma (configure após primeira inicialização)
KUMA_API_KEY=sua_api_key
KUMA_URL=http://uptime-kuma:3001
KUMA_MONITOR_ID=1
KUMA_STATUS_SLUG=hytale

# Servidor Hytale
JAVA_OPTS=-Xms6G -Xmx12G
SERVER_PORT=25565
USE_AOT_CACHE=true
EXTRA_ARGS=
```

### 4. Iniciar Serviços

```bash
docker-compose up -d --build
```

### 5. Verificar Status

```bash
docker-compose ps
docker-compose logs -f
```

---

## Configuração

### Memória do Servidor

Ajuste baseado na RAM disponível no seu servidor:

| RAM Total | Configuração JAVA_OPTS |
|-----------|------------------------|
| 8GB       | -Xms2G -Xmx4G         |
| 16GB      | -Xms6G -Xmx12G        |
| 32GB      | -Xms12G -Xmx24G       |

Edite no arquivo `.env`:

```env
JAVA_OPTS=-Xms6G -Xmx12G
```

### Configuração do Discord Bot

1. Acesse [Discord Developer Portal](https://discord.com/developers/applications)
2. Crie uma nova aplicação
3. Vá em "Bot" e crie um bot
4. Copie o token e adicione em `DISCORD_TOKEN`
5. Ative "Message Content Intent"
6. Convide o bot para seu servidor com permissões de:
   - Ler mensagens
   - Enviar mensagens
   - Embed links
7. Copie o ID do canal onde deseja receber notificações e adicione em `DISCORD_CHANNEL_ID`

### Configuração do Uptime Kuma

1. Acesse `http://seu-servidor:3001`
2. Crie uma conta de administrador
3. Adicione um novo monitor:
   - **Nome:** Hytale Server
   - **Tipo:** UDP (Port)
   - **Hostname:** hytale-server
   - **Porta:** 25565
   - **Intervalo de verificação:** 30 segundos
4. Vá em Settings > API Keys
5. Gere uma nova API Key
6. Adicione a key no `.env` como `KUMA_API_KEY`
7. Reinicie o bot: `docker-compose restart discord-bot`

### Cloudflare Tunnel (Opcional)

O projeto já vem configurado com Cloudflare Tunnel para expor o dashboard Uptime Kuma via HTTPS.

Configuração atual (`/etc/cloudflared/config.yml`):

```yaml
tunnel: 2de19421-18aa-4fc5-a0ba-0e961ae4f505
credentials-file: /root/.cloudflared/2de19421-18aa-4fc5-a0ba-0e961ae4f505.json

ingress:
  - hostname: norhytale.com
    service: http://localhost:3001
  - hostname: www.norhytale.com
    service: http://localhost:3001
  - service: http_status:404
```

---

## Como Conectar

### Para Jogar

Use o IP direto do servidor no cliente do Hytale:

```
186.219.130.224:25565
```

O domínio `norhytale.com:25565` não funciona porque o Cloudflare Tunnel não suporta UDP/QUIC. Use apenas o IP direto para jogar.

### Para Monitorar

Acesse o dashboard de monitoramento:

- **Online:** https://norhytale.com
- **Local:** http://192.168.1.13:3001

---

## Manutenção

### Painel Interativo

Execute o script de manutenção para gerenciar os containers de forma visual:

```bash
./scripts/maintenance.sh
```

Funcionalidades:
- Iniciar/Parar/Reiniciar containers individuais
- Ver logs em tempo real
- Ver estatísticas de recursos
- Acessar shell dos containers
- Reconstruir containers

### Comandos Manuais

```bash
# Ver status de todos os serviços
docker-compose ps

# Ver logs de um serviço específico
docker-compose logs -f hytale-server
docker-compose logs -f discord-bot
docker-compose logs -f uptime-kuma

# Reiniciar todos os serviços
docker-compose restart

# Reiniciar um serviço específico
docker-compose restart hytale-server

# Parar todos os serviços
docker-compose down

# Iniciar com rebuild
docker-compose up -d --build

# Ver uso de recursos
docker stats
```

---

## Atualização do Servidor

Quando uma nova versão do Hytale for lançada, use o script automatizado:

```bash
./scripts/update-hytale.sh
```

O script realiza as seguintes operações automaticamente:

1. Verifica requisitos (Docker rodando, downloader disponível)
2. Mostra a versão atual instalada
3. Pede confirmação antes de prosseguir
4. Para o servidor Hytale (desconecta jogadores)
5. Faz backup da versão atual (`.server.backup-YYYYMMDD-HHMMSS`)
6. Baixa a nova versão usando o hytale-downloader
7. Reconstrói a imagem Docker com os novos arquivos
8. Reinicia o servidor
9. Mostra logs para verificação
10. Limpa backups antigos (mantém os 3 mais recentes)

Em caso de falha, o script restaura automaticamente a versão anterior (rollback).

### Atualização Manual

Se preferir fazer manualmente:

```bash
# 1. Parar o servidor
docker-compose stop hytale-server

# 2. Fazer backup
mv .server .server.backup-$(date +%Y%m%d)

# 3. Baixar nova versão
mkdir .server
cd .server
../tools/hytale-downloader-linux-amd64 download
cd ..

# 4. Rebuild e reiniciar
docker-compose build hytale-server
docker-compose up -d hytale-server

# 5. Verificar logs
docker-compose logs -f hytale-server
```

---

## Backup e Restauração

### Backup Manual

```bash
# Criar backup completo com data
tar -czf backup-$(date +%Y%m%d-%H%M%S).tar.gz data/

# Ou copiar diretório
cp -r data/ /caminho/do/backup/hytale-data-$(date +%Y%m%d)
```

### Restauração

```bash
# Parar serviços
docker-compose down

# Restaurar dados
tar -xzf backup-20260127-143000.tar.gz

# Reiniciar
docker-compose up -d
```

### Backup Automático do Jogo

O servidor Hytale suporta backups automáticos nativos. Ative no `.env`:

```env
EXTRA_ARGS=--backup --backup-frequency 30
```

Isso criará backups automáticos do mundo a cada 30 minutos dentro do container.

---

## Solução de Problemas

### Servidor não inicia

**Sintoma:** Container `hytale-server` fica reiniciando constantemente

**Verificações:**

```bash
# Ver logs detalhados
docker-compose logs -f hytale-server

# Verificar se os arquivos existem
ls -lh .server/

# Verificar memória disponível
free -h
```

**Soluções:**
- Certifique-se de que os arquivos `HytaleServer.jar` e `Assets.zip` foram baixados
- Verifique se há RAM suficiente (mínimo 8GB)
- Ajuste `JAVA_OPTS` se necessário
- Desative AOT cache se houver problemas: `USE_AOT_CACHE=false`

### Discord Bot não conecta

**Sintoma:** Bot não aparece online no Discord

**Verificações:**

```bash
docker-compose logs discord-bot
```

**Soluções:**
- Verifique se `DISCORD_TOKEN` está correto no `.env`
- Certifique-se de que "Message Content Intent" está ativado no Discord Developer Portal
- Verifique se `DISCORD_CHANNEL_ID` está correto
- Reinicie o bot: `docker-compose restart discord-bot`

### Uptime Kuma não monitora

**Sintoma:** Monitor mostra servidor offline mesmo estando online

**Soluções:**
- Verifique se o hostname está como `hytale-server` (nome do container, não IP)
- Porta deve ser `25565`
- Tipo de monitor deve ser **UDP (Port)**, não TCP
- Certifique-se de que ambos os containers estão na mesma rede Docker

### Permissões negadas

**Sintoma:** Erros de "permission denied" nos logs

**Solução:**

```bash
sudo chown -R 1000:1000 data/
```

Ou, se necessário:

```bash
sudo chmod -R 755 data/
```

### Cloudflare Tunnel não funciona

**Verificações:**

```bash
systemctl status cloudflared
journalctl -u cloudflared -n 50
```

**Soluções:**
- Verifique se o tunnel está autenticado
- Certifique-se de que o arquivo de credenciais existe
- Reinicie o serviço: `systemctl restart cloudflared`

---

## Portas Utilizadas

| Porta | Serviço        | Protocolo | Descrição                    |
|-------|----------------|-----------|------------------------------|
| 25565 | Hytale Server  | UDP       | Conexão de jogadores (QUIC)  |
| 3001  | Uptime Kuma    | TCP       | Dashboard web                |
| 22    | Docker Host    | TCP       | Monitoramento SSH (interno)  |
| 80    | Network Check  | TCP       | Verificação de conectividade |

### Configurar Firewall

```bash
# Permitir porta do jogo
sudo ufw allow 25565/udp comment "Hytale Server"

# Permitir dashboard (opcional, se não usar Cloudflare Tunnel)
sudo ufw allow 3001/tcp comment "Uptime Kuma"

# Verificar regras
sudo ufw status
```

---

## Monitoramento do Discord Bot

O bot executa 4 verificações a cada 30 segundos:

1. **Cloudflare DNS:** Verifica se `norhytale.com` resolve corretamente
2. **Docker Host:** Testa conexão SSH na porta 22 (192.168.1.13)
3. **Network:** Verifica conectividade HTTP na porta 80 (IP público)
4. **Hytale Server:** Verifica se o container está rodando via Docker API

O bot mantém uma mensagem fixa no Discord que é atualizada apenas quando o status muda, evitando spam no canal.

---

## Controle de Versões

Este projeto utiliza Git com tags para marcar versões estáveis:

```bash
# Ver versões disponíveis
git tag

# Voltar para uma versão estável
git checkout v1.0-estavel

# Criar nova tag ao finalizar mudanças
git tag -a v2.0-fevereiro -m "Versão estável de fevereiro"
git push --tags
```

Versões marcadas:
- `v1.0-estavel`: Versão inicial estável de janeiro de 2026

---

## Tecnologias Utilizadas

- **Java 25 JRE:** Runtime do servidor Hytale
- **Docker & Docker Compose:** Containerização e orquestração
- **Python 3.12:** Discord bot
- **Discord.py:** Biblioteca para integração com Discord
- **Uptime Kuma:** Sistema de monitoramento open-source
- **Cloudflare Tunnel:** Proxy reverso seguro com HTTPS
- **QUIC Protocol:** Protocolo de transporte UDP do Hytale
- **Bash:** Scripts de automação

---

## Recursos

- Servidor Hytale dedicado 24/7
- Monitoramento em tempo real com dashboard web
- Notificações automáticas no Discord
- Sistema de backup automático
- Scripts de manutenção e atualização
- Acesso HTTPS seguro via Cloudflare
- Containers isolados para segurança
- Configuração via variáveis de ambiente
- Documentação completa

---

## Licença

Este projeto está sob a licença MIT. Veja o arquivo LICENSE para mais detalhes.

---

## Autor

Desenvolvido e mantido por NOR para a comunidade Hytale brasileira.

Repositório: https://github.com/rainzrz/hytale-server
