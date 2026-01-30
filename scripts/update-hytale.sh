#!/bin/bash

# Hytale Server Updater
# Downloads and installs the latest Hytale server version

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

# Functions
print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║           HYTALE SERVER UPDATER                        ║${RESET}"
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

# Initial checks
check_requirements() {
    print_step "Checking requirements..."

    # Check if in correct directory
    if [ ! -d "$PROJECT_DIR" ]; then
        print_error "Project directory not found: $PROJECT_DIR"
        exit 1
    fi

    # Check if Docker is running
    if ! docker ps > /dev/null 2>&1; then
        print_error "Docker is not running or you don't have permission"
        exit 1
    fi

    # Check if downloader exists
    if [ ! -f "$DOWNLOADER" ]; then
        print_error "Hytale downloader not found: $DOWNLOADER"
        exit 1
    fi

    # Check if downloader has execution permission
    if [ ! -x "$DOWNLOADER" ]; then
        print_warning "Adding execution permission to downloader..."
        chmod +x "$DOWNLOADER"
    fi

    print_success "All requirements verified"
    echo ""
}

# Show current version
show_current_version() {
    print_step "Current installed version:"

    if [ -f "$SERVER_DIR/HytaleServer.jar" ]; then
        # Extract version from manifest
        local version=$(unzip -p "$SERVER_DIR/HytaleServer.jar" META-INF/MANIFEST.MF 2>/dev/null | grep "Implementation-Version:" | cut -d' ' -f2 | tr -d '\r')

        if [ -n "$version" ]; then
            echo -e "  ${CYAN}[VERSION]${RESET} $version"
        else
            local jar_date=$(stat -c %y "$SERVER_DIR/HytaleServer.jar" | cut -d' ' -f1)
            echo -e "  ${CYAN}[JAR]${RESET} Installed on $jar_date"
        fi

        local jar_size=$(du -h "$SERVER_DIR/HytaleServer.jar" | cut -f1)
        echo -e "  ${CYAN}[SIZE]${RESET} $jar_size"

        if [ -f "$SERVER_DIR/Assets.zip" ]; then
            local assets_size=$(du -h "$SERVER_DIR/Assets.zip" | cut -f1)
            echo -e "  ${CYAN}[ASSETS]${RESET} $assets_size"
        fi
    else
        print_warning "No version installed"
    fi
    echo ""
}

# Confirm update
confirm_update() {
    echo -e "${CYAN}════════════════════════════════════════════════════════${RESET}"
    echo -e "${WHITE}  UPDATE PROCESS${RESET}"
    echo -e "${CYAN}════════════════════════════════════════════════════════${RESET}"
    echo ""
    echo "The process will:"
    echo -e "  ${BLUE}1.${RESET} Stop the server (players will be disconnected)"
    echo -e "  ${BLUE}2.${RESET} Backup current version"
    echo -e "  ${BLUE}3.${RESET} Download new version"
    echo -e "  ${BLUE}4.${RESET} Rebuild Docker image"
    echo -e "  ${BLUE}5.${RESET} Restart the server"
    echo ""
    echo -ne "${GRAY}Continue? (y/N): ${RESET}"
    read confirm

    if [[ ! "$confirm" =~ ^[YySs]$ ]]; then
        print_warning "Update cancelled by user"
        exit 0
    fi
    echo ""
}

# Stop server
stop_server() {
    print_step "Stopping Hytale server..."
    cd "$PROJECT_DIR"

    if docker ps --format '{{.Names}}' | grep -q "^hytale-server$"; then
        if docker compose stop hytale-server 2>/dev/null || docker-compose stop hytale-server 2>/dev/null; then
            print_success "Server stopped"
        else
            print_error "Failed to stop server"
            exit 1
        fi
    else
        print_warning "Server was already stopped"
    fi
    echo ""
}

# Backup
backup_current_version() {
    print_step "Backing up current version..."

    if [ -d "$SERVER_DIR" ]; then
        local backup_name=".server.backup-$(date +%Y%m%d-%H%M%S)"
        mv "$SERVER_DIR" "$PROJECT_DIR/$backup_name"
        print_success "Backup created: $backup_name"

        # Clean old backups (keep only 3 most recent)
        print_step "Cleaning old backups..."
        cd "$PROJECT_DIR"
        ls -dt .server.backup-* 2>/dev/null | tail -n +4 | xargs rm -rf 2>/dev/null
        print_success "Old backups cleaned (kept 3 most recent)"
    else
        print_warning "No previous version to backup"
    fi
    echo ""
}

# Download new version
download_new_version() {
    print_step "Downloading new Hytale version..."
    echo ""

    mkdir -p "$SERVER_DIR"
    cd "$SERVER_DIR"

    # Download ZIP
    if "$DOWNLOADER"; then
        echo ""
        print_success "Download completed!"

        # Find downloaded ZIP file
        local zip_file=$(ls -t *.zip 2>/dev/null | head -n1)
        if [ -z "$zip_file" ]; then
            print_error "ZIP file not found"
            print_warning "Restoring backup..."
            rollback
            exit 1
        fi

        # List ZIP contents
        print_step "Verifying file contents..."
        unzip -l "$zip_file"
        echo ""

        # Extract ZIP
        print_step "Extracting files..."
        if unzip -o "$zip_file"; then
            echo ""
            print_success "Extraction completed!"

            # Move files from Server/ subdirectory to root
            if [ -d "Server" ]; then
                print_step "Moving files from Server/ subdirectory..."
                mv Server/* . 2>/dev/null
                rm -rf Server
            fi

            # Remove ZIP and temporary credentials
            rm -f "$zip_file" .hytale-downloader-credentials.json

            # Show installed files
            print_step "Installed files:"
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
            print_error "Failed to extract files"
            print_warning "Restoring backup..."
            rollback
            exit 1
        fi
    else
        print_error "Failed to download new version"
        print_warning "Restoring backup..."
        rollback
        exit 1
    fi
    echo ""
}

# Rebuild Docker
rebuild_docker() {
    print_step "Rebuilding Docker image..."
    cd "$PROJECT_DIR"

    if docker compose build hytale-server 2>/dev/null || docker-compose build hytale-server 2>/dev/null; then
        print_success "Docker image rebuilt"
    else
        print_error "Failed to rebuild Docker image"
        print_warning "Restoring backup..."
        rollback
        exit 1
    fi
    echo ""
}

# Start server
start_server() {
    print_step "Starting Hytale server..."
    cd "$PROJECT_DIR"

    if docker compose up -d hytale-server 2>/dev/null || docker-compose up -d hytale-server 2>/dev/null; then
        print_success "Server started"
    else
        print_error "Failed to start server"
        print_warning "Restoring backup..."
        rollback
        exit 1
    fi
    echo ""
}

# Show logs
show_logs() {
    print_step "Waiting for server to initialize (5 seconds)..."
    sleep 5
    echo ""

    print_step "Recent server logs:"
    echo -e "${GRAY}════════════════════════════════════════════════════════${RESET}"
    docker logs --tail 20 hytale-server
    echo -e "${GRAY}════════════════════════════════════════════════════════${RESET}"
    echo ""

    print_success "To view live logs, use:"
    echo -e "  ${CYAN}docker compose logs -f hytale-server${RESET}"
    echo ""
}

# Restart Discord bot
restart_discord_bot() {
    print_step "Restarting Discord bot to update version..."
    cd "$PROJECT_DIR"

    if docker compose restart discord-bot 2>/dev/null || docker-compose restart discord-bot 2>/dev/null; then
        print_success "Discord bot restarted"
    else
        print_warning "Could not restart Discord bot automatically"
        echo -e "  ${GRAY}Restart manually: docker compose restart discord-bot${RESET}"
    fi
    echo ""
}

# Rollback on error
rollback() {
    print_warning "Starting rollback..."

    # Remove problematic version
    if [ -d "$SERVER_DIR" ]; then
        rm -rf "$SERVER_DIR"
    fi

    # Restore last backup
    local last_backup=$(ls -dt "$PROJECT_DIR"/.server.backup-* 2>/dev/null | head -n1)
    if [ -n "$last_backup" ]; then
        mv "$last_backup" "$SERVER_DIR"
        print_success "Backup restored: $(basename $last_backup)"

        # Rebuild with old version
        cd "$PROJECT_DIR"
        docker compose build hytale-server 2>/dev/null || docker-compose build hytale-server
        docker compose up -d hytale-server 2>/dev/null || docker-compose up -d hytale-server

        print_success "Server reverted to previous version"
    else
        print_error "No backup found to restore"
    fi
}

# Final summary
show_summary() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║           UPDATE COMPLETED SUCCESSFULLY                ║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo "Next steps:"
    echo ""
    echo -e "  ${BLUE}1.${RESET} Verify server is running:"
    echo -e "     ${CYAN}docker compose ps${RESET}"
    echo ""
    echo -e "  ${BLUE}2.${RESET} Monitor logs in real time:"
    echo -e "     ${CYAN}docker compose logs -f hytale-server${RESET}"
    echo ""
    echo -e "  ${BLUE}3.${RESET} Test connection in-game:"
    echo -e "     ${CYAN}186.219.130.224:25565${RESET}"
    echo ""
    echo -e "  ${BLUE}4.${RESET} If problems occur, revert manually:"
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
