#!/bin/bash
set -e

# Build Java command
JAVA_CMD="java"

# Add JVM options
JAVA_CMD="$JAVA_CMD $JAVA_OPTS"

# Add AOT cache if enabled
if [ "$USE_AOT_CACHE" = "true" ] && [ -f "/server/HytaleServer.aot" ]; then
    JAVA_CMD="$JAVA_CMD -XX:AOTCache=HytaleServer.aot"
fi

# Add server jar and assets
JAVA_CMD="$JAVA_CMD -jar HytaleServer.jar --assets Assets.zip"

# Add bind address
JAVA_CMD="$JAVA_CMD --bind 0.0.0.0:${SERVER_PORT:-5520}"

# Add extra arguments if provided
if [ -n "$EXTRA_ARGS" ]; then
    JAVA_CMD="$JAVA_CMD $EXTRA_ARGS"
fi

echo "Starting Hytale Server..."
echo "Command: $JAVA_CMD"

# Execute the server
exec $JAVA_CMD
