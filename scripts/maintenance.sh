#!/bin/bash

# Container Management Panel
# Interactive menu for managing Docker containers

# Colors - Blue and White theme
RESET='\033[0m'
BLUE='\033[38;5;39m'
CYAN='\033[38;5;51m'
WHITE='\033[1;37m'
GRAY='\033[38;5;245m'

# Reset colors on exit or interrupt
trap 'echo -e "\033[0m"; /home/rainz/hytale-server/scripts/.maintenance-mode.sh disable 2>/dev/null; exit 130' INT TERM EXIT

# Status indicators
ONLINE="${BLUE}[ONLINE]${RESET}"
OFFLINE="${GRAY}[OFFLINE]${RESET}"
PAUSED="${GRAY}[PAUSED]${RESET}"
UNKNOWN="${GRAY}[UNKNOWN]${RESET}"

clear_screen() {
    clear
    echo ""
}

print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║      PAINEL DE GERENCIAMENTO DE CONTÊINERES            ║${RESET}"
    echo -e "${CYAN}║           NOR HYTALE INFRASTRUCTURE                    ║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

get_container_status() {
    local container=$1
    local status=$(docker inspect -f '{{.State.Status}}' $container 2>/dev/null)

    case "$status" in
        running)
            echo -e "$ONLINE"
            ;;
        exited)
            echo -e "$OFFLINE"
            ;;
        paused)
            echo -e "$PAUSED"
            ;;
        *)
            echo -e "$UNKNOWN"
            ;;
    esac
}

get_container_uptime() {
    local container=$1
    docker inspect -f '{{.State.StartedAt}}' $container 2>/dev/null | xargs -I {} date -d {} +'%d/%m às %H:%M' 2>/dev/null || echo "N/A"
}

show_container_menu() {
    local container=$1
    local display_name=$2

    clear_screen
    print_header

    local status=$(get_container_status $container)
    local uptime=$(get_container_uptime $container)

    echo -e "${WHITE}╭─────────────────────────────────────────────────────╮${RESET}"
    echo -e "${WHITE}│${RESET}  ${CYAN}$display_name${RESET}"
    echo -e "${WHITE}│${RESET}  Status: ${status}"
    echo -e "${WHITE}│${RESET}  Started: ${GRAY}${uptime}${RESET}"
    echo -e "${WHITE}╰─────────────────────────────────────────────────────╯${RESET}"
    echo ""

    echo -e "${WHITE}Selecione uma ação:${RESET}"
    echo ""
    echo -e "  ${BLUE}1${RESET}) [+] Iniciar contêiner"
    echo -e "  ${BLUE}2${RESET}) [-] Parar contêiner"
    echo -e "  ${BLUE}3${RESET}) [~] Reiniciar contêiner"
    echo -e "  ${BLUE}4${RESET}) [>] Ver logs"
    echo -e "  ${BLUE}5${RESET}) [>] Ver logs (ao vivo)"
    echo -e "  ${BLUE}6${RESET}) [>] Ver estatísticas"
    echo -e "  ${BLUE}7${RESET}) [~] Rebuildar contêiner"
    echo -e "  ${BLUE}8${RESET}) [>] Acessar shell"
    echo -e "  ${BLUE}9${RESET}) [>] Ver informações"
    echo -e "  ${BLUE}0${RESET}) [<] Voltar"
    echo ""
    echo -ne "${GRAY}Escolha: ${RESET}"

    read action
    echo ""

    case "$action" in
        1)
            echo -e "${BLUE}[>]${RESET} Iniciando ${container}..."
            docker start $container
            echo -e "${BLUE}[OK]${RESET} Contêiner iniciado"
            ;;
        2)
            echo -e "${BLUE}[>]${RESET} Parando ${container}..."
            docker stop $container
            echo -e "${BLUE}[OK]${RESET} Contêiner parado"
            ;;
        3)
            echo -e "${BLUE}[>]${RESET} Reiniciando ${container}..."
            docker restart $container
            echo -e "${BLUE}[OK]${RESET} Contêiner reiniciado"
            ;;
        4)
            echo -e "${BLUE}[>]${RESET} Últimas 50 linhas de log:"
            echo -e "${GRAY}────────────────────────────────────────────────────${RESET}"
            docker logs --tail 50 $container
            ;;
        5)
            echo -e "${BLUE}[>]${RESET} Logs ao vivo (Ctrl+C para sair):"
            echo -e "${GRAY}────────────────────────────────────────────────────${RESET}"
            docker logs -f --tail 20 $container
            ;;
        6)
            echo -e "${BLUE}[>]${RESET} Estatísticas ao vivo (Ctrl+C para sair):"
            echo -e "${GRAY}────────────────────────────────────────────────────${RESET}"
            docker stats $container
            ;;
        7)
            echo -e "${BLUE}[>]${RESET} Rebuildando ${container}..."
            cd /home/rainz/hytale-server
            docker-compose up -d --build --force-recreate $container
            echo -e "${BLUE}[OK]${RESET} Contêiner rebuilded"
            ;;
        8)
            echo -e "${BLUE}[>]${RESET} Acessando shell (digite 'exit' para sair)..."
            docker exec -it $container /bin/bash 2>/dev/null || docker exec -it $container /bin/sh
            ;;
        9)
            echo -e "${BLUE}[>]${RESET} Informações do contêiner:"
            echo -e "${GRAY}────────────────────────────────────────────────────${RESET}"
            docker inspect $container | head -50
            ;;
        0)
            return
            ;;
        *)
            echo -e "${GRAY}[!] Opção inválida${RESET}"
            ;;
    esac

    echo ""
    read -p "Pressione Enter para continuar..."
}

main_menu() {
    while true; do
        clear_screen
        print_header

        echo -e "${WHITE}Selecione um contêiner:${RESET}"
        echo ""

        # Hytale Server
        local status1=$(get_container_status "hytale-server")
        echo -e "  ${BLUE}1${RESET}) [SERVER] hytale-server ${status1}"

        # Uptime Kuma
        local status2=$(get_container_status "uptime-kuma")
        echo -e "  ${BLUE}2${RESET}) [MONITOR] uptime-kuma ${status2}"

        # Discord Bot
        local status3=$(get_container_status "discord-bot")
        echo -e "  ${BLUE}3${RESET}) [BOT] discord-bot ${status3}"

        echo ""
        echo -e "  ${BLUE}4${RESET}) [~] Reiniciar todos os contêineres"
        echo -e "  ${BLUE}5${RESET}) [>] Ver status de todos"
        echo -e "  ${BLUE}6${RESET}) [>] Ver todos os logs"
        echo -e "  ${BLUE}0${RESET}) [X] Sair"
        echo ""
        echo -ne "${GRAY}Escolha: ${RESET}"

        read choice

        case "$choice" in
            1)
                show_container_menu "hytale-server" "HYTALE SERVER"
                ;;
            2)
                show_container_menu "uptime-kuma" "UPTIME KUMA MONITOR"
                ;;
            3)
                show_container_menu "discord-bot" "DISCORD BOT"
                ;;
            4)
                echo ""
                echo -e "${BLUE}[>]${RESET} Reiniciando todos os contêineres..."
                cd /home/rainz/hytale-server
                docker-compose restart
                echo -e "${BLUE}[OK]${RESET} Todos os contêineres reiniciados"
                echo ""
                read -p "Pressione Enter para continuar..."
                ;;
            5)
                echo ""
                echo -e "${BLUE}[>]${RESET} Status dos contêineres:"
                echo -e "${GRAY}────────────────────────────────────────────────────${RESET}"
                docker-compose ps
                echo ""
                read -p "Pressione Enter para continuar..."
                ;;
            6)
                echo ""
                echo -e "${BLUE}[>]${RESET} Logs dos contêineres (Ctrl+C para sair):"
                echo -e "${GRAY}────────────────────────────────────────────────────${RESET}"
                cd /home/rainz/hytale-server
                docker-compose logs -f --tail 20
                ;;
            0)
                clear_screen
                exit 0
                ;;
            *)
                echo ""
                echo -e "${GRAY}[!] Opção inválida${RESET}"
                sleep 1
                ;;
        esac
    done
}

# Check if Docker is running
if ! docker ps > /dev/null 2>&1; then
    clear_screen
    echo -e "${GRAY}[ERROR] Docker não está rodando ou você não tem permissão${RESET}"
    echo ""
    exit 1
fi

# Enable maintenance mode
/home/rainz/hytale-server/scripts/.maintenance-mode.sh enable "Manutenção manual em andamento" 2>/dev/null || true

# Disable maintenance mode on exit (trap)
trap '/home/rainz/hytale-server/scripts/.maintenance-mode.sh disable 2>/dev/null || true' EXIT INT TERM

# Start main menu
main_menu
