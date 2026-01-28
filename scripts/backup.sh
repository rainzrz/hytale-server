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
DATA_DIR="$PROJECT_DIR/data"
BACKUP_DIR="$PROJECT_DIR/backups"

# Funções
print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║           BACKUP DO SERVIDOR HYTALE - NOR              ║${RESET}"
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

print_info() {
    echo -e "${CYAN}ℹ${RESET} $1"
}

# Verificações iniciais
check_requirements() {
    print_step "Verificando requisitos..."

    # Verifica se o diretório data existe
    if [ ! -d "$DATA_DIR" ]; then
        print_error "Diretório de dados não encontrado: $DATA_DIR"
        exit 1
    fi

    # Verifica se há espaço em disco suficiente
    local data_size=$(du -sb "$DATA_DIR" | cut -f1)
    local available_space=$(df -B1 "$PROJECT_DIR" | tail -1 | awk '{print $4}')

    if [ "$available_space" -lt "$((data_size * 2))" ]; then
        print_warning "Espaço em disco pode ser insuficiente"
        echo -e "  Tamanho dos dados: $(du -sh "$DATA_DIR" | cut -f1)"
        echo -e "  Espaço disponível: $(df -h "$PROJECT_DIR" | tail -1 | awk '{print $4}')"
        echo ""
        read -p "Deseja continuar mesmo assim? (s/N): " confirm
        if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
            print_warning "Backup cancelado"
            exit 0
        fi
    fi

    print_success "Requisitos verificados"
    echo ""
}

# Mostra informações do save
show_save_info() {
    print_step "Informações do save atual:"
    echo ""

    # Tamanho total
    local total_size=$(du -sh "$DATA_DIR" | cut -f1)
    echo -e "  Tamanho total: ${GREEN}$total_size${RESET}"

    # Detalhes por diretório
    if [ -d "$DATA_DIR/universe" ]; then
        local universe_size=$(du -sh "$DATA_DIR/universe" 2>/dev/null | cut -f1)
        echo -e "  └─ Mundo (universe): ${universe_size}"
    fi

    if [ -d "$DATA_DIR/mods" ]; then
        local mods_count=$(ls -1 "$DATA_DIR/mods" 2>/dev/null | wc -l)
        local mods_size=$(du -sh "$DATA_DIR/mods" 2>/dev/null | cut -f1)
        echo -e "  └─ Mods: ${mods_count} arquivos (${mods_size})"
    fi

    if [ -d "$DATA_DIR/logs" ]; then
        local logs_size=$(du -sh "$DATA_DIR/logs" 2>/dev/null | cut -f1)
        echo -e "  └─ Logs: ${logs_size}"
    fi

    if [ -d "$DATA_DIR/uptime-kuma" ]; then
        local kuma_size=$(du -sh "$DATA_DIR/uptime-kuma" 2>/dev/null | cut -f1)
        echo -e "  └─ Uptime Kuma: ${kuma_size}"
    fi

    # Última modificação
    if [ -d "$DATA_DIR/universe" ]; then
        local last_modified=$(stat -c %y "$DATA_DIR/universe" | cut -d' ' -f1,2 | cut -d'.' -f1)
        echo -e "  Última modificação: ${last_modified}"
    fi

    echo ""
}

# Pergunta se deve parar o servidor
ask_stop_server() {
    print_warning "Recomendação: Pare o servidor antes do backup para evitar corrupção de dados"
    echo ""
    read -p "Deseja parar o servidor antes do backup? (S/n): " stop_server
    echo ""

    if [[ ! "$stop_server" =~ ^[Nn]$ ]]; then
        print_step "Parando servidor Hytale..."
        cd "$PROJECT_DIR"

        # Tenta docker compose (novo) ou docker-compose (antigo)
        if docker compose stop hytale-server 2>/dev/null || docker-compose stop hytale-server 2>/dev/null; then
            print_success "Servidor parado"
            SERVER_WAS_STOPPED=true
        else
            print_warning "Não foi possível parar o servidor"
            echo -e "  ${YELLOW}Verifique se o Docker está rodando e se você está no diretório correto${RESET}"
            echo ""
            read -p "Deseja continuar o backup mesmo assim? (s/N): " continue_anyway
            if [[ ! "$continue_anyway" =~ ^[Ss]$ ]]; then
                print_error "Backup cancelado"
                exit 1
            fi
            SERVER_WAS_STOPPED=false
        fi
        echo ""
    else
        print_warning "Backup será feito com o servidor rodando (risco de corrupção)"
        SERVER_WAS_STOPPED=false
        echo ""
        sleep 2
    fi
}

# Escolhe destino do backup
choose_backup_location() {
    echo -e "${YELLOW}Escolha o destino do backup:${RESET}"
    echo ""
    echo "  1) Diretório padrão (backups/)"
    echo "  2) Especificar outro caminho"
    echo ""
    read -p "Escolha (1-2): " location_choice
    echo ""

    case "$location_choice" in
        1)
            mkdir -p "$BACKUP_DIR"
            CHOSEN_BACKUP_DIR="$BACKUP_DIR"
            ;;
        2)
            read -p "Digite o caminho completo: " custom_path
            if [ ! -d "$custom_path" ]; then
                print_warning "Diretório não existe. Criando..."
                mkdir -p "$custom_path"
            fi
            CHOSEN_BACKUP_DIR="$custom_path"
            ;;
        *)
            print_error "Opção inválida. Usando diretório padrão."
            mkdir -p "$BACKUP_DIR"
            CHOSEN_BACKUP_DIR="$BACKUP_DIR"
            ;;
    esac

    print_success "Destino: $CHOSEN_BACKUP_DIR"
    echo ""
}

# Escolhe o que incluir no backup
choose_backup_content() {
    echo -e "${YELLOW}O que deseja incluir no backup?${RESET}"
    echo ""
    echo "  1) Tudo (mundo, mods, logs, configs, uptime-kuma)"
    echo "  2) Apenas mundo (universe)"
    echo "  3) Mundo + Mods + Configs"
    echo "  4) Personalizado"
    echo ""
    read -p "Escolha (1-4): " content_choice
    echo ""

    case "$content_choice" in
        1)
            BACKUP_CONTENT="data"
            BACKUP_NAME="full"
            print_info "Backup completo selecionado"
            ;;
        2)
            BACKUP_CONTENT="data/universe"
            BACKUP_NAME="world"
            print_info "Apenas mundo será incluído"
            ;;
        3)
            BACKUP_CONTENT="data/universe data/mods data/config.json data/permissions.json data/whitelist.json data/bans.json"
            BACKUP_NAME="essential"
            print_info "Mundo + Mods + Configs selecionados"
            ;;
        4)
            echo "Selecione os itens (separados por espaço):"
            echo "  u = universe (mundo)"
            echo "  m = mods"
            echo "  l = logs"
            echo "  c = configs"
            echo "  k = uptime-kuma"
            echo ""
            read -p "Itens: " custom_items

            BACKUP_CONTENT=""
            BACKUP_NAME="custom"

            [[ "$custom_items" =~ "u" ]] && BACKUP_CONTENT="$BACKUP_CONTENT data/universe"
            [[ "$custom_items" =~ "m" ]] && BACKUP_CONTENT="$BACKUP_CONTENT data/mods"
            [[ "$custom_items" =~ "l" ]] && BACKUP_CONTENT="$BACKUP_CONTENT data/logs"
            [[ "$custom_items" =~ "c" ]] && BACKUP_CONTENT="$BACKUP_CONTENT data/config.json data/permissions.json data/whitelist.json data/bans.json"
            [[ "$custom_items" =~ "k" ]] && BACKUP_CONTENT="$BACKUP_CONTENT data/uptime-kuma"

            print_info "Backup personalizado configurado"
            ;;
        *)
            print_error "Opção inválida. Usando backup completo."
            BACKUP_CONTENT="data"
            BACKUP_NAME="full"
            ;;
    esac
    echo ""
}

# Cria o backup
create_backup() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="$CHOSEN_BACKUP_DIR/hytale-backup-${BACKUP_NAME}-${timestamp}.tar.gz"

    print_step "Criando backup..."
    echo -e "  Arquivo: $(basename $backup_file)"
    echo ""

    cd "$PROJECT_DIR"

    # Cria o backup com barra de progresso
    if tar -czf "$backup_file" $BACKUP_CONTENT 2>/dev/null; then
        echo ""
        print_success "Backup criado com sucesso!"

        # Mostra informações do backup
        local backup_size=$(du -h "$backup_file" | cut -f1)
        echo ""
        echo -e "${GREEN}════════════════════════════════════════════════════════${RESET}"
        echo -e "  Arquivo: ${CYAN}$(basename $backup_file)${RESET}"
        echo -e "  Tamanho: ${GREEN}$backup_size${RESET}"
        echo -e "  Local: ${CYAN}$backup_file${RESET}"
        echo -e "${GREEN}════════════════════════════════════════════════════════${RESET}"
        echo ""
    else
        print_error "Falha ao criar backup"

        # Tenta limpar arquivo parcial
        [ -f "$backup_file" ] && rm -f "$backup_file"

        return 1
    fi
}

# Reinicia servidor se foi parado
restart_server_if_needed() {
    if [ "$SERVER_WAS_STOPPED" = true ]; then
        echo ""
        read -p "Deseja reiniciar o servidor agora? (S/n): " restart

        if [[ ! "$restart" =~ ^[Nn]$ ]]; then
            print_step "Reiniciando servidor Hytale..."
            cd "$PROJECT_DIR"
            if docker compose start hytale-server 2>/dev/null || docker-compose start hytale-server 2>/dev/null; then
                print_success "Servidor reiniciado"
            else
                print_error "Não foi possível reiniciar o servidor automaticamente"
                echo -e "  ${YELLOW}Reinicie manualmente: docker compose up -d hytale-server${RESET}"
            fi
        else
            print_warning "Servidor continua parado. Inicie manualmente quando necessário."
        fi
    fi
}

# Lista backups existentes
list_existing_backups() {
    echo ""
    print_step "Backups existentes:"
    echo ""

    if [ -d "$BACKUP_DIR" ] && [ "$(ls -A $BACKUP_DIR 2>/dev/null)" ]; then
        cd "$BACKUP_DIR"
        local count=0

        for backup in $(ls -t hytale-backup-*.tar.gz 2>/dev/null); do
            count=$((count + 1))
            local size=$(du -h "$backup" | cut -f1)
            local date=$(stat -c %y "$backup" | cut -d' ' -f1,2 | cut -d'.' -f1)
            echo -e "  ${count}. ${CYAN}${backup}${RESET}"
            echo -e "     Tamanho: ${size} | Criado: ${date}"
        done

        if [ $count -eq 0 ]; then
            print_info "Nenhum backup encontrado no diretório padrão"
        else
            echo ""
            print_info "Total: $count backup(s)"
        fi
    else
        print_info "Nenhum backup encontrado no diretório padrão"
    fi
    echo ""
}

# Resumo final
show_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║            BACKUP CONCLUÍDO COM SUCESSO                ║${RESET}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo "Como restaurar este backup:"
    echo ""
    echo "  1. Pare o servidor:"
    echo -e "     ${CYAN}docker-compose down${RESET}"
    echo ""
    echo "  2. Faça backup dos dados atuais (segurança):"
    echo -e "     ${CYAN}mv data data.old${RESET}"
    echo ""
    echo "  3. Extraia o backup:"
    echo -e "     ${CYAN}tar -xzf $(basename $backup_file)${RESET}"
    echo ""
    echo "  4. Reinicie o servidor:"
    echo -e "     ${CYAN}docker-compose up -d${RESET}"
    echo ""
}

# Main
main() {
    clear
    print_header

    check_requirements
    show_save_info
    ask_stop_server
    choose_backup_location
    choose_backup_content

    if create_backup; then
        restart_server_if_needed
        list_existing_backups
        show_summary
    else
        print_error "Backup falhou!"
        restart_server_if_needed
        exit 1
    fi
}

# Executa
main
