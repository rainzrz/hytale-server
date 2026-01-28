#!/bin/bash

# Cores
RESET='\033[0m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'

# Diretórios
PROJECT_DIR="/home/rainz/hytale-server"
SERVER_DIR="$PROJECT_DIR/.server"
TOOLS_DIR="$PROJECT_DIR/tools"
DOWNLOADER="$TOOLS_DIR/hytale-downloader-linux-amd64"

# Funções
print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║        🎮 ATUALIZADOR DE HYTALE SERVER 🎮             ║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

print_step() {
    echo -e "${BLUE}▶${RESET} $1"
}

print_success() {
    echo -e "${GREEN}✓${RESET} $1"
}

print_error() {
    echo -e "${RED}✗${RESET} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${RESET} $1"
}

# Verificações iniciais
check_requirements() {
    print_step "Verificando requisitos..."

    # Verifica se está no diretório correto
    if [ ! -d "$PROJECT_DIR" ]; then
        print_error "Diretório do projeto não encontrado: $PROJECT_DIR"
        exit 1
    fi

    # Verifica se Docker está rodando
    if ! docker ps > /dev/null 2>&1; then
        print_error "Docker não está rodando ou você não tem permissão"
        exit 1
    fi

    # Verifica se o downloader existe
    if [ ! -f "$DOWNLOADER" ]; then
        print_error "Hytale downloader não encontrado: $DOWNLOADER"
        exit 1
    fi

    # Verifica se o downloader tem permissão de execução
    if [ ! -x "$DOWNLOADER" ]; then
        print_warning "Adicionando permissão de execução ao downloader..."
        chmod +x "$DOWNLOADER"
    fi

    print_success "Todos os requisitos verificados"
    echo ""
}

# Mostra versão atual
show_current_version() {
    print_step "Versão atual instalada:"

    if [ -f "$SERVER_DIR/HytaleServer.jar" ]; then
        # Extrai versão do manifesto
        local version=$(unzip -p "$SERVER_DIR/HytaleServer.jar" META-INF/MANIFEST.MF 2>/dev/null | grep "Implementation-Version:" | cut -d' ' -f2 | tr -d '\r')

        if [ -n "$version" ]; then
            echo -e "  📦 Versão: ${GREEN}$version${RESET}"
        else
            local jar_date=$(stat -c %y "$SERVER_DIR/HytaleServer.jar" | cut -d' ' -f1)
            echo -e "  📦 HytaleServer.jar: ${GREEN}instalado em $jar_date${RESET}"
        fi

        local jar_size=$(du -h "$SERVER_DIR/HytaleServer.jar" | cut -f1)
        echo -e "  📦 Tamanho: ${jar_size}"

        if [ -f "$SERVER_DIR/Assets.zip" ]; then
            local assets_size=$(du -h "$SERVER_DIR/Assets.zip" | cut -f1)
            echo -e "  📦 Assets: ${assets_size}"
        fi
    else
        print_warning "Nenhuma versão instalada"
    fi
    echo ""
}

# Confirma atualização
confirm_update() {
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${RESET}"
    echo -e "${YELLOW}⚠  ATENÇÃO: Esta ação vai atualizar o servidor Hytale${RESET}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${RESET}"
    echo ""
    echo "O processo vai:"
    echo "  1️⃣  Parar o servidor (jogadores serão desconectados)"
    echo "  2️⃣  Fazer backup da versão atual"
    echo "  3️⃣  Baixar a nova versão"
    echo "  4️⃣  Reconstruir a imagem Docker"
    echo "  5️⃣  Reiniciar o servidor"
    echo ""
    echo -e "${CYAN}Tempo estimado: 5-15 minutos (depende da internet)${RESET}"
    echo ""
    read -p "Deseja continuar? (s/N): " confirm

    if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
        print_warning "Atualização cancelada pelo usuário"
        exit 0
    fi
    echo ""
}

# Para o servidor
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

# Faz backup
backup_current_version() {
    print_step "Fazendo backup da versão atual..."

    if [ -d "$SERVER_DIR" ]; then
        local backup_name=".server.backup-$(date +%Y%m%d-%H%M%S)"
        mv "$SERVER_DIR" "$PROJECT_DIR/$backup_name"
        print_success "Backup criado: $backup_name"

        # Limpa backups antigos (mantém apenas os 3 mais recentes)
        print_step "Limpando backups antigos..."
        cd "$PROJECT_DIR"
        ls -dt .server.backup-* 2>/dev/null | tail -n +4 | xargs rm -rf 2>/dev/null
        print_success "Backups antigos limpos (mantidos os 3 mais recentes)"
    else
        print_warning "Nenhuma versão anterior para backup"
    fi
    echo ""
}

# Baixa nova versão
download_new_version() {
    print_step "Baixando nova versão do Hytale..."
    echo ""

    mkdir -p "$SERVER_DIR"
    cd "$SERVER_DIR"

    if "$DOWNLOADER" download; then
        echo ""
        print_success "Download concluído!"

        # Mostra arquivos baixados
        print_step "Arquivos baixados:"
        if [ -f "HytaleServer.jar" ]; then
            local jar_size=$(du -h "HytaleServer.jar" | cut -f1)
            echo -e "  ✓ HytaleServer.jar (${jar_size})"
        fi
        if [ -f "HytaleServer.aot" ]; then
            local aot_size=$(du -h "HytaleServer.aot" | cut -f1)
            echo -e "  ✓ HytaleServer.aot (${aot_size})"
        fi
        if [ -f "Assets.zip" ]; then
            local assets_size=$(du -h "Assets.zip" | cut -f1)
            echo -e "  ✓ Assets.zip (${assets_size})"
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

# Inicia servidor
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

# Mostra logs
show_logs() {
    print_step "Aguardando servidor inicializar (30 segundos)..."
    sleep 5
    echo ""

    print_step "Últimos logs do servidor:"
    echo -e "${CYAN}════════════════════════════════════════════════════════${RESET}"
    docker logs --tail 20 hytale-server
    echo -e "${CYAN}════════════════════════════════════════════════════════${RESET}"
    echo ""

    print_success "Para ver logs em tempo real, use:"
    echo -e "  ${CYAN}docker compose logs -f hytale-server${RESET}"
    echo ""
}

# Rollback em caso de erro
rollback() {
    print_warning "Iniciando rollback..."

    # Remove versão com problema
    if [ -d "$SERVER_DIR" ]; then
        rm -rf "$SERVER_DIR"
    fi

    # Restaura último backup
    local last_backup=$(ls -dt "$PROJECT_DIR"/.server.backup-* 2>/dev/null | head -n1)
    if [ -n "$last_backup" ]; then
        mv "$last_backup" "$SERVER_DIR"
        print_success "Backup restaurado: $(basename $last_backup)"

        # Rebuild com versão antiga
        cd "$PROJECT_DIR"
        docker compose build hytale-server 2>/dev/null || docker-compose build hytale-server
        docker compose up -d hytale-server 2>/dev/null || docker-compose up -d hytale-server

        print_success "Servidor revertido para versão anterior"
    else
        print_error "Nenhum backup encontrado para restaurar"
    fi
}

# Resumo final
show_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║          ✓ ATUALIZAÇÃO CONCLUÍDA COM SUCESSO          ║${RESET}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo "Próximos passos:"
    echo "  1️⃣  Verificar se o servidor está rodando:"
    echo -e "     ${CYAN}docker compose ps${RESET}"
    echo ""
    echo "  2️⃣  Monitorar logs em tempo real:"
    echo -e "     ${CYAN}docker compose logs -f hytale-server${RESET}"
    echo ""
    echo "  3️⃣  Testar conexão no jogo:"
    echo -e "     ${CYAN}186.219.130.224:25565${RESET}"
    echo ""
    echo "  4️⃣  Em caso de problemas, reverta manualmente:"
    echo -e "     ${YELLOW}cd $PROJECT_DIR${RESET}"
    echo -e "     ${YELLOW}docker compose stop hytale-server${RESET}"
    echo -e "     ${YELLOW}rm -rf .server${RESET}"
    echo -e "     ${YELLOW}mv .server.backup-XXXXXX .server${RESET}"
    echo -e "     ${YELLOW}docker compose build hytale-server${RESET}"
    echo -e "     ${YELLOW}docker compose up -d hytale-server${RESET}"
    echo ""
}

# Main
main() {
    clear
    print_header

    check_requirements
    show_current_version
    confirm_update

    stop_server
    backup_current_version
    download_new_version
    rebuild_docker
    start_server
    show_logs
    show_summary
}

# Executa
main
