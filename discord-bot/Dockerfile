# Usa imagem oficial do Python
FROM python:3.12-slim

# Define pasta de trabalho
WORKDIR /app

# Copia arquivos para o container
COPY bot.py requirements.txt /app/

# Instala dependências
RUN pip install --no-cache-dir -r requirements.txt

# Comando para rodar o bot
CMD ["python", "bot.py"]
