import os
import asyncio
import aiohttp
import discord
from discord.ext import tasks
from datetime import datetime

TOKEN = os.getenv("DISCORD_TOKEN")
CHANNEL_ID = int(os.getenv("DISCORD_CHANNEL_ID"))
KUMA_API_KEY = os.getenv("KUMA_API_KEY")
KUMA_URL = os.getenv("KUMA_URL")

intents = discord.Intents.default()
client = discord.Client(intents=intents)

ultimo_status = None

async def buscar_status_kuma():
    headers = {
        "Authorization": f"Bearer {KUMA_API_KEY}"
    }

    timeout = aiohttp.ClientTimeout(total=10)

    async with aiohttp.ClientSession(timeout=timeout) as session:
        async with session.get(KUMA_URL, headers=headers) as response:
            if response.status != 200:
                raise Exception(f"Erro HTTP {response.status}")
            return await response.json()

@tasks.loop(seconds=30)
async def checar_status():
    global ultimo_status

    agora = datetime.now().strftime("%H:%M:%S")
    print(f"[{agora}] Checando status no Uptime Kuma...")

    canal = client.get_channel(CHANNEL_ID)
    if not canal:
        print("Canal do Discord não encontrado")
        return

    try:
        data = await buscar_status_kuma()

        monitor = data["monitors"][0]
        status = monitor["status"]

        if status != ultimo_status:
            if status == 1:
                await canal.send("🟢 **Servidor ONLINE**")
                print("Servidor ONLINE")
            elif status == 0:
                await canal.send("🔴 **Servidor OFFLINE**")
                print("Servidor OFFLINE")
            elif status == 2:
                await canal.send("⏸️ **Monitor PAUSADO**")
                print("Monitor PAUSADO")

            ultimo_status = status
        else:
            print("Status inalterado")

    except Exception as e:
        print(f"Erro ao consultar Kuma: {e}")

@client.event
async def on_ready():
    print(f"Bot conectado como {client.user}")
    checar_status.start()

client.run(TOKEN)
