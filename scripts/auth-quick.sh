#!/bin/bash

# Quick Authentication Helper
# Simplifies the authentication process

# Colors - Blue and White theme
RESET='\033[0m'
BLUE='\033[38;5;39m'
CYAN='\033[38;5;51m'
WHITE='\033[1;37m'
GRAY='\033[38;5;245m'
YELLOW='\033[38;5;226m'

# Reset colors on exit or interrupt
trap 'echo -e "\033[0m"; exit 130' INT TERM

clear

echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║           AUTENTICAÇÃO RÁPIDA - HYTALE SERVER          ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${WHITE}Este script vai abrir o console do servidor.${RESET}"
echo ""
echo -e "${YELLOW}INSTRUÇÕES:${RESET}"
echo ""
echo -e "  ${BLUE}1.${RESET} Quando o console abrir, digite:"
echo -e "     ${CYAN}/auth login device${RESET}"
echo ""
echo -e "  ${BLUE}2.${RESET} Um link será exibido. Abra-o no navegador:"
echo -e "     ${CYAN}https://login.microsoftonline.com/...${RESET}"
echo ""
echo -e "  ${BLUE}3.${RESET} Faça login com sua conta Microsoft/Xbox"
echo ""
echo -e "  ${BLUE}4.${RESET} Após confirmar, volte ao console"
echo ""
echo -e "  ${BLUE}5.${RESET} Para sair SEM PARAR o servidor:"
echo -e "     Pressione ${CYAN}Ctrl+P${RESET} e depois ${CYAN}Ctrl+Q${RESET}"
echo ""
echo -e "${GRAY}════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${YELLOW}IMPORTANTE:${RESET} NÃO use Ctrl+C ou feche a janela!"
echo -e "Isso vai parar o servidor!"
echo ""
echo -e "${GRAY}════════════════════════════════════════════════════════${RESET}"
echo ""

read -p "Pressione Enter para abrir o console do servidor..."
echo ""
echo -e "${BLUE}[>]${RESET} Conectando ao console..."
echo ""

# Attach to container
docker attach hytale-server

# After detach
echo ""
echo -e "${BLUE}[OK]${RESET} Desconectado do console"
echo -e "${CYAN}    Servidor continua rodando em background${RESET}"
echo ""
