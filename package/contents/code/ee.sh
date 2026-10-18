#!/usr/bin/env bash
# Easy Effects bridge for the Nyx Player plasmoid.
#   ee.sh state        presets / current preset / its effects / bypass / output device, one key=value per line
#   ee.sh load NAME    load an output preset
#   ee.sh bypass 1|2   1 = bypass (effects off), 2 = effects on
#   ee.sh open         show the Easy Effects window
# Easy Effects itself runs in the background via ~/.config/autostart/easyeffects-service.desktop
set -u
PRESETS="$HOME/.local/share/easyeffects/output"
RC="$HOME/.config/easyeffects/db/easyeffectsrc"

running() { pgrep -x easyeffects >/dev/null; }
start() { running || { setsid easyeffects --service-mode --hide-window >/dev/null 2>&1 & sleep 2; }; }

case "${1:-}" in
    state)
        for f in "$PRESETS"/*.json; do [ -e "$f" ] && { n=${f##*/}; echo "preset=${n%.json}"; }; done
        cur=$(sed -n 's/^lastLoadedOutputPreset=//p' "$RC" 2>/dev/null)
        echo "current=$cur"
        # effects in the current preset, in order ("bass_enhancer#0" -> "bass_enhancer")
        [ -n "$cur" ] && [ -e "$PRESETS/$cur.json" ] && tr -d ' \n' < "$PRESETS/$cur.json" \
            | sed -n 's/.*"plugins_order":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' | tr -d '"' | sed 's/#.*//; /^$/d; s/^/effect=/'
        echo
        if running; then echo "running=1"; echo "bypass=$(easyeffects -b 3 2>/dev/null)"; else echo "running=0"; fi
        echo "sink=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | sed -n 's/.*node.description = "\(.*\)"/\1/p' | head -1)"
        ;;
    load)   start; easyeffects -l "$2" >/dev/null 2>&1 ;;
    bypass) start; easyeffects -b "$2" >/dev/null 2>&1 ;;
    open)   start; easyeffects >/dev/null 2>&1 & ;;
    *) sed -n '2,7p' "$0" ;;
esac
