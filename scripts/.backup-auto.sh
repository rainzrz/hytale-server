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
trap 'echo -e "\033[0m"; /home/rainz/hytale-server/scripts/.maintenance-mode.sh disable 2>/dev/null > /dev/null; exit 130' INT TERM

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
"$PROJECT_DIR/scripts/.maintenance-mode.sh" enable "Backup automático em andamento" 2>/dev/null || true

# Verify data directory exists
if [ ! -d "$DATA_DIR" ]; then
    log_error "Data directory not found: $DATA_DIR"
    "$PROJECT_DIR/scripts/.maintenance-mode.sh" disable 2>/dev/null || true
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Create backup
# Formato brasileiro: DD-MM-YYYY_HHhMM
timestamp=$(date +%d-%m-%Y_%Hh%M)
BACKUP_FILE="$BACKUP_DIR/${timestamp}.tar.gz"

log "Creating backup: $(basename "$BACKUP_FILE")"
cd "$PROJECT_DIR"

if tar -czf "$BACKUP_FILE" data 2>&1 | tee -a "$LOG_FILE"; then
    backup_size=$(du -h "$BACKUP_FILE" | cut -f1)
    log_success "Backup created successfully! Size: $backup_size"
else
    log_error "Failed to create backup"
    [ -f "$BACKUP_FILE" ] && rm -f "$BACKUP_FILE"
    "$PROJECT_DIR/scripts/.maintenance-mode.sh" disable 2>/dev/null || true
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

                # Clean old Drive backups (keep most recent backup per day for 7 days)
                log "Cleaning old Google Drive backups (keeping most recent per day for 7 days)..."

                backups=$(rclone lsf "$GDRIVE_BACKUP_PATH" --files-only 2>/dev/null | grep "^[0-9]\{2\}-[0-9]\{2\}-[0-9]\{4\}_.*\.tar\.gz$" | sort -r || true)

                if [ -n "$backups" ]; then
                    # Group backups by date
                    declare -A daily_drive_backups
                    cutoff_date=$(date -d '7 days ago' +%Y%m%d 2>/dev/null || date -v-7d +%Y%m%d 2>/dev/null)

                    while IFS= read -r backup; do
                        # Extract date from filename: DD-MM-YYYY_HHhMM.tar.gz
                        if [[ $backup =~ ^([0-9]{2})-([0-9]{2})-([0-9]{4})_([0-9]{2})h([0-9]{2})\.tar\.gz$ ]]; then
                            day="${BASH_REMATCH[1]}"
                            month="${BASH_REMATCH[2]}"
                            year="${BASH_REMATCH[3]}"
                            # Convert to YYYYMMDD for comparison
                            backup_date="${year}${month}${day}"

                            # Check if backup is older than 7 days
                            if [ "$backup_date" -lt "$cutoff_date" ]; then
                                log "Removing from Drive: $backup (older than 7 days)"
                                rclone delete "$GDRIVE_BACKUP_PATH/$backup" 2>&1 | tee -a "$LOG_FILE"
                            elif [ -z "${daily_drive_backups[$backup_date]}" ]; then
                                # Keep first (most recent) backup for this date
                                daily_drive_backups[$backup_date]="$backup"
                                log "Keeping in Drive: $backup (most recent for $backup_date)"
                            else
                                # Remove older backup from same day
                                log "Removing from Drive: $backup (superseded by newer backup on same day)"
                                rclone delete "$GDRIVE_BACKUP_PATH/$backup" 2>&1 | tee -a "$LOG_FILE"
                            fi
                        fi
                    done <<< "$backups"

                    remaining_count=$(rclone lsf "$GDRIVE_BACKUP_PATH" --files-only 2>/dev/null | grep -c "^[0-9]\{2\}-[0-9]\{2\}-[0-9]\{4\}_.*\.tar\.gz$" || echo "0")
                    log_success "Drive cleanup completed (kept $remaining_count daily backups)"
                else
                    log "No backups found in Google Drive"
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

# Clean old local backups (keep most recent backup per day for 7 days)
log "Cleaning old local backups (keeping most recent per day for 7 days)..."
cd "$BACKUP_DIR"

# Get list of all backups sorted by name (which includes timestamp)
backups=$(ls -1 [0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9]_*.tar.gz 2>/dev/null | sort -r || true)

if [ -n "$backups" ]; then
    # Group backups by date
    declare -A daily_backups

    while IFS= read -r backup; do
        # Extract date from filename: DD-MM-YYYY_HHhMM.tar.gz
        if [[ $backup =~ ^([0-9]{2})-([0-9]{2})-([0-9]{4})_([0-9]{2})h([0-9]{2})\.tar\.gz$ ]]; then
            day="${BASH_REMATCH[1]}"
            month="${BASH_REMATCH[2]}"
            year="${BASH_REMATCH[3]}"
            # Convert to YYYYMMDD for comparison
            backup_date="${year}${month}${day}"

            # Keep only the most recent backup for each date (first one since sorted in reverse)
            if [ -z "${daily_backups[$backup_date]}" ]; then
                daily_backups[$backup_date]="$backup"
                log "Keeping: $backup (most recent for $backup_date)"
            else
                log "Removing: $backup (superseded by newer backup on same day)"
                rm -f "$backup"
            fi
        fi
    done <<< "$backups"

    # Now remove backups older than 7 days
    cutoff_date=$(date -d '7 days ago' +%Y%m%d 2>/dev/null || date -v-7d +%Y%m%d 2>/dev/null)

    for backup_date in "${!daily_backups[@]}"; do
        if [ "$backup_date" -lt "$cutoff_date" ]; then
            backup_file="${daily_backups[$backup_date]}"
            log "Removing: $backup_file (older than 7 days)"
            rm -f "$backup_file"
        fi
    done

    remaining_count=$(ls -1 [0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9]_*.tar.gz 2>/dev/null | wc -l)
    log_success "Local cleanup completed (kept $remaining_count daily backups)"
else
    log "No backups found"
fi

log "=========================================="
log "Automated backup completed successfully!"
log "=========================================="

# Disable maintenance mode
"$PROJECT_DIR/scripts/.maintenance-mode.sh" disable 2>/dev/null || true
