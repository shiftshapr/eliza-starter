#!/bin/bash

DEBUG_MODE=false
CHARACTERS=()

# Function for logging
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Parse command line options
while [[ $# -gt 0 ]]; do
  case $1 in
    --debug)
      DEBUG_MODE=true
      shift
      ;;
    -*)
      echo "Unknown option: $1"
      exit 1
      ;;
    *)
      # If argument doesn't start with -, treat as character name
      CHARACTERS+=("$1")
      shift
      ;;
  esac
done

if [ ${#CHARACTERS[@]} -eq 0 ]; then
    echo "Usage: $0 [--debug] character1 [character2 ...]"
    echo "Available characters:"
    ls -1 /home/ubuntu/eliza-starter/characters/*.character.json | xargs -n1 basename | sed 's/\.character\.json//'
    exit 1
fi

# Validate characters and build character paths
CHARACTER_PATHS=()
for char in "${CHARACTERS[@]}"; do
    # If the character doesn't end with .character.json, append it
    if [[ "$char" != *".character.json" ]]; then
        char="${char}.character.json"
    fi
    
    # Check if the character is in the characters directory
    CHARACTER_PATH="/home/ubuntu/eliza-starter/characters/$char"
    if [ ! -f "$CHARACTER_PATH" ]; then
        echo "Character file not found: $CHARACTER_PATH"
        echo "Available characters:"
        ls -1 /home/ubuntu/eliza-starter/characters/*.character.json | xargs -n1 basename | sed 's/\.character\.json//'
        exit 1
    fi
    
    CHARACTER_PATHS+=("characters/$char")
    CHARACTER_NAME=$(basename "$CHARACTER_PATH" .character.json)
    log "Validated character: $CHARACTER_NAME"
done

# Build comma-separated list of characters
CHARACTER_LIST=$(IFS=, ; echo "${CHARACTER_PATHS[*]}")
log "Restarting server with characters: $CHARACTER_LIST"

# Restart the server with new characters
pm2 stop eliza-server
pm2 delete eliza-server

# Create command script
SCRIPT_FILE="/home/ubuntu/eliza-starter/logs/restart_server.sh"
if [ "$DEBUG_MODE" = true ]; then
    echo "Debug mode enabled: Detailed logs will be available"
    cat > "$SCRIPT_FILE" << EOF
#!/bin/bash
cd /home/ubuntu/eliza-starter && NODE_ENV=production HOST=0.0.0.0 SERVER_PORT=3000 NODE_OPTIONS="--max-old-space-size=4096" DEBUG=* TRACE=* ELIZA_LOG_LEVEL=debug pnpm start -- --character $CHARACTER_LIST
EOF
else
    cat > "$SCRIPT_FILE" << EOF
#!/bin/bash
cd /home/ubuntu/eliza-starter && NODE_ENV=production HOST=0.0.0.0 SERVER_PORT=3000 NODE_OPTIONS="--max-old-space-size=4096" pnpm start -- --character $CHARACTER_LIST
EOF
fi
chmod +x "$SCRIPT_FILE"

cd /home/ubuntu/eliza-starter && \
pm2 start "$SCRIPT_FILE" \
    --name "eliza-server" \
    --log "/home/ubuntu/eliza-starter/logs/server.log" \
    --merge-logs \
    --time

# Check if server started
for i in {1..30}; do
    if curl -s "http://localhost:3000/agents" > /dev/null 2>&1; then
        echo "Server is running with new characters!"
        # Display the agents
        echo "Available agents:"
        curl -s "http://localhost:3000/agents" | python3 -m json.tool
        break
    fi
    echo -n "."
    sleep 1
done

echo "Server restarted! Access at http://localhost:3000"
echo "Check logs with: pm2 logs eliza-server"
