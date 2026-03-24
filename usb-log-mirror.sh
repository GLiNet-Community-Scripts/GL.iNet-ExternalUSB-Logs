#!/bin/sh
# usb-log-mirror.sh
# Mirror OpenWrt logread output to USB without changing default logd behavior.

set -u

CONFIG_FILE="${USB_LOG_MIRROR_CONFIG:-/etc/usb-log-mirror.conf}"

# Defaults (can be overridden by config file or env)
USB_MOUNT="${USB_MOUNT:-/mnt/sda1}"
LOG_SUBDIR="${LOG_SUBDIR:-gl-usb-logs}"
LOG_NAME="${LOG_NAME:-system.log}"
MAX_SIZE_KB="${MAX_SIZE_KB:-5120}"
MAX_FILES="${MAX_FILES:-5}"
RETRY_SECONDS="${RETRY_SECONDS:-10}"
CHECK_EVERY_LINES="${CHECK_EVERY_LINES:-50}"
TAG="usb-log-mirror"

# Load optional config file
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CONFIG_FILE"
fi

LOG_DIR="${LOG_DIR:-$USB_MOUNT/$LOG_SUBDIR}"
LOG_FILE="${LOG_FILE:-$LOG_DIR/$LOG_NAME}"

log_msg() {
    logger -t "$TAG" "$*"
}

is_mounted_rw() {
    [ -d "$USB_MOUNT" ] || return 1
    awk -v m="$USB_MOUNT" '$2==m {print $4}' /proc/mounts | grep -q 'rw' || return 1
    touch "$USB_MOUNT/.usb-log-mirror-write-test" 2>/dev/null || return 1
    rm -f "$USB_MOUNT/.usb-log-mirror-write-test" 2>/dev/null
    return 0
}

ensure_paths() {
    mkdir -p "$LOG_DIR" 2>/dev/null || return 1
    touch "$LOG_FILE" 2>/dev/null || return 1
    return 0
}

rotate_copytruncate() {
    [ -f "$LOG_FILE" ] || return 0

    size_kb=$(du -k "$LOG_FILE" 2>/dev/null | awk '{print $1}')
    [ -n "$size_kb" ] || size_kb=0

    [ "$size_kb" -lt "$MAX_SIZE_KB" ] && return 0

    # Shift old archives: .(n-1) -> .n
    i="$MAX_FILES"
    while [ "$i" -gt 1 ]; do
        prev=$((i - 1))
        [ -f "$LOG_FILE.$prev" ] && mv -f "$LOG_FILE.$prev" "$LOG_FILE.$i"
        i=$prev
    done

    # copytruncate keeps current writer FD valid
    cp "$LOG_FILE" "$LOG_FILE.1" 2>/dev/null || return 1
    : > "$LOG_FILE" 2>/dev/null || return 1
    log_msg "rotated $LOG_FILE at ${size_kb}KB (max=${MAX_SIZE_KB}KB, files=${MAX_FILES})"
    return 0
}

stream_logs() {
    line_count=0
    log_msg "stream start -> $LOG_FILE"

    logread -f 2>/dev/null | while IFS= read -r line; do
        printf '%s\n' "$line" >> "$LOG_FILE" || exit 1
        line_count=$((line_count + 1))

        if [ $((line_count % CHECK_EVERY_LINES)) -eq 0 ]; then
            rotate_copytruncate || true
        fi
    done

    rc=$?
    log_msg "stream ended rc=$rc"
    return "$rc"
}

daemon() {
    log_msg "daemon start (USB_MOUNT=$USB_MOUNT LOG_FILE=$LOG_FILE)"

    while true; do
        if ! is_mounted_rw; then
            sleep "$RETRY_SECONDS"
            continue
        fi

        if ! ensure_paths; then
            log_msg "unable to access $LOG_FILE"
            sleep "$RETRY_SECONDS"
            continue
        fi

        rotate_copytruncate || true
        stream_logs
        sleep 2
    done
}

case "${1:-}" in
    daemon)
        daemon
        ;;
    rotate)
        rotate_copytruncate
        ;;
    check)
        if is_mounted_rw && ensure_paths; then
            echo "ok"
            exit 0
        fi
        echo "not-ready"
        exit 1
        ;;
    *)
        echo "Usage: $0 {daemon|rotate|check}" >&2
        exit 1
        ;;
esac
