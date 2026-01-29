#!/bin/bash

# Automated Backup Script
# Runs daily backups without user interaction

# Colors - Blue and White theme
RESET='\033[0m'
BLUE='\033[38;5;39m'
CYAN='\033[38;5;51m'
WHITE='\033[1;37m'
GRAY='\033[38;5;245m'

# Reset colors on exit or interrupt and disable maintenance
trap 'echo -e "\033[0m"; /home/rainz/hytale-server/scripts/maintenance-mode.sh disable 2>/dev/null > /dev/null; exit 130' INT TERM

# Directories
PROJECT_DIR="/home/rainz/hytale-server"
DATA_DIR="$PROJECT_DIR/data"
BACKUP_DIR="$PROJECT_DIR/backups"
LOG_FILE="$PROJECT_DIR/logs/backup-auto.log"

# Google Drive via rclone
GDRIVE_BACKUP_PATH="gdrive:Backups/Hytale"

# Ensure log directory exists
mkdir -p "$PROJECT_DIR/logs"

# Log functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [OK] $1" | tee -a "$LOG_FILE"
}

# Start
log "=========================================="
log "Starting automated backup"
log "=========================================="

# Enable maintenance mode
"$PROJECT_DIR/scripts/maintenance-mode.sh" enable "Backup automático em andamento" 2>/dev/null || true

# Verify data directory exists
if [ ! -d "$DATA_DIR" ]; then
    log_error "Data directory not found: $DATA_DIR"
    "$PROJECT_DIR/scripts/maintenance-mode.sh" disable 2>/dev/null || true
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Create backup
timestamp=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/hytale-backup-full-${timestamp}.tar.gz"

log "Creating backup: $(basename "$BACKUP_FILE")"
cd "$PROJECT_DIR"

if tar -czf "$BACKUP_FILE" data 2>&1 | tee -a "$LOG_FILE"; then
    backup_size=$(du -h "$BACKUP_FILE" | cut -f1)
    log_success "Backup created successfully! Size: $backup_size"
else
    log_error "Failed to create backup"
    [ -f "$BACKUP_FILE" ] && rm -f "$BACKUP_FILE"
    "$PROJECT_DIR/scripts/maintenance-mode.sh" disable 2>/dev/null || true
    exit 1
fi

# Upload to Google Drive
if [ -n "$GDRIVE_BACKUP_PATH" ]; then
    if command -v rclone &> /dev/null; then
        remote=$(echo "$GDRIVE_BACKUP_PATH" | cut -d: -f1)

        if rclone listremotes | grep -q "^${remote}:$"; then
            log "Uploading backup to Google Drive..."

            if rclone copy "$BACKUP_FILE" "$GDRIVE_BACKUP_PATH" 2>&1 | tee -a "$LOG_FILE"; then
                log_success "Backup uploaded to Google Drive"

                # Clean old Drive backups
                log "Cleaning old Google Drive backups (keeping 7 most recent)..."

                backups=$(rclone lsf "$GDRIVE_BACKUP_PATH" --files-only 2>/dev/null | grep "hytale-backup-.*\.tar\.gz$" | sort -r)
                total_backups=$(echo "$backups" | grep -c "hytale-backup-" || echo "0")

                if [ "$total_backups" -gt 7 ]; then
                    to_delete=$((total_backups - 7))
                    log "Total Drive backups: $total_backups - Removing: $to_delete"

                    count=0
                    echo "$backups" | while read -r backup; do
                        count=$((count + 1))
                        if [ $count -gt 7 ]; then
                            log "Removing: $backup"
                            rclone delete "$GDRIVE_BACKUP_PATH/$backup" 2>&1 | tee -a "$LOG_FILE"
                        fi
                    done

                    log_success "Drive cleanup completed"
                else
                    log "Total Drive backups: $total_backups (within limit)"
                fi
            else
                log_error "Failed to upload backup to Google Drive"
            fi
        else
            log_error "Google Drive not configured in rclone"
        fi
    else
        log_error "rclone is not installed"
    fi
fi

# Clean old local backups (keep 7 most recent)
log "Cleaning old local backups (keeping 7 most recent)..."
cd "$BACKUP_DIR"
backup_count=$(ls -t hytale-backup-*.tar.gz 2>/dev/null | wc -l)

if [ "$backup_count" -gt 7 ]; then
    ls -t hytale-backup-*.tar.gz | tail -n +8 | while read -r old_backup; do
        log "Removing old local backup: $old_backup"
        rm -f "$old_backup"
    done
    log_success "Local cleanup completed"
else
    log "Total local backups: $backup_count (within limit)"
fi

log "=========================================="
log "Automated backup completed successfully!"
log "=========================================="

# Disable maintenance mode
"$PROJECT_DIR/scripts/maintenance-mode.sh" disable 2>/dev/null || true
