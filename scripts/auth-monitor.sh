#!/bin/bash

# Hytale Authentication Monitor
# Monitors server logs and alerts when authentication is needed

# Colors - Blue and White theme
RESET='\033[0m'
BLUE='\033[38;5;39m'
CYAN='\033[38;5;51m'
WHITE='\033[1;37m'
GRAY='\033[38;5;245m'
RED='\033[38;5;196m'
YELLOW='\033[38;5;226m'

# Reset colors on exit or interrupt
trap 'echo -e "\033[0m"; exit 130' INT TERM

# Configuration
PROJECT_DIR="/home/rainz/hytale-server"
CONTAINER_NAME="hytale-server"
CHECK_INTERVAL=30  # seconds
NOTIFICATION_FILE="/tmp/hytale_auth_alert.flag"

print_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║           AUTHENTICATION MONITOR                       ║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

check_auth_status() {
    # Pega os últimos 150 logs
    local logs=$(docker logs --tail 150 "$CONTAINER_NAME" 2>&1)

    # Verifica se há erros de autenticação
    if echo "$logs" | grep -qi "session token not available\|make sure to auth first\|authentication unavailable\|auth required"; then
        return 1  # Auth needed
    else
        return 0  # Auth OK
    fi
}

send_auth_command() {
    echo -e "${YELLOW}[!]${RESET} Autenticação necessária detectada!"
    echo ""
    echo -e "${WHITE}ATENÇÃO:${RESET} O servidor Hytale requer autenticação via navegador."
    echo ""
    echo -e "${BLUE}Para autenticar:${RESET}"
    echo -e "  1. Acesse o console do servidor:"
    echo -e "     ${CYAN}docker attach hytale-server${RESET}"
    echo ""
    echo -e "  2. Digite o comando:"
    echo -e "     ${CYAN}/auth login device${RESET}"
    echo ""
    echo -e "  3. Abra o link fornecido no navegador e confirme"
    echo ""
    echo -e "  4. Para sair do console sem parar o servidor:"
    echo -e "     Pressione ${CYAN}Ctrl+P${RESET} seguido de ${CYAN}Ctrl+Q${RESET}"
    echo ""
    echo -e "${WHITE}Ou use o atalho:${RESET}"
    echo -e "     ${CYAN}./scripts/auth-monitor.sh attach${RESET}"
    echo ""
    echo -e "${GRAY}════════════════════════════════════════════════════════${RESET}"
    echo ""
}

monitor_loop() {
    print_header

    echo -e "${BLUE}[>]${RESET} Iniciando monitoramento de autenticação..."
    echo -e "${GRAY}    Intervalo de verificação: ${CHECK_INTERVAL}s${RESET}"
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════${RESET}"
    echo ""

    local last_alert_time=0
    local alert_interval=300  # 5 minutos entre alertas

    while true; do
        local current_time=$(date +%s)

        if ! check_auth_status; then
            local time_since_alert=$((current_time - last_alert_time))

            if [ $time_since_alert -ge $alert_interval ]; then
                echo -e "${RED}[!]${RESET} $(date '+%H:%M:%S') - Autenticação necessária detectada!"

                # Cria flag para alertas externos
                echo "$(date '+%Y-%m-%d %H:%M:%S')" > "$NOTIFICATION_FILE"

                send_auth_command

                last_alert_time=$current_time
            fi
        else
            # Remove flag se autenticação OK
            rm -f "$NOTIFICATION_FILE" 2>/dev/null
            echo -e "${BLUE}[✓]${RESET} $(date '+%H:%M:%S') - Autenticação OK"
        fi

        sleep $CHECK_INTERVAL
    done
}

check_once() {
    if ! check_auth_status; then
        echo -e "${RED}[!]${RESET} Autenticação necessária"
        send_auth_command
        exit 1
    else
        echo -e "${BLUE}[✓]${RESET} Autenticação OK"
        exit 0
    fi
}

show_help() {
    print_header
    echo -e "${WHITE}Uso:${RESET}"
    echo "  $0 [comando]"
    echo ""
    echo -e "${WHITE}Comandos:${RESET}"
    echo "  monitor     - Monitora continuamente (padrão)"
    echo "  check       - Verifica status uma vez"
    echo "  attach      - Abre console do servidor"
    echo "  help        - Mostra esta ajuda"
    echo ""
    echo -e "${GRAY}Exemplos:${RESET}"
    echo "  $0                    # Inicia monitoramento"
    echo "  $0 monitor            # Inicia monitoramento"
    echo "  $0 check              # Verifica uma vez"
    echo "  $0 attach             # Acessa console"
    echo ""
}

attach_console() {
    print_header
    echo -e "${BLUE}[>]${RESET} Abrindo console do servidor Hytale..."
    echo ""
    echo -e "${YELLOW}[!]${RESET} ${WHITE}Para sair sem parar o servidor:${RESET}"
    echo -e "    Pressione ${CYAN}Ctrl+P${RESET} seguido de ${CYAN}Ctrl+Q${RESET}"
    echo ""
    echo -e "${YELLOW}[!]${RESET} ${WHITE}Para autenticar:${RESET}"
    echo -e "    1. Digite: ${CYAN}/auth login device${RESET}"
    echo -e "    2. Abra o link no navegador e confirme"
    echo -e "    3. Aguarde a confirmação no console"
    echo ""
    echo -e "${GRAY}════════════════════════════════════════════════════════${RESET}"
    echo ""
    read -p "Pressione Enter para continuar..."

    docker attach "$CONTAINER_NAME"
}

# Main
case "${1:-monitor}" in
    monitor)
        monitor_loop
        ;;
    check)
        check_once
        ;;
    attach)
        attach_console
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Erro:${RESET} Comando desconhecido: $1"
        echo "Use '$0 help' para ver os comandos disponíveis."
        exit 1
        ;;
esac
