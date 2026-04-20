# TheTechSavage VPN Manager
Universal Auto-Installer for VPN Services (SSH, WS, XRAY, SlowDNS).

## Features
- Ubuntu 20.04 / 22.04 / 24.04 Support
- Xray Core (Vmess, Vless, Trojan)
- SSH Over Websocket
- SlowDNS & Stunnel4
- Full Menu Management

## One-Click Installation
Run the following command as **root** user:

```bash
apt update && apt install -y wget curl && wget -q https://raw.githubusercontent.com/goodyog/TheTechSavageVpnManager/main/setup.sh && chmod +x setup.sh && ./setup.sh
