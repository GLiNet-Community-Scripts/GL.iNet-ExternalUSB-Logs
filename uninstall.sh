#!/bin/sh
set -e

INIT_DST="/etc/init.d/usb-log-mirror"
BIN_DST="/usr/bin/usb-log-mirror.sh"
CONF_DST="/etc/usb-log-mirror.conf"

echo "[usb-log-mirror] Uninstalling..."

if [ -x "$INIT_DST" ]; then
    "$INIT_DST" stop || true
    "$INIT_DST" disable || true
fi

rm -f "$INIT_DST" "$BIN_DST"

echo "[usb-log-mirror] Removed service and binary."
echo "[usb-log-mirror] Config preserved at $CONF_DST (delete manually if desired)."
