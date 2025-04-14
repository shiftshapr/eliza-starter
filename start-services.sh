#!/bin/bash

# Define log file paths
LOG_DIR="/home/ubuntu/eliza-starter/logs"
mkdir -p $LOG_DIR

# Default settings
DEBUG_MODE=false
CHARACTERS=()
DEFAULT_CHARACTER="horatio"
INSTANCE_NAME="default"  # Default instance name

# Function for logging
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_DIR/script.log"
}

debug_log() {
  if [ "$DEBUG_MODE" = true ]; then
    echo "[DEBUG][$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "[DEBUG][$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_DIR/debug.log"
  fi
}

# Parse command line options
while [[ $# -gt 0 ]]; do
  case $1 in
    --debug)
      DEBUG_MODE=true
      shift
      ;;
    --character=*)
      CHARACTERS+=("${1#*=}")
      shift
      ;;
    --instance=*)
      INSTANCE_NAME="${1#*=}"
      shift
      ;;
    -*)
      log "Unknown option: $1"
      exit 1
      ;;
    *)
      # If argument doesn't start with -, treat as character name
      CHARACTERS+=("$1")
      shift
      ;;
  esac
done

# If no characters specified, use default
if [ ${#CHARACTERS[@]} -eq 0 ]; then
  CHARACTERS=("$DEFAULT_CHARACTER")
fi

log "Starting services script for instance: $INSTANCE_NAME"
[ "$DEBUG_MODE" = true ] && log "Debug mode ENABLED - detailed logs will be written to $LOG_DIR/debug.log"

# Log character info
log "Characters to load: ${CHARACTERS[*]}"

# Check for PM2 and install if needed
if ! command -v pm2 &> /dev/null; then
    log "Installing PM2..."
    npm install -g pm2
fi

# Kill any existing processes using our ports
log "Clearing ports..."
lsof -ti:3000,3001,3002,3003,3004,3005,5173,9000 | xargs kill -9 2>/dev/null || true
# Also kill any node processes that might be holding onto ports
pkill -9 -f "node.*index.ts" 2>/dev/null || true
pkill -9 -f "pnpm.*start" 2>/dev/null || true
sleep 2

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
        log "Character file not found: $CHARACTER_PATH"
        log "Available characters:"
        ls -1 /home/ubuntu/eliza-starter/characters/*.character.json | xargs -n1 basename | sed 's/\.character\.json//'
        exit 1
    fi
    
    CHARACTER_PATHS+=("characters/$char")
    CHARACTER_NAME=$(basename "$CHARACTER_PATH" .character.json)
    log "Validated character: $CHARACTER_NAME ($CHARACTER_PATH)"
done

# Build comma-separated list of characters without the path prefix
CHAR_FILES=()
for char_path in "${CHARACTER_PATHS[@]}"; do
    CHAR_FILES+=("$char_path")
    log "Adding character path: $char_path to CHAR_FILES"
done

CHARACTER_LIST=$(IFS=, ; echo "${CHAR_FILES[*]}")
log "Final CHARACTER_LIST: $CHARACTER_LIST"

# Stop any existing PM2 processes for this instance
log "Stopping any existing PM2 processes for instance: $INSTANCE_NAME..."
pm2 stop "deepseek-proxy-$INSTANCE_NAME" 2>/dev/null || true
pm2 stop "eliza-server-$INSTANCE_NAME" 2>/dev/null || true
pm2 stop "eliza-client-$INSTANCE_NAME" 2>/dev/null || true
pm2 delete "deepseek-proxy-$INSTANCE_NAME" 2>/dev/null || true
pm2 delete "eliza-server-$INSTANCE_NAME" 2>/dev/null || true
pm2 delete "eliza-client-$INSTANCE_NAME" 2>/dev/null || true

# Clear the server log
log "Clearing server log..."
echo "" > "$LOG_DIR/server-$INSTANCE_NAME.log"

# Function to check if a service is running
check_service() {
    local service_name=$1
    local endpoint=$2
    local max_attempts=$3
    local delay=$4

    log "Waiting for $service_name to start (max $max_attempts attempts)..."
    for i in $(seq 1 $max_attempts); do
        if curl -s "$endpoint" > /dev/null 2>&1; then
            log "$service_name is running after $i attempts."
            return 0
        fi
        debug_log "Attempt $i: $service_name not responding yet"
        sleep $delay
    done
    
    log "ERROR: $service_name failed to start after $max_attempts attempts."
    pm2 logs $service_name --lines 50
    return 1
}

# STEP 1: Start DeepSeek Proxy
log "Starting DeepSeek proxy with PM2..."
cd /home/ubuntu/eliza-starter/deepseek-proxy && \
pm2 start "pnpm start" --name "deepseek-proxy-$INSTANCE_NAME" \
  --log "$LOG_DIR/proxy-$INSTANCE_NAME.log" \
  --merge-logs \
  --time

# Check if proxy started
check_service "deepseek-proxy-$INSTANCE_NAME" "http://localhost:9000/health" 15 1 || exit 1

# STEP 2: Start Server with all characters in one process
log "Starting server with characters: $CHARACTER_LIST"

# Restart the server with new characters
pm2 stop "eliza-server-$INSTANCE_NAME" 2>/dev/null || true
pm2 delete "eliza-server-$INSTANCE_NAME" 2>/dev/null || true

# Create base command script if it doesn't exist
SCRIPT_FILE="$LOG_DIR/start_server-$INSTANCE_NAME.sh"
if [ ! -f "$SCRIPT_FILE" ] || ! grep -q "CHARACTERS=" "$SCRIPT_FILE"; then
    log "Creating flexible start_server.sh script for instance: $INSTANCE_NAME"
    cat > "$SCRIPT_FILE" << EOF
#!/bin/bash
# Get characters from command line args, default to metalayer if none provided
CHARACTERS=\${@:-metalayer}
cd /home/ubuntu/eliza-starter && NODE_ENV=production HOST=0.0.0.0 SERVER_PORT=3000 NODE_OPTIONS="--max-old-space-size=2048" pnpm start -- --character \$CHARACTERS > /dev/null 2>&1
EOF
    chmod +x "$SCRIPT_FILE"
fi

# Start server with PM2, passing character list as arguments
cd /home/ubuntu/eliza-starter && \
pm2 start "$SCRIPT_FILE" \
    --name "eliza-server-$INSTANCE_NAME" \
    --log "/home/ubuntu/eliza-starter/logs/server-$INSTANCE_NAME.log" \
    --merge-logs \
    --time \
    --no-autorestart \
    --output /dev/null \
    --error /dev/null \
    -- $CHARACTER_LIST

# Check if server started
log "Waiting for server to start (this may take a few minutes)..."
check_service "eliza-server-$INSTANCE_NAME" "http://localhost:3000/agents" 180 2 || log "Warning: Server check failed, but continuing anyway..."

# STEP 3: Start Client
log "Starting client with PM2..."

# First install client dependencies
cd /home/ubuntu/eliza/client && \
pnpm install

# Then start the client
cd /home/ubuntu/eliza/client && \
pm2 start "pnpm dev" \
    --name "eliza-client-$INSTANCE_NAME" \
    --log "$LOG_DIR/client-$INSTANCE_NAME.log" \
    --merge-logs \
    --time

# Save PM2 configuration so it persists through reboots
log "Saving PM2 configuration..."
pm2 save

log "All services started successfully for instance: $INSTANCE_NAME!"
log "Use these commands for management:"
log "  - View all processes: pm2 list"
log "  - View logs: pm2 logs [service-name]"
log "  - Restart server: pm2 restart eliza-server-$INSTANCE_NAME"
log "  - Stop all: pm2 stop all"
log "  - Start all: pm2 start all"