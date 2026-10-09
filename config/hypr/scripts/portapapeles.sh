#!/usr/bin/env bash
# portapapeles.sh — historial del portapapeles (cliphist + rofi), con los colores de tu paleta
#   portapapeles.sh           → elegir algo del historial y copiarlo (Super + Shift + V)
#   portapapeles.sh borrar    → quitar una entrada del historial
#   portapapeles.sh limpiar   → borrar todo el historial

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
TEMA="$CFG/rofi/themes/zero.rasi"
I_CLIP=$'\uf0ea'; I_BORRAR=$'\uf1f8'

notificar() { command -v notify-send >/dev/null 2>&1 && notify-send -a "Portapapeles" "$@"; return 0; }

for c in cliphist wl-copy; do
  command -v "$c" >/dev/null 2>&1 || { notificar -u critical "Falta $c" "Instálalo con: sudo pacman -S cliphist wl-clipboard"; exit 1; }
done

elegir() {   # $1 = prompt
  cliphist list | rofi -dmenu -i -p "$1" -display-columns 2 -display-column-separator $'\t' \
    -theme "$TEMA" -theme-str 'window { width: 760px; } listview { lines: 12; }'
}

pkill -x rofi && exit 0   # si ya estaba abierto, lo cierra

case "${1:-}" in
  limpiar)
    cliphist wipe && notificar "$I_BORRAR  Historial borrado" ;;
  borrar)
    sel=$(elegir "$I_BORRAR  Borrar") || exit 0
    [[ -n "$sel" ]] && cliphist delete <<<"$sel" ;;
  "")
    sel=$(elegir "$I_CLIP  Portapapeles") || exit 0
    [[ -n "$sel" ]] && cliphist decode <<<"$sel" | wl-copy ;;
  *)
    sed -n '2,5p' "$0" ;;
esac
