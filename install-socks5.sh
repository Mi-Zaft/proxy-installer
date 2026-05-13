#!/usr/bin/env bash

set -e

PORT="1080"

echo "[+] Updating system..."
apt update -y

echo "[+] Installing Dante..."
apt install -y dante-server curl ufw

echo "[+] Detecting network interface..."
IFACE=$(ip route get 8.8.8.8 | awk '{print $5; exit}')

if [ -z "$IFACE" ]; then
    echo "[-] Could not detect network interface"
    exit 1
fi

echo "[+] Interface detected: $IFACE"

echo
read -p "Enter proxy username: " PROXY_USER
read -s -p "Enter proxy password: " PROXY_PASS
echo

echo "[+] Creating system user..."

if id "$PROXY_USER" &>/dev/null; then
    echo "[!] User already exists"
else
    useradd -r -s /bin/false "$PROXY_USER"
    echo "${PROXY_USER}:${PROXY_PASS}" | chpasswd
fi

echo "[+] Writing Dante config..."

cat > /etc/danted.conf <<EOF
logoutput: syslog

internal: 0.0.0.0 port = ${PORT}
external: ${IFACE}

socksmethod: username

user.privileged: root
user.unprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect
}

pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    protocol: tcp udp
}
EOF

echo "[+] Restarting Dante..."

systemctl restart danted
systemctl enable danted

echo "[+] Opening firewall..."

ufw allow ${PORT}/tcp || true

SERVER_IP=$(curl -s https://api.ipify.org)

echo
echo "======================================"
echo "[+] SOCKS5 Proxy Installed Successfully"
echo "======================================"
echo
echo "Proxy:"
echo
echo "${PROXY_USER}:${PROXY_PASS}@${SERVER_IP}:${PORT}"
echo
echo "Test command:"
echo
echo "curl --socks5-hostname ${PROXY_USER}:${PROXY_PASS}@${SERVER_IP}:${PORT} https://api.ipify.org"
echo