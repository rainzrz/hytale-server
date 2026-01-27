FROM python:3.12-slim

WORKDIR /app

# Instala docker-cli
RUN apt-get update \
    && apt-get install -y docker.io \
    && rm -rf /var/lib/apt/lists/*

# Copia arquivos do bot
COPY .docker/discord-bot/bot.py .docker/discord-bot/requirements.txt /app/

# Instala dependências Python
RUN pip install --no-cache-dir -r requirements.txt

# Logs em tempo real
ENV PYTHONUNBUFFERED=1

CMD ["python", "-u", "bot.py"]
