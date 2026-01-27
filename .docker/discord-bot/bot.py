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
    """Busca status dos monitores no Uptime Kuma"""
    headers = {
        "Accept": "application/json"
    }
    if KUMA_API_KEY:
        # Uptime Kuma usa x-api-key ao invés de Bearer
        headers["x-api-key"] = KUMA_API_KEY

    timeout = aiohttp.ClientTimeout(total=10)

    # Tentar buscar monitor específico pelo ID primeiro
    if KUMA_MONITOR_ID:
        api_url = f"{KUMA_URL}/api/monitor/{KUMA_MONITOR_ID}"
    else:
        api_url = f"{KUMA_URL}/api/monitor"

    async with aiohttp.ClientSession(timeout=timeout) as session:
        async with session.get(api_url, headers=headers) as response:
            print(f"DEBUG: Status HTTP: {response.status}", flush=True)
            response_text = await response.text()
            print(f"DEBUG: Resposta (primeiros 300 chars): {response_text[:300]}", flush=True)

            if response.status != 200:
                raise Exception(f"Erro HTTP {response.status}: {response_text}")

            data = await response.json()
            return data

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

        # Se buscamos um monitor específico, data já é o monitor
        # Se buscamos todos, data pode ser uma lista ou objeto com lista
        monitor = None

        if isinstance(data, dict):
            # Se tem 'id' no root, é um monitor específico
            if 'id' in data or 'status' in data:
                monitor = data
            else:
                # Pode ser {monitorList: [...]} ou {monitors: [...]}
                monitors = data.get("monitorList", data.get("monitors", []))
                if monitors:
                    monitor = monitors[0] if isinstance(monitors, list) else monitors
        elif isinstance(data, list):
            monitor = data[0] if data else None

        if not monitor:
            print(f"⚠️ Nenhum monitor encontrado. Resposta: {data}", flush=True)
            return

        # Status pode estar em diferentes campos dependendo da versão do Kuma
        # Normalmente: 0 = offline, 1 = online, 2 = pausado
        status = monitor.get("status", monitor.get("active", None))

        if status is None:
            print(f"⚠️ Status não encontrado. Monitor: {monitor}", flush=True)
            return

        print(f"DEBUG: Status atual: {status}", flush=True)

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
