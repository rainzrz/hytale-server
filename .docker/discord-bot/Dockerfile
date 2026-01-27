# Usa imagem oficial do Python
FROM python:3.12-slim

# Define pasta de trabalho
WORKDIR /app

# Copia arquivos para o container
COPY .docker/discord-bot/bot.py .docker/discord-bot/requirements.txt /app/

# Instala dependências
RUN pip install --no-cache-dir -r requirements.txt

# Desabilita buffer do Python para logs em tempo real
ENV PYTHONUNBUFFERED=1

# Comando para rodar o bot
CMD ["python", "-u", "bot.py"]
