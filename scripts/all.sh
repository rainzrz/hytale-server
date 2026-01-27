#!/bin/bash

# Script de manutenção para todos os containers
cd "$(dirname "$0")/.." || exit 1

case "$1" in
    start)
        echo "Iniciando todos os containers..."
        docker compose up -d
        echo "Todos os containers iniciados."
        ;;
    stop)
        echo "Parando todos os containers..."
        docker compose stop
        echo "Todos os containers parados."
        ;;
    restart)
        echo "Reiniciando todos os containers..."
        docker compose restart
        echo "Todos os containers reiniciados."
        ;;
    logs)
        echo "Logs de todos os containers:"
        docker compose logs -f
        ;;
    status)
        docker compose ps
        ;;
    rebuild)
        echo "Reconstruindo todos os containers..."
        docker compose up -d --build
        echo "Todos os containers reconstruídos."
        ;;
    down)
        echo "Removendo todos os containers..."
        docker compose down
        echo "Todos os containers removidos."
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|logs|status|rebuild|down}"
        exit 1
        ;;
esac
