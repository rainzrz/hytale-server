import os
import sys
import asyncio
import aiohttp
import discord
from discord.ext import tasks
from datetime import datetime

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
print(f"  - Canal: {CHANNEL_ID}", flush=True)
print(f"  - Kuma URL: {KUMA_URL}", flush=True)
print(f"  - Monitor ID: {KUMA_MONITOR_ID}", flush=True)
print(f"  - Auth: {'Sim' if KUMA_API_KEY else 'Não'}", flush=True)

intents = discord.Intents.default()
client = discord.Client(intents=intents)

ultimo_status = None

async def buscar_status_kuma():
    """Busca status do monitor via Badge API do Uptime Kuma"""
    timeout = aiohttp.ClientTimeout(total=10)

    # Badge API retorna informações de status em tempo real
    # Formato: /api/badge/{monitor_id}/status
    # Retorna JSON com status, uptime, etc
    api_url = f"{KUMA_URL}/api/badge/{KUMA_MONITOR_ID}/status"
    print(f"DEBUG: Usando Badge API: {api_url}", flush=True)

    async with aiohttp.ClientSession(timeout=timeout) as session:
        try:
            async with session.get(api_url) as response:
                print(f"DEBUG: Status HTTP: {response.status}", flush=True)

                if response.status == 200:
                    data = await response.json()
                    print(f"DEBUG: Resposta da Badge API: {data}", flush=True)
                    return data
                else:
                    response_text = await response.text()
                    raise Exception(f"Erro HTTP {response.status}: {response_text}")
        except Exception as e:
            print(f"DEBUG: Erro ao buscar badge: {e}", flush=True)
            raise

@tasks.loop(seconds=30)
async def checar_status():
    global ultimo_status

    agora = datetime.now().strftime("%H:%M:%S")
    print(f"[{agora}] Checando status no Uptime Kuma...", flush=True)

    canal = client.get_channel(CHANNEL_ID)
    if not canal:
        print("❌ Canal do Discord não encontrado", flush=True)
        return

    try:
        data = await buscar_status_kuma()

        # Badge API retorna: {status: "up"|"down"|"pending", uptime: "99.9%", ...}
        if not isinstance(data, dict):
            print(f"⚠️ Resposta inválida da API: {data}", flush=True)
            return

        print(f"DEBUG: Campos disponíveis: {list(data.keys())}", flush=True)

        # Badge API usa "status" com valores "up", "down", "pending"
        status_str = data.get("status")

        if not status_str:
            print(f"⚠️ Campo 'status' não encontrado. Dados: {data}", flush=True)
            return

        # Converter string para número (0 = offline, 1 = online, 2 = pending)
        if status_str == "up":
            status = 1
        elif status_str == "down":
            status = 0
        elif status_str == "pending":
            status = 2
        else:
            print(f"⚠️ Status desconhecido: {status_str}", flush=True)
            return

        print(f"DEBUG: Status: {status_str} ({status})", flush=True)

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
