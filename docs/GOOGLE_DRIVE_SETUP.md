# Configuração do Google Drive para Backups

Este guia explica como configurar o Google Drive para receber backups automáticos do servidor Hytale.

## Pré-requisitos

- Conta Google
- Acesso root ao servidor

## 1. Instalar rclone

```bash
curl https://rclone.org/install.sh | sudo bash
```

Verifique a instalação:
```bash
rclone version
```

## 2. Configurar Google Drive

Execute o comando de configuração:
```bash
rclone config
```

Siga os passos:

1. **n** (New remote)
2. **Nome**: Digite `gdrive` (ou outro nome de sua preferência)
3. **Storage**: Digite `drive` (Google Drive)
4. **client_id**: Deixe em branco (Enter)
5. **client_secret**: Deixe em branco (Enter)
6. **scope**: Digite `1` (Full access)
7. **root_folder_id**: Deixe em branco (Enter)
8. **service_account_file**: Deixe em branco (Enter)
9. **Edit advanced config**: `n` (No)
10. **Use auto config**: `n` (No - pois é um servidor sem browser)

### 2.1. Autenticação

O rclone vai gerar um link e um código. Você tem duas opções:

**Opção A: Em outra máquina com browser**
1. Copie o comando mostrado (começa com `rclone authorize`)
2. Execute em uma máquina com browser
3. Copie o token gerado
4. Cole no servidor

**Opção B: Direto no browser**
1. Copie o link mostrado
2. Abra em um browser
3. Faça login na sua conta Google
4. Autorize o rclone
5. Copie o código de autorização
6. Cole no servidor

### 2.2. Finalizar configuração

1. **Team Drive**: `n` (No)
2. **Confirm**: `y` (Yes)
3. **Quit**: `q` (Quit)

## 3. Testar a configuração

Listar arquivos do Google Drive:
```bash
rclone ls gdrive:
```

Criar diretório de teste:
```bash
rclone mkdir gdrive:Backups/Hytale
```

## 4. Configurar o script de backup

Edite o arquivo `/home/rainz/hytale-server/scripts/backup.sh`:

```bash
# Encontre esta linha no início do arquivo:
GDRIVE_BACKUP_PATH="gdrive:Backups/Hytale"
```

Se você usou um nome diferente de `gdrive` na configuração, ajuste aqui:
```bash
GDRIVE_BACKUP_PATH="seu-nome:Backups/Hytale"
```

Para desabilitar o backup no Google Drive, deixe vazio:
```bash
GDRIVE_BACKUP_PATH=""
```

## 5. Testar o backup

Execute o script de backup:
```bash
cd /home/rainz/hytale-server
./scripts/backup.sh
```

O backup deve ser salvo em:
- Local: `/home/rainz/hytale-server/backups/`
- Google Drive: `Backups/Hytale/`

## Verificar backups no Google Drive

Listar backups:
```bash
rclone ls gdrive:Backups/Hytale
```

Ver tamanho total:
```bash
rclone size gdrive:Backups/Hytale
```

## Restaurar do Google Drive

Para baixar um backup específico:
```bash
rclone copy gdrive:Backups/Hytale/hytale-backup-NOME.tar.gz /home/rainz/hytale-server/backups/
```

## Limpeza automática (opcional)

Para manter apenas os 5 backups mais recentes no Google Drive:

```bash
# Adicione ao crontab (crontab -e):
0 4 * * * rclone delete gdrive:Backups/Hytale --min-age 30d
```

Isso remove backups com mais de 30 dias.

## Troubleshooting

### Erro: "Failed to create file system"
- Verifique se o remote está configurado: `rclone listremotes`
- Reconfigure: `rclone config`

### Erro: "Rate limit exceeded"
- Google Drive tem limites de taxa
- Aguarde alguns minutos e tente novamente

### Upload muito lento
- Ajuste o número de transferências paralelas:
  ```bash
  rclone copy arquivo.tar.gz gdrive:Backups/Hytale --transfers 4
  ```

### Ver logs detalhados
```bash
# Edite o script backup.sh, linha do rclone copy:
rclone copy "$backup_file" "$GDRIVE_BACKUP_PATH" --progress -v
```

## Recursos adicionais

- [Documentação oficial do rclone](https://rclone.org/docs/)
- [Google Drive com rclone](https://rclone.org/drive/)
