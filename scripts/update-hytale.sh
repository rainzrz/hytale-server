#!/bin/bash

# Atualizador do Servidor Hytale
# Baixa e instala a versão mais recente do servidor Hytale

# Colors - Blue and White theme
RESET='\033[0m'
BLUE='\033[38;5;39m'
CYAN='\033[38;5;51m'
WHITE='\033[1;37m'
GRAY='\033[38;5;245m'

# Reset colors on exit or interrupt and disable maintenance
trap 'echo -e "\033[0m"; /home/rainz/hytale-server/scripts/.maintenance-mode.sh disable 2>/dev/null > /dev/null; exit 130' INT TERM

# Directories
PROJECT_DIR="/home/rainz/hytale-server"
SERVER_DIR="$PROJECT_DIR/.server"
TOOLS_DIR="$PROJECT_DIR/tools"
DOWNLOADER="$TOOLS_DIR/hytale-downloader-linux-amd64"

# Patchline (will be set interactively)
PATCHLINE=""

# Functions
print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║           ATUALIZADOR DO SERVIDOR HYTALE               ║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

print_step() {
    echo -e "${BLUE}[>]${RESET} $1"
}

print_success() {
    echo -e "${BLUE}[OK]${RESET} $1"
}

print_error() {
    echo -e "${GRAY}[ERRO]${RESET} $1"
}

print_warning() {
    echo -e "${GRAY}[AVISO]${RESET} $1"
}

# Initial checks
check_requirements() {
    print_step "Verificando requisitos..."

    # Check if in correct directory
    if [ ! -d "$PROJECT_DIR" ]; then
        print_error "Diretório do projeto não encontrado: $PROJECT_DIR"
        exit 1
    fi

    # Check if Docker is running
    if ! docker ps > /dev/null 2>&1; then
        print_error "Docker não está rodando ou você não tem permissão"
        exit 1
    fi

    # Check if downloader exists
    if [ ! -f "$DOWNLOADER" ]; then
        print_error "Downloader do Hytale não encontrado: $DOWNLOADER"
        exit 1
    fi

    # Check if downloader has execution permission
    if [ ! -x "$DOWNLOADER" ]; then
        print_warning "Adicionando permissão de execução ao downloader..."
        chmod +x "$DOWNLOADER"
    fi

    print_success "Todos os requisitos verificados"
    echo ""
}

# Show current version
show_current_version() {
    print_step "Versão instalada atualmente:"

    if [ -f "$SERVER_DIR/HytaleServer.jar" ]; then
        # Extract version from manifest
        local version=$(unzip -p "$SERVER_DIR/HytaleServer.jar" META-INF/MANIFEST.MF 2>/dev/null | grep "Implementation-Version:" | cut -d' ' -f2 | tr -d '\r')

        if [ -n "$version" ]; then
            echo -e "  ${CYAN}[VERSÃO]${RESET} $version"
        else
            local jar_date=$(stat -c %y "$SERVER_DIR/HytaleServer.jar" | cut -d' ' -f1)
            echo -e "  ${CYAN}[JAR]${RESET} Instalado em $jar_date"
        fi

        local jar_size=$(du -h "$SERVER_DIR/HytaleServer.jar" | cut -f1)
        echo -e "  ${CYAN}[TAMANHO]${RESET} $jar_size"

        if [ -f "$SERVER_DIR/Assets.zip" ]; then
            local assets_size=$(du -h "$SERVER_DIR/Assets.zip" | cut -f1)
            echo -e "  ${CYAN}[ASSETS]${RESET} $assets_size"
        fi
    else
        print_warning "Nenhuma versão instalada"
    fi
    echo ""
}

# Choose patchline
choose_patchline() {
    echo -e "${CYAN}════════════════════════════════════════════════════════${RESET}"
    echo -e "${WHITE}  SELECIONAR VERSÃO${RESET}"
    echo -e "${CYAN}════════════════════════════════════════════════════════${RESET}"
    echo ""
    echo "Qual versão você deseja baixar?"
    echo ""
    echo -e "  ${BLUE}1.${RESET} Release (versão estável)"
    echo -e "  ${BLUE}2.${RESET} Pre-Release (versão de testes)"
    echo ""
    echo -ne "${GRAY}Escolha (1-2): ${RESET}"

    while true; do
        read choice
        case "$choice" in
            1)
                PATCHLINE="release"
                print_success "Selecionado: Release"
                break
                ;;
            2)
                PATCHLINE="pre-release"
                print_success "Selecionado: Pre-Release"
                break
                ;;
            *)
                echo -ne "${GRAY}Opção inválida. Escolha 1 ou 2: ${RESET}"
                ;;
        esac
    done
    echo ""
}

# Confirm update
confirm_update() {
    echo -e "${CYAN}════════════════════════════════════════════════════════${RESET}"
    echo -e "${WHITE}  PROCESSO DE ATUALIZAÇÃO${RESET}"
    echo -e "${CYAN}════════════════════════════════════════════════════════${RESET}"
    echo ""
    echo "O processo irá:"
    echo -e "  ${BLUE}1.${RESET} Parar o servidor (jogadores serão desconectados)"
    echo -e "  ${BLUE}2.${RESET} Fazer backup da versão atual"
    echo -e "  ${BLUE}3.${RESET} Baixar nova versão"
    echo -e "  ${BLUE}4.${RESET} Rebuildar imagem Docker"
    echo -e "  ${BLUE}5.${RESET} Reiniciar o servidor"
    echo ""
    echo -ne "${GRAY}Continuar? (s/N): ${RESET}"
    read confirm

    if [[ ! "$confirm" =~ ^[YySs]$ ]]; then
        print_warning "Atualização cancelada pelo usuário"
        exit 0
    fi
    echo ""
}

# Stop server
stop_server() {
    print_step "Parando servidor Hytale..."
    cd "$PROJECT_DIR"

    if docker ps --format '{{.Names}}' | grep -q "^hytale-server$"; then
        if docker compose stop hytale-server 2>/dev/null || docker-compose stop hytale-server 2>/dev/null; then
            print_success "Servidor parado"
        else
            print_error "Falha ao parar servidor"
            exit 1
        fi
    else
        print_warning "Servidor já estava parado"
    fi
    echo ""
}

# Backup
backup_current_version() {
    print_step "Fazendo backup da versão atual..."

    if [ -d "$SERVER_DIR" ]; then
        local backup_name=".server.backup-$(date +%Y%m%d-%H%M%S)"
        mv "$SERVER_DIR" "$PROJECT_DIR/$backup_name"
        print_success "Backup criado: $backup_name"

        # Clean old backups (keep only 3 most recent)
        print_step "Limpando backups antigos..."
        cd "$PROJECT_DIR"
        ls -dt .server.backup-* 2>/dev/null | tail -n +4 | xargs rm -rf 2>/dev/null
        print_success "Backups antigos limpos (mantidos 3 mais recentes)"
    else
        print_warning "Nenhuma versão anterior para backup"
    fi
    echo ""
}

# Download new version
download_new_version() {
    print_step "Baixando nova versão do Hytale ($PATCHLINE)..."
    echo ""

    mkdir -p "$SERVER_DIR"
    cd "$SERVER_DIR"

    # Download ZIP
    if "$DOWNLOADER" -patchline "$PATCHLINE"; then
        echo ""
        print_success "Download concluído!"

        # Find downloaded ZIP file
        local zip_file=$(ls -t *.zip 2>/dev/null | head -n1)
        if [ -z "$zip_file" ]; then
            print_error "Arquivo ZIP não encontrado"
            print_warning "Restaurando backup..."
            rollback
            exit 1
        fi

        # List ZIP contents
        print_step "Verificando conteúdo do arquivo..."
        unzip -l "$zip_file"
        echo ""

        # Extract ZIP
        print_step "Extraindo arquivos..."
        if unzip -o "$zip_file"; then
            echo ""
            print_success "Extração concluída!"

            # Move files from Server/ subdirectory to root
            if [ -d "Server" ]; then
                print_step "Movendo arquivos do subdiretório Server/..."
                mv Server/* . 2>/dev/null
                rm -rf Server
            fi

            # Remove ZIP and temporary credentials
            rm -f "$zip_file" .hytale-downloader-credentials.json

            # Show installed files
            print_step "Arquivos instalados:"
            if [ -f "HytaleServer.jar" ]; then
                local jar_size=$(du -h "HytaleServer.jar" | cut -f1)
                echo -e "  ${BLUE}[+]${RESET} HytaleServer.jar ($jar_size)"
            fi
            if [ -f "HytaleServer.aot" ]; then
                local aot_size=$(du -h "HytaleServer.aot" | cut -f1)
                echo -e "  ${BLUE}[+]${RESET} HytaleServer.aot ($aot_size)"
            fi
            if [ -f "Assets.zip" ]; then
                local assets_size=$(du -h "Assets.zip" | cut -f1)
                echo -e "  ${BLUE}[+]${RESET} Assets.zip ($assets_size)"
            fi
        else
            print_error "Falha ao extrair arquivos"
            print_warning "Restaurando backup..."
            rollback
            exit 1
        fi
    else
        print_error "Falha ao baixar nova versão"
        print_warning "Restaurando backup..."
        rollback
        exit 1
    fi
    echo ""
}

# Rebuild Docker
rebuild_docker() {
    print_step "Reconstruindo imagem Docker..."
    cd "$PROJECT_DIR"

    if docker compose build hytale-server 2>/dev/null || docker-compose build hytale-server 2>/dev/null; then
        print_success "Imagem Docker reconstruída"
    else
        print_error "Falha ao reconstruir imagem Docker"
        print_warning "Restaurando backup..."
        rollback
        exit 1
    fi
    echo ""
}

# Start server
start_server() {
    print_step "Iniciando servidor Hytale..."
    cd "$PROJECT_DIR"

    if docker compose up -d hytale-server 2>/dev/null || docker-compose up -d hytale-server 2>/dev/null; then
        print_success "Servidor iniciado"
    else
        print_error "Falha ao iniciar servidor"
        print_warning "Restaurando backup..."
        rollback
        exit 1
    fi
    echo ""
}

# Show logs
show_logs() {
    print_step "Aguardando servidor inicializar (5 segundos)..."
    sleep 5
    echo ""

    print_step "Logs recentes do servidor:"
    echo -e "${GRAY}════════════════════════════════════════════════════════${RESET}"
    docker logs --tail 20 hytale-server
    echo -e "${GRAY}════════════════════════════════════════════════════════${RESET}"
    echo ""

    print_success "Para ver logs ao vivo, use:"
    echo -e "  ${CYAN}docker compose logs -f hytale-server${RESET}"
    echo ""
}

# Restart Discord bot
restart_discord_bot() {
    print_step "Reiniciando Discord bot para atualizar versão..."
    cd "$PROJECT_DIR"

    if docker compose restart discord-bot 2>/dev/null || docker-compose restart discord-bot 2>/dev/null; then
        print_success "Discord bot reiniciado"
    else
        print_warning "Não foi possível reiniciar Discord bot automaticamente"
        echo -e "  ${GRAY}Reinicie manualmente: docker compose restart discord-bot${RESET}"
    fi
    echo ""
}

# Rollback on error
rollback() {
    print_warning "Iniciando rollback..."

    # Remove problematic version
    if [ -d "$SERVER_DIR" ]; then
        rm -rf "$SERVER_DIR"
    fi

    # Restore last backup
    local last_backup=$(ls -dt "$PROJECT_DIR"/.server.backup-* 2>/dev/null | head -n1)
    if [ -n "$last_backup" ]; then
        mv "$last_backup" "$SERVER_DIR"
        print_success "Backup restaurado: $(basename $last_backup)"

        # Rebuild with old version
        cd "$PROJECT_DIR"
        docker compose build hytale-server 2>/dev/null || docker-compose build hytale-server
        docker compose up -d hytale-server 2>/dev/null || docker-compose up -d hytale-server

        print_success "Servidor revertido para versão anterior"
    else
        print_error "Nenhum backup encontrado para restaurar"
    fi
}

# Final summary
show_summary() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║         ATUALIZAÇÃO CONCLUÍDA COM SUCESSO              ║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo "Próximos passos:"
    echo ""
    echo -e "  ${BLUE}1.${RESET} Verificar se o servidor está rodando:"
    echo -e "     ${CYAN}docker compose ps${RESET}"
    echo ""
    echo -e "  ${BLUE}2.${RESET} Monitorar logs em tempo real:"
    echo -e "     ${CYAN}docker compose logs -f hytale-server${RESET}"
    echo ""
    echo -e "  ${BLUE}3.${RESET} Testar conexão no jogo:"
    echo -e "     ${CYAN}186.219.130.224:25565${RESET}"
    echo ""
    echo -e "  ${BLUE}4.${RESET} Se ocorrerem problemas, reverta manualmente:"
    echo -e "     ${GRAY}cd $PROJECT_DIR${RESET}"
    echo -e "     ${GRAY}docker compose stop hytale-server${RESET}"
    echo -e "     ${GRAY}rm -rf .server${RESET}"
    echo -e "     ${GRAY}mv .server.backup-XXXXXX .server${RESET}"
    echo -e "     ${GRAY}docker compose build hytale-server${RESET}"
    echo -e "     ${GRAY}docker compose up -d hytale-server${RESET}"
    echo ""
}

# Main
main() {
    # Enable maintenance mode
    "$PROJECT_DIR/scripts/.maintenance-mode.sh" enable "Atualização do servidor em andamento" 2>/dev/null || true

    clear
    print_header

    check_requirements
    show_current_version
    choose_patchline
    confirm_update

    stop_server
    backup_current_version
    download_new_version
    rebuild_docker
    start_server
    show_logs
    restart_discord_bot
    show_summary

    # Disable maintenance mode
    "$PROJECT_DIR/scripts/.maintenance-mode.sh" disable 2>/dev/null || true
}

# Execute
main
