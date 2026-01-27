#!/bin/bash

# Cores (apenas para status)
RESET='\033[0m'
GREEN='\033[0;32m'
RED='\033[0;31m'

# Ícones
ICON_SERVER="🎮"
ICON_MONITOR="📊"
ICON_BOT="🤖"
ICON_ONLINE="🟢"
ICON_OFFLINE="🔴"
ICON_PAUSED="🟡"
ICON_UNKNOWN="⚪"

clear_screen() {
    clear
    echo ""
}

print_header() {
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║        ⚡ PAINEL DE MANUTENÇÃO - NOR HYTALE ⚡        ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
}

get_container_status() {
    local container=$1
    local status=$(docker inspect -f '{{.State.Status}}' $container 2>/dev/null)

    case "$status" in
        running)
            echo -e "${ICON_ONLINE} ${GREEN}Online${RESET}"
            ;;
        exited)
            echo -e "${ICON_OFFLINE} ${RED}Offline${RESET}"
            ;;
        paused)
            echo -e "${ICON_PAUSED} Pausado"
            ;;
        *)
            echo -e "${ICON_UNKNOWN} Não encontrado"
            ;;
    esac
}

get_container_uptime() {
    local container=$1
    docker inspect -f '{{.State.StartedAt}}' $container 2>/dev/null | xargs -I {} date -d {} +'%d/%m às %H:%M' 2>/dev/null || echo "N/A"
}

show_container_menu() {
    local container=$1
    local icon=$2

    clear_screen
    print_header

    local status=$(get_container_status $container)
    local uptime=$(get_container_uptime $container)

    echo "╭─────────────────────────────────────────────────────╮"
    echo "│  ${icon} ${container}"
    echo "│  Status: ${status}"
    echo "│  Iniciado: ${uptime}"
    echo "╰─────────────────────────────────────────────────────╯"
    echo ""

    echo "O que você deseja fazer?"
    echo ""
    echo "  1) ▶️  Iniciar"
    echo "  2) ⏹️  Parar"
    echo "  3) 🔄 Reiniciar"
    echo "  4) 📋 Ver logs"
    echo "  5) 📋 Ver logs (tempo real)"
    echo "  6) 📊 Ver estatísticas"
    echo "  7) 🔧 Reconstruir container"
    echo "  8) 💻 Acessar shell"
    echo "  9) ℹ️  Ver informações"
    echo "  0) ⬅️  Voltar"
    echo ""
    echo -n "Escolha: "

    read action
    echo ""

    case "$action" in
        1)
            echo "Iniciando ${container}..."
            docker start $container
            echo "✓ Container iniciado"
            ;;
        2)
            echo "Parando ${container}..."
            docker stop $container
            echo "✓ Container parado"
            ;;
        3)
            echo "Reiniciando ${container}..."
            docker restart $container
            echo "✓ Container reiniciado"
            ;;
        4)
            echo "Últimas 50 linhas de log:"
            echo "────────────────────────────────────────────────────"
            docker logs --tail 50 $container
            ;;
        5)
            echo "Logs em tempo real (Ctrl+C para sair):"
            echo "────────────────────────────────────────────────────"
            docker logs -f --tail 20 $container
            ;;
        6)
            echo "Estatísticas em tempo real (Ctrl+C para sair):"
            echo "────────────────────────────────────────────────────"
            docker stats $container
            ;;
        7)
            echo "Reconstruindo ${container}..."
            cd /home/rainz/hytale-server
            docker-compose up -d --build --force-recreate $container
            echo "✓ Container reconstruído"
            ;;
        8)
            echo "Acessando shell do ${container}..."
            echo "(digite 'exit' para sair)"
            docker exec -it $container /bin/bash 2>/dev/null || docker exec -it $container /bin/sh
            ;;
        9)
            echo "Informações do ${container}:"
            echo "────────────────────────────────────────────────────"
            docker inspect $container | head -50
            ;;
        0)
            return
            ;;
        *)
            echo "✗ Opção inválida"
            ;;
    esac

    echo ""
    read -p "Pressione Enter para continuar..."
}

main_menu() {
    while true; do
        clear_screen
        print_header

        echo "Selecione o container:"
        echo ""

        # Hytale Server
        local status1=$(get_container_status "hytale-server")
        echo "  1) ${ICON_SERVER} hytale-server - ${status1}"

        # Uptime Kuma
        local status2=$(get_container_status "uptime-kuma")
        echo "  2) ${ICON_MONITOR} uptime-kuma    - ${status2}"

        # Discord Bot
        local status3=$(get_container_status "discord-bot")
        echo "  3) ${ICON_BOT} discord-bot     - ${status3}"

        echo ""
        echo "  4) 🔄 Reiniciar todos"
        echo "  5) 📊 Ver todos os status"
        echo "  6) 📋 Ver todos os logs"
        echo "  0) 🚪 Sair"
        echo ""
        echo -n "Escolha: "

        read choice

        case "$choice" in
            1)
                show_container_menu "hytale-server" "$ICON_SERVER"
                ;;
            2)
                show_container_menu "uptime-kuma" "$ICON_MONITOR"
                ;;
            3)
                show_container_menu "discord-bot" "$ICON_BOT"
                ;;
            4)
                echo ""
                echo "Reiniciando todos os containers..."
                cd /home/rainz/hytale-server
                docker-compose restart
                echo "✓ Todos os containers foram reiniciados"
                echo ""
                read -p "Pressione Enter para continuar..."
                ;;
            5)
                echo ""
                echo "Status de todos os containers:"
                echo "────────────────────────────────────────────────────"
                docker-compose ps
                echo ""
                read -p "Pressione Enter para continuar..."
                ;;
            6)
                echo ""
                echo "Logs de todos os containers (Ctrl+C para sair):"
                echo "────────────────────────────────────────────────────"
                cd /home/rainz/hytale-server
                docker-compose logs -f --tail 20
                ;;
            0)
                clear_screen
                echo "👋 Até logo!"
                echo ""
                exit 0
                ;;
            *)
                echo ""
                echo "✗ Opção inválida"
                sleep 1
                ;;
        esac
    done
}

# Verificar se Docker está rodando
if ! docker ps > /dev/null 2>&1; then
    clear_screen
    echo "✗ Erro: Docker não está rodando ou você não tem permissão"
    echo ""
    exit 1
fi

# Iniciar menu principal
main_menu
