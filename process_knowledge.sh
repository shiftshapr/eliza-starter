#!/bin/bash

# Ensure we're in the characterfile directory
cd /home/ubuntu/characterfile

# Process each character's knowledge directory
for dir in /home/ubuntu/eliza-starter/knowledge/*/; do
    if [ -d "$dir" ]; then
        character=$(basename "$dir")
        echo "Processing knowledge for $character..."
        
        # Process the directory
        node /home/ubuntu/characterfile/scripts/folder2knowledge.js "$dir"
        
        echo "Completed processing $character"
    fi
done 