# TheTechSavage VPN Manager
> **Premium Edition — v3.5 | Ubuntu VPS Auto-Installer**

A fully automated, multi-protocol VPN server installer for Ubuntu VPS.  
Built and maintained by [@TheTechSavageTelegram](https://t.me/TheTechSavageTelegram).

---

## ⚡ One-Click Install

Run this single command on your VPS as **root**:

```bash
bash <(curl -sL https://raw.githubusercontent.com/goodyog/TheTechSavageVpnManager/main/install.sh)
```

> **Requirements:** Ubuntu 20.04 or 22.04 or 24.04 — 64-bit — Root access — 1GB+ RAM

---

## 📦 What Gets Installed

| Component | Details |
|---|---|
| **Xray Core** | VLESS WS, VMess WS, Trojan WS (TLS & non-TLS) |
| **OpenSSH** | Port 22 — standard SSH access |
| **Dropbear SSH** | Ports 109, 143 — lightweight SSH |
| **Stunnel4** | Ports 447, 777 — TLS tunneling over Dropbear |
| **Nginx** | Ports 81, 443 — SSL reverse proxy & multiplexer |
| **SSH-WS Proxy** | Port 80 — SSH over WebSocket |
| **SSH-WS Alt** | Port 8880 — alternate SSH WebSocket |
| **BadVPN UDPGW** | Port 7300 — UDP gateway for HTTP injector |
| **SlowDNS (DNSTT)** | Ports 53/5300 UDP — DNS tunneling |
| **Dante SOCKS5** | Port 1080 — SOCKS5 proxy with authentication |
| **OpenVPN** | TCP/UDP — classic VPN support |
| **Let's Encrypt SSL** | Auto-issued; self-signed fallback |
| **UFW Firewall** | Auto-configured for all active ports |

---

## 🗂️ Repository Structure

```
TheTechSavageVpnManager/
├── install.sh              ← Main installer (run this)
├── README.md
├── core/
│   ├── config.json.template    ← Xray config template
│   ├── xray.service            ← Xray systemd unit
│   ├── openvpn.sh              ← OpenVPN installer
│   ├── ohp.py                  ← OHP proxy script
│   ├── proxy.py                ← SSH-WS proxy (Port 80)
│   ├── proxy-8880.py           ← SSH-WS proxy (Port 8880)
│   └── dnstt-server            ← SlowDNS pre-compiled binary
├── menu/
│   ├── menu                    ← Main management menu
│   ├── menu-domain.sh
│   ├── menu-set.sh
│   ├── menu-ssh.sh
│   ├── menu-trojan.sh
│   ├── menu-vless.sh
│   ├── menu-vmess.sh
│   └── running.sh
├── ssh/
│   ├── usernew
│   ├── trial
│   ├── renew
│   ├── hapus
│   ├── member
│   ├── delete
│   ├── autokill
│   ├── cek
│   ├── tendang
│   ├── xp
│   ├── backup
│   ├── restore
│   ├── cleaner
│   ├── health-check
│   ├── show-conf
│   ├── ceklim
│   ├── speedtest
│   ├── api-ssh
│   ├── locker
│   ├── limit
│   └── user-timed
└── xray/
    ├── add-ws / del-ws / renew-ws / cek-ws / trial-ws / member-ws
    ├── add-vless / del-vless / renew-vless / cek-vless / trial-vless / member-vless
    └── add-tr / del-tr / renew-tr / cek-tr / trial-tr / member-tr
```

---

## 🛠️ Before You Install

1. **Point a domain (or subdomain) A Record to your VPS IP.**  
   The installer will ask for your domain and verify the DNS record.

2. **(Optional) Create an NS record for SlowDNS.**  
   e.g., `ns.vpn.yourdomain.com` pointing to your VPS.  
   If you skip this, a default is auto-generated.

3. **Run as root.** Use `sudo su` if needed before running the install command.

---

## 🔌 Port Reference

| Port | Protocol | Service |
|---|---|---|
| 22 | TCP | OpenSSH |
| 53 | UDP | SlowDNS (redirect) |
| 80 | TCP | SSH-WS Proxy |
| 81 | TCP | Nginx (HTTP) |
| 109 | TCP | Dropbear SSH (main) |
| 143 | TCP | Dropbear SSH (alt) |
| 443 | TCP | Nginx HTTPS / Xray TLS |
| 447 | TCP | Stunnel → Dropbear TLS |
| 777 | TCP | Stunnel → Dropbear TLS |
| 1080 | TCP | SOCKS5 (Dante) |
| 5300 | UDP | SlowDNS DNSTT server |
| 7300 | TCP | BadVPN UDPGW |
| 8880 | TCP | SSH-WS Proxy (alt) |

---

## 🧭 After Installation

Once installation completes, type:

```bash
menu
```

to open the interactive VPN Manager panel for creating users, managing accounts, and monitoring the server.

---

## 📋 OS Compatibility

| OS | Status |
|---|---|
| Ubuntu 20.04 LTS | ✅ Supported |
| Ubuntu 22.04 LTS | ✅ Supported |
| Ubuntu 24.04 LTS | ✅ Supported (auto-patches applied) |
| Debian / CentOS | ❌ Not supported |

---

## 🔗 Links & Support

| | |
|---|---|
| Telegram Support | https://t.me/TheTechSavageSupport |
| Main Channel | https://t.me/TheTechSavageTelegram |
| Freebie Channel | https://t.me/TheTechSavageFreebie |
| Website | https://thetechsavage.org.ng |

---

> *Script recovered and refined by goodyog. Hosted at `github.com/goodyog/TheTechSavageVpnManager`.*
