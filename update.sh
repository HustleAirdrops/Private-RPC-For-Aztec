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

echo "✅ Updated docker-compose.yml and restarted Docker Compose successfully."

# 5️⃣ Signal governance proposal
curl -X POST http://localhost:8880 \
  -H 'Content-Type: application/json' \
  -d '{
    "jsonrpc":"2.0",
    "method":"nodeAdmin_setConfig",
    "params":[{"governanceProposerPayload":"0x9D8869D17Af6B899AFf1d93F23f863FF41ddc4fa"}],
    "id":1
  }'

echo "✅ Governance proposal vote sent successfully."
