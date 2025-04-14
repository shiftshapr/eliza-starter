#!/bin/bash

echo "Available characters:"
echo "-------------------"
ls -1 /home/ubuntu/eliza-starter/characters/*.character.json | xargs -n1 basename | sed 's/\.character\.json//'
echo ""

echo "Running agents:"
echo "--------------"
curl -s "http://localhost:3000/agents" | python3 -m json.tool
