import os
import discord
from discord.ext import tasks
import aiohttp
import asyncio

# Variáveis de ambiente
TOKEN = os.environ.get("DISCORD_TOKEN")
KANAL_ID = int(os.environ.get("KANAL_ID"))
KUMA_URL = os.environ.get("KUMA_URL")
API_KEY = os.environ.get("API_KEY")

intents = discord.Intents.default()
client = discord.Client(intents=intents)

monitor_status = {}

# Função para buscar status de forma assíncrona
async def buscar_status():
    headers = {"Authorization": f"Bearer {API_KEY}"}
    async with aiohttp.ClientSession(headers=headers) as session:
        async with session.get(KUMA_URL) as resp:
            return await resp.json()

# Loop rápido: alertas imediatos (30 segundos)
@tasks.loop(seconds=30)
async def checar_alertas():
    global monitor_status
    try:
        data = await buscar_status()
        canal = client.get_channel(KANAL_ID)
        if not canal:
            print(f"Canal com ID {KANAL_ID} não encontrado")
            return

        for monitor in data.get('monitors', []):
            name = monitor.get('name', 'Desconhecido')
            status = monitor.get('status', 'down')
            anterior = monitor_status.get(name, status)
            monitor_status[name] = status

            if status != anterior:
                # Define emoji e cor por status
                if status == 'up':
                    emoji = "🟢"
                    color = 0x00FF00
                    desc = "Agora está online"
                elif status == 'down':
                    emoji = "🔴"
                    color = 0xFF0000
                    desc = "Monitor caiu!"
                elif status == 'paused':
                    emoji = "🟡"
                    color = 0xFFFF00
                    desc = "Monitor está pausado"

                alerta_embed = discord.Embed(
                    title=f"{emoji} {name} mudou de status!",
                    description=desc,
                    color=color
                )
                alerta_embed.set_footer(text="Uptime Monitor • Synks Bot")
                await canal.send(embed=alerta_embed)

    except Exception as e:
        print("Erro ao checar alertas:", e)

# Loop lento: dashboard completo (5 minutos)
@tasks.loop(minutes=5)
async def enviar_dashboard():
    try:
        data = await buscar_status()
        canal = client.get_channel(KANAL_ID)
        if not canal:
            print(f"Canal com ID {KANAL_ID} não encontrado")
            return

        embed = discord.Embed(
            title="🎮 Dashboard de Servidores",
            description="Status atualizado dos monitores do Uptime Kuma",
            color=0x1F1F1F
        )

        for monitor in data.get('monitors', []):
            name = monitor.get('name', 'Desconhecido')
            status = monitor.get('status', 'down')
            if status == 'up':
                emoji = "🟢"
            elif status == 'down':
                emoji = "🔴"
            else:
                emoji = "🟡"
            embed.add_field(
                name=f"{emoji} {name}",
                value=f"Status: {status.upper()}",
                inline=False
            )

        embed.set_footer(text="Uptime Monitor • Synks Bot")
        await canal.send(embed=embed)

    except Exception as e:
        print("Erro ao enviar dashboard:", e)

@client.event
async def on_ready():
    print(f'Logado como {client.user}')
    checar_alertas.start()
    enviar_dashboard.start()

client.run(TOKEN)
