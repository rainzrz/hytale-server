#!/bin/bash

# Helper script para autenticação automática do Hytale
# Este script usa expect (se disponível) ou bash puro

# Cores
RESET='\033[0m'
BLUE='\033[38;5;39m'
CYAN='\033[38;5;51m'
WHITE='\033[1;37m'
GRAY='\033[38;5;245m'
RED='\033[38;5;196m'
YELLOW='\033[38;5;226m'
GREEN='\033[38;5;46m'

CONTAINER_NAME="${1:-hytale-server}"

# Limpa tela
clear
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║        🔐 ASSISTENTE DE AUTENTICAÇÃO AUTOMÁTICO        ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Verifica se expect está disponível
if command -v expect > /dev/null 2>&1; then
    echo -e "${GREEN}[✓]${RESET} Expect detectado - usando modo totalmente automático"
    echo ""
    sleep 1

    # Cria script expect temporário
    EXPECT_SCRIPT=$(mktemp)
    cat > "$EXPECT_SCRIPT" << 'EOF_EXPECT'
#!/usr/bin/expect -f
set timeout -1

# Cores
set CYAN "\033\[38;5;51m"
set YELLOW "\033\[38;5;226m"
set WHITE "\033\[1;37m"
set RESET "\033\[0m"
set BLUE "\033\[38;5;39m"
set GRAY "\033\[38;5;245m"

set container_name [lindex $argv 0]

# Conecta ao container
spawn docker attach $container_name

# Aguarda o prompt
expect ">"

# Envia comando de autenticação
send "/auth login device\r"

# Aguarda e captura o link
expect {
    -re "Or visit: (https://\[^\\s\]+)" {
        set url $expect_out(1,string)

        # Limpa tela e mostra link em destaque
        send_user "\n\n"
        send_user "$CYAN╔════════════════════════════════════════════════════════╗$RESET\n"
        send_user "$CYAN║                  🔐 LINK DE AUTENTICAÇÃO               ║$RESET\n"
        send_user "$CYAN╚════════════════════════════════════════════════════════╝$RESET\n"
        send_user "\n"
        send_user "$WHITE>>> Abra este link no seu navegador:$RESET\n"
        send_user "\n"
        send_user "       $YELLOW$url$RESET\n"
        send_user "\n"
        send_user "$GRAY Aguardando autorização...$RESET\n"
        send_user "\n\n"
    }
}

# Verifica se tem múltiplos perfis
expect {
    -re "Multiple profiles available" {
        send_user "\n"
        send_user "$YELLOW╔════════════════════════════════════════════════════════╗$RESET\n"
        send_user "$YELLOW║               ⚠️  MÚLTIPLOS PERFIS DETECTADOS          ║$RESET\n"
        send_user "$YELLOW╚════════════════════════════════════════════════════════╝$RESET\n"
        send_user "\n"

        # Captura perfis
        expect -re "\\\[1\\\] (\[^\\r\\n\]+)" {
            set profile1 $expect_out(1,string)
            send_user "$CYAN  [1] $profile1$RESET\n"
        }

        expect {
            -re "\\\[2\\\] (\[^\\r\\n\]+)" {
                set profile2 $expect_out(1,string)
                send_user "$CYAN  [2] $profile2$RESET\n"

                send_user "\n"
                send_user "$WHITE>>> Digite o número do perfil desejado:$RESET "

                # Aguarda input do usuário
                interact -o -re "^\[0-9\]+\r" {
                    # Usuário digitou um número
                    set selection $interact_out(0,string)
                    # Continua o script
                }
            }
            timeout {
                # Apenas 1 perfil ou timeout
                expect ">"
                send "/auth select 1\r"
            }
        }
    }
    -re "Authentication successful" {
        # Já foi autenticado (apenas 1 perfil)
        send_user "\n"
        send_user "$BLUE╔════════════════════════════════════════════════════════╗$RESET\n"
        send_user "$BLUE║            ✅ AUTENTICAÇÃO BEM-SUCEDIDA!               ║$RESET\n"
        send_user "$BLUE╚════════════════════════════════════════════════════════╝$RESET\n"
        send_user "\n"
        send_user "$WHITE>>> Saindo automaticamente em 3 segundos...$RESET\n"
        send_user "\n"

        sleep 3

        # Envia Ctrl+P + Ctrl+Q para desatachar
        send "\x10\x11"
        expect eof
        exit 0
    }
}

# Se chegou aqui, teve múltiplos perfis - aguarda autenticação após seleção
expect -re "Authentication successful" {
    send_user "\n"
    send_user "$BLUE╔════════════════════════════════════════════════════════╗$RESET\n"
    send_user "$BLUE║            ✅ AUTENTICAÇÃO BEM-SUCEDIDA!               ║$RESET\n"
    send_user "$BLUE╚════════════════════════════════════════════════════════╝$RESET\n"
    send_user "\n"
    send_user "$WHITE>>> Saindo automaticamente em 3 segundos...$RESET\n"
    send_user "\n"

    sleep 3

    # Envia Ctrl+P + Ctrl+Q
    send "\x10\x11"
}

expect eof
EOF_EXPECT

    # Executa o script expect
    chmod +x "$EXPECT_SCRIPT"
    expect "$EXPECT_SCRIPT" "$CONTAINER_NAME"

    # Remove script temporário
    rm -f "$EXPECT_SCRIPT"

else
    # Modo manual com assistência
    echo -e "${YELLOW}[!]${RESET} Expect não encontrado - usando modo assistido"
    echo ""
    echo -e "${WHITE}Instalando expect para modo totalmente automático:${RESET}"
    echo -e "  ${GRAY}sudo apt-get install expect${RESET}"
    echo ""
    echo -e "${GRAY}Pressione Enter para continuar com modo assistido...${RESET}"
    read

    clear
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║              📋 INSTRUÇÕES DE AUTENTICAÇÃO             ║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${YELLOW}[1]${RESET} ${WHITE}Digite o comando:${RESET} ${YELLOW}/auth login device${RESET}"
    echo ""
    echo -e "${YELLOW}[2]${RESET} ${WHITE}Quando aparecer o link, copie e abra no navegador${RESET}"
    echo ""
    echo -e "${YELLOW}[3]${RESET} ${WHITE}Se tiver múltiplos perfis, escolha com:${RESET} ${YELLOW}/auth select X${RESET}"
    echo ""
    echo -e "${YELLOW}[4]${RESET} ${WHITE}Após autenticação, saia com:${RESET} ${YELLOW}Ctrl+P${RESET} ${WHITE}e${RESET} ${YELLOW}Ctrl+Q${RESET}"
    echo ""
    echo -e "${GRAY}════════════════════════════════════════════════════════${RESET}"
    echo ""
    echo -e "${GRAY}Abrindo console em 3 segundos...${RESET}"
    sleep 3

    docker attach "$CONTAINER_NAME"
fi

# Limpa tela ao sair
clear
echo ""
echo -e "${BLUE}[✓]${RESET} Processo de autenticação finalizado."
echo ""
