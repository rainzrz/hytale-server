#!/bin/bash

# Maintenance Mode Controller for Discord Bot
# Controls the maintenance flag that triggers blue status circles

# Colors - Blue and White theme
RESET='\033[0m'
BLUE='\033[38;5;39m'
CYAN='\033[38;5;51m'
WHITE='\033[1;37m'
GRAY='\033[38;5;245m'

# Reset colors on exit or interrupt
trap 'echo -e "\033[0m"; exit 130' INT TERM

MAINTENANCE_FILE="/tmp/hytale_maintenance.flag"
PROJECT_DIR="/home/rainz/hytale-server"

print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║           MAINTENANCE MODE CONTROLLER                  ║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

show_progress() {
    local message="$1"
    echo -ne "${BLUE}[>]${RESET} $message"

    for i in {1..10}; do
        echo -ne "."
        sleep 0.15
    done
    echo -e " ${BLUE}[OK]${RESET}"
}

enable_maintenance() {
    local motivo="$1"
    if [ -z "$motivo" ]; then
        motivo="Manutenção em andamento"
    fi

    clear
    print_header

    echo "$motivo" | sudo tee "$MAINTENANCE_FILE" > /dev/null
    sudo chmod 666 "$MAINTENANCE_FILE"
    show_progress "Ativando modo de manutenção"

    # Restart bot to apply changes in background
    cd "$PROJECT_DIR" 2>/dev/null
    (sudo docker compose restart discord-bot 2>/dev/null || sudo docker-compose restart discord-bot 2>/dev/null) > /dev/null 2>&1 &

    echo ""
}

disable_maintenance() {
    clear
    print_header

    sudo rm -f "$MAINTENANCE_FILE"
    show_progress "Desativando modo de manutenção"

    # Restart bot to apply changes in background
    cd "$PROJECT_DIR" 2>/dev/null
    (sudo docker compose restart discord-bot 2>/dev/null || sudo docker-compose restart discord-bot 2>/dev/null) > /dev/null 2>&1 &

    echo ""
}

show_status() {
    clear
    print_header

    if [ -f "$MAINTENANCE_FILE" ]; then
        local motivo=$(cat "$MAINTENANCE_FILE")
        echo -e "${CYAN}════════════════════════════════════════════════════════${RESET}"
        echo -e "  Status: ${WHITE}ATIVO${RESET}"
        echo -e "  Motivo: ${GRAY}$motivo${RESET}"
        echo -e "${CYAN}════════════════════════════════════════════════════════${RESET}"
    else
        echo -e "${CYAN}════════════════════════════════════════════════════════${RESET}"
        echo -e "  Status: ${WHITE}INATIVO${RESET}"
        echo -e "${CYAN}════════════════════════════════════════════════════════${RESET}"
    fi
    echo ""
}

case "$1" in
    enable)
        enable_maintenance "$2"
        ;;
    disable)
        disable_maintenance
        ;;
    status)
        show_status
        ;;
    *)
        clear
        print_header
        echo -e "${WHITE}Usage:${RESET}"
        echo "  $0 enable [reason]    - Enable maintenance mode"
        echo "  $0 disable            - Disable maintenance mode"
        echo "  $0 status             - Check maintenance status"
        echo ""
        echo -e "${GRAY}Examples:${RESET}"
        echo "  $0 enable 'Backup em andamento'"
        echo "  $0 enable 'Atualização do servidor'"
        echo "  $0 disable"
        echo "  $0 status"
        echo ""
        exit 1
        ;;
esac
