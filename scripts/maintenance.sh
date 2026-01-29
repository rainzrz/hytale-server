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
trap 'echo -e "\033[0m"; /home/rainz/hytale-server/scripts/maintenance-mode.sh disable 2>/dev/null; exit 130' INT TERM EXIT

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
    echo -e "${CYAN}║           CONTAINER MANAGEMENT PANEL                   ║${RESET}"
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

    echo -e "${WHITE}Select an action:${RESET}"
    echo ""
    echo -e "  ${BLUE}1${RESET}) [+] Start container"
    echo -e "  ${BLUE}2${RESET}) [-] Stop container"
    echo -e "  ${BLUE}3${RESET}) [~] Restart container"
    echo -e "  ${BLUE}4${RESET}) [>] View logs"
    echo -e "  ${BLUE}5${RESET}) [>] View logs (live)"
    echo -e "  ${BLUE}6${RESET}) [>] View statistics"
    echo -e "  ${BLUE}7${RESET}) [~] Rebuild container"
    echo -e "  ${BLUE}8${RESET}) [>] Access shell"
    echo -e "  ${BLUE}9${RESET}) [>] View information"
    echo -e "  ${BLUE}0${RESET}) [<] Back"
    echo ""
    echo -ne "${GRAY}Choice: ${RESET}"

    read action
    echo ""

    case "$action" in
        1)
            echo -e "${BLUE}[>]${RESET} Starting ${container}..."
            docker start $container
            echo -e "${BLUE}[OK]${RESET} Container started"
            ;;
        2)
            echo -e "${BLUE}[>]${RESET} Stopping ${container}..."
            docker stop $container
            echo -e "${BLUE}[OK]${RESET} Container stopped"
            ;;
        3)
            echo -e "${BLUE}[>]${RESET} Restarting ${container}..."
            docker restart $container
            echo -e "${BLUE}[OK]${RESET} Container restarted"
            ;;
        4)
            echo -e "${BLUE}[>]${RESET} Last 50 log lines:"
            echo -e "${GRAY}────────────────────────────────────────────────────${RESET}"
            docker logs --tail 50 $container
            ;;
        5)
            echo -e "${BLUE}[>]${RESET} Live logs (Ctrl+C to exit):"
            echo -e "${GRAY}────────────────────────────────────────────────────${RESET}"
            docker logs -f --tail 20 $container
            ;;
        6)
            echo -e "${BLUE}[>]${RESET} Live statistics (Ctrl+C to exit):"
            echo -e "${GRAY}────────────────────────────────────────────────────${RESET}"
            docker stats $container
            ;;
        7)
            echo -e "${BLUE}[>]${RESET} Rebuilding ${container}..."
            cd /home/rainz/hytale-server
            docker-compose up -d --build --force-recreate $container
            echo -e "${BLUE}[OK]${RESET} Container rebuilt"
            ;;
        8)
            echo -e "${BLUE}[>]${RESET} Accessing shell (type 'exit' to quit)..."
            docker exec -it $container /bin/bash 2>/dev/null || docker exec -it $container /bin/sh
            ;;
        9)
            echo -e "${BLUE}[>]${RESET} Container information:"
            echo -e "${GRAY}────────────────────────────────────────────────────${RESET}"
            docker inspect $container | head -50
            ;;
        0)
            return
            ;;
        *)
            echo -e "${GRAY}[!] Invalid option${RESET}"
            ;;
    esac

    echo ""
    read -p "Press Enter to continue..."
}

main_menu() {
    while true; do
        clear_screen
        print_header

        echo -e "${WHITE}Select a container:${RESET}"
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
        echo -e "  ${BLUE}4${RESET}) [~] Restart all containers"
        echo -e "  ${BLUE}5${RESET}) [>] View all status"
        echo -e "  ${BLUE}6${RESET}) [>] View all logs"
        echo -e "  ${BLUE}0${RESET}) [X] Exit"
        echo ""
        echo -ne "${GRAY}Choice: ${RESET}"

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
                echo -e "${BLUE}[>]${RESET} Restarting all containers..."
                cd /home/rainz/hytale-server
                docker-compose restart
                echo -e "${BLUE}[OK]${RESET} All containers restarted"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                echo ""
                echo -e "${BLUE}[>]${RESET} Container status:"
                echo -e "${GRAY}────────────────────────────────────────────────────${RESET}"
                docker-compose ps
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6)
                echo ""
                echo -e "${BLUE}[>]${RESET} Container logs (Ctrl+C to exit):"
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
                echo -e "${GRAY}[!] Invalid option${RESET}"
                sleep 1
                ;;
        esac
    done
}

# Check if Docker is running
if ! docker ps > /dev/null 2>&1; then
    clear_screen
    echo -e "${GRAY}[ERROR] Docker is not running or you don't have permission${RESET}"
    echo ""
    exit 1
fi

# Enable maintenance mode
/home/rainz/hytale-server/scripts/maintenance-mode.sh enable "Manutenção manual em andamento" 2>/dev/null || true

# Disable maintenance mode on exit (trap)
trap '/home/rainz/hytale-server/scripts/maintenance-mode.sh disable 2>/dev/null || true' EXIT INT TERM

# Start main menu
main_menu
