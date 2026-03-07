#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════╗
# ║              ZeroDesk Ports — Installation Script                ║
# ║                      by ZeroDesk Team                            ║
# ╚══════════════════════════════════════════════════════════════════╝

rootDir="$HOME/ZeroDesk-Ports"
stateFile="$HOME/.config/zerodesk/install.state"

# ── Colors ────────────────────────────────────────────────────────
GRN=$(printf '\033[38;2;183;212;49m')
YLW=$(printf '\033[38;2;255;174;1m')
RED=$(printf '\033[38;2;230;126;128m')
BLU=$(printf '\033[38;2;100;180;255m')
PRP=$(printf '\033[38;2;180;140;255m')
DIM=$(printf '\033[2m')
BLD=$(printf '\033[1m')
RST=$(printf '\033[0m')

# ── Symbols ───────────────────────────────────────────────────────
CHECK="${GRN}✔${RST}"
CROSS="${RED}✘${RST}"
ARROW="${YLW}❯${RST}"
DOT="${DIM}·${RST}"
SKIP="${BLU}⟳${RST}"
STAR="${YLW}✦${RST}"

# ── Summary tracking ──────────────────────────────────────────────
declare -A SUMMARY
declare -A STATUS

# ══════════════════════════════════════════════════════════════════
# UTILITIES
# ══════════════════════════════════════════════════════════════════

type_text() {
    local text="$1" color="${2:-$RST}"
    printf "%s" "$color"
    for ((i = 0; i < ${#text}; i++)); do
        printf "%s" "${text:$i:1}"
        sleep 0.045
    done
    printf "%s\n" "$RST"
}

fade_in() {
    while IFS= read -r line; do
        echo -e "$line"
        sleep 0.07
    done <<< "$1"
}

spinner() {
    local pid=$1 msg="${2:-Working...}"
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${YLW}%s${RST}  %s " "${frames[$((i % ${#frames[@]}))]}" "$msg"
        sleep 0.08
        ((i++))
    done
    printf "\r\033[K"
}

section() {
    local title="$1"
    local width=60
    local pad=$(( (width - ${#title} - 2) / 2 ))
    echo
    sleep 0.15
    printf "%s" "$YLW"
    printf '═%.0s' $(seq 1 $width)
    echo
    printf "%*s %s%s%s %*s\n" $pad "" "$BLD" "$title" "$RST$YLW" $pad ""
    printf '═%.0s' $(seq 1 $width)
    printf "%s\n" "$RST"
    sleep 0.1
}

progress_bar() {
    local current=$1 total=$2 width=40
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))
    printf "  ${DIM}[${RST}${GRN}"
    printf '█%.0s' $(seq 1 $filled)
    printf "%s" "$RST$DIM"
    printf '░%.0s' $(seq 1 $empty)
    printf "${RST}${DIM}]${RST} ${YLW}%d/%d${RST}  ${DIM}steps done${RST}\n" "$current" "$total"
}

# Live countdown prompt — writes result into named variable (avoids subshell)
timed_prompt() {
    local _var="$1" prompt="$2" timeout="${3:-10}" default="${4:-1}"
    local _input="" _remaining=$timeout

    printf "  ${ARROW} %s ${DIM}[default: %s | %2ds]${RST} " \
        "$prompt" "$default" "$_remaining"

    while (( _remaining > 0 )); do
        if read -t 1 -r _input 2>/dev/null; then
            break
        fi
        (( _remaining-- ))
        printf "\r  ${ARROW} %s ${DIM}[default: %s | %2ds]${RST} " \
            "$prompt" "$default" "$_remaining"
    done

    printf "\r\033[K"
    local _result="${_input:-$default}"
    printf "  ${CHECK} Selected: ${YLW}%s${RST}\n" "$_result"
    printf -v "$_var" '%s' "$_result"
}

save_state() {
    local key="$1" value="$2"
    mkdir -p "$(dirname "$stateFile")"
    grep -v "^${key}=" "$stateFile" > "${stateFile}.tmp" 2>/dev/null || true
    echo "${key}=${value}" >> "${stateFile}.tmp"
    mv "${stateFile}.tmp" "$stateFile"
}

load_state() {
    local key="$1"
    grep "^${key}=" "$stateFile" 2>/dev/null | cut -d= -f2-
}

already_installed() {
    local key="$1" value="$2"
    local stored
    stored=$(load_state "$key")
    [[ "$stored" == "$value" ]]
}

remove_state() {
    local key="$1"
    grep -v "^${key}=" "$stateFile" > "${stateFile}.tmp" 2>/dev/null || true
    mv "${stateFile}.tmp" "$stateFile"
}

skipped() {
    echo -e "  ${SKIP} ${DIM}Already installed (${1}). Skipping...${RST}"
}

# Resolve the Firefox default profile directory (returns first match)
get_firefox_profile_dir() {
    local profiles_ini="$HOME/.mozilla/firefox/profiles.ini"
    [[ -f "$profiles_ini" ]] || return 1
    local path
    path=$(grep '^Path=' "$profiles_ini" | head -n1 | cut -d= -f2-)
    [[ -n "$path" ]] && echo "$HOME/.mozilla/firefox/$path"
}

# ══════════════════════════════════════════════════════════════════
# BANNER
# ══════════════════════════════════════════════════════════════════

TAGLINES=(
    "Your desktop. Perfected."
    "Dark. Sharp. Yours."
    "Aesthetic by default."
    "Zero compromise. Zero clutter."
    "Built different. Looks different."
    "The theme suite your desktop deserves."
    "Style is not optional."
)
tagline="${TAGLINES[$((RANDOM % ${#TAGLINES[@]}))]}"

BANNERS=(
"   ███████╗███████╗██████╗ ██████╗   ██████╗ ███████╗███████╗██╗  ██╗
   ╚══███╔╝██╔════╝██╔══██╗██╔═══██╗  ██╔══██╗██╔════╝██╔════╝██║ ██╔╝
     ███╔╝ █████╗  ██████╔╝██║   ██║  ██║  ██║█████╗  ███████╗█████╔╝
    ███╔╝  ██╔══╝  ██╔══██╗██║   ██║  ██║  ██║██╔══╝  ╚════██║██╔═██╗
   ███████╗███████╗██║  ██║╚██████╔╝  ██████╔╝███████╗███████║██║  ██╗
   ╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝   ╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝"

"   ____                 ____          _ __ 
   /_  / ___ _______  __/ __ \___  ___/ / /
    / /_/ -_) __/ _ \/ / / / / -_|_-</ ' /
   /___/\__/_/  \___/_/_____/\__/___/_/\_\  "
)
banner="${BANNERS[$((RANDOM % ${#BANNERS[@]}))]}"

clear
echo
printf "%s%s%s\n" "$GRN" "$banner" "$RST"
echo
printf "  %s%s%s  %s│%s  %s%s%s\n" \
    "$BLD$YLW" "Ports Installer" "$RST" \
    "$DIM" "$RST" \
    "$DIM$GRN" "$tagline" "$RST"
echo

# ══════════════════════════════════════════════════════════════════
# MODE SELECTION — install or uninstall
# ══════════════════════════════════════════════════════════════════

MODE="install"
if [[ "${1:-}" == "--uninstall" ]]; then
    MODE="uninstall"
fi

if [[ "$MODE" == "uninstall" ]]; then

    section "Uninstalling ZeroDesk Ports"
    fade_in "  ${RED}This will remove all ZeroDesk themes and restore system defaults.${RST}"
    echo
    timed_prompt confirm "Continue with uninstall? (y/n)" 15 "y"
    [[ "${confirm,,}" == "y" ]] || { echo -e "  ${SKIP} Uninstall cancelled."; exit 0; }

    echo

    # ── Terminal ──────────────────────────────────────────────────
    echo -e "  ${DOT} Resetting terminal theme..."
    profile=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'" 2>/dev/null)
    if [[ -n "$profile" ]]; then
        dconf reset -f "/org/gnome/terminal/legacy/profiles:/:${profile}/"
        echo -e "  ${CHECK} Terminal profile reset."
    fi
    remove_state "terminal"

    # ── Wallpaper ─────────────────────────────────────────────────
    echo -e "  ${DOT} Resetting wallpaper..."
    gsettings reset org.gnome.desktop.background picture-uri      2>/dev/null
    gsettings reset org.gnome.desktop.background picture-uri-dark 2>/dev/null
    echo -e "  ${CHECK} Wallpaper reset."
    remove_state "wallpaper"

    # ── Shell theme ───────────────────────────────────────────────
    echo -e "  ${DOT} Resetting shell theme..."
    gsettings reset org.gnome.shell.extensions.user-theme name 2>/dev/null
    rm -rf "$HOME/.themes/ZeroDesk-Dark" "$HOME/.themes/ZeroDesk-Dark-Soft"
    echo -e "  ${CHECK} Shell theme removed."
    remove_state "shell_theme"

    # ── GTK theme ─────────────────────────────────────────────────
    echo -e "  ${DOT} Resetting GTK theme..."
    gsettings reset org.gnome.desktop.interface gtk-theme 2>/dev/null
    echo -e "  ${CHECK} GTK theme reset."
    remove_state "gtk_theme"

    # ── Icons ─────────────────────────────────────────────────────
    echo -e "  ${DOT} Resetting icon theme..."
    gsettings reset org.gnome.desktop.interface icon-theme 2>/dev/null
    rm -rf "$HOME/.icons/ZeroDesk-Dark"
    echo -e "  ${CHECK} Icon theme removed."
    remove_state "icon_theme"

    # ── Cursor ────────────────────────────────────────────────────
    echo -e "  ${DOT} Resetting cursor theme..."
    gsettings reset org.gnome.desktop.interface cursor-theme 2>/dev/null
    gsettings reset org.gnome.desktop.interface cursor-size  2>/dev/null
    rm -rf "$HOME/.icons/Ghoul-Cursor" \
           "$HOME/.icons/ZeroDesk-Cursor" \
           "$HOME/.icons/ZeroDesk-Cursor-Light"
    echo -e "  ${CHECK} Cursor theme removed."
    remove_state "cursor_theme"

    # ── Vesktop ───────────────────────────────────────────────────
    vesktop_dest="$HOME/.config/vesktop/settings/quickCss.css"
    if [[ -f "$vesktop_dest" ]]; then
        rm -f "$vesktop_dest"
        echo -e "  ${CHECK} Vesktop theme removed."
    else
        echo -e "  ${SKIP} ${DIM}Vesktop theme not found. Skipping.${RST}"
    fi
    remove_state "vesktop_css"

    # ── OBS Studio ────────────────────────────────────────────────
    obs_dest="$HOME/.config/obs-studio/themes/ZeroDesk.ovt"
    if [[ -f "$obs_dest" ]]; then
        rm -f "$obs_dest"
        echo -e "  ${CHECK} OBS Studio theme removed."
    else
        echo -e "  ${SKIP} ${DIM}OBS theme not found. Skipping.${RST}"
    fi
    remove_state "obs_theme"

    # ── Obsidian ──────────────────────────────────────────────────
    obsidian_theme_dir="$HOME/Documents/Obsidian Vault/.obsidian/themes/ZeroDesk"
    if [[ -d "$obsidian_theme_dir" ]]; then
        rm -rf "$obsidian_theme_dir"
        echo -e "  ${CHECK} Obsidian theme removed."
    else
        echo -e "  ${SKIP} ${DIM}Obsidian theme not found. Skipping.${RST}"
    fi
    remove_state "obsidian_theme"

    # ── Sublime Text ──────────────────────────────────────────────
    sublime_pkg="$HOME/.config/sublime-text/Packages/ZeroDesk"
    if [[ -d "$sublime_pkg" ]]; then
        rm -rf "$sublime_pkg"
        echo -e "  ${CHECK} Sublime Text theme removed."
    else
        echo -e "  ${SKIP} ${DIM}Sublime Text theme not found. Skipping.${RST}"
    fi
    remove_state "sublime_theme"

    # ── Firefox ───────────────────────────────────────────────────
    firefox_profile_dir=$(get_firefox_profile_dir)
    if [[ -n "$firefox_profile_dir" ]]; then
        rm -rf "${firefox_profile_dir}/chrome"
        # Remove the pref line from user.js if present
        userjs="${firefox_profile_dir}/user.js"
        if [[ -f "$userjs" ]]; then
            grep -v 'toolkit.legacyUserProfileCustomizations.stylesheets' "$userjs" \
                > "${userjs}.tmp" && mv "${userjs}.tmp" "$userjs"
        fi
        echo -e "  ${CHECK} Firefox theme removed."
    else
        echo -e "  ${SKIP} ${DIM}Firefox profile not found. Skipping.${RST}"
    fi
    remove_state "firefox"

    # ── State file ────────────────────────────────────────────────
    echo
    timed_prompt rm_state "Remove state file and downloaded assets? (y/n)" 10 "n"
    if [[ "${rm_state,,}" == "y" ]]; then
        rm -f "$stateFile"
        rm -rf "$rootDir"
        echo -e "  ${CHECK} State file and ZeroDesk-Ports directory removed."
    fi

    echo
    type_text "  ✦  ZeroDesk uninstalled. Your desktop has been restored.  ✦" "$RED"
    echo
    printf "%s" "$GRN"
    printf '═%.0s' $(seq 1 60)
    printf "%s\n\n" "$RST"
    exit 0
fi

# ══════════════════════════════════════════════════════════════════
# INSTALL MODE
# ══════════════════════════════════════════════════════════════════

if [[ -f "$stateFile" ]]; then
    fade_in "  ${BLU}ℹ${RST}  ${DIM}Previous installation state detected.${RST}
  ${BLU}ℹ${RST}  ${DIM}Unchanged components will be skipped automatically.${RST}"
    echo
fi

type_text "  Initializing ZeroDesk Installation..." "$GRN"
sleep 0.5

# ══════════════════════════════════════════════════════════════════
# DOWNLOAD & EXTRACT
# ══════════════════════════════════════════════════════════════════

tarball="$HOME/ZeroDesk-Ports.tar.xz"
archive_url="https://github.com/cyb3rgh0u1/ZeroDesk-Ports/raw/refs/heads/main/ZeroDesk-Ports.tar.xz"

section "Downloading ZeroDesk Ports"

if [[ -d "$rootDir" ]]; then
    echo -e "  ${SKIP} ${DIM}ZeroDesk-Ports already exists. Skipping download.${RST}"
else
    echo -e "  ${DOT} Source: ${DIM}${archive_url}${RST}"
    echo

    if wget --show-progress -q -O "$tarball" "$archive_url"; then
        echo -e "  ${CHECK} ${GRN}Download complete.${RST}"
    else
        echo -e "  ${CROSS} ${RED}Download failed. Check your connection and try again.${RST}"
        exit 1
    fi

    echo
    echo -e "  ${DOT} Extracting to ${YLW}${HOME}${RST}..."

    if tar -xJf "$tarball" -C "$HOME"; then
        rm -f "$tarball"
        echo -e "  ${CHECK} ${GRN}Extraction complete. Archive removed.${RST}"
    else
        echo -e "  ${CROSS} ${RED}Extraction failed.${RST}"
        exit 1
    fi
fi

# ══════════════════════════════════════════════════════════════════
# STEP COUNTER
# ══════════════════════════════════════════════════════════════════

TOTAL_STEPS=7
CURRENT_STEP=0

next_step() {
    ((CURRENT_STEP++))
    echo
    progress_bar "$CURRENT_STEP" "$TOTAL_STEPS"
    sleep 0.2
}

# ══════════════════════════════════════════════════════════════════
# 1 — TERMINAL THEME
# ══════════════════════════════════════════════════════════════════

section "GNOME Terminal Theme"

profile=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")

if already_installed "terminal" "$profile"; then
    skipped "ZeroDesk Terminal Theme"
    SUMMARY[terminal]="ZeroDesk"
    STATUS[terminal]="skipped"
else
    fade_in "  ${DOT} Applying theme to profile: ${YLW}${profile}${RST}"
    dconf load "/org/gnome/terminal/legacy/profiles:/:${profile}/" \
        < "$rootDir/Terminal/ZeroDesk.dconf"
    save_state "terminal" "$profile"
    sleep 0.2
    echo -e "  ${CHECK} ${GRN}Terminal theme applied successfully.${RST}"
    SUMMARY[terminal]="ZeroDesk"
    STATUS[terminal]="installed"
fi

next_step

# ══════════════════════════════════════════════════════════════════
# 2 — WALLPAPER
# ══════════════════════════════════════════════════════════════════

section "Wallpaper"

mkdir -p "$HOME/.local/share/backgrounds"
# FIX: unquoted glob so it actually expands
cp -r "$rootDir"/Wallpaper/* "$HOME/.local/share/backgrounds/" 2>/dev/null

shopt -s nullglob
walls=("$rootDir"/Wallpaper/*.png "$rootDir"/Wallpaper/*.jpg \
       "$rootDir"/Wallpaper/*.jpeg "$rootDir"/Wallpaper/*.webp)

if [[ ${#walls[@]} -eq 0 ]]; then
    echo -e "  ${CROSS} ${RED}No wallpapers found in $rootDir/Wallpaper/${RST}"
    SUMMARY[wallpaper]="none"
    STATUS[wallpaper]="missing"
else
    fade_in "$(for ((i = 0; i < ${#walls[@]}; i++)); do
        echo "    ${YLW}$((i+1)).${RST} $(basename "${walls[$i]%.*}")"
    done)"
    echo

    timed_prompt choice "Select wallpaper" 10 1

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#walls[@]} )); then
        echo -e "  ${BLU}ℹ${RST}  Invalid choice, using default (1)."
        choice=1
    fi

    selected="${walls[$((choice-1))]}"
    wall_name=$(basename "${selected%.*}")

    if already_installed "wallpaper" "$wall_name"; then
        skipped "$wall_name"
        STATUS[wallpaper]="skipped"
    else
        gsettings set org.gnome.desktop.background picture-uri      "file://$selected"
        gsettings set org.gnome.desktop.background picture-uri-dark "file://$selected"
        save_state "wallpaper" "$wall_name"
        echo -e "  ${CHECK} ${GRN}Wallpaper set: ${YLW}${wall_name}${RST}"
        STATUS[wallpaper]="installed"
    fi
    SUMMARY[wallpaper]="$wall_name"
fi

next_step

# ══════════════════════════════════════════════════════════════════
# 3 — SHELL THEME
# ══════════════════════════════════════════════════════════════════

section "GNOME Shell Theme"

mkdir -p "$HOME/.themes"
cp -r "$rootDir/Shell&Legacy/ZeroDesk-Dark"      "$HOME/.themes/" 2>/dev/null
cp -r "$rootDir/Shell&Legacy/ZeroDesk-Dark-Soft" "$HOME/.themes/" 2>/dev/null

shell_themes=("ZeroDesk-Dark" "ZeroDesk-Dark-Soft")

fade_in "    ${YLW}1.${RST} Floating Bar  ${DIM}(ZeroDesk-Dark)${RST}
    ${YLW}2.${RST} Flatten Bar   ${DIM}(ZeroDesk-Dark-Soft)${RST}"
echo

timed_prompt choice "Select shell theme" 10 1
[[ "$choice" =~ ^[12]$ ]] || choice=1
selected="${shell_themes[$((choice-1))]}"

if already_installed "shell_theme" "$selected"; then
    skipped "$selected"
    STATUS[shell]="skipped"
else
    gsettings set org.gnome.shell.extensions.user-theme name "$selected"
    save_state "shell_theme" "$selected"
    echo -e "  ${CHECK} ${GRN}Shell theme applied: ${YLW}${selected}${RST}"
    STATUS[shell]="installed"
fi
SUMMARY[shell]="$selected"

next_step

# ══════════════════════════════════════════════════════════════════
# 4 — LEGACY / GTK THEME
# ══════════════════════════════════════════════════════════════════

section "Legacy Applications (GTK) Theme"

legacy_themes=("ZeroDesk-Dark" "ZeroDesk-Dark-Soft")

fade_in "    ${YLW}1.${RST} Apple Menu Bar    ${DIM}(ZeroDesk-Dark)${RST}
    ${YLW}2.${RST} General Menu Bar  ${DIM}(ZeroDesk-Dark-Soft)${RST}"
echo

timed_prompt choice "Select GTK theme" 10 1
[[ "$choice" =~ ^[12]$ ]] || choice=1
selected="${legacy_themes[$((choice-1))]}"

if already_installed "gtk_theme" "$selected"; then
    skipped "$selected"
    STATUS[gtk]="skipped"
else
    gsettings set org.gnome.desktop.interface gtk-theme "$selected"
    save_state "gtk_theme" "$selected"
    echo -e "  ${CHECK} ${GRN}GTK theme applied: ${YLW}${selected}${RST}"
    STATUS[gtk]="installed"
fi
SUMMARY[gtk]="$selected"

next_step

# ══════════════════════════════════════════════════════════════════
# 5 — ICON THEME
# ══════════════════════════════════════════════════════════════════

section "Icon Theme"

mkdir -p "$HOME/.icons"

if already_installed "icon_theme" "ZeroDesk-Dark"; then
    skipped "ZeroDesk-Dark"
    STATUS[icons]="skipped"
else
    echo -e "  ${DOT} Copying icon theme..."
    cp -r "$rootDir/Icon/ZeroDesk-Dark" "$HOME/.icons/" &
    copy_pid=$!
    spinner "$copy_pid" "Installing icons..."
    wait "$copy_pid"
    gsettings set org.gnome.desktop.interface icon-theme "ZeroDesk-Dark"
    save_state "icon_theme" "ZeroDesk-Dark"
    echo -e "  ${CHECK} ${GRN}Icon theme applied: ${YLW}ZeroDesk-Dark${RST}"
    STATUS[icons]="installed"
fi
SUMMARY[icons]="ZeroDesk-Dark"

next_step

# ══════════════════════════════════════════════════════════════════
# 6 — CURSOR THEME
# ══════════════════════════════════════════════════════════════════

section "Cursor Theme"

cursor_themes=("Ghoul-Cursor" "ZeroDesk-Cursor" "ZeroDesk-Cursor-Light")

echo -e "  ${DOT} Copying cursor themes..."
cp -r "$rootDir/Cursor/Ghoul-Cursor"          "$HOME/.icons/" 2>/dev/null
cp -r "$rootDir/Cursor/ZeroDesk-Cursor"       "$HOME/.icons/" 2>/dev/null
cp -r "$rootDir/Cursor/ZeroDesk-Cursor-Light" "$HOME/.icons/" 2>/dev/null

fade_in "    ${YLW}1.${RST} Ghoul           ${DIM}(Ghoul-Cursor)${RST}
    ${YLW}2.${RST} ZeroDesk        ${DIM}(ZeroDesk-Cursor)${RST}
    ${YLW}3.${RST} ZeroDesk Light  ${DIM}(ZeroDesk-Cursor-Light)${RST}"
echo

timed_prompt choice "Select cursor" 10 2
[[ "$choice" =~ ^[123]$ ]] || choice=2
selected="${cursor_themes[$((choice-1))]}"

if already_installed "cursor_theme" "$selected"; then
    skipped "$selected"
    STATUS[cursor]="skipped"
else
    gsettings set org.gnome.desktop.interface cursor-theme "$selected"
    gsettings set org.gnome.desktop.interface cursor-size  27
    save_state "cursor_theme" "$selected"
    echo -e "  ${CHECK} ${GRN}Cursor applied: ${YLW}${selected}${RST}"
    STATUS[cursor]="installed"
fi
SUMMARY[cursor]="$selected"

next_step

# ══════════════════════════════════════════════════════════════════
# 7 — DESKTOP APP THEMES
# ══════════════════════════════════════════════════════════════════

section "Desktop App Themes"

# ── Vesktop (Discord) ─────────────────────────────────────────
vesktop_css="$rootDir/Discord/ZeroDesk.css"
vesktop_dest="$HOME/.config/vesktop/settings/quickCss.css"

if ! command -v vesktop >/dev/null 2>&1; then
    echo -e "  ${CROSS} ${DIM}Vesktop not installed. Skipping.${RST}"
    SUMMARY[vesktop]="not installed"
    STATUS[vesktop]="missing"
else
    src_hash=$(md5sum "$vesktop_css" 2>/dev/null | awk '{print $1}')
    if already_installed "vesktop_css" "$src_hash"; then
        skipped "Vesktop (no changes)"
        STATUS[vesktop]="skipped"
    else
        mkdir -p "$(dirname "$vesktop_dest")"
        cp "$vesktop_css" "$vesktop_dest"
        save_state "vesktop_css" "$src_hash"
        echo -e "  ${CHECK} ${GRN}Vesktop theme installed.${RST}"
        STATUS[vesktop]="installed"
    fi
    SUMMARY[vesktop]="ZeroDesk.css"
fi

# ── OBS Studio ────────────────────────────────────────────────
obs_src="$rootDir/OBS-Studio/ZeroDesk.ovt"
obs_dest="$HOME/.config/obs-studio/themes/ZeroDesk.ovt"

if ! command -v obs >/dev/null 2>&1; then
    echo -e "  ${CROSS} ${DIM}OBS Studio not found. Skipping.${RST}"
    SUMMARY[obs]="not installed"
    STATUS[obs]="missing"
else
    src_hash=$(md5sum "$obs_src" 2>/dev/null | awk '{print $1}')
    if already_installed "obs_theme" "$src_hash"; then
        skipped "OBS (no changes)"
        STATUS[obs]="skipped"
    else
        mkdir -p "$(dirname "$obs_dest")"
        cp "$obs_src" "$obs_dest"
        save_state "obs_theme" "$src_hash"
        echo -e "  ${CHECK} ${GRN}OBS Studio theme installed.${RST}"
        STATUS[obs]="installed"
    fi
    SUMMARY[obs]="ZeroDesk.ovt"
fi

# ── Obsidian ──────────────────────────────────────────────────
if ! command -v obsidian >/dev/null 2>&1; then
    echo -e "  ${CROSS} ${DIM}Obsidian not installed. Skipping.${RST}"
    SUMMARY[obsidian]="not installed"
    STATUS[obsidian]="missing"
else
    if already_installed "obsidian_theme" "ZeroDesk"; then
        skipped "Obsidian"
        STATUS[obsidian]="skipped"
    else
        mkdir -p "$HOME/Documents/Obsidian Vault/.obsidian/themes"
        cp -r "$rootDir/Obsidian/ZeroDesk" "$HOME/Documents/Obsidian Vault/.obsidian/themes/"
        save_state "obsidian_theme" "ZeroDesk"
        echo -e "  ${CHECK} ${GRN}Obsidian theme installed.${RST}"
        STATUS[obsidian]="installed"
    fi
    SUMMARY[obsidian]="ZeroDesk"
fi

# ── Sublime Text ──────────────────────────────────────────────
if ! command -v subl >/dev/null 2>&1; then
    echo -e "  ${CROSS} ${DIM}Sublime Text not installed. Skipping.${RST}"
    SUMMARY[sublime]="not installed"
    STATUS[sublime]="missing"
else
    if already_installed "sublime_theme" "ZeroDesk"; then
        skipped "Sublime Text"
        STATUS[sublime]="skipped"
    else
        mkdir -p "$HOME/.config/sublime-text/Packages"
        cp -r "$rootDir/Sublime-Text/ZeroDesk" "$HOME/.config/sublime-text/Packages/"
        save_state "sublime_theme" "ZeroDesk"
        echo -e "  ${CHECK} ${GRN}Sublime Text theme installed.${RST}"
        STATUS[sublime]="installed"
    fi
    SUMMARY[sublime]="ZeroDesk"
fi

# ── Firefox ───────────────────────────────────────────────────
# FIX: Proper profile detection using helper function.
# FIX: Removed stray literal text and broken glob in destination path.
# FIX: user.js pref loop now uses process substitution to avoid subshell variable loss.
if ! command -v firefox >/dev/null 2>&1; then
    echo -e "  ${CROSS} ${DIM}Firefox not installed. Skipping.${RST}"
    SUMMARY[firefox]="not installed"
    STATUS[firefox]="missing"
else
    firefox_profile_dir=$(get_firefox_profile_dir)

    if [[ -z "$firefox_profile_dir" ]]; then
        echo -e "  ${CROSS} ${RED}Firefox profile not found. Skipping.${RST}"
        SUMMARY[firefox]="no profile"
        STATUS[firefox]="missing"
    elif already_installed "firefox" "ZeroDesk"; then
        skipped "Firefox"
        STATUS[firefox]="skipped"
        SUMMARY[firefox]="ZeroDesk"
    else
        # Enable legacy userChrome support in every profile
        profiles_ini="$HOME/.mozilla/firefox/profiles.ini"
        pref='user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'

        while IFS= read -r path; do
            profile_dir="$HOME/.mozilla/firefox/$path"
            userjs="${profile_dir}/user.js"
            # Only add if not already present
            if ! grep -qF 'toolkit.legacyUserProfileCustomizations.stylesheets' "$userjs" 2>/dev/null; then
                echo "$pref" >> "$userjs"
                echo -e "  ${DOT} Updated: ${DIM}${userjs}${RST}"
            fi
        done < <(grep '^Path=' "$profiles_ini" | cut -d= -f2-)

        # Copy chrome assets into the default profile
        cp -r "$rootDir/Firefox/chrome" "${firefox_profile_dir}/"
        save_state "firefox" "ZeroDesk"
        echo -e "  ${CHECK} ${GRN}Firefox theme installed.${RST}"
        STATUS[firefox]="installed"
        SUMMARY[firefox]="ZeroDesk"
    fi
fi

next_step

# ══════════════════════════════════════════════════════════════════
# SUMMARY TABLE
# ══════════════════════════════════════════════════════════════════

echo
sleep 0.2
printf "%s" "$PRP"
printf '─%.0s' $(seq 1 60)
printf "%s\n" "$RST"
printf "  %s%s  Installation Summary%s\n" "$BLD" "$PRP" "$RST"
printf "%s" "$PRP"
printf '─%.0s' $(seq 1 60)
printf "%s\n\n" "$RST"

declare -A LABELS=(
    [terminal]="Terminal Theme"
    [wallpaper]="Wallpaper"
    [shell]="Shell Theme"
    [gtk]="GTK Theme"
    [icons]="Icon Theme"
    [cursor]="Cursor Theme"
    [vesktop]="Vesktop"
    [obs]="OBS Studio"
    [obsidian]="Obsidian"
    [sublime]="Sublime Text"
    [firefox]="Firefox"
)
order=(terminal wallpaper shell gtk icons cursor vesktop obs obsidian sublime firefox)

for key in "${order[@]}"; do
    label="${LABELS[$key]}"
    value="${SUMMARY[$key]:-—}"
    st="${STATUS[$key]:-—}"

    case "$st" in
        installed) icon="${CHECK}"  color="$GRN" ;;
        skipped)   icon="${SKIP}"   color="$DIM" ;;
        missing)   icon="${CROSS}"  color="$RED" ;;
        *)         icon="  "        color="$DIM" ;;
    esac

    sleep 0.07
    printf "  %s  %-22s %s%s%s\n" "$icon" "${label}" "$color" "$value" "$RST"
done

echo
printf "%s" "$PRP"
printf '─%.0s' $(seq 1 60)
printf "%s\n" "$RST"

# ══════════════════════════════════════════════════════════════════
# DONE
# ══════════════════════════════════════════════════════════════════

echo
sleep 0.3
type_text "  ✦  ZeroDesk Is Ready. Enjoy Your Desktop.  ✦" "$YLW"
echo
echo -e "  ${DIM}State saved to: ${BLU}${stateFile}${RST}"
echo -e "  ${DIM}Re-run anytime — unchanged components are skipped.${RST}"
echo -e "  ${DIM}To uninstall, run: ${BLU}./install.sh --uninstall${RST}"
echo
printf "%s" "$GRN"
printf '═%.0s' $(seq 1 60)
printf "%s\n\n" "$RST"
