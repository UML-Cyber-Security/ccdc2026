#!/usr/bin/env bash
# Types the current clipboard contents as simulated keystrokes into the
# focused window after a 3s delay. Intended for pasting into ESXi web
# consoles that block native clipboard paste.
#
# Usage: esxi-paste.sh [delay_seconds] [key_delay_ms]
#   delay_seconds  seconds to wait before typing starts (default 3)
#   key_delay_ms   ms between keystrokes (default 30)

set -euo pipefail

DELAY="${1:-3}"
KEY_DELAY="${2:-30}"

have() { command -v "$1" >/dev/null 2>&1; }

session="${XDG_SESSION_TYPE:-x11}"

get_clip() {
    if [[ "$session" == "wayland" ]] && have wl-paste; then
        wl-paste --no-newline
    elif have xclip; then
        xclip -o -selection clipboard
    elif have xsel; then
        xsel --clipboard --output
    else
        echo "error: need xclip, xsel, or wl-paste" >&2
        exit 1
    fi
}

type_text() {
    local text="$1"
    if [[ "$session" == "wayland" ]]; then
        if have wtype; then
            wtype -d "$KEY_DELAY" -- "$text"
        elif have ydotool; then
            ydotool type --key-delay "$KEY_DELAY" -- "$text"
        else
            echo "error: need wtype or ydotool on Wayland" >&2
            exit 1
        fi
    else
        if have xdotool; then
            xdotool type --delay "$KEY_DELAY" -- "$text"
        else
            echo "error: need xdotool on X11" >&2
            exit 1
        fi
    fi
}

text="$(get_clip)"
if [[ -z "$text" ]]; then
    echo "error: clipboard is empty" >&2
    exit 1
fi

bytes=$(printf '%s' "$text" | wc -c)
echo "Clipboard: $bytes bytes. Focus the ESXi console window now."
for ((i = DELAY; i > 0; i--)); do
    printf '\rTyping in %d... ' "$i"
    sleep 1
done
printf '\rTyping now...   \n'

type_text "$text"
echo "Done."
