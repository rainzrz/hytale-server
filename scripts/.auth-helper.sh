#!/bin/bash

# Helper script para autenticação automática do Hytale
# Versão simplificada e robusta

CONTAINER_NAME="${1:-hytale-server}"
PROFILE_INDEX="${HYTALE_PROFILE_INDEX:-1}"

echo ""
echo "=== AUTENTICAÇÃO AUTOMÁTICA DO HYTALE ==="
echo ""
echo "Perfil configurado: ${PROFILE_INDEX}"
echo ""

# Verifica se expect está disponível
if ! command -v expect > /dev/null 2>&1; then
    echo "ERRO: expect não está instalado"
    echo "Instale com: sudo apt-get install expect"
    exit 1
fi

# Cria script expect temporário
EXPECT_SCRIPT=$(mktemp)

cat > "$EXPECT_SCRIPT" << 'EXPECT_EOF'
#!/usr/bin/expect -f
set timeout -1

set container_name [lindex $argv 0]
set profile_index [lindex $argv 1]

# Conecta ao container
spawn docker attach $container_name

# Aguarda o prompt
expect ">"

# Envia comando de autenticação
send "/auth login device\r"

# Aguarda e captura o link
expect {
    -re {Or visit: (https://[^\s]+)} {
        set url $expect_out(1,string)
        send_user "\n"
        send_user "========================================\n"
        send_user "LINK DE AUTENTICACAO:\n"
        send_user "$url\n"
        send_user "========================================\n"
        send_user "\n"
        send_user "Aguardando autorizacao...\n"
        send_user "\n"
    }
}

# Aguarda resultado da autenticação
expect {
    -re "Multiple profiles available" {
        send_user "\n"
        send_user "Multiplos perfis detectados\n"

        # Aguarda a lista completa de perfis
        expect -re ">" {
            send_user "\n"
            send_user "Selecionando perfil $profile_index automaticamente...\n"
            send_user "\n"
            send "/auth select $profile_index\r"
        }

        # Aguarda confirmação da seleção
        expect {
            -re "Selected profile:" {
                send_user "\n"
                send_user "Perfil selecionado com sucesso!\n"
                send_user "\n"
            }
            timeout {
                send_user "\nErro ao selecionar perfil\n"
            }
        }
    }
    -re "Authentication successful|Selected profile:" {
        send_user "\n"
        send_user "Autenticacao bem-sucedida!\n"
        send_user "\n"
    }
}

# Aguarda 2 segundos
sleep 2

# Desconecta do container (Ctrl+P seguido de Ctrl+Q)
send "\x10"
sleep 0.5
send "\x11"

# Aguarda desconexão com timeout
set timeout 5
expect {
    eof { }
    timeout { }
}
EXPECT_EOF

# Executa o script expect
chmod +x "$EXPECT_SCRIPT"
expect "$EXPECT_SCRIPT" "$CONTAINER_NAME" "$PROFILE_INDEX" 2>&1

EXIT_CODE=$?

# Remove script temporário
rm -f "$EXPECT_SCRIPT"

echo ""
echo "=== PROCESSO FINALIZADO ==="
echo ""

exit $EXIT_CODE
