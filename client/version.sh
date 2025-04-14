#!/bin/bash

# Create src/lib directory if it doesn't exist
mkdir -p src/lib

# Extract version from package.json, looking for @elizaos/core version
VERSION=$(grep -A 1 '"@elizaos/core"' package.json | grep -o '"[0-9]\+\.[0-9]\+\.[0-9]\+"' | tr -d '"' || echo "0.1.0")

# Create or overwrite info.json with the version
echo "{\"version\": \"$VERSION\"}" > src/lib/info.json

echo "Created src/lib/info.json with version $VERSION"
