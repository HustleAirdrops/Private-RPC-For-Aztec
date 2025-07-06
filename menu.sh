#!/bin/bash

set -euo pipefail
trap 'echo -e "\033[1;31m❌ Error occurred at line $LINENO. Exiting.\033[0m"' ERR

GREEN="\033[1;32m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RED="\033[1;31m"
NC="\033[0m"

BASE_DIR="/opt/eth-rpc-node"
JWT_PATH="$BASE_DIR/jwt.hex"

# Fetch IP safely
IP_ADDR="$(curl -s ifconfig.me || true)"
if [ -z "$IP_ADDR" ]; then
  IP_ADDR="$(hostname -I | awk '{print $1}')"
fi

print_banner() {
    clear
    echo "┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐"
    echo "│  ██╗░░██╗██╗░░░██╗░██████╗████████╗██╗░░░░░███████╗  ░█████╗░██╗██████╗░██████╗░██████╗░░█████╗░██████╗░░██████╗  │"
    echo "│  ██║░░██║██║░░░██║██╔════╝╚══██╔══╝██║░░░░░██╔════╝  ██╔══██╗██║██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝  │"
    echo "│  ███████║██║░░░██║╚█████╗░░░░██║░░░██║░░░░░█████╗░░  ███████║██║██████╔╝██║░░██║██████╔╝██║░░██║██████╔╝╚█████╗░  │"
    echo "│  ██╔══██║██║░░░██║░╚═══██╗░░░██║░░░██║░░░░░██╔══╝░░  ██╔══██║██║██╔══██╗██║░░██║██╔══██╗██║░░██║██╔═══╝░░╚═══██╗  │"
    echo "│  ██║░░██║╚██████╔╝██████╔╝░░░██║░░░███████╗███████╗  ██║░░██║██║██║░░██║██████╔╝██║░░██║╚█████╔╝██║░░░░░██████╔╝  │"
    echo "│  ╚═╝░░╚═╝░╚═════╝░╚═════╝░░░░╚═╝░░░╚══════╝╚══════╝  ╚═╝░░╚═╝╚═╝╚═╝░░╚═╝╚═════╝░╚═╝░░╚═╝░╚════╝░╚═╝░░░░░╚═════╝░  │"
    echo "└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘"
    echo -e "${YELLOW}                  🚀 Aztec Node Manager by Aashish 🚀${NC}"
    echo -e "${YELLOW}              GitHub: https://github.com/HustleAirdrops${NC}"
    echo -e "${YELLOW}              Telegram: https://t.me/Hustle_Airdrops${NC}"
    echo -e "${GREEN}===============================================================================${NC}"
    
    echo -e "  📡 Ethereum Sepolia Full Node Setup Menu"
    echo -e "  🔗 Geth (Execution) + Prysm (Beacon Chain)"
    echo -e "==============================================${NC}"
    echo "1) 🚀 Install & Start Rpc Sync"
    echo "2) 📜 View Logs"
    echo "3) 📶 Check Node Status"
    echo "4) 🔗 Get RPC URLs"
    echo "5) 🔐 Rpc Access Controller"
    echo "6) ❌ Exit"
    echo -e "==============================================${NC}"
    echo -en "${NC}Choose an option [1-5]: "
}

install_dependencies() {
  echo -e "${YELLOW}🔧 Installing required packages...${NC}"
  sudo apt update -y && sudo apt upgrade -y

  # Fix common lock issues
  sudo rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock-frontend
  sudo dpkg --configure -a

  local packages=(
    curl jq net-tools iptables build-essential git wget lz4 make gcc nano
    automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev
    libleveldb-dev tar clang bsdmainutils ncdu unzip ufw openssl
  )

  for pkg in "${packages[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      echo -e "${BLUE}🔄 Installing $pkg...${NC}"
      sudo apt-get install -y "$pkg"
      echo -e "${GREEN}✅ $pkg installed${NC}"
    else
      echo -e "${CYAN}✔️ $pkg already present${NC}"
    fi
  done
}

install_docker() {
  if ! command -v docker &>/dev/null; then
    echo -e "${CYAN}🐳 Installing Docker...${NC}"
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
    sudo apt-get install -y ca-certificates gnupg

    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo systemctl enable docker
    sudo systemctl restart docker

    echo -e "${GREEN}✅ Docker installed successfully${NC}"
  else
    echo -e "${CYAN}ℹ️ Docker already installed. Skipping.${NC}"
  fi
}

check_ports() {
  echo -e "${YELLOW}🕵️ Checking required ports...${NC}"
  local conflicts
  conflicts=$(sudo netstat -tuln | grep -E '30303|8545|8546|8551|4000|3500' || true)

  if [ -n "$conflicts" ]; then
    echo -e "${RED}❌ Ports already in use:\n$conflicts${NC}"
    exit 1
  else
    echo -e "${GREEN}✅ All required ports are available.${NC}"
  fi
}

create_directories() {
  echo -e "${YELLOW}📁 Creating directories...${NC}"
  sudo mkdir -p "$BASE_DIR/execution" "$BASE_DIR/consensus"
  sudo rm -f "$JWT_PATH"
  sudo openssl rand -hex 32 | sudo tee "$JWT_PATH" > /dev/null
  echo -e "${GREEN}✅ JWT created at $JWT_PATH${NC}"
}

write_compose_file() {
  echo -e "${YELLOW}📝 Writing docker-compose.yml...${NC}"
  sudo tee "$BASE_DIR/docker-compose.yml" > /dev/null <<EOF
version: '3.8'

services:
  execution:
    image: ethereum/client-go:stable
    container_name: geth
    network_mode: host
    restart: unless-stopped
    volumes:
      - ./execution:/data
      - ./jwt.hex:/data/jwt.hex
    command:
      - --sepolia
      - --http
      - --http.addr=0.0.0.0
      - --http.api=eth,net,web3
      - --authrpc.addr=0.0.0.0
      - --authrpc.jwtsecret=/data/jwt.hex
      - --authrpc.port=8551
      - --authrpc.vhosts=*
      - --syncmode=snap
      - --datadir=/data

  consensus:
    image: gcr.io/prysmaticlabs/prysm/beacon-chain:stable
    container_name: prysm
    network_mode: host
    restart: unless-stopped
    depends_on:
      - execution
    volumes:
      - ./consensus:/data
      - ./jwt.hex:/data/jwt.hex
    command:
      - --sepolia
      - --accept-terms-of-use
      - --datadir=/data
      - --disable-monitoring
      - --rpc-host=0.0.0.0
      - --rpc-port=4000
      - --grpc-gateway-host=0.0.0.0
      - --grpc-gateway-port=3500
      - --execution-endpoint=http://127.0.0.1:8551
      - --jwt-secret=/data/jwt.hex
      - --checkpoint-sync-url=https://checkpoint-sync.sepolia.ethpandaops.io
      - --genesis-beacon-api-url=https://checkpoint-sync.sepolia.ethpandaops.io
EOF

echo -e "${GREEN}✅ docker-compose.yml created successfully${NC}"
}


start_services() {
  echo -e "${CYAN}🚀 Starting Ethereum Sepolia services...${NC}"
  cd "$BASE_DIR"
  sudo docker compose up -d
  echo -e "${GREEN}✅ Services started.${NC}"
  echo -e "${GREEN}✅ Node is syncing now. Estimated time: 4-5 hours${NC}"
}

monitor_sync() {
  local last_block=0
  local last_time=$(date +%s)

  while true; do
    clear
    echo -e "\n${CYAN}🔍 Monitoring and Checking Node Sync Status...${NC}"

    echo -e "\n${YELLOW}📡 Geth (Execution) Sync Status...${NC}"
    SYNC=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
      -H "Content-Type: application/json" http://localhost:8545)

    IS_SYNCING=$(echo "$SYNC" | jq -r '.result != false')

    if [[ "$IS_SYNCING" == "true" ]]; then
      CURRENT=$(echo "$SYNC" | jq -r '.result.currentBlock // 0' | xargs printf "%d\n")
      HIGHEST=$(echo "$SYNC" | jq -r '.result.highestBlock // 0' | xargs printf "%d\n")
      START=$(echo "$SYNC" | jq -r '.result.startingBlock // 0' | xargs printf "%d\n")

      PROGRESS=$(awk "BEGIN {printf \"%.2f\", ($CURRENT/$HIGHEST)*100}")
      REMAINING=$((HIGHEST - CURRENT))

      current_time=$(date +%s)
      time_diff=$((current_time - last_time))
      block_diff=$((CURRENT - last_block))
      eta_msg="⏱️ Estimating time left..."

      if (( time_diff > 0 && block_diff > 0 )); then
        blocks_per_sec=$(awk "BEGIN {printf \"%.4f\", $block_diff / $time_diff}")
        seconds_left=$(awk "BEGIN {printf \"%d\", $REMAINING / $blocks_per_sec}")
        hours_left=$((seconds_left / 3600))
        minutes_left=$(((seconds_left % 3600) / 60))
        eta_msg="⏱️ Estimated Time Left : ${GREEN}${hours_left}h ${minutes_left}m${NC}"
      fi

      echo -e "$eta_msg"

      last_block=$CURRENT
      last_time=$current_time

      echo -e "🧱 Starting Block : $START"
      echo -e "⏳ Current Block  : $CURRENT"
      echo -e "🚀 Highest Block  : $HIGHEST"
      echo -e "🧮 Remaining      : $REMAINING"
      echo -e "📈 Sync Progress  : ${GREEN}${PROGRESS}%${NC}"
    else
      echo -e "${GREEN}✅ Geth is fully synced or syncing hasn't started yet.${NC}"
    fi

    echo -e "\n${YELLOW}🟣 Beacon Node Status (Prysm)...${NC}"
    PRYSM=$(curl -s http://localhost:3500/eth/v1/node/syncing)
    echo "$PRYSM" | jq

    echo -e "\n⏲️  Updated: $(date)"
    [[ "$IS_SYNCING" == "false" && "$(echo "$PRYSM" | jq -r '.data.sync_distance')" == "0" ]] && break

    sleep 10
  done
}


print_endpoints() {
  echo -e "${CYAN}\n🔗 Ethereum Sepolia RPC Endpoints:${NC}"
  echo -e "${GREEN}📎 Geth:     http://$IP_ADDR:8545${NC}"
  echo -e "${GREEN}📎 Prysm:    http://$IP_ADDR:3500${NC}"
  echo -e "${BLUE}\n🎉 Setup complete — Powered by Aashish💖 ✨${NC}"
}

check_node_status() {
  echo -e "\n${CYAN}🔍 Monitoring and Checking Node Sync Status...${NC}"
  IP_ADDR=$(curl -s ifconfig.me)
  local start_time=$(date +%s)

  while true; do
    clear
    echo -e "${CYAN}🔍 Monitoring and Checking Node Sync Status...${NC}"

    echo -e "\n${YELLOW}📡 Geth (Execution) Sync Status...${NC}"
    SYNC=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
      -H "Content-Type: application/json" http://localhost:8545)

    IS_SYNCING=$(echo "$SYNC" | jq -r '.result != false')

    if [[ "$IS_SYNCING" == "true" ]]; then
      CURRENT=$(echo "$SYNC" | jq -r '.result.currentBlock // 0' | xargs printf "%d\n")
      HIGHEST=$(echo "$SYNC" | jq -r '.result.highestBlock // 0' | xargs printf "%d\n")
      START=$(echo "$SYNC" | jq -r '.result.startingBlock // 0' | xargs printf "%d\n")

      PROGRESS=$(awk "BEGIN {printf \"%.2f\", ($CURRENT/$HIGHEST)*100}")
      REMAINING=$((HIGHEST - CURRENT))
      elapsed=$(( $(date +%s) - start_time ))

      eta_fmt=""
      if [[ $CURRENT -gt 0 && $elapsed -gt 0 ]]; then
        speed=$(awk "BEGIN { if ($elapsed > 0) printf \"%.4f\", $CURRENT / $elapsed; else print 0 }")
        if (( $(awk "BEGIN {print ($speed > 0)}") )); then
          eta=$(awk "BEGIN {printf \"%d\", $REMAINING / $speed}")
          eta_fmt=$(printf "%02d:%02d:%02d" $((eta/3600)) $((eta%3600/60)) $((eta%60)))
        fi
      fi

      echo -e "🧱 Starting Block : $START"
      echo -e "⏳ Current Block  : $CURRENT"
      echo -e "🚀 Highest Block  : $HIGHEST"
      echo -e "🧮 Remaining      : $REMAINING"
      echo -e "📈 Sync Progress  : ${GREEN}${PROGRESS}%${NC}"
      [[ -n "$eta_fmt" ]] && echo -e "⏱️ Estimated Time  : ${YELLOW}${eta_fmt}${NC}"
    else
      echo -e "${GREEN}✅ Geth is fully synced!${NC}"
    fi

    echo -e "\n${YELLOW}🟣 Beacon Node Status (Prysm)...${NC}"
    PRYSM=$(curl -s http://localhost:3500/eth/v1/node/syncing)
    echo "$PRYSM" | jq

    DISTANCE=$(echo "$PRYSM" | jq -r '.data.sync_distance // "1"')

    if [[ "$IS_SYNCING" == "false" && "$DISTANCE" == "0" ]]; then
      echo -e "\n${GREEN}✅ Both Geth and Prysm are fully synced!${NC}"
      echo -e "${CYAN}\n🔗 Ethereum Sepolia RPC Endpoints:${NC}"
      echo -e "${GREEN}📎 Geth:     http://$IP_ADDR:8545${NC}"
      echo -e "${GREEN}📎 Prysm:    http://$IP_ADDR:3500${NC}"
      echo -e "${BLUE}\n🎉 Setup complete — Powered by Aashish💖 ✨${NC}"
      break
    fi

    echo -e "\n⏲️  Updated: $(date)"
    echo -e "🔁 Next check in 10 seconds..."
    sleep 10
  done
}


print_rpc_endpoints() {
  echo -e "${CYAN}\n🔗 Ethereum Sepolia RPC Endpoints:${NC}"
  echo -e "${GREEN}📎 Geth:     http://$IP_ADDR:8545${NC}"
  echo -e "${GREEN}📎 Prysm:    http://$IP_ADDR:3500${NC}"

  echo -e "\n${CYAN}🔍 Checking Ethereum Sepolia Node Sync Status...${NC}"

  # === Geth Sync Check ===
  geth_sync=$(curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' http://$IP_ADDR:8545)

  if [[ "$geth_sync" == *"false"* ]]; then
    echo -e "✅ ${GREEN}Geth (Execution Layer): Fully Synced!${NC}"
    geth_synced=true
  else
    current_hex=$(echo "$geth_sync" | jq -r '.result.currentBlock')
    highest_hex=$(echo "$geth_sync" | jq -r '.result.highestBlock')

    current_dec=$((16#${current_hex:2}))
    highest_dec=$((16#${highest_hex:2}))
    percent=$(awk "BEGIN {printf \"%.2f\", ($current_dec/$highest_dec)*100}")
    remaining=$((highest_dec - current_dec))

    echo -e "🔄 ${YELLOW}Geth Syncing...${NC}"
    echo -e "   ⏳ Current Block : $current_dec"
    echo -e "   🚀 Highest Block : $highest_dec"
    echo -e "   ⌛ Remaining      : $remaining blocks"
    echo -e "   📊 Progress       : ${GREEN}$percent%${NC}"
    geth_synced=false
  fi

  # === Prysm Sync Check ===
  prysm_sync=$(curl -s http://$IP_ADDR:3500/eth/v1/node/syncing)

  distance=$(echo "$prysm_sync" | jq -r '.data.sync_distance // "0"' 2>/dev/null)
  head_slot=$(echo "$prysm_sync" | jq -r '.data.head_slot // "0"' 2>/dev/null)

  if [[ "$distance" == "0" ]]; then
    echo -e "✅ ${GREEN}Prysm (Consensus Layer): Fully Synced ${NC}"
    prysm_synced=true
  else
    echo -e "🔄 ${YELLOW}Prysm Syncing...${NC}"
    echo -e "   🌀 Sync Distance : $distance slots"
    echo -e "   🧠 Head Slot     : $head_slot"
    prysm_synced=false
  fi

  # === Final Status ===
  if [[ "$geth_synced" == true && "$prysm_synced" == true ]]; then
    echo -e "\n${BLUE}🎉 Node is Fully Synced & Operational! — Powered by Aashish 💖 ✨${NC}"
  else
    echo -e "\n${RED}⚠️  Node is still syncing... please wait until both layers are ready.${NC}"
  fi
}

access_controller() {
  trap 'echo -e "\n${RED}👋 Exiting Access Controller...${NC}"; return' SIGINT

  while true; do
    clear
    echo -e "\n${CYAN}${BOLD}=============================================="
    echo -e "      🔐 ETHEREUM RPC ACCESS CONTROLLER       "
    echo -e "==============================================${NC}"
    echo -e "${WHITE}${BOLD}📋 Main Menu — Select Action:${NC}"
    echo "1) Grant access"
    echo "2) Revoke access"
    echo "3) Show current access list"
    echo "4) Show RPC links"
    echo "5) Back"
    echo -n -e "${CYAN}Choose option: ${NC}"
    read mainopt

    case $mainopt in
      1|2)
        ACTION=$([[ $mainopt == 1 ]] && echo "grant" || echo "revoke")
        echo -ne "${CYAN}🌐 Enter IP to $ACTION access (or type 'all'): ${NC}"
        read IP
        [[ "$IP" == "all" ]] && IP="0.0.0.0/0" && echo -e "${YELLOW}⚠️  Allowing ALL access — use with caution!${NC}"

        while true; do
          echo -e "\n${YELLOW}${BOLD}➡️  Which RPC do you want to $ACTION access for?${NC}"
          echo "1) Sepolia (8545)"
          echo "2) Beacon  (3500)"
          echo "3) Both"
          echo "4) Back"
          echo -n -e "${CYAN}Choose option: ${NC}"
          read rpcopt

          case $rpcopt in
            1) ports=(8545) ;;
            2) ports=(3500) ;;
            3) ports=(8545 3500) ;;
            4) break ;;
            *) echo -e "${RED}❌ Invalid choice. Try again.${NC}"; continue ;;
          esac

          for PORT in "${ports[@]}"; do
            if [[ "$ACTION" == "grant" ]]; then
              sudo iptables -I INPUT -p tcp --dport "$PORT" -s "$IP" -j ACCEPT 2>/dev/null
              echo -e "${GREEN}✅ Granted access to $IP on port $PORT${NC}"
            else
              sudo iptables -D INPUT -p tcp --dport "$PORT" -s "$IP" -j ACCEPT 2>/dev/null
              echo -e "${RED}❌ Revoked access for $IP on port $PORT${NC}"
            fi
          done

          echo -e "${CYAN}\nReturning to main menu in 2s...${NC}"
          sleep 2
          break
        done
        ;;

      3)
        echo -e "\n${YELLOW}${BOLD}📡 Current Access List:${NC}"
        ips_8545=$(sudo iptables -L INPUT -n | grep "tcp dpt:8545" | grep ACCEPT | awk '{print $4}')
        ips_3500=$(sudo iptables -L INPUT -n | grep "tcp dpt:3500" | grep ACCEPT | awk '{print $4}')

        mapfile -t list_8545 <<< "$ips_8545"
        mapfile -t list_3500 <<< "$ips_3500"

        both_ports=(); only_8545=(); only_3500=()

        for ip in "${list_8545[@]}"; do
          [[ " ${list_3500[*]} " == *" $ip "* ]] && both_ports+=("$ip") || only_8545+=("$ip")
        done
        for ip in "${list_3500[@]}"; do
          [[ ! " ${list_8545[*]} " == *" $ip "* ]] && only_3500+=("$ip")
        done

        if [[ ${#both_ports[@]} -eq 0 && ${#only_8545[@]} -eq 0 && ${#only_3500[@]} -eq 0 ]]; then
          echo -e "${RED}❌ No IPs have access.${NC}"
        else
          [[ ${#both_ports[@]} -gt 0 ]] && echo -e "${CYAN}🔁 Both Ports (8545 & 3500):${NC}" && for ip in "${both_ports[@]}"; do echo -e "   ${GREEN}- $ip"; done
          [[ ${#only_8545[@]} -gt 0 ]] && echo -e "${CYAN}🔸 Port 8545 only:${NC}" && for ip in "${only_8545[@]}"; do echo -e "   ${GREEN}- $ip"; done
          [[ ${#only_3500[@]} -gt 0 ]] && echo -e "${CYAN}🔸 Port 3500 only:${NC}" && for ip in "${only_3500[@]}"; do echo -e "   ${GREEN}- $ip"; done
        fi
        read -p $'\nPress enter to return to menu...' dummy
        ;;

      4)
        DETECTED_IP=$(curl -s ifconfig.me)
        echo -e "${CYAN}🌐 Detected Public IP: ${GREEN}$DETECTED_IP${NC}"
        echo -ne "${CYAN}📥 Press Enter to use it, or type your own IP/domain: ${NC}"
        read custom_ip
        [[ -z "$custom_ip" ]] && IP="$DETECTED_IP" || IP="$custom_ip"

        echo -e "\n${GREEN}🔗 RPC Endpoints:"
        echo -e "   • Sepolia : ${CYAN}http://$IP:8545${NC}"
        echo -e "   • Beacon  : ${CYAN}http://$IP:3500${NC}\n"
        read -p $'Press enter to return to menu...' dummy
        ;;

      5) break ;;
      *) echo -e "${RED}❌ Invalid choice. Try again.${NC}" ;;
    esac
  done
}



handle_choice() {
  case "$1" in
    1)
      install_dependencies
      install_docker
      check_ports
      create_directories
      write_compose_file
      start_services
      monitor_sync
      print_endpoints
      ;;
    2)
      if [ -f "$BASE_DIR/docker-compose.yml" ]; then
        cd "$BASE_DIR"
        echo -e "${YELLOW}📜 Showing logs... Ctrl+C to exit.${NC}"
        sudo docker compose logs -f
      else
        echo -e "${RED}❌ No docker-compose.yml found. Please run installation first.${NC}"
      fi
      ;;
    3)
      check_node_status
      ;;
    4)
      print_rpc_endpoints
      ;;
    5)
      access_controller
      ;;
    6)
      echo -e "${CYAN}👋 Goodbye!${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}❌ Invalid input. Enter 1, 2, 3, or 4.${NC}"
      ;;
  esac
}

main() {
  while true; do
    print_banner
    read -r choice
    handle_choice "$choice"
    echo ""
    read -rp "Press Enter to return to the menu..."
  done
}

main
