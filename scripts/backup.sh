#!/bin/bash

# Interactive Backup Script
# Creates backups of Hytale server data with customization options

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

# Google Drive via rclone (leave empty to disable)
# Format: "remote:path" (ex: "gdrive:Backups/Hytale")
GDRIVE_BACKUP_PATH="gdrive:Backups/Hytale"

# Functions
print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║           HYTALE SERVER BACKUP MANAGER                 ║${RESET}"
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
    echo -e "${GRAY}[ERROR]${RESET} $1"
}

print_warning() {
    echo -e "${GRAY}[WARN]${RESET} $1"
}

print_info() {
    echo -e "${CYAN}[INFO]${RESET} $1"
}

# Initial checks
check_requirements() {
    print_step "Checking requirements..."

    # Verify data directory exists
    if [ ! -d "$DATA_DIR" ]; then
        print_error "Data directory not found: $DATA_DIR"
        exit 1
    fi

    # Check if there's enough disk space
    local data_size=$(du -sb "$DATA_DIR" | cut -f1)
    local available_space=$(df -B1 "$PROJECT_DIR" | tail -1 | awk '{print $4}')

    if [ "$available_space" -lt "$((data_size * 2))" ]; then
        print_warning "Disk space may be insufficient"
        echo -e "  Data size: $(du -sh "$DATA_DIR" | cut -f1)"
        echo -e "  Available space: $(df -h "$PROJECT_DIR" | tail -1 | awk '{print $4}')"
        echo ""
        read -p "Continue anyway? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[YySs]$ ]]; then
            print_warning "Backup cancelled"
            exit 0
        fi
    fi

    print_success "Requirements verified"
    echo ""
}

# Show save information
show_save_info() {
    print_step "Current save information:"
    echo ""

    # Total size
    local total_size=$(du -sh "$DATA_DIR" | cut -f1)
    echo -e "  Total size: ${CYAN}$total_size${RESET}"

    # Details per directory
    if [ -d "$DATA_DIR/universe" ]; then
        local universe_size=$(du -sh "$DATA_DIR/universe" 2>/dev/null | cut -f1)
        echo -e "  ${GRAY}└─${RESET} World (universe): $universe_size"
    fi

    if [ -d "$DATA_DIR/mods" ]; then
        local mods_count=$(ls -1 "$DATA_DIR/mods" 2>/dev/null | wc -l)
        local mods_size=$(du -sh "$DATA_DIR/mods" 2>/dev/null | cut -f1)
        echo -e "  ${GRAY}└─${RESET} Mods: $mods_count files ($mods_size)"
    fi

    if [ -d "$DATA_DIR/logs" ]; then
        local logs_size=$(du -sh "$DATA_DIR/logs" 2>/dev/null | cut -f1)
        echo -e "  ${GRAY}└─${RESET} Logs: $logs_size"
    fi

    if [ -d "$DATA_DIR/uptime-kuma" ]; then
        local kuma_size=$(du -sh "$DATA_DIR/uptime-kuma" 2>/dev/null | cut -f1)
        echo -e "  ${GRAY}└─${RESET} Uptime Kuma: $kuma_size"
    fi

    # Last modification
    if [ -d "$DATA_DIR/universe" ]; then
        local last_modified=$(stat -c %y "$DATA_DIR/universe" | cut -d' ' -f1,2 | cut -d'.' -f1)
        echo -e "  Last modified: ${GRAY}$last_modified${RESET}"
    fi

    echo ""
}

# Ask if server should be stopped
ask_stop_server() {
    print_warning "Recommendation: Stop the server before backup to avoid data corruption"
    echo ""
    read -p "Stop the server before backup? (Y/n): " stop_server
    echo ""

    if [[ ! "$stop_server" =~ ^[Nn]$ ]]; then
        print_step "Stopping Hytale server..."
        cd "$PROJECT_DIR"

        # Try docker compose (new) or docker-compose (old)
        if docker compose stop hytale-server 2>/dev/null || docker-compose stop hytale-server 2>/dev/null; then
            print_success "Server stopped"
            SERVER_WAS_STOPPED=true
        else
            print_warning "Could not stop server"
            echo -e "  ${GRAY}Check if Docker is running and you're in the correct directory${RESET}"
            echo ""
            read -p "Continue backup anyway? (y/N): " continue_anyway
            if [[ ! "$continue_anyway" =~ ^[YySs]$ ]]; then
                print_error "Backup cancelled"
                exit 1
            fi
            SERVER_WAS_STOPPED=false
        fi
        echo ""
    else
        print_warning "Backup will be performed with server running (corruption risk)"
        SERVER_WAS_STOPPED=false
        echo ""
        sleep 2
    fi

    # Clear screen for next step
    sleep 1
    clear
    print_header
}

# Choose backup destination
choose_backup_location() {
    echo -e "${WHITE}Choose backup destination:${RESET}"
    echo ""
    echo -e "  ${BLUE}1${RESET}) Default directory (backups/)"
    echo -e "  ${BLUE}2${RESET}) Specify another path"
    echo ""
    read -p "Choice (1-2): " location_choice
    echo ""

    case "$location_choice" in
        1)
            mkdir -p "$BACKUP_DIR"
            CHOSEN_BACKUP_DIR="$BACKUP_DIR"
            ;;
        2)
            read -p "Enter full path: " custom_path
            if [ ! -d "$custom_path" ]; then
                print_warning "Directory doesn't exist. Creating..."
                mkdir -p "$custom_path"
            fi
            CHOSEN_BACKUP_DIR="$custom_path"
            ;;
        *)
            print_error "Invalid option. Using default directory."
            mkdir -p "$BACKUP_DIR"
            CHOSEN_BACKUP_DIR="$BACKUP_DIR"
            ;;
    esac

    print_success "Destination: $CHOSEN_BACKUP_DIR"
    echo ""

    # Clear screen for next step
    sleep 1
    clear
    print_header
}

# Choose backup content
choose_backup_content() {
    echo -e "${WHITE}What should be included in the backup?${RESET}"
    echo ""
    echo -e "  ${BLUE}1${RESET}) Everything (world, mods, logs, configs, uptime-kuma)"
    echo -e "  ${BLUE}2${RESET}) World only (universe)"
    echo -e "  ${BLUE}3${RESET}) World + Mods + Configs"
    echo -e "  ${BLUE}4${RESET}) Custom"
    echo ""
    read -p "Choice (1-4): " content_choice
    echo ""

    case "$content_choice" in
        1)
            BACKUP_CONTENT="data"
            BACKUP_NAME="full"
            print_info "Complete backup selected"
            ;;
        2)
            BACKUP_CONTENT="data/universe"
            BACKUP_NAME="world"
            print_info "World only will be included"
            ;;
        3)
            BACKUP_CONTENT="data/universe data/mods data/config.json data/permissions.json data/whitelist.json data/bans.json"
            BACKUP_NAME="essential"
            print_info "World + Mods + Configs selected"
            ;;
        4)
            echo "Select items (space separated):"
            echo "  u = universe (world)"
            echo "  m = mods"
            echo "  l = logs"
            echo "  c = configs"
            echo "  k = uptime-kuma"
            echo ""
            read -p "Items: " custom_items

            BACKUP_CONTENT=""
            BACKUP_NAME="custom"

            [[ "$custom_items" =~ "u" ]] && BACKUP_CONTENT="$BACKUP_CONTENT data/universe"
            [[ "$custom_items" =~ "m" ]] && BACKUP_CONTENT="$BACKUP_CONTENT data/mods"
            [[ "$custom_items" =~ "l" ]] && BACKUP_CONTENT="$BACKUP_CONTENT data/logs"
            [[ "$custom_items" =~ "c" ]] && BACKUP_CONTENT="$BACKUP_CONTENT data/config.json data/permissions.json data/whitelist.json data/bans.json"
            [[ "$custom_items" =~ "k" ]] && BACKUP_CONTENT="$BACKUP_CONTENT data/uptime-kuma"

            print_info "Custom backup configured"
            ;;
        *)
            print_error "Invalid option. Using complete backup."
            BACKUP_CONTENT="data"
            BACKUP_NAME="full"
            ;;
    esac
    echo ""

    # Clear screen for next step
    sleep 1
    clear
    print_header
}

# Create backup
create_backup() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    BACKUP_FILE_PATH="$CHOSEN_BACKUP_DIR/hytale-backup-${BACKUP_NAME}-${timestamp}.tar.gz"

    print_step "Creating backup..."
    echo -e "  File: $(basename "$BACKUP_FILE_PATH")"
    echo ""

    cd "$PROJECT_DIR"

    # Create backup with progress bar
    if tar -czf "$BACKUP_FILE_PATH" $BACKUP_CONTENT 2>/dev/null; then
        echo ""
        print_success "Backup created successfully!"

        # Show backup information
        local backup_size=$(du -h "$BACKUP_FILE_PATH" | cut -f1)
        echo ""
        echo -e "${CYAN}════════════════════════════════════════════════════════${RESET}"
        echo -e "  File: ${WHITE}$(basename "$BACKUP_FILE_PATH")${RESET}"
        echo -e "  Size: ${CYAN}$backup_size${RESET}"
        echo -e "  Location: ${GRAY}$BACKUP_FILE_PATH${RESET}"
        echo -e "${CYAN}════════════════════════════════════════════════════════${RESET}"
        echo ""
        return 0
    else
        print_error "Failed to create backup"

        # Try to clean partial file
        [ -f "$BACKUP_FILE_PATH" ] && rm -f "$BACKUP_FILE_PATH"

        return 1
    fi
}

# Upload to Google Drive
upload_to_gdrive() {
    local backup_file="$1"

    # Check if Google Drive is configured
    if [ -z "$GDRIVE_BACKUP_PATH" ]; then
        return 0
    fi

    print_step "Uploading to Google Drive..."
    echo ""

    # Check if rclone is installed
    if ! command -v rclone &> /dev/null; then
        print_warning "rclone is not installed"
        echo -e "  ${GRAY}To enable Google Drive backup, install rclone:${RESET}"
        echo -e "  ${CYAN}curl https://rclone.org/install.sh | sudo bash${RESET}"
        echo ""
        return 1
    fi

    # Extract remote from path (part before :)
    local remote=$(echo "$GDRIVE_BACKUP_PATH" | cut -d: -f1)

    # Check if remote is configured
    if ! rclone listremotes | grep -q "^${remote}:$"; then
        print_warning "Google Drive is not configured in rclone"
        echo -e "  ${GRAY}Configure Google Drive:${RESET}"
        echo -e "  ${CYAN}rclone config${RESET}"
        echo ""
        return 1
    fi

    # Upload file
    if rclone copy "$backup_file" "$GDRIVE_BACKUP_PATH" --progress; then
        echo ""
        print_success "Backup uploaded to Google Drive!"
        echo -e "  Location: ${CYAN}$GDRIVE_BACKUP_PATH/$(basename "$backup_file")${RESET}"
        echo ""
        return 0
    else
        print_error "Failed to upload backup to Google Drive"
        echo ""
        return 1
    fi
}

# Clean old Google Drive backups
cleanup_old_gdrive_backups() {
    local keep_count=7

    # Check if Google Drive is configured
    if [ -z "$GDRIVE_BACKUP_PATH" ]; then
        return 0
    fi

    print_step "Cleaning old Google Drive backups (keeping $keep_count most recent)..."

    # List backups sorted by date (newest first)
    local backups=$(rclone lsf "$GDRIVE_BACKUP_PATH" --files-only 2>/dev/null | grep "hytale-backup-.*\.tar\.gz$" | sort -r)
    local total_backups=$(echo "$backups" | grep -c "hytale-backup-")

    if [ $total_backups -le $keep_count ]; then
        print_info "Total Drive backups: $total_backups (within limit)"
        echo ""
        return 0
    fi

    # Calculate how many backups should be deleted
    local to_delete=$((total_backups - keep_count))
    print_info "Total Drive backups: $total_backups"
    print_info "Backups to remove: $to_delete"
    echo ""

    # Skip N most recent and delete the rest
    local count=0
    echo "$backups" | while read -r backup; do
        count=$((count + 1))
        if [ $count -gt $keep_count ]; then
            print_step "Removing: $backup"
            if rclone delete "$GDRIVE_BACKUP_PATH/$backup" 2>/dev/null; then
                print_success "Removed: $backup"
            else
                print_warning "Failed to remove: $backup"
            fi
        fi
    done

    echo ""
    print_success "Cleanup completed!"
    echo ""
}

# Restart server if it was stopped
restart_server_if_needed() {
    if [ "$SERVER_WAS_STOPPED" = true ]; then
        echo ""
        read -p "Restart the server now? (Y/n): " restart

        if [[ ! "$restart" =~ ^[Nn]$ ]]; then
            print_step "Restarting Hytale server..."
            cd "$PROJECT_DIR"
            if docker compose start hytale-server 2>/dev/null || docker-compose start hytale-server 2>/dev/null; then
                print_success "Server restarted"
            else
                print_error "Could not restart server automatically"
                echo -e "  ${GRAY}Restart manually: docker compose up -d hytale-server${RESET}"
            fi
        else
            print_warning "Server remains stopped. Start manually when needed."
        fi
    fi
}

# List existing backups
list_existing_backups() {
    echo ""
    print_step "Existing backups:"
    echo ""

    if [ -d "$BACKUP_DIR" ] && [ "$(ls -A $BACKUP_DIR 2>/dev/null)" ]; then
        cd "$BACKUP_DIR"
        local count=0

        for backup in $(ls -t hytale-backup-*.tar.gz 2>/dev/null); do
            count=$((count + 1))
            local size=$(du -h "$backup" | cut -f1)
            local date=$(stat -c %y "$backup" | cut -d' ' -f1,2 | cut -d'.' -f1)
            echo -e "  ${count}. ${CYAN}${backup}${RESET}"
            echo -e "     Size: $size | Created: ${GRAY}$date${RESET}"
        done

        if [ $count -eq 0 ]; then
            print_info "No backups found in default directory"
        else
            echo ""
            print_info "Total: $count backup(s)"
        fi
    else
        print_info "No backups found in default directory"
    fi
    echo ""
}

# Final summary
show_summary() {
    local backup_file="$1"

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║           BACKUP COMPLETED SUCCESSFULLY                ║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo "How to restore this backup:"
    echo ""
    echo -e "  ${BLUE}1.${RESET} Stop the server:"
    echo -e "     ${CYAN}docker compose down${RESET}"
    echo ""
    echo -e "  ${BLUE}2.${RESET} Backup current data (safety):"
    echo -e "     ${CYAN}mv data data.old${RESET}"
    echo ""
    echo -e "  ${BLUE}3.${RESET} Extract backup:"
    echo -e "     ${CYAN}tar -xzf $(basename "$backup_file")${RESET}"
    echo ""
    echo -e "  ${BLUE}4.${RESET} Restart server:"
    echo -e "     ${CYAN}docker compose up -d${RESET}"
    echo ""
}

# Main
main() {
    # Enable maintenance mode
    "$PROJECT_DIR/scripts/maintenance-mode.sh" enable "Backup em andamento" 2>/dev/null || true

    clear
    print_header

    check_requirements
    show_save_info
    ask_stop_server
    choose_backup_location
    choose_backup_content

    if create_backup; then
        if upload_to_gdrive "$BACKUP_FILE_PATH"; then
            cleanup_old_gdrive_backups
        fi
        restart_server_if_needed
        list_existing_backups
        show_summary "$BACKUP_FILE_PATH"
    else
        print_error "Backup failed!"
        restart_server_if_needed
        # Disable maintenance mode even on error
        "$PROJECT_DIR/scripts/maintenance-mode.sh" disable 2>/dev/null || true
        exit 1
    fi

    # Disable maintenance mode
    "$PROJECT_DIR/scripts/maintenance-mode.sh" disable 2>/dev/null || true
}

# Execute
main
