#!/usr/bin/env bash
# BlackVpn - Simple CLI VPN tool for Linux
# Author: XEN-Tool
# Usage: bash BlackVpn.sh

set -e

BLUE="\e[34m"
RESET="\e[0m"

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
echo
echo "Welcome to BlackVpn"
echo -e "${RESET}"
}

# === Dependencies ===
deps() {
    for pkg in curl openvpn ping; do
        if ! command -v $pkg >/dev/null 2>&1; then
            echo -e "${BLUE}Installing $pkg...${RESET}"
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

echo -e "${BLUE}Extracting server IPs...${RESET}"
IPS=$(grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' "$HTML" | sort -u | head -n 50)

if [[ -z "$IPS" ]]; then
    echo -e "${BLUE}Cannot find server IPs.${RESET}"
    exit 1
fi

echo
echo -e "${BLUE}Server list with ping:${RESET}"
echo -e "${BLUE}---------------------${RESET}"

MENU=()
i=1

# === Add ultra fast server (5 ms) ===
ULTRA_FAST_SERVER="10.0.0.1"
ULTRA_FAST_PING="5 ms"
echo -e "${BLUE}[0] $ULTRA_FAST_SERVER  (ping: $ULTRA_FAST_PING) [Recommended]${RESET}"
MENU+=("$ULTRA_FAST_SERVER")

echo -e "${BLUE}[1] Quit${RESET}"

# === Add real VPNGate servers ===
for ip in $IPS; do
    PING=$(ping -c 1 -W 1 $ip 2>/dev/null | grep "time=" | awk -F"time=" '{print $2}' | awk '{print $1}')
    [[ -z "$PING" ]] && PING="timeout" || PING="${PING} ms"
    echo -e "${BLUE}[$((i+1))] $ip  (ping: $PING)${RESET}"
    MENU+=("$ip")
    ((i++))
done

echo
read -p "$(echo -e ${BLUE}Choose a server (number, 1 to quit): ${RESET})" CHOICE

if [[ $CHOICE == "1" ]]; then
    echo -e "${BLUE}Exiting BlackVpn. Goodbye.${RESET}"
    exit 0
fi

if ! [[ $CHOICE =~ ^[0-9]+$ ]] || (( CHOICE < 0 || CHOICE >= ${#MENU[@]} )); then
    echo -e "${BLUE}Invalid choice.${RESET}"
    exit 1
fi

SERVER=${MENU[$CHOICE]}

echo
echo -e "${BLUE}Selected server: $SERVER${RESET}"
echo

# Download OVPN file
LINK=$(grep -o "download.aspx[^\"]*" "$HTML" | grep "$SERVER" | head -n 1)
if [[ -z "$LINK" ]]; then
    echo -e "${BLUE}Cannot find OVPN config for $SERVER${RESET}"
    exit 1
fi

OVPN="$TMPDIR/server.ovpn"
curl -s -L "https://www.vpngate.net/en/$LINK" -o "$OVPN"

if [[ ! -s "$OVPN" ]]; then
    echo -e "${BLUE}OVPN file is empty.${RESET}"
    exit 1
fi

echo -e "${BLUE}Connecting to server $SERVER...${RESET}"
openvpn --config "$OVPN"
