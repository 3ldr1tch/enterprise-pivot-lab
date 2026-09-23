#!/usr/bin/env bash

set -euo pipefail

SITE_NAME="northstar"
SITE_ROOT="/var/www/northstar"
APACHE_SITE="/etc/apache2/sites-available/northstar.conf"
FLAG_DIR="/opt/northstar"
FLAG_FILE="${FLAG_DIR}/flag.txt"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "[*] Installing Northstar CMS"

# ---------------------------------------------------------------------------
# Root check
# ---------------------------------------------------------------------------

if [[ "${EUID}" -ne 0 ]]; then
    echo "[!] This installer must be run as root."
    echo "    Run: sudo ./install.sh"
    exit 1
fi

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

echo "[*] Installing Apache and PHP..."

apt-get update

apt-get install -y \
    apache2 \
    libapache2-mod-php \
    php

# ---------------------------------------------------------------------------
# Site installation
# ---------------------------------------------------------------------------

echo "[*] Creating Northstar document root..."

mkdir -p "${SITE_ROOT}"

echo "[*] Copying Northstar CMS files..."

cp -a "${SCRIPT_DIR}/www/." "${SITE_ROOT}/"

# Remove repository placeholder from deployed site.

rm -f "${SITE_ROOT}/uploads/.gitkeep"

# ---------------------------------------------------------------------------
# Permissions
# ---------------------------------------------------------------------------

echo "[*] Configuring permissions..."

chown -R root:root "${SITE_ROOT}"

find "${SITE_ROOT}" -type d -exec chmod 0755 {} \;
find "${SITE_ROOT}" -type f -exec chmod 0644 {} \;

# MediaTools needs write access to this directory.
chown www-data:www-data "${SITE_ROOT}/uploads"
chmod 0755 "${SITE_ROOT}/uploads"

# ---------------------------------------------------------------------------
# Apache configuration
# ---------------------------------------------------------------------------

echo "[*] Installing Apache configuration..."

install -m 0644 \
    "${SCRIPT_DIR}/apache/northstar.conf" \
    "${APACHE_SITE}"

a2dissite 000-default.conf >/dev/null 2>&1 || true
a2ensite northstar.conf >/dev/null

apache2ctl configtest

# ---------------------------------------------------------------------------
# Challenge flag
# ---------------------------------------------------------------------------

echo "[*] Installing scenario flag..."

mkdir -p "${FLAG_DIR}"

cat > "${FLAG_FILE}" <<'EOF'
PIVOT{internal_routes_change_the_attack_surface}
EOF

chown root:www-data "${FLAG_DIR}"
chmod 0750 "${FLAG_DIR}"

chown root:www-data "${FLAG_FILE}"
chmod 0640 "${FLAG_FILE}"

# ---------------------------------------------------------------------------
# Start Apache
# ---------------------------------------------------------------------------

echo "[*] Enabling Apache..."

systemctl enable apache2
systemctl restart apache2

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo
echo "[+] Northstar CMS installation complete."
echo
echo "    Site:       ${SITE_ROOT}"
echo "    Listener:   0.0.0.0:80"
echo "    Web user:   www-data"
echo "    Flag:       ${FLAG_FILE}"
echo
echo "    Check Apache with:"
echo "      systemctl status apache2 --no-pager"
echo
echo "    Test locally with:"
echo "      curl http://127.0.0.1/"
echo

echo "============================================================"
echo " IMPORTANT: FINAL LAB NETWORK CONFIGURATION"
echo "============================================================"
echo
echo " The NAT adapter is for provisioning only."
echo
echo " After installation:"
echo "   1. Shut down TARGET01."
echo "   2. Disable the temporary VirtualBox NAT adapter."
echo "   3. Boot TARGET01."
echo "   4. Verify Apache is running."
echo "   5. Verify TARGET01 has no direct Internet access."
echo
echo " Final TARGET01 network:"
echo
echo "   CORP-LAN -> 172.16.10.20/24"
echo "   NAT      -> DISABLED"
echo
echo "============================================================"
