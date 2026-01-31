import os
import sys
import asyncio
import discord
from discord.ext import tasks
from datetime import datetime
from zoneinfo import ZoneInfo
import socket
import subprocess
import json

# =======================
# CONFIG
# =======================

TOKEN = os.getenv("DISCORD_TOKEN")
CHANNEL_ID_STR = os.getenv("DISCORD_CHANNEL_ID")

STATUS_FILE = "status_message_id.txt"
MAINTENANCE_FILE = "/tmp/hytale_maintenance.flag"
PLAYERS_STATE_FILE = "/app/players_online.json"

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

        # Usa timezone de São Paulo
        tz = ZoneInfo("America/Sao_Paulo")
        data_backup = datetime.fromtimestamp(timestamp, tz=tz)

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
                return version

        return "N/A"

    except Exception as e:
        print("[DEBUG] Erro ao obter versão do servidor:", e)
        return "N/A"


def verificar_autenticacao():
    """Verifica se o servidor precisa de autenticação"""
    try:
        # Verifica os últimos logs do servidor (aumentado para capturar mensagens antigas de boot)
        result = subprocess.run(
            ["docker", "logs", "--tail", "2000", "hytale-server"],
            capture_output=True,
            text=True,
            timeout=5
        )

        logs = result.stdout + result.stderr
        logs_lower = logs.lower()

        # Padrões críticos que indicam necessidade de autenticação
        padroes_criticos = [
            "session token not available",
            "make sure to auth first",
            "authentication unavailable",
            "auth required",
            "no server tokens configured"
        ]

        # Padrões que indicam autenticação bem-sucedida
        padroes_sucesso = [
            "selected profile:",
            "authentication successful",
            "authenticated as",
            "logged in as",
            "found 2 game profile(s)",
            "found 1 game profile(s)",
            "multiple profiles available"
        ]

        # Verifica se há mensagens de sucesso (autenticação foi feita)
        tem_sucesso = any(padrao_sucesso in logs_lower for padrao_sucesso in padroes_sucesso)

        # Verifica padrões críticos de erro
        tem_erro_auth = False

        if tem_sucesso:
            # Se há evidências de autenticação bem-sucedida, verifica se está aguardando seleção de perfil
            if "multiple profiles available" in logs_lower and "selected profile:" not in logs_lower:
                print("[DEBUG] Autenticação OK mas aguardando seleção de perfil")
                tem_erro_auth = False  # Não é erro de autenticação, apenas precisa selecionar perfil
            else:
                print("[DEBUG] Autenticação bem-sucedida detectada - ignorando erros antigos")
                tem_erro_auth = False
        else:
            # Só verifica erros se não há evidências de sucesso
            for padrao in padroes_criticos:
                if padrao in logs_lower:
                    print(f"[DEBUG] Padrão de erro '{padrao}' encontrado sem evidência de sucesso")
                    tem_erro_auth = True
                    break

        # Verifica se há muitos erros de handshake (indica problema de auth)
        tem_erro_handshake = False
        contador_handshake = logs_lower.count("handshakehandler")
        if contador_handshake >= 5:
            # Verifica se não há mensagens de autenticação bem-sucedida
            if "authenticated" not in logs_lower and "login successful" not in logs_lower:
                tem_erro_handshake = True

        # Se encontrou erros reais nos logs, retorna erro
        if tem_erro_auth:
            return "⚠️ Necessária", "Use: /auth login device"

        if tem_erro_handshake:
            return "⚠️ Atenção", "Possível problema de auth"

        # Se não há erros nos logs, limpa flag antiga se existir
        try:
            if os.path.exists("/tmp/hytale_auth_alert.flag"):
                os.remove("/tmp/hytale_auth_alert.flag")
                print("[DEBUG] Flag de alerta removida - autenticação OK confirmada pelos logs")
        except Exception as e:
            print(f"[DEBUG] Não foi possível remover flag: {e}")

        return "✅ OK", ""

    except subprocess.TimeoutExpired:
        print("[DEBUG] Timeout ao verificar autenticação")
        return "⚠️ Timeout", ""
    except Exception as e:
        print("[DEBUG] Erro ao verificar autenticação:", e)
        return "❓ Erro", ""


def carregar_estado_players():
    """Carrega o estado persistente dos jogadores online"""
    try:
        if os.path.exists(PLAYERS_STATE_FILE):
            with open(PLAYERS_STATE_FILE, 'r') as f:
                return set(json.load(f))
        return set()
    except Exception as e:
        print(f"[DEBUG] Erro ao carregar estado de players: {e}")
        return set()


def salvar_estado_players(players_set):
    """Salva o estado persistente dos jogadores online"""
    try:
        with open(PLAYERS_STATE_FILE, 'w') as f:
            json.dump(list(players_set), f)
        print(f"[DEBUG] Estado salvo: {list(players_set)}")
    except Exception as e:
        print(f"[DEBUG] Erro ao salvar estado de players: {e}")


def obter_players_online():
    """Obtém a lista de players atualmente online no servidor usando estado persistente"""
    try:
        # Carrega estado anterior (quem estava online)
        players_online = carregar_estado_players()

        print(f"[DEBUG] Estado carregado: {list(players_online)}")

        # Se a lista está vazia (primeira execução ou servidor reiniciou),
        # processa histórico completo para detectar quem está online
        if len(players_online) == 0:
            print("[DEBUG] ⚠️ Lista vazia - processando histórico completo")
            tail_lines = "2000"
        else:
            tail_lines = "200"

        result = subprocess.run(
            ["docker", "logs", "--tail", tail_lines, "hytale-server"],
            capture_output=True,
            text=True,
            timeout=5
        )

        logs = result.stdout + result.stderr
        lines = logs.split('\n')

        # Detecta reinicialização do servidor
        # Se o servidor reiniciou, reseta a lista de players
        if "Starting Hytale server" in logs or "Server started" in logs:
            print("[DEBUG] ⚠️ Servidor reiniciou - resetando lista de players")
            players_online = set()

        # Processa apenas mudanças recentes
        for line in lines:
            # Padrão: [Universe|P] Adding player 'nome (uuid)'
            if "[Universe|P] Adding player" in line:
                try:
                    # Extrai o nome: começa após ' e termina antes de ' ('
                    start = line.find("'") + 1
                    end = line.find(" (", start)
                    if start > 0 and end > start:
                        player_name = line[start:end].strip()
                        if player_name not in players_online:
                            players_online.add(player_name)
                            print(f"[DEBUG] ✅ Player conectou: {player_name}")
                except Exception as e:
                    print(f"[DEBUG] Erro ao parsear Adding: {line[:100]}", e)

            # Padrão: [Universe|P] Removing player 'nome' (uuid)
            elif "[Universe|P] Removing player" in line:
                try:
                    # Extrai o nome: começa após ' e termina antes de ' (' ou '''
                    start = line.find("'") + 1
                    # Tenta encontrar ' (' primeiro, se não encontrar usa a segunda '
                    end_paren = line.find(" (", start)
                    end_quote = line.find("'", start)

                    if end_paren > start:
                        end = end_paren
                    elif end_quote > start:
                        end = end_quote
                    else:
                        end = -1

                    if start > 0 and end > start:
                        player_name = line[start:end].strip()
                        if player_name in players_online:
                            players_online.discard(player_name)
                            print(f"[DEBUG] ❌ Player desconectou: {player_name}")
                except Exception as e:
                    print(f"[DEBUG] Erro ao parsear Removing: {line[:100]}", e)

        # Salva estado atualizado
        salvar_estado_players(players_online)

        # Retorna contagem, lista de nomes, e max players
        players_list = sorted(list(players_online))
        count = len(players_list)

        print(f"[DEBUG] Players online: {count} - {players_list}")

        return count, players_list, 100  # max_players = 100

    except subprocess.TimeoutExpired:
        print("[DEBUG] Timeout ao obter players online")
        # Em caso de timeout, retorna estado anterior
        players_online = carregar_estado_players()
        return len(players_online), sorted(list(players_online)), 100
    except Exception as e:
        print("[DEBUG] Erro ao obter players online:", e)
        # Em caso de erro, retorna estado anterior
        players_online = carregar_estado_players()
        return len(players_online), sorted(list(players_online)), 100


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

    # Prepara status de autenticação
    if em_manutencao:
        auth_status = "🔵"
    else:
        status_auth, detalhes_auth = status['autenticacao']
        if "✅" in status_auth:
            auth_status = "🟢"
        elif "⚠️" in status_auth:
            auth_status = "🔴"
        else:
            auth_status = "⚠️"

    if em_manutencao:
        embed = discord.Embed(
            title="NOR Infrastructure",
            description=f"🔧 **MANUTENÇÃO EM ANDAMENTO**\n\n{motivo_manutencao}",
            color=discord.Color.from_rgb(59, 130, 246),  # Azul
            timestamp=datetime.now(ZoneInfo("America/Sao_Paulo"))
        )
        # Em manutenção, todos os indicadores ficam azuis
        embed.add_field(
            name="Serviços Monitorados",
            value=(
                f"🔵 Cloudflare DNS\n"
                f"🔵 Docker Host\n"
                f"🔵 Network\n"
                f"🔵 Hytale Server\n"
                f"🔵 Autenticação"
            ),
            inline=False
        )
    elif tudo_ok:
        embed = discord.Embed(
            title="NOR Infrastructure",
            description="Todos os serviços estão operando normalmente.",
            color=discord.Color.from_rgb(34, 197, 94),
            timestamp=datetime.now(ZoneInfo("America/Sao_Paulo"))
        )
        embed.add_field(
            name="Serviços Monitorados",
            value=(
                f"{'🟢' if status['cloudflare'] else '🔴'} Cloudflare DNS\n"
                f"{'🟢' if status['docker'] else '🔴'} Docker Host\n"
                f"{'🟢' if status['network'] else '🔴'} Network\n"
                f"{'🟢' if status['hytale'] else '🔴'} Hytale Server\n"
                f"{auth_status} Autenticação"
            ),
            inline=False
        )
    else:
        embed = discord.Embed(
            title="NOR Infrastructure",
            description="Um ou mais serviços estão indisponíveis.",
            color=discord.Color.from_rgb(239, 68, 68),
            timestamp=datetime.now(ZoneInfo("America/Sao_Paulo"))
        )
        embed.add_field(
            name="Serviços Monitorados",
            value=(
                f"{'🟢' if status['cloudflare'] else '🔴'} Cloudflare DNS\n"
                f"{'🟢' if status['docker'] else '🔴'} Docker Host\n"
                f"{'🟢' if status['network'] else '🔴'} Network\n"
                f"{'🟢' if status['hytale'] else '🔴'} Hytale Server\n"
                f"{auth_status} Autenticação"
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

    # Players Online
    if not em_manutencao and status['hytale']:
        count, players_list, max_players = status['players']
        if count > 0:
            players_str = ", ".join(players_list)
            embed.add_field(
                name="Players Online",
                value=f"**{count}/{max_players}** jogadores\n{players_str}",
                inline=False
            )
        else:
            embed.add_field(
                name="Players Online",
                value=f"**0/{max_players}** jogadores\nNenhum jogador online",
                inline=False
            )
    elif em_manutencao:
        embed.add_field(
            name="Players Online",
            value="🔵 Em manutenção",
            inline=False
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
        "versao": obter_versao_servidor(),
        "autenticacao": verificar_autenticacao(),
        "players": obter_players_online()
    }

    # Verifica estado geral apenas dos serviços (exclui backup, versão, autenticação e players)
    servicos = {k: v for k, v in status_atual.items() if k not in ["ultimo_backup", "versao", "autenticacao", "players"]}
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
