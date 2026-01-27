#!/bin/bash

# Script de manutenção para o container hytale-server
CONTAINER_NAME="hytale-server"

cd "$(dirname "$0")/.." || exit 1

case "$1" in
    start)
        echo "Iniciando $CONTAINER_NAME..."
        docker compose up -d $CONTAINER_NAME
        echo "$CONTAINER_NAME iniciado."
        ;;
    stop)
        echo "Parando $CONTAINER_NAME..."
        docker compose stop $CONTAINER_NAME
        echo "$CONTAINER_NAME parado."
        ;;
    restart)
        echo "Reiniciando $CONTAINER_NAME..."
        docker compose restart $CONTAINER_NAME
        echo "$CONTAINER_NAME reiniciado."
        ;;
    logs)
        echo "Logs de $CONTAINER_NAME:"
        docker compose logs -f $CONTAINER_NAME
        ;;
    status)
        docker compose ps $CONTAINER_NAME
        ;;
    rebuild)
        echo "Reconstruindo $CONTAINER_NAME..."
        docker compose up -d --build $CONTAINER_NAME
        echo "$CONTAINER_NAME reconstruído."
        ;;
    attach)
        echo "Conectando ao console do servidor..."
        docker attach $CONTAINER_NAME
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|logs|status|rebuild|attach}"
        exit 1
        ;;
esac
