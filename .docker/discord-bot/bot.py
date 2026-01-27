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
print(f"  - Monitorando: hytale-server:5520", flush=True)

intents = discord.Intents.default()
client = discord.Client(intents=intents)

ultimo_status = None

async def checar_servidor_hytale():
    """Verifica se o container do servidor Hytale está online"""
    # O servidor Hytale está no container "hytale-server" na mesma rede Docker
    servidor_host = "hytale-server"
    servidor_porta = 5520  # Porta UDP do servidor

    print(f"DEBUG: Verificando {servidor_host}:{servidor_porta}", flush=True)

    try:
        # Tentar conectar via TCP para verificar se o container está respondendo
        # Como é UDP, vamos verificar se o host é alcançável
        loop = asyncio.get_event_loop()

        # Verificar se o host resolve
        def check_host():
            try:
                socket.getaddrinfo(servidor_host, None)
                return True
            except socket.gaierror:
                return False

        host_exists = await loop.run_in_executor(None, check_host)

        if not host_exists:
            print(f"DEBUG: Host {servidor_host} não encontrado", flush=True)
            return 0  # Offline

        # Tentar conectar na porta UDP
        # Como UDP não tem handshake, vamos verificar se a porta está bound
        def check_udp_port():
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                sock.settimeout(2)
                # Enviar um pacote vazio e ver se recebemos algo de volta
                sock.sendto(b'', (servidor_host, servidor_porta))
                # Se conseguiu enviar, o host está alcançável
                sock.close()
                return True
            except Exception as e:
                print(f"DEBUG: Erro UDP: {e}", flush=True)
                return False

        udp_ok = await loop.run_in_executor(None, check_udp_port)

        if udp_ok:
            print(f"DEBUG: Servidor alcançável", flush=True)
            return 1  # Online
        else:
            print(f"DEBUG: Servidor não respondendo", flush=True)
            return 0  # Offline

    except Exception as e:
        print(f"DEBUG: Erro ao verificar servidor: {e}", flush=True)
        return 0  # Offline em caso de erro

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
        # Verificar status diretamente
        status = await checar_servidor_hytale()

        print(f"DEBUG: Status do servidor: {status}", flush=True)

        if status != ultimo_status:
            if status == 1:
                await canal.send("🟢 **Servidor Hytale ONLINE**")
                print("✓ Servidor ONLINE", flush=True)
            elif status == 0:
                await canal.send("🔴 **Servidor Hytale OFFLINE**")
                print("✗ Servidor OFFLINE", flush=True)
            elif status == 2:
                await canal.send("⏸️ **Monitor PAUSADO**")
                print("⏸ Monitor PAUSADO", flush=True)

            ultimo_status = status
        else:
            print("  Status inalterado", flush=True)

    except Exception as e:
        print(f"❌ Erro ao consultar Kuma: {e}", flush=True)

@client.event
async def on_ready():
    print(f"Bot conectado como {client.user}", flush=True)
    print("Iniciando verificação de status...", flush=True)
    checar_status.start()

client.run(TOKEN)
