#!/bin/bash

# Cores
RESET='\033[0m'
GREEN='\033[38;2;0;255;100m'
YELLOW='\033[38;2;255;200;0m'
RED='\033[38;2;255;50;50m'
BLUE='\033[38;2;100;150;255m'
CYAN='\033[38;2;0;200;255m'
PURPLE='\033[38;2;200;100;255m'
GRAY='\033[38;2;150;150;150m'

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
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${PURPLE}║${RESET}        ${CYAN}⚡ PAINEL DE MANUTENÇÃO - NOR HYTALE ⚡${RESET}        ${PURPLE}║${RESET}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════╝${RESET}"
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
            echo -e "${ICON_PAUSED} ${YELLOW}Pausado${RESET}"
            ;;
        *)
            echo -e "${ICON_UNKNOWN} ${GRAY}Não encontrado${RESET}"
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

    echo -e "${CYAN}╭─────────────────────────────────────────────────────╮${RESET}"
    echo -e "${CYAN}│${RESET}  ${icon} ${BLUE}${container}${RESET}"
    echo -e "${CYAN}│${RESET}  Status: ${status}"
    echo -e "${CYAN}│${RESET}  Iniciado: ${GRAY}${uptime}${RESET}"
    echo -e "${CYAN}╰─────────────────────────────────────────────────────╯${RESET}"
    echo ""

    echo -e "${YELLOW}O que você deseja fazer?${RESET}"
    echo ""
    echo -e "  ${GREEN}1)${RESET} ▶️  Iniciar"
    echo -e "  ${RED}2)${RESET} ⏹️  Parar"
    echo -e "  ${YELLOW}3)${RESET} 🔄 Reiniciar"
    echo -e "  ${CYAN}4)${RESET} 📋 Ver logs"
    echo -e "  ${CYAN}5)${RESET} 📋 Ver logs (tempo real)"
    echo -e "  ${BLUE}6)${RESET} 📊 Ver estatísticas"
    echo -e "  ${PURPLE}7)${RESET} 🔧 Reconstruir container"
    echo -e "  ${PURPLE}8)${RESET} 💻 Acessar shell"
    echo -e "  ${BLUE}9)${RESET} ℹ️  Ver informações"
    echo -e "  ${GRAY}0)${RESET} ⬅️  Voltar"
    echo ""
    echo -n "Escolha: "

    read action
    echo ""

    case "$action" in
        1)
            echo -e "${GREEN}Iniciando ${container}...${RESET}"
            docker start $container
            echo -e "${GREEN}✓ Container iniciado${RESET}"
            ;;
        2)
            echo -e "${RED}Parando ${container}...${RESET}"
            docker stop $container
            echo -e "${RED}✓ Container parado${RESET}"
            ;;
        3)
            echo -e "${YELLOW}Reiniciando ${container}...${RESET}"
            docker restart $container
            echo -e "${YELLOW}✓ Container reiniciado${RESET}"
            ;;
        4)
            echo -e "${CYAN}Últimas 50 linhas de log:${RESET}"
            echo -e "${GRAY}────────────────────────────────────────────────────${RESET}"
            docker logs --tail 50 $container
            ;;
        5)
            echo -e "${CYAN}Logs em tempo real (Ctrl+C para sair):${RESET}"
            echo -e "${GRAY}────────────────────────────────────────────────────${RESET}"
            docker logs -f --tail 20 $container
            ;;
        6)
            echo -e "${BLUE}Estatísticas em tempo real (Ctrl+C para sair):${RESET}"
            echo -e "${GRAY}────────────────────────────────────────────────────${RESET}"
            docker stats $container
            ;;
        7)
            echo -e "${PURPLE}Reconstruindo ${container}...${RESET}"
            cd /home/rainz/hytale-server
            docker-compose up -d --build --force-recreate $container
            echo -e "${PURPLE}✓ Container reconstruído${RESET}"
            ;;
        8)
            echo -e "${PURPLE}Acessando shell do ${container}...${RESET}"
            echo -e "${GRAY}(digite 'exit' para sair)${RESET}"
            docker exec -it $container /bin/bash 2>/dev/null || docker exec -it $container /bin/sh
            ;;
        9)
            echo -e "${BLUE}Informações do ${container}:${RESET}"
            echo -e "${GRAY}────────────────────────────────────────────────────${RESET}"
            docker inspect $container | head -50
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}✗ Opção inválida${RESET}"
            ;;
    esac

    echo ""
    read -p "Pressione Enter para continuar..."
}

main_menu() {
    while true; do
        clear_screen
        print_header

        echo -e "${YELLOW}Selecione o container:${RESET}"
        echo ""

        # Hytale Server
        local status1=$(get_container_status "hytale-server")
        echo -e "  ${GREEN}1)${RESET} ${ICON_SERVER} ${BLUE}hytale-server${RESET} - ${status1}"

        # Uptime Kuma
        local status2=$(get_container_status "uptime-kuma")
        echo -e "  ${GREEN}2)${RESET} ${ICON_MONITOR} ${BLUE}uptime-kuma${RESET}    - ${status2}"

        # Discord Bot
        local status3=$(get_container_status "discord-bot")
        echo -e "  ${GREEN}3)${RESET} ${ICON_BOT} ${BLUE}discord-bot${RESET}     - ${status3}"

        echo ""
        echo -e "  ${CYAN}4)${RESET} 🔄 Reiniciar todos"
        echo -e "  ${CYAN}5)${RESET} 📊 Ver todos os status"
        echo -e "  ${CYAN}6)${RESET} 📋 Ver todos os logs"
        echo -e "  ${RED}0)${RESET} 🚪 Sair"
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
                echo -e "${YELLOW}Reiniciando todos os containers...${RESET}"
                cd /home/rainz/hytale-server
                docker-compose restart
                echo -e "${GREEN}✓ Todos os containers foram reiniciados${RESET}"
                echo ""
                read -p "Pressione Enter para continuar..."
                ;;
            5)
                echo ""
                echo -e "${CYAN}Status de todos os containers:${RESET}"
                echo -e "${GRAY}────────────────────────────────────────────────────${RESET}"
                docker-compose ps
                echo ""
                read -p "Pressione Enter para continuar..."
                ;;
            6)
                echo ""
                echo -e "${CYAN}Logs de todos os containers (Ctrl+C para sair):${RESET}"
                echo -e "${GRAY}────────────────────────────────────────────────────${RESET}"
                cd /home/rainz/hytale-server
                docker-compose logs -f --tail 20
                ;;
            0)
                clear_screen
                echo -e "${GREEN}👋 Até logo!${RESET}"
                echo ""
                exit 0
                ;;
            *)
                echo ""
                echo -e "${RED}✗ Opção inválida${RESET}"
                sleep 1
                ;;
        esac
    done
}

# Verificar se Docker está rodando
if ! docker ps > /dev/null 2>&1; then
    clear_screen
    echo -e "${RED}✗ Erro: Docker não está rodando ou você não tem permissão${RESET}"
    echo ""
    exit 1
fi

# Iniciar menu principal
main_menu
