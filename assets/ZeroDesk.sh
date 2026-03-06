#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════╗
# ║              ZeroDesk Ports — Installation Script                ║
# ║                      by ZeroDesk Team                            ║
# ╚══════════════════════════════════════════════════════════════════╝

rootDir="$HOME/ZeroDesk-Ports"
stateFile="$HOME/.config/zerodesk/install.state"

# ── Colors ────────────────────────────────────────────────────────
GRN=$(printf '\033[38;2;183;212;49m')   # #B7D431
YLW=$(printf '\033[38;2;255;174;1m')    # #FFAE01
RED=$(printf '\033[38;2;230;126;128m')  # #E67E80
BLU=$(printf '\033[38;2;100;180;255m')  # accent blue
PRP=$(printf '\033[38;2;180;140;255m')  # soft purple accent
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
declare -A SUMMARY   # key → chosen value
declare -A STATUS    # key → "installed" | "skipped" | "missing"

# ══════════════════════════════════════════════════════════════════
# UTILITIES
# ══════════════════════════════════════════════════════════════════

# Typewriter effect
type_text() {
    local text="$1" color="${2:-$RST}"
    printf "%s" "$color"
    for ((i = 0; i < ${#text}; i++)); do
        printf "%s" "${text:$i:1}"
        sleep 0.045
    done
    printf "%s\n" "$RST"
}

# Fade-in a block of lines (reveal line by line with delay)
fade_in() {
    while IFS= read -r line; do
        echo -e "$line"
        sleep 0.07
    done <<< "$1"
}

# Spinner for long operations
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

# Section header with animated reveal
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

# Progress bar
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

# Live countdown timer prompt
# Usage: timed_prompt <var_name> <prompt> <timeout> <default>
# Writes result into the variable named by $1 (avoids subshell)
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

# Save state
save_state() {
    local key="$1" value="$2"
    mkdir -p "$(dirname "$stateFile")"
    grep -v "^${key}=" "$stateFile" > "${stateFile}.tmp" 2>/dev/null || true
    echo "${key}=${value}" >> "${stateFile}.tmp"
    mv "${stateFile}.tmp" "$stateFile"
}

# Load state
load_state() {
    local key="$1"
    grep "^${key}=" "$stateFile" 2>/dev/null | cut -d= -f2-
}

# Check if component was already installed with same value
already_installed() {
    local key="$1" value="$2"
    local stored
    stored=$(load_state "$key")
    [[ "$stored" == "$value" ]]
}

# Print skipped message
skipped() {
    echo -e "  ${SKIP} ${DIM}Already installed (${1}). Skipping...${RST}"
}

# ══════════════════════════════════════════════════════════════════
# BANNER — random tagline on each launch
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
"   ███████╗███████╗██████╗  ██████╗  ██████╗ ███████╗███████╗██╗  ██╗
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

# Detect re-run
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
    dconf load /org/gnome/terminal/legacy/profiles:/:$profile/ < "$rootDir/Terminal/ZeroDesk.dconf"
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
    SUMMARY[vesktop]="not installed"; STATUS[vesktop]="missing"
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
    SUMMARY[obs]="not installed"; STATUS[obs]="missing"
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
    SUMMARY[obsidian]="not installed"; STATUS[obsidian]="missing"
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
    SUMMARY[sublime]="not installed"; STATUS[sublime]="missing"
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

# Map display labels
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
)
order=(terminal wallpaper shell gtk icons cursor vesktop obs obsidian sublime)

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
echo
printf "%s" "$GRN"
printf '═%.0s' $(seq 1 60)
printf "%s\n\n" "$RST"