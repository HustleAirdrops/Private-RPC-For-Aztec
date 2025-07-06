# 🚀 Ethereum Sepolia RPC Node Setup Guide

Welcome! This guide will help you set up your own Ethereum Sepolia RPC node using **Geth** (execution) and **Prysm** (consensus) with Docker. No prior experience needed—just follow each step carefully! 🧑‍💻✨

---

## ✨ Key Highlights

- ✅ **Single-command launch** — Everything starts with just one line.
- 📦 **Geth Client (Execution Layer)** — Robust Ethereum execution environment.
- 🛰️ **Prysm Beacon Node (Consensus Layer)** — Secure, efficient consensus with staking support.
- 🔐 **Auto-generated JWT Secrets** — Seamless, secure communication between layers.
- 🌐 **Access Anywhere** — Instantly available on both local and public RPC interfaces.
- 📊 **Live Sync Status Dashboard** — Always know your node’s sync progress.
- 🛡️ **Port Usage Scanner** — Prevents port binding issues before they happen.
- 🐳 **Complete Docker Orchestration** — No manual installs; everything is containerized.

---

## 🖥️ Minimum Requirements

- **OS:** Ubuntu 20.04+ / Debian 11+
- **RAM:** 16 GB minimum
- **Disk:** 500 GB+ SSD
- **Privileges:** Root/sudo access

---

## 🚀 Quick Start

Run this command to launch the setup menu:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HustleAirdrops/Private-RPC-For-Aztec/main/menu.sh)
```

---

## 📋 Menu Options Explained

When you run the script, you’ll see:

```
══════════════════════════════════════
  🧠 Ethereum Sepolia Node Manager
  ➤ Geth + Prysm | Fully Dockerized
══════════════════════════════════════
1) 🚀 Install & Start Node
2) 📜 View Logs
3) 📶 Check Node Status
4) 🔗 Get RPC URLs
5) 🔐 Rpc Access Controller
6) ❌ Exit
```

- **1) Install & Start Rpc Sync:** Installs all dependencies and starts your Sepolia node.
- **2) View Logs:** Shows real-time logs for troubleshooting or monitoring.
- **3) Check Node Status:** Displays sync status and health of your node.
- **4) Get RPC URLs:** Shows your node’s RPC endpoints for easy access.
- **5) Rpc Access Controller:** Give RPC Access and Revoke.
- **6) Exit:** Closes the menu.

---

## 🌐 RPC Endpoints Table

After your node is fully synced, use these endpoints:

| Layer      | Description                    | Endpoint                        |
|------------|-------------------------------|----------------------------------|
| ⚙️ Geth    | Execution RPC (ETH)           | `http://<your-ip>:8545`          |
| 🔗 Prysm   | Beacon RPC (Consensus)        | `http://<your-ip>:3500`          |

> 🔒 **Endpoints are accessible both locally and externally.**

---

## ❌ Delete Old Rpc Data 
```bash
sudo docker compose -f /opt/eth-rpc-node/docker-compose.yml down -v && sudo rm -rf /opt/eth-rpc-node
```
---

## 💬 Need Help?

- **Contact:** [@Legend_Aashish](https://t.me/Legend_Aashish)
- **Guides, Videos & Updates:** [@Hustle_Airdrops](https://t.me/Hustle_Airdrops)
- 🚀 **Stay ahead — join the channel now!**

---

<p align="center">
    Made By <b>Aashish</b> 💖
</p>
