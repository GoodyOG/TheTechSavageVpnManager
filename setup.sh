#!/bin/bash
# ==========================================
#  TheTechSavage Universal Auto-Installer
#  GitHub Edition: goodyog/TheTechSavageVpnManager
# ==========================================

# --- COLORS & STYLING ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Define Repository
REPO_URL="https://raw.githubusercontent.com/goodyog/TheTechSavageVpnManager/main"

function print_title() {
    clear
    echo -e "${CYAN}======================================================${NC}"
    local text="$1"
    local width=54
    local padding=$(( (width - ${#text}) / 2 ))
    printf "${YELLOW}%*s%s%*s${NC}\n" $padding "" "$text" $padding ""
    echo -e "${CYAN}======================================================${NC}"
    sleep 1
}

function print_success() { echo -e "${GREEN} [OK] $1${NC}"; }
function print_info() { echo -e "${BLUE} [INFO] $1${NC}"; }

# --- INITIALIZATION ---
clear
echo -e "${CYAN}┌────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC}           ${GREEN}THETECHSAVAGE AUTOSCRIPT INSTALLER${NC}           ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  ${YELLOW}   Premium Autoscript Manager - goodyog GitHub Edition ${NC}  ${CYAN}│${NC}"
echo -e "${CYAN}└────────────────────────────────────────────────────────┘${NC}"
echo -e " ${BLUE}>${NC} Initializing System..."
sleep 2

# --- SYSTEM PREPARATION ---
print_title "SYSTEM PREPARATION"
print_info "Creating System Directories..."
mkdir -p /etc/xray /etc/xray/limit/vmess /etc/xray/limit/vless /etc/xray/limit/trojan
mkdir -p /usr/local/etc/xray /etc/openvpn /etc/slowdns

print_info "Installing Essentials..."
systemctl stop apache2 > /dev/null 2>&1
systemctl disable apache2 > /dev/null 2>&1
apt update -y && apt upgrade -y
apt install -y wget curl jq socat cron zip unzip net-tools git build-essential python3 python3-pip vnstat dropbear nginx dnsutils dante-server stunnel4 cmake

# OS Compatibility Patch
source /etc/os-release
if [[ "$VERSION_ID" == "24.04" ]]; then
    print_info "Ubuntu 24.04 Detected: Applying Patches..."
    apt-get install -y iptables iptables-nft > /dev/null 2>&1
    systemctl disable --now ssh.socket > /dev/null 2>&1
    systemctl enable --now ssh.service > /dev/null 2>&1
    systemctl restart ssh > /dev/null 2>&1
fi

# --- DOMAIN SETUP ---
print_title "DOMAIN CONFIGURATION"
MYIP=$(curl -sS -4 ifconfig.me)
read -p " Input SubDomain (e.g. vpn.example.com): " domain
if [[ -z "$domain" ]]; then domain=$MYIP; fi
echo "$domain" > /etc/xray/domain
echo "ns.$domain" > /etc/xray/nsdomain

# --- CONFIGURING SERVICES ---
print_title "CONFIGURING DROPBEAR & SSH"
echo "/bin/false" >> /etc/shells
echo "/usr/sbin/nologin" >> /etc/shells
cat > /etc/default/dropbear <<EOF
NO_START=0
DROPBEAR_PORT=109
DROPBEAR_EXTRA_ARGS="-p 143 -b /etc/issue.net -K 35 -I 60"
EOF

# Banner Creation
cat > /etc/issue.net << 'EOF'
<h3 style="text-align: center;"><span style="color: #0000FF;"><strong>Premium Server by TheTechSavage</strong></span></h3>
<p style="text-align: center;">No Torrent | No DDOS | No Hacking</p>
EOF
systemctl restart dropbear

# --- XRAY & SSL ---
print_title "INSTALLING XRAY CORE"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

print_title "GENERATING SSL"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/xray/xray.key -out /etc/xray/xray.crt -subj "/C=US/ST=State/L=City/O=TheTechSavage/CN=$domain" 2>/dev/null

# --- DOWNLOADING REPO COMPONENTS ---
print_title "DOWNLOADING SCRIPTS FROM GITHUB"
download_bin() {
    local folder=$1
    local file=$2
    wget -q -O /usr/bin/$file "${REPO_URL}/$folder/$file"
    chmod +x /usr/bin/$file
    echo -e " [OK] Installed: $file"
}

# Main Components
wget -q -O /usr/local/etc/xray/config.json "${REPO_URL}/core/config.json"
wget -q -O /etc/xray/proxy.py "${REPO_URL}/core/proxy.py"

# Menus & SSH Tools
download_bin "menu" "menu"
files_ssh=(usernew trial renew hapus member delete autokill cek tendang xp cleaner speedtest)
for file in "${files_ssh[@]}"; do
    download_bin "ssh" "$file"
done

# --- FINALIZING ---
print_title "INSTALLATION COMPLETE"
echo -e " Your Server IP: $MYIP"
echo -e " Domain: $domain"
echo -e " Rebooting in 5 seconds..."
sleep 5
reboot
