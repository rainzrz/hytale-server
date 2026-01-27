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
    """Busca status dos monitores no Uptime Kuma via Status Page API"""
    timeout = aiohttp.ClientTimeout(total=10)

    # Uptime Kuma Status Page API (pública, não requer auth)
    # Formato: /api/status-page/{slug}
    # Onde slug é o identificador da status page
    # Por padrão, vamos tentar alguns slugs comuns
    slugs_to_try = [os.getenv("KUMA_STATUS_SLUG", "hytale"), "default", "status"]

    async with aiohttp.ClientSession(timeout=timeout) as session:
        for slug in slugs_to_try:
            api_url = f"{KUMA_URL}/api/status-page/{slug}"
            print(f"DEBUG: Tentando URL: {api_url}", flush=True)

            try:
                async with session.get(api_url) as response:
                    print(f"DEBUG: Status HTTP: {response.status}", flush=True)

                    if response.status == 200:
                        content_type = response.headers.get('Content-Type', '')
                        if 'application/json' in content_type:
                            data = await response.json()
                            print(f"DEBUG: Status page encontrada: {slug}", flush=True)
                            return data
                        else:
                            print(f"DEBUG: Resposta não é JSON (slug={slug})", flush=True)
            except Exception as e:
                print(f"DEBUG: Erro tentando slug '{slug}': {e}", flush=True)
                continue

        # Se nenhum slug funcionou, tentar endpoint de heartbeat
        print("DEBUG: Tentando endpoint alternativo...", flush=True)
        raise Exception("Nenhuma status page encontrada. Configure KUMA_STATUS_SLUG no .env ou crie uma status page no Kuma")

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

        # Status Page API retorna: {config: {...}, publicGroupList: [{monitorList: [...]}]}
        monitor = None
        status = None

        if isinstance(data, dict):
            # Formato Status Page API
            if "publicGroupList" in data:
                print(f"DEBUG: Encontrado publicGroupList", flush=True)
                for group in data.get("publicGroupList", []):
                    monitor_list = group.get("monitorList", [])
                    if monitor_list:
                        # Pegar primeiro monitor ou o monitor com ID especificado
                        for mon in monitor_list:
                            if KUMA_MONITOR_ID:
                                if str(mon.get("id")) == str(KUMA_MONITOR_ID):
                                    monitor = mon
                                    break
                            else:
                                monitor = mon
                                break
                    if monitor:
                        break

            # Formato direto do monitor
            elif 'id' in data or 'status' in data:
                monitor = data

        if not monitor:
            print(f"⚠️ Nenhum monitor encontrado. Estrutura: {list(data.keys()) if isinstance(data, dict) else 'lista'}", flush=True)
            return

        # Status pode estar em diferentes campos
        # Status Page usa: 0 = offline, 1 = online, 2 = pausado
        status = monitor.get("status", monitor.get("active", None))

        if status is None:
            print(f"⚠️ Status não encontrado. Campos do monitor: {list(monitor.keys())}", flush=True)
            return

        print(f"DEBUG: Status atual: {status} (Monitor: {monitor.get('name', 'N/A')})", flush=True)

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
