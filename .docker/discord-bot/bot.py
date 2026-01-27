import os
import sys
import asyncio
import aiohttp
import discord
from discord.ext import tasks
from datetime import datetime
import socket

# Validar variáveis de ambiente
TOKEN = os.getenv("DISCORD_TOKEN")
CHANNEL_ID_STR = os.getenv("DISCORD_CHANNEL_ID")
KUMA_API_KEY = os.getenv("KUMA_API_KEY")
KUMA_URL = os.getenv("KUMA_URL", "http://uptime-kuma:3001")
KUMA_MONITOR_ID = os.getenv("KUMA_MONITOR_ID", "1")

# Verificar se variáveis obrigatórias estão configuradas
if not TOKEN or TOKEN == "seu_token_aqui":
    print("❌ ERRO: DISCORD_TOKEN não configurado no .env")
    print("Configure o token do bot em https://discord.com/developers/applications")
    sys.exit(1)

if not CHANNEL_ID_STR or CHANNEL_ID_STR == "seu_canal_id_aqui":
    print("❌ ERRO: DISCORD_CHANNEL_ID não configurado no .env")
    print("Ative o Modo Desenvolvedor no Discord e copie o ID do canal")
    sys.exit(1)

try:
    CHANNEL_ID = int(CHANNEL_ID_STR)
except ValueError:
    print(f"❌ ERRO: DISCORD_CHANNEL_ID inválido: {CHANNEL_ID_STR}")
    print("O ID do canal deve ser apenas números")
    sys.exit(1)

if not KUMA_API_KEY or KUMA_API_KEY == "sua_api_key_aqui":
    print("⚠️ AVISO: KUMA_API_KEY não configurado")
    print("O bot tentará acessar a API sem autenticação")
    KUMA_API_KEY = None

print("✓ Configurações validadas", flush=True)
print(f"  - Canal Discord: {CHANNEL_ID}", flush=True)
print(f"  - Monitorando 3 serviços:", flush=True)
print(f"    • NOR Cloudflare (DNS norhytale.com)", flush=True)
print(f"    • NOR Docker (SSH 192.168.1.13:22)", flush=True)
print(f"    • NOR Network (186.219.130.224)", flush=True)

intents = discord.Intents.default()
client = discord.Client(intents=intents)

ultimo_status = {
    "cloudflare": None,
    "docker": None,
    "network": None
}

async def checar_cloudflare():
    """Verifica DNS do domínio norhytale.com"""
    try:
        loop = asyncio.get_event_loop()
        def dns_lookup():
            try:
                result = socket.getaddrinfo("norhytale.com", None)
                return len(result) > 0
            except Exception:
                return False

        online = await loop.run_in_executor(None, dns_lookup)
        return 1 if online else 0
    except Exception as e:
        print(f"DEBUG: Erro Cloudflare DNS: {e}", flush=True)
        return 0

async def checar_docker():
    """Verifica TCP porta 22 em 192.168.1.13"""
    try:
        loop = asyncio.get_event_loop()
        def tcp_check():
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(5)
                result = sock.connect_ex(("192.168.1.13", 22))
                sock.close()
                return result == 0
            except Exception:
                return False

        online = await loop.run_in_executor(None, tcp_check)
        return 1 if online else 0
    except Exception as e:
        print(f"DEBUG: Erro Docker SSH: {e}", flush=True)
        return 0

async def checar_network():
    """Verifica ping para 186.219.130.224"""
    try:
        loop = asyncio.get_event_loop()
        def ping_check():
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(5)
                result = sock.connect_ex(("186.219.130.224", 80))
                sock.close()
                return result == 0
            except Exception:
                return False

        online = await loop.run_in_executor(None, ping_check)
        return 1 if online else 0
    except Exception as e:
        print(f"DEBUG: Erro Network ping: {e}", flush=True)
        return 0

@tasks.loop(seconds=30)
async def checar_status():
    global ultimo_status

    agora = datetime.now().strftime("%H:%M:%S")
    print(f"[{agora}] Checando status do servidor...", flush=True)

    canal = client.get_channel(CHANNEL_ID)
    if not canal:
        print("❌ Canal do Discord não encontrado", flush=True)
        return

    try:
        # Checar todos os serviços
        status_cloudflare = await checar_cloudflare()
        status_docker = await checar_docker()
        status_network = await checar_network()

        print(f"DEBUG: Cloudflare={status_cloudflare}, Docker={status_docker}, Network={status_network}", flush=True)

        # Verificar mudanças e notificar
        if status_cloudflare != ultimo_status["cloudflare"]:
            if status_cloudflare == 1:
                await canal.send("🟢 **NOR Cloudflare (norhytale.com) ONLINE**")
                print("✓ Cloudflare ONLINE", flush=True)
            else:
                await canal.send("🔴 **NOR Cloudflare (norhytale.com) OFFLINE**")
                print("✗ Cloudflare OFFLINE", flush=True)
            ultimo_status["cloudflare"] = status_cloudflare

        if status_docker != ultimo_status["docker"]:
            if status_docker == 1:
                await canal.send("🟢 **NOR Docker (SSH 192.168.1.13:22) ONLINE**")
                print("✓ Docker SSH ONLINE", flush=True)
            else:
                await canal.send("🔴 **NOR Docker (SSH 192.168.1.13:22) OFFLINE**")
                print("✗ Docker SSH OFFLINE", flush=True)
            ultimo_status["docker"] = status_docker

        if status_network != ultimo_status["network"]:
            if status_network == 1:
                await canal.send("🟢 **NOR Network (186.219.130.224) ONLINE**")
                print("✓ Network ONLINE", flush=True)
            else:
                await canal.send("🔴 **NOR Network (186.219.130.224) OFFLINE**")
                print("✗ Network OFFLINE", flush=True)
            ultimo_status["network"] = status_network

        if (status_cloudflare == ultimo_status["cloudflare"] and
            status_docker == ultimo_status["docker"] and
            status_network == ultimo_status["network"]):
            print("  Todos os status inalterados", flush=True)

    except Exception as e:
        print(f"❌ Erro ao verificar serviços: {e}", flush=True)

@client.event
async def on_ready():
    print(f"Bot conectado como {client.user}", flush=True)
    print("Iniciando verificação de status...", flush=True)
    checar_status.start()

client.run(TOKEN)
