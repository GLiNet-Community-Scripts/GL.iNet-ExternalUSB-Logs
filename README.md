# GL.iNet External USB Logs (GL-XE300 / OpenWrt)

Persistent USB log mirror for GL.iNet/OpenWrt routers that keeps **default logging behavior unchanged** while writing a copy to USB/SD storage, with a **local fallback** if no writable USB/SD mount is available.

---

## Why this exists

OpenWrt keeps system logs in memory by default. That is fast and normal, but logs are lost after reboot.  
This project mirrors logs to persistent storage so they survive reboots while preserving normal `logread` behavior.

---

## Guarantees

- ✅ Does **not** replace `logd` destination.
- ✅ Keeps normal `logread` behavior.
- ✅ Adds a second persistent copy on USB/SD when available.
- ✅ Falls back locally to `/logs-backup` when USB/SD is unavailable.
- ✅ Waits/retries automatically.
- ✅ Includes size-based rotation.

---

## One-line install

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/zippyy/GL.iNet-ExternalUSB-Logs/main/install.sh)"
