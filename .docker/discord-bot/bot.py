import os
import sys
import asyncio
import discord
from discord.ext import tasks
from datetime import datetime
import socket

TOKEN = os.getenv("DISCORD_TOKEN")
CHANNEL_ID_STR = os.getenv("DISCORD_CHANNEL_ID")

if not TOKEN:
    print("ERRO: DISCORD_TOKEN não configurado")
    sys.exit(1)

if not CHANNEL_ID_STR:
    print("ERRO: DISCORD_CHANNEL_ID não configurado")
    sys.exit(1)

try:
    CHANNEL_ID = int(CHANNEL_ID_STR)
except ValueError:
    print("ERRO: DISCORD_CHANNEL_ID inválido")
    sys.exit(1)

intents = discord.Intents.default()
client = discord.Client(intents=intents)

status_message_id = None

ultimo_status = {
    "cloudflare": None,
    "docker": None,
    "network": None,
    "hytale": None
}

async def checar_cloudflare():
    try:
        loop = asyncio.get_event_loop()
        def dns_lookup():
            try:
                return bool(socket.getaddrinfo("norhytale.com", None))
            except Exception:
                return False
        return 1 if await loop.run_in_executor(None, dns_lookup) else 0
    except Exception:
        return 0

async def checar_docker():
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
        return 1 if await loop.run_in_executor(None, tcp_check) else 0
    except Exception:
        return 0

async def checar_network():
    try:
        loop = asyncio.get_event_loop()
        def net_check():
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(5)
                result = sock.connect_ex(("186.219.130.224", 80))
                sock.close()
                return result == 0
            except Exception:
                return False
        return 1 if await loop.run_in_executor(None, net_check) else 0
    except Exception:
        return 0

async def checar_hytale_server():
    try:
        loop = asyncio.get_event_loop()
        def server_check():
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(5)
                result = sock.connect_ex(("hytale-server", 25565))
                sock.close()
                return result == 0
            except Exception:
                return False
        return 1 if await loop.run_in_executor(None, server_check) else 0
    except Exception:
        return 0

def criar_embed_online():
    embed = discord.Embed(
        title="NOR Infrastructure Status",
        description="Todos os serviços estão operando normalmente.",
        color=discord.Color.from_rgb(34, 197, 94),
        timestamp=datetime.now()
    )

    embed.add_field(
        name="Serviços",
        value=(
            f"{'🟢' if status['cloudflare'] else '🔴'} Cloudflare DNS\n"
            f"{'🟢' if status['docker'] else '🔴'} Docker Host\n"
            f"{'🟢' if status['network'] else '🔴'} Network\n"
            f"{'🟢' if status['hytale'] else '🔴'} Hytale Server"
        ),
        inline=False
    )

    embed.add_field(
        name="Endpoints",
        value="norhytale.com:25565\n186.219.130.224:25565",
        inline=False
    )

    embed.set_image(url="https://i.imgur.com/8YQZQZB.png")
    embed.set_footer(text="Monitoramento automático | NOR")

    return embed

def criar_embed_problema(status):
    embed = discord.Embed(
        title="NOR Infrastructure",
        description="Um ou mais serviços estão indisponíveis.",
        color=discord.Color.from_rgb(239, 68, 68),
        timestamp=datetime.now()
    )

    embed.add_field(
        name="Serviços",
        value=(
            f"Cloudflare DNS: {'🟢' if status['cloudflare'] else 'OFFLINE'}\n"
            f"Docker Host: {'🟢' if status['docker'] else 'OFFLINE'}\n"
            f"Network: {'🟢' if status['network'] else 'OFFLINE'}\n"
            f"Hytale Server: {'🟢' if status['hytale'] else 'OFFLINE'}"
        ),
        inline=False
    )

    embed.add_field(
        name="Monitoramento",
        value="https://norhytale.com",
        inline=False
    )

    embed.set_image(url="https://i.imgur.com/JzqZQZV.png")
    embed.set_footer(text="Aguardando normalização | NOR")

    return embed

@tasks.loop(seconds=30)
async def checar_status():
    global status_message_id, ultimo_status

    canal = client.get_channel(CHANNEL_ID)
    if not canal:
        return

    status_atual = {
        "cloudflare": await checar_cloudflare(),
        "docker": await checar_docker(),
        "network": await checar_network(),
        "hytale": await checar_hytale_server()
    }

    ultimo_status = status_atual.copy()

    if all(status_atual.values()):
        embed = criar_embed_online()
    else:
        embed = criar_embed_problema(status_atual)

    if status_message_id:
        try:
            msg = await canal.fetch_message(status_message_id)
            await msg.edit(embed=embed)
        except discord.NotFound:
            msg = await canal.send(embed=embed)
            status_message_id = msg.id
    else:
        msg = await canal.send(embed=embed)
        status_message_id = msg.id

@client.event
async def on_ready():
    print(f"Bot conectado como {client.user}")
    checar_status.start()

client.run(TOKEN)
