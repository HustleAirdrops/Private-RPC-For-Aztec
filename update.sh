#!/bin/bash

# 1️⃣ Go to ethereum folder
cd /root/ethereum || { echo "Folder not found"; exit 1; }

# 2️⃣ Backup old docker-compose.yml
cp docker-compose.yml docker-compose.yml.bak.$(date +%F_%T)

# 3️⃣ Download latest docker-compose.yml from GitHub
curl -o docker-compose.yml https://raw.githubusercontent.com/HustleAirdrops/Private-RPC-For-Aztec/main/docker-compose.yml

# 4️⃣ Restart Docker Compose
docker-compose down
docker-compose up -d
