#!/bin/bash

# Kill any existing server processes
echo "Cleaning up existing processes..."
pkill -f "pnpm.*start" || true

# Kill any processes using our ports
echo "Clearing ports..."
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
lsof -ti:3001 | xargs kill -9 2>/dev/null || true
lsof -ti:3002 | xargs kill -9 2>/dev/null || true

# Wait a moment to ensure ports are cleared
sleep 2

# Verify ports are clear
echo "Verifying ports are clear..."
if lsof -i:3000 > /dev/null; then
    echo "Port 3000 is still in use. Please check manually."
    exit 1
fi

# Start the server with the specified character
echo "Starting server with character: characters/horatio.character.json"
cd /home/ubuntu/eliza-starter && \
NODE_ENV=production \
HOST=0.0.0.0 \
SERVER_PORT=3000 \
DEBUG=* \
pnpm start -- --character characters/horatio.character.json 2>&1 | tee server.log