#!/usr/bin/env bash
# Installs the noray connection server for Moving Day Chaos online play.
# Run once on the VPS (Ubuntu 22.04/24.04) as root:
#   sudo bash setup_noray.sh      (the repo is private: paste this file onto the server first)
# Re-running it updates noray to the latest image and keeps the settings.
set -euo pipefail

RELAY_PORTS="31000-31299"   # 300 relay slots, below Linux's ephemeral port range
DIR=/opt/noray

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root (sudo)." >&2
  exit 1
fi

echo "==> Checking that our ports are free (nothing else on this server is touched)"
if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -qx noray; then
  BUSY=$(ss -H -tuln 2>/dev/null | awk '{print $5}' | grep -E ':(8890|8891|8809|310[0-9][0-9]|31[12][0-9][0-9])$' || true)
  if [ -n "$BUSY" ]; then
    echo "These ports are already used by another service, stopping without changes:" >&2
    echo "$BUSY" >&2
    echo "Tell Claude which ports are busy and it will pick others." >&2
    exit 1
  fi
fi

echo "==> Installing Docker (if needed)"
if ! command -v docker >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y docker.io
fi
systemctl enable --now docker

echo "==> Writing $DIR/.env"
mkdir -p "$DIR"
cat > "$DIR/.env" <<ENV
# Short, readable room codes (no 0/O/1/I confusion)
NORAY_OID_LENGTH=6
NORAY_OID_CHARSET=ABCDEFGHJKLMNPQRSTUVWXYZ23456789
NORAY_PID_LENGTH=128
NORAY_SOCKET_HOST=0.0.0.0
NORAY_SOCKET_PORT=8890
NORAY_HTTP_HOST=127.0.0.1
NORAY_HTTP_PORT=8891
NORAY_UDP_REGISTRAR_PORT=8809
NORAY_UDP_RELAY_PORTS=$RELAY_PORTS
NORAY_UDP_RELAY_TIMEOUT=30s
NORAY_UDP_RELAY_MAX_INDIVIDUAL_TRAFFIC=128kb
NORAY_UDP_RELAY_MAX_GLOBAL_TRAFFIC=100Mb
NORAY_UDP_RELAY_MAX_LIFETIME_DURATION=4hr
NORAY_LOGLEVEL=info
ENV

echo "==> Starting noray"
docker pull ghcr.io/foxssake/noray:main
docker rm -f noray >/dev/null 2>&1 || true
docker run -d --name noray --restart unless-stopped --network host \
  --env-file "$DIR/.env" ghcr.io/foxssake/noray:main >/dev/null

echo "==> Opening firewall ports (ufw)"
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  ufw allow 8890/tcp
  ufw allow 8809/udp
  ufw allow ${RELAY_PORTS/-/:}/udp
else
  echo "    ufw not active - skipping"
fi

echo "==> Self test"
sleep 3
if printf 'register-host\n' | timeout 3 bash -c 'exec 3<>/dev/tcp/127.0.0.1/8890; cat >&3; head -1 <&3' | grep -q "set-oid"; then
  echo "    noray answers on port 8890 ✔"
else
  echo "    noray did not answer yet - check: docker logs noray" >&2
fi

IP=$(curl -fsS -4 https://ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
cat <<DONE

✅ noray is running.
   Public IP of this server:  $IP
   Ports: 8890/tcp, 8809/udp, $RELAY_PORTS/udp

If Hostinger's panel firewall is enabled (hPanel → VPS → Security → Firewall),
add the same three rules there as well.

Send this IP to Claude to put it in the game (data/online.json).
Logs: docker logs -f noray
DONE
