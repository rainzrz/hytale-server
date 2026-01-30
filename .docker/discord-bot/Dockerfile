FROM python:3.12-slim

WORKDIR /app

# Instala docker-cli
RUN apt-get update \
    && apt-get install -y docker.io \
    && rm -rf /var/lib/apt/lists/*

# Copia arquivos do bot
COPY .docker/discord-bot/bot.py .docker/discord-bot/requirements.txt /app/

# DEBUG: Verify file was copied correctly
RUN echo "=== VERIFICANDO BOT.PY ===" && \
    ls -la /app/bot.py && \
    wc -l /app/bot.py && \
    grep -c "verificar_autenticacao" /app/bot.py && \
    echo "=== FIM VERIFICAÇÃO ==="

# Instala dependências Python
RUN pip install --no-cache-dir -r requirements.txt

# Logs em tempo real
ENV PYTHONUNBUFFERED=1

CMD ["python", "-u", "bot.py"]
