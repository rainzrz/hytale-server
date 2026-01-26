FROM eclipse-temurin:25-jre

LABEL maintainer="Hytale Server"
LABEL description="Hytale Dedicated Server"

# Create non-root user for security
RUN groupadd -r hytale && useradd -r -g hytale hytale

# Create server directory
WORKDIR /server

# Create necessary directories
RUN mkdir -p /server/mods /server/universe /server/logs /server/.cache \
    && chown -R hytale:hytale /server

# Copy server files
COPY --chown=hytale:hytale HytaleServer.jar /server/
COPY --chown=hytale:hytale HytaleServer.aot /server/
COPY --chown=hytale:hytale Assets.zip /server/

# Copy entrypoint script
COPY --chown=hytale:hytale entrypoint.sh /server/
RUN chmod +x /server/entrypoint.sh

# Switch to non-root user
USER hytale

# Expose UDP port (QUIC protocol)
EXPOSE 5520/udp

# Environment variables
ENV JAVA_OPTS="-Xms2G -Xmx4G"
ENV SERVER_PORT=5520
ENV USE_AOT_CACHE=true

# Health check - verifica se o processo Java está rodando
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pgrep -f "HytaleServer.jar" > /dev/null || exit 1

# Volumes for persistent data
VOLUME ["/server/universe", "/server/mods", "/server/logs"]

ENTRYPOINT ["/server/entrypoint.sh"]
