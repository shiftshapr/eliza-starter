# Eliza

## Edit the character files

Open `src/character.ts` to modify the default character. Uncomment and edit.

### Custom characters

To load custom characters instead:
- Use `pnpm start --characters="path/to/your/character.json"`
- Multiple character files can be loaded simultaneously
- Character files are stored in the `characters/` directory

### Process Knowledge Files

The system supports adding knowledge to characters from text and PDF documents. Here's how to process and merge knowledge:

1. Place your knowledge documents in the `knowledge/[character-name]/` directory
   - Supported formats: .txt and .pdf files
   - Create a subdirectory for each character (e.g., `knowledge/metalayer/`, `knowledge/horatio/`)

2. Process knowledge files into JSON:
```bash
# This will process all characters' knowledge files
./process_knowledge.sh

# The script will:
# - Skip characters with no documents
# - Process .txt and .pdf files
# - Create knowledge files in knowledge_files/[character].knowledge.json
```

3. Merge knowledge into character files:
```bash
# Navigate to the characterfile directory
cd characterfile

# Merge knowledge for a specific character
node scripts/knowledge2character.js ../eliza-starter/characters/[character].character.json ../eliza-starter/knowledge_files/[character].knowledge.json

# Example:
node scripts/knowledge2character.js ../eliza-starter/characters/metalayer.character.json ../eliza-starter/knowledge_files/metalayer.knowledge.json
```

The knowledge will be added to the character file in a `knowledge` section containing:
- `documents`: Full text of processed documents
- `chunks`: Text split into manageable chunks for processing

> **Performance Note**: Large knowledge files may increase startup time as they need to be loaded into memory. Consider:
> - Breaking up large documents into smaller, focused files
> - Using the `chunks` array for more efficient processing
> - Only including essential knowledge that the character needs to reference

### Add clients
```
# in character.ts
clients: [Clients.TWITTER, Clients.DISCORD],

# in character.json
clients: ["twitter", "discord"]
```

## Duplicate the .env.example template

```bash
cp .env.example .env
```

\* Fill out the .env file with your own values.

### Add login credentials and keys to .env
```
DISCORD_APPLICATION_ID="discord-application-id"
DISCORD_API_TOKEN="discord-api-token"
...
OPENROUTER_API_KEY="sk-xx-xx-xxx"
...
TWITTER_USERNAME="username"
TWITTER_PASSWORD="password"
TWITTER_EMAIL="your@email.com"
```

## Install dependencies and start your agent

```bash
pnpm i && pnpm start
```
Note: this requires node to be at least version 22 when you install packages and run the agent.

## Available Scripts

The project includes several utility scripts:

- `start-server.sh`: Starts the main server
- `start-services.sh`: Starts all required services
- `restart-characters.sh`: Restarts character instances
- `list-characters.sh`: Lists all available characters

## Project Structure

- `src/`: Source code directory
- `characters/`: Character configuration files
- `data/`: Data storage directory
- `logs/`: Application logs
- `content_cache/`: Cached content
- `deepseek-proxy/`: Proxy service for DeepSeek integration
- `client/`: Client-side code
- `scripts/`: Utility scripts

## Run with Docker

### Build and run Docker Compose (For x86_64 architecture)

#### Edit the docker-compose.yaml file with your environment variables

```yaml
services:
    eliza:
        environment:
            - OPENROUTER_API_KEY=blahdeeblahblahblah
```

#### Run the image

```bash
docker compose up
```

### Build the image with Mac M-Series or aarch64

Make sure docker is running.

```bash
# The --load flag ensures the built image is available locally
docker buildx build --platform linux/amd64 -t eliza-starter:v1 --load .
```

#### Edit the docker-compose-image.yaml file with your environment variables

```yaml
services:
    eliza:
        environment:
            - OPENROUTER_API_KEY=blahdeeblahblahblah
```

#### Run the image

```bash
docker compose -f docker-compose-image.yaml up
```

# Deploy with Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/template/aW47_j)