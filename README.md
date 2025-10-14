# 🚀 Ethereum Sepolia RPC Node Setup Guide (Noob Friendly!)

Welcome! This guide will help you set up your own Ethereum Sepolia RPC node using **Geth** (execution) and **Prysm** (consensus) with Docker. No prior experience needed! Just follow each step carefully. 🧑‍💻✨

---

## ✅ Minimum Requirements  
- 🧠 RAM: 16 GB  
- 💾 Storage: 1 TB+

---

## ☁️ Recommended Google VPS Setup

- 🌍 Region: US Central (Iowa)  
- 🛠️ Machine: N2 series  
- 🧠 RAM: 16 GB  
- 💾 Storage: 2 TB (Standard Persistent Disk)

> ⚠️ Make sure to choose **Standard Persistent Disk** to avoid setup issues.

---


## 1️⃣ Update & Install Essentials

Open your terminal and run:

```bash
sudo -i
```
```bash
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install curl iptables build-essential ufw git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y
```

---

## 2️⃣ Install Docker 🐳

```bash
sudo apt update -y && sudo apt upgrade -y
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
    "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    \"$(. /etc/os-release && echo \"$VERSION_CODENAME\")\" stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update -y && sudo apt upgrade -y
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo docker run hello-world
sudo systemctl enable docker
sudo systemctl restart docker
```

---

## 3️⃣ Prepare Folders & JWT Secret 🔑

```bash
mkdir -p /root/ethereum/execution
mkdir -p /root/ethereum/consensus
openssl rand -hex 32 > /root/ethereum/jwt.hex
cat /root/ethereum/jwt.hex
```

---

## 4️⃣ Create Docker Compose File 📝

```bash
cd /root/ethereum
nano docker-compose.yml
```

Paste the following content in file:

```bash
services:
    geth:
        image: ethereum/client-go:stable
        container_name: geth
        network_mode: host
        restart: unless-stopped
        ports:
            - 30303:30303
            - 30303:30303/udp
            - 8545:8545
            - 8546:8546
            - 8551:8551
        volumes:
            - /root/ethereum/execution:/data
            - /root/ethereum/jwt.hex:/data/jwt.hex
        command:
            - --sepolia
            - --http
            - --http.api=eth,net,web3
            - --http.addr=0.0.0.0
            - --authrpc.addr=0.0.0.0
            - --authrpc.vhosts=*
            - --authrpc.jwtsecret=/data/jwt.hex
            - --authrpc.port=8551
            - --syncmode=snap
            - --datadir=/data
        logging:
            driver: "json-file"
            options:
                max-size: "10m"
                max-file: "3"

    prysm:
        image: gcr.io/prysmaticlabs/prysm/beacon-chain
        container_name: prysm
        network_mode: host
        restart: unless-stopped
        volumes:
            - /root/ethereum/consensus:/data
            - /root/ethereum/jwt.hex:/data/jwt.hex
        depends_on:
            - geth
        ports:
            - 4000:4000
            - 3500:3500
        command:
            - --sepolia
            - --accept-terms-of-use
            - --datadir=/data
            - --disable-monitoring
            - --rpc-host=0.0.0.0
            - --execution-endpoint=http://127.0.0.1:8551
            - --jwt-secret=/data/jwt.hex
            - --rpc-port=4000
            - --grpc-gateway-corsdomain=*
            - --grpc-gateway-host=0.0.0.0
            - --grpc-gateway-port=3500
            - --min-sync-peers=3
            - --checkpoint-sync-url=https://checkpoint-sync.sepolia.ethpandaops.io
            - --genesis-beacon-api-url=https://checkpoint-sync.sepolia.ethpandaops.io
            - --subscribe-all-data-subnets
        logging:
            driver: "json-file"
            options:
                max-size: "10m"
                max-file: "3"
```

After Pasting, 
Press Ctrl + X,
Then press Y and
Then press Enter 

---

## 5️⃣ Start Your Nodes 🚦

```bash
docker compose up -d
```

---

## 6️⃣ Open Firewall Ports 🔥

```bash
sudo ufw allow 22 && sudo ufw allow ssh && sudo ufw allow 8545/tcp && sudo ufw allow 8546/tcp && sudo ufw allow 8551/tcp && sudo ufw allow 3500/tcp && sudo ufw allow 4000/tcp && sudo ufw allow 30303/tcp && sudo ufw allow 30303/udp && sudo ufw enable && sudo ufw status
```

---

## 7️⃣ (Optional) Google Cloud Firewall Setup ☁️

1. Go to [Firewall Rules](https://console.cloud.google.com/networking/firewalls)
2. Click **Create Firewall Rule**
3. Fill as below:

| Field              | Value                              |
|--------------------|------------------------------------|
| Name               | allow-rpc-access                   |
| Network            | default (or your VPC name)         |
| Priority           | 1000                               |
| Direction          | Ingress                            |
| Action             | Allow                              |
| Targets            | Specified target tags              |
| Target tags        | allow-rpc                          |
| Source IP ranges   | 0.0.0.0/0                          |
| Protocols and ports| tcp:3500,4000,8545-8551,30303, udp:30303     |

4. Click **Create**

5. Tag your instance:
     - Go to [Compute Instances](https://console.cloud.google.com/compute/instances)
     - Click your instance → Edit
     - Add `allow-rpc` to **Network tags**
     - Click **Save**

---

## 8️⃣ Check Node Logs 📜

```bash
docker compose logs -fn 100
```
> Press `Ctrl + C` to stop viewing logs.

---

## 9️⃣ Check If Nodes Are Synced ⏳

**Geth (Sepolia):**
```bash
curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' http://localhost:8545
```
- ✅ If synced: `{"jsonrpc":"2.0","id":1,"result":false}`

**Prysm (Beacon):**
```bash
curl http://localhost:3500/eth/v1/node/syncing
```
- ✅ If synced: `{"data":{"head_slot":"12345","sync_distance":"0","is_syncing":false}}`

---

## 🔗 Your RPC Endpoints

- **Geth (Sepolia):**
    - Inside VPS: `http://localhost:8545`
    - Outside VPS: `http://<your-vps-ip>:8545` (replace  `<your-vps-ip>` with your VPS’s public IP address, e.g., http://101.1.101.1:8545)

- **Prysm (Beacon Sepolia):**
    - Inside VPS: `http://localhost:3500`
    - Outside VPS: `http://<your-vps-ip>:3500`  (replace  `<your-vps-ip>` with your VPS’s public IP address, e.g., http://101.1.101.1:3500)

---

## 🎉 All Done!

Your node will sync in **24-30 hours**. After that, you can use your own RPC endpoints! If you get stuck, re-read the steps or ask for help. Happy building! 🚀

---


> 💬 **Need help?** Reach out: [@Legend_Aashish](https://t.me/Legend_Aashish)  

> 📺 **All guides, videos & updates:** [@Hustle_Airdrops](https://t.me/Hustle_Airdrops)  
> 🚀 **Stay ahead — join the channel now!**

---
