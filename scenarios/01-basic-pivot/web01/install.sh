#!/usr/bin/env bash

set -euo pipefail

APP_NAME="opscheck"
APP_USER="opscheck"
APP_GROUP="opscheck"
APP_DIR="/opt/opscheck"
SERVICE_FILE="/etc/systemd/system/opscheck.service"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "[*] Installing OpsCheck vulnerable diagnostics service"

if [[ "${EUID}" -ne 0 ]]; then
    echo "[!] This installer must be run as root."
    echo "    Run: sudo ./install.sh"
    exit 1
fi

echo "[*] Installing system dependencies..."

apt-get update
apt-get install -y \
    python3 \
    python3-venv \
    iputils-ping

echo "[*] Creating OpsCheck service account..."

if ! getent group "${APP_GROUP}" >/dev/null; then
    groupadd --system "${APP_GROUP}"
fi

if ! id "${APP_USER}" >/dev/null 2>&1; then
    useradd \
        --system \
        --gid "${APP_GROUP}" \
        --home-dir "${APP_DIR}" \
        --shell /usr/sbin/nologin \
        "${APP_USER}"
fi

echo "[*] Creating application directory..."

mkdir -p \
    "${APP_DIR}/templates" \
    "${APP_DIR}/static"

echo "[*] Copying application files..."

install -m 0644 \
    "${SCRIPT_DIR}/app.py" \
    "${APP_DIR}/app.py"

install -m 0644 \
    "${SCRIPT_DIR}/requirements.txt" \
    "${APP_DIR}/requirements.txt"

cp -a \
    "${SCRIPT_DIR}/templates/." \
    "${APP_DIR}/templates/"

if [[ -d "${SCRIPT_DIR}/static" ]]; then
    cp -a \
        "${SCRIPT_DIR}/static/." \
        "${APP_DIR}/static/"
fi

echo "[*] Creating Python virtual environment..."

if [[ ! -x "${APP_DIR}/venv/bin/python" ]]; then
    python3 -m venv "${APP_DIR}/venv"
fi

echo "[*] Installing Python dependencies..."

"${APP_DIR}/venv/bin/pip" install \
    -r "${APP_DIR}/requirements.txt"

echo "[*] Setting application ownership..."

chown -R \
    "${APP_USER}:${APP_GROUP}" \
    "${APP_DIR}"

echo "[*] Installing systemd service..."

install -m 0644 \
    "${SCRIPT_DIR}/opscheck.service" \
    "${SERVICE_FILE}"

systemctl daemon-reload

echo "[*] Enabling OpsCheck..."

systemctl enable opscheck.service

echo "[*] Restarting OpsCheck..."

systemctl restart opscheck.service

echo
echo "[+] OpsCheck installation complete."
echo
echo "    Service:  opscheck.service"
echo "    Location: ${APP_DIR}"
echo "    Listener: 0.0.0.0:8080"
echo
echo "    Check status with:"
echo "      systemctl status opscheck --no-pager"
echo
echo "    Test locally with:"
echo "      curl http://127.0.0.1:8080/health"
