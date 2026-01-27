#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Containers disponíveis
CONTAINERS=("discord-bot" "uptime-kuma" "hytale-server")

print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════╗"
    echo "║       Hytale Server Manager           ║"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${NC}"
}

print_help() {
    print_banner
    echo -e "${YELLOW}Uso:${NC} $0 <container|all> <comando>"
    echo ""
    echo -e "${YELLOW}Containers:${NC}"
    echo "  discord-bot    Bot do Discord"
    echo "  uptime-kuma    Monitor de uptime"
    echo "  hytale-server  Servidor Hytale"
    echo "  all            Todos os containers"
    echo ""
    echo -e "${YELLOW}Comandos:${NC}"
    echo "  start          Iniciar container(s)"
    echo "  stop           Parar container(s)"
    echo "  restart        Reiniciar container(s)"
    echo "  logs           Ver logs (tempo real)"
    echo "  status         Ver status"
    echo "  rebuild        Reconstruir container(s)"
    echo "  down           Remover container(s) (apenas 'all')"
    echo "  attach         Conectar ao console (apenas hytale-server)"
    echo ""
    echo -e "${YELLOW}Exemplos:${NC}"
    echo "  $0 discord-bot restart"
    echo "  $0 all status"
    echo "  $0 hytale-server logs"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

validate_container() {
    local container=$1
    if [[ "$container" != "all" && ! " ${CONTAINERS[@]} " =~ " ${container} " ]]; then
        log_error "Container '$container' não encontrado"
        echo "Containers válidos: ${CONTAINERS[*]} all"
        exit 1
    fi
}

run_command() {
    local container=$1
    local action=$2

    case "$action" in
        start)
            log_info "Iniciando $container..."
            if [[ "$container" == "all" ]]; then
                docker compose up -d
            else
                docker compose up -d "$container"
            fi
            log_success "$container iniciado"
            ;;
        stop)
            log_info "Parando $container..."
            if [[ "$container" == "all" ]]; then
                docker compose stop
            else
                docker compose stop "$container"
            fi
            log_success "$container parado"
            ;;
        restart)
            log_info "Reiniciando $container..."
            if [[ "$container" == "all" ]]; then
                docker compose restart
            else
                docker compose restart "$container"
            fi
            log_success "$container reiniciado"
            ;;
        logs)
            if [[ "$container" == "all" ]]; then
                docker compose logs -f
            else
                docker compose logs -f "$container"
            fi
            ;;
        status)
            if [[ "$container" == "all" ]]; then
                docker compose ps
            else
                docker compose ps "$container"
            fi
            ;;
        rebuild)
            log_info "Reconstruindo $container..."
            if [[ "$container" == "all" ]]; then
                docker compose up -d --build
            else
                docker compose up -d --build "$container"
            fi
            log_success "$container reconstruído"
            ;;
        down)
            if [[ "$container" != "all" ]]; then
                log_error "'down' só funciona com 'all'"
                exit 1
            fi
            log_info "Removendo todos os containers..."
            docker compose down
            log_success "Containers removidos"
            ;;
        attach)
            if [[ "$container" != "hytale-server" ]]; then
                log_error "'attach' só funciona com 'hytale-server'"
                exit 1
            fi
            log_info "Conectando ao console..."
            docker attach hytale-server
            ;;
        *)
            log_error "Comando '$action' não reconhecido"
            print_help
            exit 1
            ;;
    esac
}

# Main
if [[ $# -lt 2 ]]; then
    print_help
    exit 1
fi

CONTAINER=$1
ACTION=$2

validate_container "$CONTAINER"
run_command "$CONTAINER" "$ACTION"
