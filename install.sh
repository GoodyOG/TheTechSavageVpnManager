#!/bin/bash
# ==========================================
#  TheTechSavage Universal Auto-Installer
#  Premium Edition - v3.5 (Verified Stable)
#  Repo: github.com/goodyog/TheTechSavageVpnManager
# ==========================================

# --- COLORS & STYLING ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- REPO BASE URL ---
REPO_URL="http://vault.thetechsavage.org.ng/premium"

# --- HELPER FUNCTIONS ---
function print_title() {
    clear
    local text="$1"
    local width=54
    local padding=$(( (width - ${#text}) / 2 ))
    echo -e "${CYAN}+======================================================+${NC}"
    printf "${CYAN}|${YELLOW}%*s%s%*s${CYAN}|${NC}\n" $padding "" "$text" $padding ""
    echo -e "${CYAN}+======================================================+${NC}"
    sleep 1
}

function print_success() {
    echo -e "${GREEN} [OK] $1${NC}"
}

function print_info() {
    echo -e "${BLUE} [INFO] $1${NC}"
}

function print_error() {
    echo -e "${RED} [ERR] $1${NC}"
}

# ==========================================
# WELCOME BANNER
# ==========================================
clear
echo -e "${CYAN}+======================================================+${NC}"
echo -e "${CYAN}|${GREEN}       THETECHSAVAGE AUTOSCRIPT INSTALLER             ${CYAN}|${NC}"
echo -e "${CYAN}|${YELLOW}    Premium VPN Manager  -  @TheTechSavageTelegram    ${CYAN}|${NC}"
echo -e "${CYAN}+======================================================+${NC}"
echo -e " ${BLUE}>${NC} Initializing Installation..."
sleep 2

# ==========================================
# ROOT CHECK
# ==========================================
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root (sudo su)"
    exit 1
fi

# ==========================================
# OS CHECK
# ==========================================
if [[ ! -f /etc/os-release ]]; then
    print_error "Cannot detect OS. Aborting."
    exit 1
fi
source /etc/os-release
if [[ "$ID" != "ubuntu" ]]; then
    print_error "This script is designed for Ubuntu only. Detected: $ID"
    exit 1
fi

# ==========================================
# 2. SYSTEM PREPARATION
# ==========================================
print_title "SYSTEM PREPARATION"

print_info "Creating System Directories..."
mkdir -p /etc/xray
mkdir -p /etc/xray/limit/vmess
mkdir -p /etc/xray/limit/vless
mkdir -p /etc/xray/limit/trojan
mkdir -p /usr/local/etc/xray
mkdir -p /etc/openvpn
mkdir -p /etc/slowdns

print_info "Stopping conflicting services..."
systemctl stop apache2 > /dev/null 2>&1
systemctl disable apache2 > /dev/null 2>&1

print_info "Updating system & installing dependencies..."
apt-get update -y
apt-get upgrade -y
apt-get install -y wget curl jq socat cron zip unzip net-tools git \
    build-essential python3 python3-pip vnstat dropbear nginx dnsutils \
    dante-server stunnel4 cmake ufw fuse psmisc

# Rclone (for backup/restore support)
curl https://rclone.org/install.sh | bash > /dev/null 2>&1

# --- UBUNTU 24.04 COMPATIBILITY PATCH ---
if [[ "$VERSION_ID" == "24.04" ]]; then
    print_info "Ubuntu 24.04 Detected: Applying compatibility patches..."
    apt-get install -y iptables iptables-nft > /dev/null 2>&1
    systemctl disable --now ssh.socket > /dev/null 2>&1
    systemctl enable --now ssh.service > /dev/null 2>&1
    systemctl restart ssh > /dev/null 2>&1
    print_success "Ubuntu 24.04 patches applied!"
fi

print_success "System preparation complete!"

# ==========================================
# 3. DOMAIN & NS SETUP
# ==========================================
print_title "DOMAIN CONFIGURATION"

MYIP=$(curl -sS -4 ifconfig.me 2>/dev/null || curl -sS -4 icanhazip.com)

# --- A. Main Domain ---
while true; do
    echo -e ""
    echo -e "${CYAN}+======================================================+${NC}"
    echo -e "${YELLOW}            ENTER YOUR DOMAIN / SUBDOMAIN             ${NC}"
    echo -e "${CYAN}+======================================================+${NC}"
    echo -e " ${CYAN}>${NC} Create an 'A Record' pointing to: ${GREEN}$MYIP${NC}"
    echo -e " ${CYAN}>${NC} Enter that subdomain below (e.g., vpn.mysite.com)."
    read -p " Input SubDomain : " domain

    if [[ -z "$domain" ]]; then
        print_error "Domain cannot be empty!"
        continue
    fi

    echo -e " ${BLUE}[...] Verifying IP pointing for $domain...${NC}"
    DOMAIN_IP=$(dig +short "$domain" 2>/dev/null | head -n 1)

    if [[ "$DOMAIN_IP" == "$MYIP" ]]; then
        echo -e " ${GREEN}[✓] Verified! Domain points to this VPS.${NC}"
        echo "$domain" > /etc/xray/domain
        break
    else
        echo -e " ${YELLOW}[!] Domain points to ${DOMAIN_IP:-'(no record)'} (Expected $MYIP)${NC}"
        echo -e "     Continuing anyway... (Please ensure DNS is correct later)"
        echo "$domain" > /etc/xray/domain
        break
    fi
done

# --- B. NameServer (NS) for SlowDNS ---
echo -e ""
echo -e "${CYAN}+======================================================+${NC}"
echo -e "${YELLOW}              ENTER YOUR NAMESERVER (NS)              ${NC}"
echo -e "${CYAN}+======================================================+${NC}"
echo -e " ${CYAN}>${NC} Required for SlowDNS (e.g., ns.vpn.mysite.com)."
echo -e " ${CYAN}>${NC} If you don't have one, just press ENTER to skip."
read -p " Input NS Domain : " nsdomain

if [[ -z "$nsdomain" ]]; then
    echo "ns.$domain" > /etc/xray/nsdomain
    print_info "Using default NS: ns.$domain"
else
    echo "$nsdomain" > /etc/xray/nsdomain
    print_success "NS Domain Saved: $nsdomain"
fi

# ==========================================
# 4. CONFIGURE DROPBEAR SSH
# ==========================================
print_title "CONFIGURING DROPBEAR SSH"

# Allow restricted shells so VPN users can connect without full shell access
grep -qxF '/bin/false' /etc/shells || echo "/bin/false" >> /etc/shells
grep -qxF '/usr/sbin/nologin' /etc/shells || echo "/usr/sbin/nologin" >> /etc/shells

cat > /etc/default/dropbear <<EOF
NO_START=0
DROPBEAR_PORT=109
DROPBEAR_EXTRA_ARGS="-p 143 -b /etc/issue.net -K 35 -I 60"
DROPBEAR_BANNER="/etc/issue.net"
DROPBEAR_RECEIVE_WINDOW=65536
EOF

# Inject SSH/Dropbear Banner
cat > /etc/issue.net <<'BANNER'
<html>
<!DOCTYPE html>
<body>
<h3 style="text-align:center;"><span style="color:#0000FF;">
<strong>Premium Server | @THETECHSAVAGE &amp; @TheTechSavageFreebie</strong>
</span></h3>
<font color="red"><b>Terms Of Service (TOS)</b></font><br>
<font color="white"><b>NO Multi Login</b></font><br>
<font color="white"><b>NO DDoS</b></font><br>
<font color="white"><b>NO Carding/Hacking/Illegal Use</b></font><br>
<font color="white"><b>NO Seed Torrent</b></font><br>
<font color="white"><b>NO SPAM</b></font><br>
<font color="red"><b>Violating TOS = Permanent Suspension Without Warning!</b></font><br>
<h5 style="text-align:center;">
<a href="https://t.me/TheTechSavageSupport">Telegram Support</a> |
<a href="https://t.me/TheTechSavageTelegram">Channel</a> |
<a href="https://t.me/TheTechSavageFreebie">Freebie</a> |
<a href="https://thetechsavage.org.ng">Website</a>
</h5>
</body>
</html>
BANNER

# Apply banner to OpenSSH (safe method for Ubuntu 24.04)
mkdir -p /etc/ssh/sshd_config.d
echo "Banner /etc/issue.net" > /etc/ssh/sshd_config.d/99-custom-banner.conf
sed -i 's/^Banner/#Banner/g' /etc/ssh/sshd_config 2>/dev/null

# Apply OpenSSH keep-alives
cat > /etc/ssh/sshd_config.d/99-keepalive.conf <<EOF
ClientAliveInterval 30
ClientAliveCountMax 2
EOF

systemctl restart ssh 2>/dev/null || true
systemctl restart sshd 2>/dev/null || true
systemctl restart dropbear
print_success "Dropbear & SSH configured with Anti-Ghost settings!"

# ==========================================
# 5. INSTALL XRAY CORE
# ==========================================
print_title "INSTALLING XRAY CORE"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
print_success "Xray Core installed!"

# ==========================================
# 6. INSTALL SSL/TLS CERTIFICATE
# ==========================================
print_title "GENERATING SSL CERTIFICATE"

domain=$(cat /etc/xray/domain)
systemctl stop nginx 2>/dev/null || true

mkdir -p /root/.acme.sh
curl -s https://get.acme.sh | sh -s email=admin@${domain}
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
/root/.acme.sh/acme.sh --issue -d "${domain}" --standalone -k ec-256 --force
/root/.acme.sh/acme.sh --installcert -d "${domain}" \
    --fullchainpath /etc/xray/xray.crt \
    --keypath /etc/xray/xray.key --ecc

# Fallback: self-signed if Let's Encrypt fails
if [[ ! -s /etc/xray/xray.crt || ! -s /etc/xray/xray.key ]]; then
    print_info "Let's Encrypt unavailable. Generating self-signed fallback SSL..."
    rm -f /etc/xray/xray.crt /etc/xray/xray.key
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout /etc/xray/xray.key \
        -out /etc/xray/xray.crt \
        -subj "/C=NG/ST=State/L=City/O=TheTechSavage/CN=${domain}" 2>/dev/null
    print_info "Self-signed SSL generated (valid 10 years)."
fi

chmod 644 /etc/xray/xray.key
chmod 644 /etc/xray/xray.crt
print_success "SSL Certificate ready!"

# ==========================================
# 6.5 CONFIGURE STUNNEL4 (TLS TUNNELING)
# ==========================================
print_title "CONFIGURING STUNNEL4"

cat /etc/xray/xray.key /etc/xray/xray.crt > /etc/stunnel/stunnel.pem

cat > /etc/stunnel/stunnel.conf <<EOF
pid = /var/run/stunnel.pid
cert = /etc/stunnel/stunnel.pem
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[dropbear_tls_1]
accept = 447
connect = 127.0.0.1:109

[dropbear_tls_2]
accept = 777
connect = 127.0.0.1:109
EOF

sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
systemctl enable stunnel4
systemctl restart stunnel4
print_success "Stunnel4 configured (Ports 447, 777 → Dropbear 109)"

# ==========================================
# 7. INSTALL BADVPN UDPGW (PORT 7300)
# ==========================================
print_title "INSTALLING UDPGW"

git clone https://github.com/ambrop72/badvpn.git /tmp/badvpn > /dev/null 2>&1
mkdir -p /tmp/badvpn/badvpn-build
cd /tmp/badvpn/badvpn-build
cmake /tmp/badvpn -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 > /dev/null 2>&1
make install > /dev/null 2>&1
cd ~

cat > /etc/systemd/system/udpgw.service <<EOF
[Unit]
Description=BadVPN UDPGW
After=network.target

[Service]
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000 --max-connections-for-client 10
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable udpgw
systemctl start udpgw
rm -rf /tmp/badvpn
print_success "UDPGW installed on port 7300!"

# ==========================================
# 7.5 CONFIGURE NGINX MULTIPLEXER
# ==========================================
print_title "CONFIGURING NGINX PROXY"

fuser -k 80/tcp > /dev/null 2>&1
fuser -k 81/tcp > /dev/null 2>&1
fuser -k 443/tcp > /dev/null 2>&1
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default

domain=$(cat /etc/xray/domain)
cat > /etc/nginx/conf.d/vps.conf <<EOF
server {
    listen 81;
    listen 443 ssl;
    server_name ${domain};

    ssl_certificate     /etc/xray/xray.crt;
    ssl_certificate_key /etc/xray/xray.key;
    ssl_ciphers         EECDH+CHACHA20:EECDH+ECDSA+AES128:EECDH+aRSA+AES128:RSA+AES128:EECDH+ECDSA+AES256:EECDH+aRSA+AES256:RSA+AES256:!MD5;
    ssl_protocols       TLSv1.2 TLSv1.3;

    location / {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:80;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
    location /vless {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
    location /vless-hu {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10004;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
    location /vmess {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
    location /vmess-hu {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10005;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
    location /trojan-ws {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
}
EOF

nginx -t && systemctl enable nginx && systemctl restart nginx
print_success "Nginx multiplexer configured (Ports 81, 443)!"

# ==========================================
# 7.6 INSTALL SLOWDNS (DNSTT)
# ==========================================
print_title "INSTALLING SLOWDNS"

mkdir -p /etc/slowdns
print_info "Downloading SlowDNS binary..."
wget -q -O /etc/slowdns/dnstt-server "${REPO_URL}/core/dnstt-server"
chmod +x /etc/slowdns/dnstt-server

print_info "Writing SlowDNS static master keys..."
echo "a0946ee29693f2394e60b251b6c9e8d5b2f3bc8d753deebf8ce778773dbe10bc" > /etc/slowdns/server.key
echo "68a93ff4e08ea51657ede89c8dcc6534088d8461c1209743c11b96399beb1408" > /etc/slowdns/server.pub
chmod 600 /etc/slowdns/server.key
chmod 644 /etc/slowdns/server.pub

nsdomain=$(cat /etc/xray/nsdomain)

cat > /etc/systemd/system/client-slow.service <<EOF
[Unit]
Description=SlowDNS Server
After=network.target

[Service]
Type=simple
User=root
ExecStartPre=/bin/sh -c 'iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 || true'
ExecStart=/etc/slowdns/dnstt-server -udp :5300 -privkey-file /etc/slowdns/server.key ${nsdomain} 127.0.0.1:109
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable client-slow
iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 || true
systemctl restart client-slow
print_success "SlowDNS configured (static key mode)!"

# ==========================================
# 7.7 INSTALL OPENVPN
# ==========================================
print_title "INSTALLING OPENVPN"
wget -q -O /tmp/openvpn.sh "${REPO_URL}/core/openvpn.sh"
chmod +x /tmp/openvpn.sh
/tmp/openvpn.sh
rm -f /tmp/openvpn.sh
print_success "OpenVPN installation complete!"

# ==========================================
# 8. DOWNLOAD CORE SCRIPTS FROM REPO
# ==========================================
print_title "DOWNLOADING SCRIPTS"

download_bin() {
    local folder=$1
    local file=$2
    if wget -q -O /usr/bin/${file} "${REPO_URL}/${folder}/${file}"; then
        chmod +x /usr/bin/${file}
        echo -e " ${GREEN}[OK]${NC} Installed: ${file}"
    else
        echo -e " ${YELLOW}[WARN]${NC} Failed to download: ${file} (may not exist yet)"
    fi
}

# Core config files
wget -q -O /usr/local/etc/xray/config.json "${REPO_URL}/core/config.json.template"
wget -q -O /etc/systemd/system/xray.service "${REPO_URL}/core/xray.service"
wget -q -O /etc/xray/ohp.py "${REPO_URL}/core/ohp.py"
wget -q -O /etc/xray/proxy.py "${REPO_URL}/core/proxy.py"
wget -q -O /etc/xray/proxy-8880.py "${REPO_URL}/core/proxy-8880.py"

# --- SSH-WS PROXY SERVICE (PORT 80) ---
print_info "Creating SSH-WS Proxy service (Port 80)..."
cat > /etc/systemd/system/ws-proxy.service <<EOF
[Unit]
Description=Python Proxy SSH-WS (Port 80)
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=root
WorkingDirectory=/etc/xray
ExecStart=/usr/bin/python3 /etc/xray/proxy.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ws-proxy
systemctl restart ws-proxy
print_success "SSH-WS Proxy service configured!"

# --- CUSTOM SSH PROXY (PORT 8880) ---
print_info "Creating Custom SSH Proxy service (Port 8880)..."
cat > /etc/systemd/system/ws-8880.service <<EOF
[Unit]
Description=Python Proxy SSH (Port 8880)
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=root
WorkingDirectory=/etc/xray
ExecStart=/usr/bin/python3 /etc/xray/proxy-8880.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ws-8880
systemctl restart ws-8880
print_success "Custom SSH Proxy service (8880) configured!"

# Reload Xray with new config
systemctl daemon-reload
systemctl enable xray
systemctl restart xray

# --- MENU SCRIPTS ---
print_info "Installing menu scripts..."
download_bin "menu" "menu"
download_bin "menu" "menu-domain.sh"
download_bin "menu" "menu-set.sh"
download_bin "menu" "menu-ssh.sh"
download_bin "menu" "menu-trojan.sh"
download_bin "menu" "menu-vless.sh"
download_bin "menu" "menu-vmess.sh"
download_bin "menu" "running.sh"

# --- SSH MANAGEMENT SCRIPTS ---
print_info "Installing SSH management scripts..."
files_ssh=(usernew trial renew hapus member delete autokill cek tendang xp backup restore cleaner health-check show-conf ceklim speedtest api-ssh locker limit user-timed)
for file in "${files_ssh[@]}"; do
    download_bin "ssh" "$file"
done
mv /usr/bin/backup /usr/bin/backup.sh 2>/dev/null || true
mv /usr/bin/restore /usr/bin/restore.sh 2>/dev/null || true

# --- XRAY MANAGEMENT SCRIPTS ---
print_info "Installing Xray management scripts..."
files_xray=(add-ws del-ws renew-ws cek-ws trial-ws member-ws add-vless del-vless renew-vless cek-vless trial-vless member-vless add-tr del-tr renew-tr cek-tr trial-tr member-tr)
for file in "${files_xray[@]}"; do
    download_bin "xray" "$file"
done

print_success "All scripts downloaded!"

# ==========================================
# 8.3 CONFIGURE SOCKS5 (DANTE)
# ==========================================
print_info "Configuring SOCKS5 proxy (Port 1080)..."
NIC=$(ip -o -4 route show to default | head -n1 | awk '{print $5}')

cat > /etc/danted.conf <<EOF
logoutput: syslog
user.privileged: root
user.unprivileged: nobody
internal: 0.0.0.0 port = 1080
external: ${NIC}
socksmethod: username
clientmethod: none

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error
}
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error
}
EOF

systemctl enable danted
systemctl restart danted
print_success "SOCKS5 (Dante) configured on Port 1080!"

# ==========================================
# 8.5 FIREWALL (UFW)
# ==========================================
print_title "CONFIGURING FIREWALL"
print_info "Configuring UFW firewall rules..."

ufw allow 22/tcp    > /dev/null 2>&1   # OpenSSH
ufw allow 109/tcp   > /dev/null 2>&1   # Dropbear main
ufw allow 143/tcp   > /dev/null 2>&1   # Dropbear alt
ufw allow 80/tcp    > /dev/null 2>&1   # HTTP / SSH-WS
ufw allow 81/tcp    > /dev/null 2>&1   # Nginx alt
ufw allow 443/tcp   > /dev/null 2>&1   # HTTPS / Xray TLS
ufw allow 447/tcp   > /dev/null 2>&1   # Stunnel TLS 1
ufw allow 777/tcp   > /dev/null 2>&1   # Stunnel TLS 2
ufw allow 1080/tcp  > /dev/null 2>&1   # SOCKS5
ufw allow 7300/tcp  > /dev/null 2>&1   # UDPGW
ufw allow 8880/tcp  > /dev/null 2>&1   # SSH-WS alt
ufw allow 5300/udp  > /dev/null 2>&1   # SlowDNS
ufw allow 53/udp    > /dev/null 2>&1   # DNS

echo "y" | ufw enable > /dev/null 2>&1
print_success "UFW firewall configured!"

# ==========================================
# 9. SET TIMEZONE
# ==========================================
print_info "Setting timezone to Africa/Lagos..."
timedatectl set-timezone Africa/Lagos 2>/dev/null || true
print_success "Timezone set!"

# ==========================================
# 10. ENABLE CRON & AUTOKILL
# ==========================================
print_info "Enabling cron service..."
systemctl enable cron
systemctl start cron

# Add autokill job (runs every minute)
(crontab -l 2>/dev/null; echo "* * * * * /usr/bin/autokill > /dev/null 2>&1") | crontab - 2>/dev/null || true
print_success "Cron & autokill configured!"

# ==========================================
# FINAL SUMMARY
# ==========================================
domain=$(cat /etc/xray/domain)
nsdomain=$(cat /etc/xray/nsdomain)

clear
echo -e "${CYAN}+======================================================+${NC}"
echo -e "${CYAN}|${GREEN}          INSTALLATION COMPLETE!                      ${CYAN}|${NC}"
echo -e "${CYAN}+======================================================+${NC}"
echo -e ""
echo -e " ${GREEN}Domain       :${NC} $domain"
echo -e " ${GREEN}NS Domain    :${NC} $nsdomain"
echo -e " ${GREEN}Server IP    :${NC} $MYIP"
echo -e ""
echo -e " ${CYAN}Active Ports:${NC}"
echo -e "   SSH / Dropbear   : 22, 109, 143"
echo -e "   Stunnel TLS      : 447, 777"
echo -e "   HTTP/WS Proxy    : 80, 8880"
echo -e "   HTTPS/Xray       : 81, 443"
echo -e "   SOCKS5           : 1080"
echo -e "   UDPGW            : 7300"
echo -e "   SlowDNS          : 53 (UDP), 5300 (UDP)"
echo -e ""
echo -e " ${CYAN}Support :${NC} https://t.me/TheTechSavageSupport"
echo -e " ${CYAN}Channel :${NC} https://t.me/TheTechSavageTelegram"
echo -e ""
echo -e "${CYAN}+======================================================+${NC}"
echo -e " ${YELLOW}Type 'menu' to open the VPN Manager${NC}"
echo -e "${CYAN}+======================================================+${NC}"
echo ""
