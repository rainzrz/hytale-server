#!/bin/bash

# Script de backup automático (sem interação)
# Executa backup completo diariamente

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
LOG_FILE="$PROJECT_DIR/logs/backup-auto.log"

# Google Drive via rclone
GDRIVE_BACKUP_PATH="gdrive:Backups/Hytale"

# Garante que o diretório de logs existe
mkdir -p "$PROJECT_DIR/logs"

# Funções de log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" | tee -a "$LOG_FILE"
}

# Início
log "=========================================="
log "Iniciando backup automático"
log "=========================================="

# Verifica se o diretório data existe
if [ ! -d "$DATA_DIR" ]; then
    log_error "Diretório de dados não encontrado: $DATA_DIR"
    exit 1
fi

# Cria diretório de backup se não existir
mkdir -p "$BACKUP_DIR"

# Cria o backup
timestamp=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/hytale-backup-full-${timestamp}.tar.gz"

log "Criando backup: $(basename "$BACKUP_FILE")"
cd "$PROJECT_DIR"

if tar -czf "$BACKUP_FILE" data 2>&1 | tee -a "$LOG_FILE"; then
    backup_size=$(du -h "$BACKUP_FILE" | cut -f1)
    log_success "Backup criado com sucesso! Tamanho: $backup_size"
else
    log_error "Falha ao criar backup"
    [ -f "$BACKUP_FILE" ] && rm -f "$BACKUP_FILE"
    exit 1
fi

# Upload para Google Drive
if [ -n "$GDRIVE_BACKUP_PATH" ]; then
    if command -v rclone &> /dev/null; then
        remote=$(echo "$GDRIVE_BACKUP_PATH" | cut -d: -f1)

        if rclone listremotes | grep -q "^${remote}:$"; then
            log "Enviando backup para Google Drive..."

            if rclone copy "$BACKUP_FILE" "$GDRIVE_BACKUP_PATH" 2>&1 | tee -a "$LOG_FILE"; then
                log_success "Backup enviado para Google Drive"

                # Limpa backups antigos do Drive
                log "Limpando backups antigos do Google Drive (mantendo os 7 mais recentes)..."

                backups=$(rclone lsf "$GDRIVE_BACKUP_PATH" --files-only 2>/dev/null | grep "hytale-backup-.*\.tar\.gz$" | sort -r)
                total_backups=$(echo "$backups" | grep -c "hytale-backup-" || echo "0")

                if [ "$total_backups" -gt 7 ]; then
                    to_delete=$((total_backups - 7))
                    log "Total de backups no Drive: $total_backups - Removendo: $to_delete"

                    count=0
                    echo "$backups" | while read -r backup; do
                        count=$((count + 1))
                        if [ $count -gt 7 ]; then
                            log "Removendo: $backup"
                            rclone delete "$GDRIVE_BACKUP_PATH/$backup" 2>&1 | tee -a "$LOG_FILE"
                        fi
                    done

                    log_success "Limpeza do Drive concluída"
                else
                    log "Total de backups no Drive: $total_backups (dentro do limite)"
                fi
            else
                log_error "Falha ao enviar backup para Google Drive"
            fi
        else
            log_error "Google Drive não está configurado no rclone"
        fi
    else
        log_error "rclone não está instalado"
    fi
fi

# Limpa backups locais antigos (mantém os 7 mais recentes)
log "Limpando backups locais antigos (mantendo os 7 mais recentes)..."
cd "$BACKUP_DIR"
backup_count=$(ls -t hytale-backup-*.tar.gz 2>/dev/null | wc -l)

if [ "$backup_count" -gt 7 ]; then
    ls -t hytale-backup-*.tar.gz | tail -n +8 | while read -r old_backup; do
        log "Removendo backup local antigo: $old_backup"
        rm -f "$old_backup"
    done
    log_success "Limpeza local concluída"
else
    log "Total de backups locais: $backup_count (dentro do limite)"
fi

log "=========================================="
log "Backup automático concluído com sucesso!"
log "=========================================="
