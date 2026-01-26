import os
import discord
from discord.ext import tasks
import requests

# Variáveis de ambiente
TOKEN = os.environ.get("DISCORD_TOKEN")
KANAL_ID = int(os.environ.get("KANAL_ID"))
KUMA_URL = os.environ.get("KUMA_URL")
API_KEY = os.environ.get("API_KEY")

intents = discord.Intents.default()
client = discord.Client(intents=intents)

# Mantém o status anterior
monitor_status = {}

@tasks.loop(seconds=300)  # 5 minutos para não encher o canal
async def checar_status():
    global monitor_status
    try:
        headers = {"Authorization": f"Bearer {API_KEY}"}
        response = requests.get(KUMA_URL, headers=headers)
        data = response.json()
        canal = client.get_channel(KANAL_ID)

        if not canal:
            print(f"Canal com ID {KANAL_ID} não encontrado")
            return

        # Cria embed principal
        embed = discord.Embed(
            title="🎮 Dashboard de Servidores",
            description="Status atualizado dos monitores do Uptime Kuma",
            color=0x1F1F1F
        )

        # Verifica cada monitor
        for monitor in data.get('monitors', []):
            name = monitor.get('name', 'Desconhecido')
            status = monitor.get('status', 'down')  # 'up' ou 'down'

            # Armazena status para alertas de mudança
            anterior = monitor_status.get(name, status)
            monitor_status[name] = status

            # Escolhe emoji e cor
            if status == 'up':
                emoji = "🟢"
            else:
                emoji = "🔴"

            # Adiciona campo no embed
            embed.add_field(
                name=f"{emoji} {name}",
                value=f"Status: {status.upper()}",
                inline=False
            )

            # Envia alerta se mudou de status
            if status != anterior:
                alerta_embed = discord.Embed(
                    title=f"{emoji} {name} mudou de status!",
                    description=f"Agora está **{status.upper()}**",
                    color=0xFF0000 if status == 'down' else 0x00FF00
                )
                alerta_embed.set_footer(text="Uptime Monitor • Synks Bot")
                await canal.send(embed=alerta_embed)

        # Footer do embed principal
        embed.set_footer(text="Uptime Monitor • Synks Bot")

        # Envia dashboard consolidado
        await canal.send(embed=embed)

    except Exception as e:
        print("Erro ao checar status:", e)

@client.event
async def on_ready():
    print(f'Logado como {client.user}')
    checar_status.start()

client.run(TOKEN)

