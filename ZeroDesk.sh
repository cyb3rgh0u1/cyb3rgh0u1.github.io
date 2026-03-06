#!/bin/sh

# ── Re-exec under bash if needed ─────────────────────────────────
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

GRN=$(printf '\033[38;2;183;212;49m')
YLW=$(printf '\033[38;2;255;174;1m')
RED=$(printf '\033[38;2;230;126;128m')
DIM=$(printf '\033[2m')
RST=$(printf '\033[0m')

INSTALLER_URL="https://github.com/cyb3rgh0u1/cyb3rgh0u1.github.io/raw/refs/heads/main/assets/ZeroDesk.sh"
INSTALLER="$HOME/.cache/zerodesk-install.sh"

mkdir -p "$HOME/.cache"

echo
echo -e "${YLW}  Fetching ZeroDesk installer...${RST}"
echo

if wget -q --show-progress -O "$INSTALLER" "$INSTALLER_URL"; then
    echo
    echo -e "${GRN}  ✔ Downloaded.${RST}"
else
    echo -e "${RED}  ✘ Download failed. Check your connection.${RST}"
    exit 1
fi

chmod +x "$INSTALLER"

echo -e "${DIM}  Launching installer in a fresh terminal session...${RST}"
echo

# ── The core fix for curl|bash interactivity ─────────────────────
# We can't reliably get interactive input while stdin is a pipe.
# Setsid + bash with stdin forced from /dev/tty creates a fully
# detached session with a real controlling terminal.
exec setsid bash --norc --noprofile -c "
    exec < /dev/tty
    export HOME='$HOME'
    export USER='$USER'
    export LOGNAME='$LOGNAME'
    export PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
    export TERM='${TERM:-xterm-256color}'
    export LANG='${LANG:-en_US.UTF-8}'
    export DISPLAY='${DISPLAY:-}'
    export DBUS_SESSION_BUS_ADDRESS='${DBUS_SESSION_BUS_ADDRESS:-}'
    export XDG_RUNTIME_DIR='${XDG_RUNTIME_DIR:-}'
    bash '$INSTALLER'
"
