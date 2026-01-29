#!/bin/bash

# Script para controlar modo de manutenção no Discord bot

MAINTENANCE_FILE="/tmp/hytale_maintenance.flag"
PROJECT_DIR="/home/rainz/hytale-server"

enable_maintenance() {
    local motivo="$1"
    if [ -z "$motivo" ]; then
        motivo="Manutenção em andamento"
    fi

    echo "$motivo" > "$MAINTENANCE_FILE"
    echo "[MAINTENANCE] Modo de manutenção ATIVADO: $motivo"

    # Tenta reiniciar o bot (usa docker compose ou docker-compose)
    cd "$PROJECT_DIR" 2>/dev/null
    (docker compose restart discord-bot 2>/dev/null || docker-compose restart discord-bot 2>/dev/null) || \
        echo "[MAINTENANCE] Aviso: Não foi possível reiniciar o bot automaticamente"
}

disable_maintenance() {
    rm -f "$MAINTENANCE_FILE"
    echo "[MAINTENANCE] Modo de manutenção DESATIVADO"

    # Tenta reiniciar o bot (usa docker compose ou docker-compose)
    cd "$PROJECT_DIR" 2>/dev/null
    (docker compose restart discord-bot 2>/dev/null || docker-compose restart discord-bot 2>/dev/null) || \
        echo "[MAINTENANCE] Aviso: Não foi possível reiniciar o bot automaticamente"
}

case "$1" in
    enable)
        enable_maintenance "$2"
        ;;
    disable)
        disable_maintenance
        ;;
    status)
        if [ -f "$MAINTENANCE_FILE" ]; then
            echo "Manutenção ATIVA: $(cat "$MAINTENANCE_FILE")"
        else
            echo "Manutenção INATIVA"
        fi
        ;;
    *)
        echo "Uso: $0 {enable|disable|status} [motivo]"
        echo ""
        echo "Exemplos:"
        echo "  $0 enable 'Backup em andamento'"
        echo "  $0 disable"
        echo "  $0 status"
        exit 1
        ;;
esac
