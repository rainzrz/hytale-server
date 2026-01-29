import os
import sys
import asyncio
import discord
from discord.ext import tasks
from datetime import datetime
import socket
import subprocess

# =======================
# CONFIG
# =======================

TOKEN = os.getenv("DISCORD_TOKEN")
CHANNEL_ID_STR = os.getenv("DISCORD_CHANNEL_ID")

STATUS_FILE = "status_message_id.txt"
MAINTENANCE_FILE = "/tmp/hytale_maintenance.flag"

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
ultimo_status = None
ultimo_estado_geral = None
loop_iniciado = False

# =======================
# LOAD MESSAGE ID
# =======================

if os.path.exists(STATUS_FILE):
    try:
        with open(STATUS_FILE) as f:
            status_message_id = int(f.read().strip())
            print("[DEBUG] status_message_id carregado:", status_message_id)
    except Exception as e:
        print("[DEBUG] Falha ao carregar status_message_id:", e)

# =======================
# CHECKS
# =======================

async def checar_cloudflare():
    try:
        loop = asyncio.get_event_loop()

        def dns_lookup():
            try:
                socket.getaddrinfo("norhytale.com", None)
                return True
            except Exception as e:
                print("[DEBUG] Cloudflare DNS falhou:", e)
                return False

        return await loop.run_in_executor(None, dns_lookup)
    except Exception as e:
        print("[DEBUG] Erro geral Cloudflare:", e)
        return False


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
            except Exception as e:
                print("[DEBUG] Docker Host TCP erro:", e)
                return False

        return await loop.run_in_executor(None, tcp_check)
    except Exception as e:
        print("[DEBUG] Erro geral Docker Host:", e)
        return False


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
            except Exception as e:
                print("[DEBUG] Network TCP erro:", e)
                return False

        return await loop.run_in_executor(None, net_check)
    except Exception as e:
        print("[DEBUG] Erro geral Network:", e)
        return False


async def checar_hytale_server():
    try:
        result = subprocess.run(
            ["docker", "inspect", "-f", "{{.State.Running}}", "hytale-server"],
            capture_output=True,
            text=True
        )

        print("[DEBUG] docker inspect stdout:", result.stdout.strip())
        print("[DEBUG] docker inspect stderr:", result.stderr.strip())
        print("[DEBUG] docker inspect returncode:", result.returncode)

        return result.stdout.strip() == "true"

    except FileNotFoundError:
        print("[DEBUG] Docker não encontrado no container do bot")
        return False
    except Exception as e:
        print("[DEBUG] Erro ao checar hytale-server:", e)
        return False


def obter_ultimo_backup():
    try:
        import glob
        backups_dir = "/backups"

        if not os.path.exists(backups_dir):
            return "Nenhum backup encontrado"

        # Lista todos os arquivos de backup
        backups = glob.glob(f"{backups_dir}/hytale-backup-*.tar.gz")

        if not backups:
            return "Nenhum backup encontrado"

        # Pega o backup mais recente
        ultimo_backup = max(backups, key=os.path.getmtime)
        timestamp = os.path.getmtime(ultimo_backup)
        data_backup = datetime.fromtimestamp(timestamp)

        return data_backup.strftime("%d/%m/%Y às %H:%M")

    except Exception as e:
        print("[DEBUG] Erro ao obter último backup:", e)
        return "Erro ao verificar"


def obter_versao_servidor():
    try:
        import zipfile
        # Extrai a versão do manifesto do JAR
        jar_path = "/server/HytaleServer.jar"

        if not os.path.exists(jar_path):
            return "N/A"

        # Lê o arquivo MANIFEST.MF do JAR
        with zipfile.ZipFile(jar_path, 'r') as jar:
            with jar.open('META-INF/MANIFEST.MF') as manifest:
                manifest_content = manifest.read().decode('utf-8')

        # Procura pela linha Implementation-Version
        for line in manifest_content.split('\n'):
            if line.startswith("Implementation-Version:"):
                version = line.split(":", 1)[1].strip()
                return f"Version: {version}"

        return "N/A"

    except Exception as e:
        print("[DEBUG] Erro ao obter versão do servidor:", e)
        return "N/A"


def esta_em_manutencao():
    """Verifica se o servidor está em modo de manutenção"""
    try:
        if os.path.exists(MAINTENANCE_FILE):
            with open(MAINTENANCE_FILE, 'r') as f:
                motivo = f.read().strip()
            return True, motivo if motivo else "Manutenção em andamento"
        return False, ""
    except Exception as e:
        print("[DEBUG] Erro ao verificar manutenção:", e)
        return False, ""


# =======================
# EMBED
# =======================

def criar_embed(status, tudo_ok):
    # Verifica se está em manutenção
    em_manutencao, motivo_manutencao = esta_em_manutencao()

    if em_manutencao:
        embed = discord.Embed(
            title="NOR Infrastructure",
            description=f"🔧 **MANUTENÇÃO EM ANDAMENTO**\n\n{motivo_manutencao}",
            color=discord.Color.from_rgb(59, 130, 246),  # Azul
            timestamp=datetime.now()
        )
        # Em manutenção, todos os indicadores ficam azuis
        embed.add_field(
            name="Serviços Monitorados",
            value=(
                f"🔵 Cloudflare DNS\n"
                f"🔵 Docker Host\n"
                f"🔵 Network\n"
                f"🔵 Hytale Server"
            ),
            inline=False
        )
    elif tudo_ok:
        embed = discord.Embed(
            title="NOR Infrastructure",
            description="Todos os serviços estão operando normalmente.",
            color=discord.Color.from_rgb(34, 197, 94),
            timestamp=datetime.now()
        )
        embed.add_field(
            name="Serviços Monitorados",
            value=(
                f"{'🟢' if status['cloudflare'] else '🔴'} Cloudflare DNS\n"
                f"{'🟢' if status['docker'] else '🔴'} Docker Host\n"
                f"{'🟢' if status['network'] else '🔴'} Network\n"
                f"{'🟢' if status['hytale'] else '🔴'} Hytale Server"
            ),
            inline=False
        )
    else:
        embed = discord.Embed(
            title="NOR Infrastructure",
            description="Um ou mais serviços estão indisponíveis.",
            color=discord.Color.from_rgb(239, 68, 68),
            timestamp=datetime.now()
        )
        embed.add_field(
            name="Serviços Monitorados",
            value=(
                f"{'🟢' if status['cloudflare'] else '🔴'} Cloudflare DNS\n"
                f"{'🟢' if status['docker'] else '🔴'} Docker Host\n"
                f"{'🟢' if status['network'] else '🔴'} Network\n"
                f"{'🟢' if status['hytale'] else '🔴'} Hytale Server"
            ),
            inline=False
        )

    embed.add_field(
        name="IP Servidor",
        value=(
            "norhytale.com:25565\n"
        ),
        inline=False
    )

    embed.add_field(
        name="IP Servidor(Reserva)",
        value=(
            "186.219.130.224:25565\n"
        ),
        inline=False
    )

    embed.add_field(
        name="Monitoramento",
        value="https://norhytale.com",
        inline=False
    )

    # Informações adicionais
    ultimo_backup = obter_ultimo_backup()
    versao_servidor = obter_versao_servidor()

    embed.add_field(
        name="Último Backup",
        value=ultimo_backup,
        inline=True
    )

    embed.add_field(
        name="Versão do Servidor",
        value=versao_servidor,
        inline=True
    )

    #embed.set_image(url="https://hytale.com/static/images/logo.png")
    embed.set_image(url="https://i.ibb.co/NdsxQwB7/NOR-Hytale-Logo.png")
    embed.set_footer(text="Monitoramento automático | NOR")

    return embed


# =======================
# LOOP
# =======================

@tasks.loop(seconds=30)
async def checar_status():
    global status_message_id, ultimo_status, ultimo_estado_geral

    canal = client.get_channel(CHANNEL_ID)
    if not canal:
        print("[DEBUG] Canal não encontrado")
        return

    status_atual = {
        "cloudflare": await checar_cloudflare(),
        "docker": await checar_docker(),
        "network": await checar_network(),
        "hytale": await checar_hytale_server(),
        "ultimo_backup": obter_ultimo_backup(),
        "versao": obter_versao_servidor()
    }

    # Verifica estado geral apenas dos serviços (exclui backup e versão)
    servicos = {k: v for k, v in status_atual.items() if k not in ["ultimo_backup", "versao"]}
    estado_geral = all(servicos.values())
    print("[DEBUG] Status atual:", status_atual)

    if status_message_id is None:
        embed = criar_embed(status_atual, estado_geral)
        msg = await canal.send(embed=embed)
        status_message_id = msg.id

        with open(STATUS_FILE, "w") as f:
            f.write(str(status_message_id))

        ultimo_status = status_atual.copy()
        ultimo_estado_geral = estado_geral
        print("[DEBUG] Mensagem inicial criada")
        return

    if status_atual != ultimo_status or estado_geral != ultimo_estado_geral:
        embed = criar_embed(status_atual, estado_geral)

        try:
            msg = await canal.fetch_message(status_message_id)
            await msg.edit(embed=embed)
            print("[DEBUG] Embed atualizado")
        except discord.NotFound:
            msg = await canal.send(embed=embed)
            status_message_id = msg.id

            with open(STATUS_FILE, "w") as f:
                f.write(str(status_message_id))

            print("[DEBUG] Mensagem recriada")

        ultimo_status = status_atual.copy()
        ultimo_estado_geral = estado_geral

# =======================
# START
# =======================

@client.event
async def on_ready():
    global loop_iniciado

    if loop_iniciado:
        print("[DEBUG] on_ready chamado novamente, ignorado")
        return

    loop_iniciado = True
    print(f"Bot conectado como {client.user}")
    checar_status.start()

client.run(TOKEN)
