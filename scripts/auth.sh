#!/bin/bash

# Monitor de Autenticação do Hytale
# Monitora logs do servidor e alerta quando autenticação é necessária

# Cores - Tema Azul e Branco
RESET='\033[0m'
BLUE='\033[38;5;39m'
CYAN='\033[38;5;51m'
WHITE='\033[1;37m'
GRAY='\033[38;5;245m'
RED='\033[38;5;196m'
YELLOW='\033[38;5;226m'

# Reseta cores ao sair ou interromper
trap 'echo -e "\033[0m"; exit 130' INT TERM

# Configuração
PROJECT_DIR="/home/rainz/hytale-server"
CONTAINER_NAME="hytale-server"
CHECK_INTERVAL=30  # segundos
NOTIFICATION_FILE="/tmp/hytale_auth_alert.flag"

print_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║           MONITOR DE AUTENTICAÇÃO                      ║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

check_auth_status() {
    # Pega os últimos 2000 logs (aumentado para capturar mensagens antigas de boot)
    local logs=$(docker logs --tail 2000 "$CONTAINER_NAME" 2>&1)
    local logs_lower=$(echo "$logs" | tr '[:upper:]' '[:lower:]')

    # Padrões de sucesso (autenticação bem-sucedida)
    local padroes_sucesso=(
        "selected profile:"
        "authentication successful"
        "authenticated as"
        "logged in as"
        "found 2 game profile(s)"
        "found 1 game profile(s)"
        "multiple profiles available"
    )

    # Verifica se há mensagens de sucesso
    local tem_sucesso=false
    for padrao in "${padroes_sucesso[@]}"; do
        if echo "$logs_lower" | grep -q "$padrao"; then
            tem_sucesso=true
            break
        fi
    done

    # Se encontrou sucesso, verifica se foi DEPOIS dos erros
    if [ "$tem_sucesso" = true ]; then
        # Se tem múltiplos perfis mas não foi selecionado, ainda precisa autenticar
        if echo "$logs_lower" | grep -q "multiple profiles available" && ! echo "$logs_lower" | grep -q "selected profile:"; then
            return 1  # Precisa selecionar perfil
        else
            return 0  # Autenticação OK
        fi
    fi

    # Verifica se há erros de autenticação
    if echo "$logs" | grep -qi "session token not available\|make sure to auth first\|authentication unavailable\|auth required\|no server tokens configured"; then
        return 1  # Autenticação necessária
    else
        return 0  # Autenticação OK
    fi
}

send_auth_command() {
    echo -e "${YELLOW}[!]${RESET} Autenticação necessária detectada!"
    echo ""
    echo -e "${WHITE}ATENÇÃO:${RESET} O servidor Hytale requer autenticação via navegador."
    echo ""
    echo -e "${BLUE}O que deseja fazer?${RESET}"
    echo ""
    echo -e "  ${CYAN}[A]${RESET} Iniciar processo de autenticação automática"
    echo -e "  ${GRAY}[I]${RESET} Ignorar e continuar monitorando"
    echo -e "  ${GRAY}[Q]${RESET} Sair do monitor"
    echo ""
    echo -ne "${WHITE}Escolha: ${RESET}"

    # Read single character without waiting for Enter
    read -n 1 -r choice
    echo ""
    echo ""

    case "$choice" in
        [Aa])
            # Usa o helper script de autenticação
            "$PROJECT_DIR/scripts/.auth-helper.sh" "$CONTAINER_NAME"

            # Limpa tela novamente
            clear
            echo ""
            echo -e "${BLUE}[✓]${RESET} Processo de autenticação finalizado."
            echo -e "${GRAY}Voltando ao monitoramento...${RESET}"
            echo ""
            sleep 2
            ;;
        [Ii])
            echo -e "${GRAY}[~]${RESET} Continuando monitoramento..."
            ;;
        [Qq])
            echo -e "${GRAY}[X]${RESET} Saindo do monitor..."
            exit 0
            ;;
        *)
            echo -e "${GRAY}[~]${RESET} Opção inválida, continuando monitoramento..."
            ;;
    esac
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
    # Usa o helper script de autenticação
    "$PROJECT_DIR/scripts/.auth-helper.sh" "$CONTAINER_NAME"
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
