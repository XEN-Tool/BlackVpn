#!/usr/bin/env bash
# BlackVpn - CLI VPN tool for Linux
# Author: XEN-Tool
# Usage: bash BlackVpn.sh

set -e

# === Colors ===
BLUE="\033[1;34m"
RESET="\033[0m"

# === Banner ===
banner() {
    clear
    echo -e "${BLUE}"
    echo "██████╗ ██╗      █████╗  ██████╗██╗  ██╗██╗   ██╗██╗   ██╗███╗   ██╗"
    echo "██╔══██╗██║     ██╔══██╗██╔════╝██║ ██╔╝██║   ██║██║   ██║████╗  ██║"
    echo "██████╔╝██║     ███████║██║     █████╔╝ ██║   ██║██║   ██║██╔██╗ ██║"
    echo "██╔═══╝ ██║     ██╔══██║██║     ██╔═██╗ ██║   ██║██║   ██║██║╚██╗██║"
    echo "██║     ███████╗██║  ██║╚██████╗██║  ██╗╚██████╔╝╚██████╔╝██║ ╚████║"
    echo "╚═╝     ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝"
    echo -e "${RESET}"
    echo
    echo -e "${BLUE}Welcome to BLACKVPN (XEN-Tool Edition)${RESET}"
    echo
    sleep 0.5
}

# === Dependencies ===
deps() {
    for pkg in curl openvpn ping; do
        if ! command -v $pkg >/dev/null 2>&1; then
            echo "Installing $pkg..."
            apt-get update -qq && apt-get install -y $pkg
        fi
    done
}

# === Main script ===
banner
deps

TMPDIR="/tmp/blackvpn"
mkdir -p "$TMPDIR"
HTML="$TMPDIR/vpngate.html"

echo -e "${BLUE}Downloading VPN server list...${RESET}"
curl -s -L "https://www.vpngate.net/en/" -o "$HTML"

IPS=$(grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' "$HTML" | sort -u | head -n 20)

if [[ -z "$IPS" ]]; then
    echo "Cannot find server IPs."
    exit 1
fi

echo
echo -e "${BLUE}Available Servers (with ping):${RESET}"
echo "---------------------------------"

MENU=()
i=2
FASTEST_IP=""
FASTEST_PING=9999

echo "[1] Quit"

for ip in $IPS; do
    PING=$(ping -c 1 -W 1 $ip 2>/dev/null | grep "time=" | awk -F"time=" '{print $2}' | awk '{print $1}')
    [[ -z "$PING" ]] && PING="timeout" || PING=$(printf "%.0f" "$PING")
    if [[ "$PING" != "timeout" && "$PING" -lt "$FASTEST_PING" ]]; then
        FASTEST_PING=$PING
        FASTEST_IP=$ip
    fi
    echo "[$i] $ip  (ping: $PING ms)"
    MENU+=("$ip")
    ((i++))
done

# Add fastest server at top (Recommended)
if [[ -n "$FASTEST_IP" ]]; then
    echo
    echo -e "[0] ${FASTEST_IP}  (ping: ${FASTEST_PING} ms) ${BLUE}[Recommended]${RESET}"
    MENU=("fastest" "${MENU[@]}")
fi

echo
read -p "Choose a server (number): " CHOICE

if [[ $CHOICE == "1" ]]; then
    echo "Exiting BlackVpn. Goodbye."
    exit 0
fi

if [[ $CHOICE == "0" && -n "$FASTEST_IP" ]]; then
    SERVER=$FASTEST_IP
else
    INDEX=$((CHOICE-2))
    SERVER=${MENU[$INDEX]}
fi

echo
echo -e "${BLUE}Selected server: $SERVER${RESET}"
echo

LINK=$(grep -o "download.aspx[^\"]*" "$HTML" | grep "$SERVER" | head -n 1)
OVPN="$TMPDIR/server.ovpn"
curl -s -L "https://www.vpngate.net/en/$LINK" -o "$OVPN"

echo -e "${BLUE}Connecting to $SERVER...${RESET}"
sleep 1
openvpn --config "$OVPN"
