#!/usr/bin/env bash
# wall.sh — tus fondos de pantalla con awww (antes llamado swww)
#   wall.sh                 → fondo aleatorio
#   wall.sh menu            → elegir con rofi (con miniaturas)
#   wall.sh sig | ant       → siguiente / anterior
#   wall.sh restaurar       → pone el último que usaste (se usa al iniciar)
#   wall.sh /ruta/img.jpg   → pone esa imagen y la copia a tu carpeta de fondos
# Carpeta de fondos: ~/.config/wallpapers  (jpg, png, gif, webp, bmp)

DIR="${WALL_DIR:-$HOME/.config/wallpapers}"
ESTADO="$DIR/.actual"
TEMA="$HOME/.config/rofi/themes/wallpapers.rasi"
LOG="/tmp/wall-daemon-$USER.log"
TRANS=(grow outer wipe wave center)

mkdir -p "$DIR"

# swww se renombró a awww; usamos el que tengas instalado
if command -v awww >/dev/null 2>&1; then
  W=awww
elif command -v swww >/dev/null 2>&1; then
  W=swww
else
  echo "No tienes awww ni swww instalado. Instálalo con:  yay -S awww" >&2
  exit 1
fi

notificar() { command -v notify-send >/dev/null 2>&1 && notify-send -a "Fondos" "$@"; return 0; }

daemon() {
  "$W" query &>/dev/null && return 0
  setsid -f "$W-daemon" >"$LOG" 2>&1
  for _ in {1..50}; do "$W" query &>/dev/null && return 0; sleep 0.1; done
  echo "No arrancó $W-daemon. Esto fue lo que dijo:" >&2
  sed 's/^/   /' "$LOG" >&2
  exit 1
}

listar() {
  find -L "$DIR" -maxdepth 2 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
       -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.bmp' \) | sort
}

poner() {
  local img="$1" trans="${2:-}"
  daemon
  [[ -z "$trans" ]] && trans="${TRANS[RANDOM % ${#TRANS[@]}]}"
  "$W" img "$img" \
    --transition-type "$trans" \
    --transition-fps 60 \
    --transition-duration 1.2 \
    --transition-angle $((RANDOM % 360))
  printf '%s\n' "$img" > "$ESTADO"
}

actual() { [[ -f "$ESTADO" ]] && cat "$ESTADO"; }

sin_fondos() {
  echo "No hay imágenes en $DIR — mete tus fondos ahí." >&2
  notificar "No hay fondos" "Mete imágenes en $DIR"
  daemon; "$W" clear 0b0b12
  exit 0
}

mapfile -t FONDOS < <(listar)
N=${#FONDOS[@]}

case "${1:-aleatorio}" in
  aleatorio|random)
    ((N)) || sin_fondos
    cur=$(actual)
    img=${FONDOS[0]}
    if ((N > 1)); then
      while :; do img=${FONDOS[RANDOM % N]}; [[ "$img" != "$cur" ]] && break; done
    fi
    poner "$img" ;;

  sig|siguiente|next|ant|anterior|prev)
    ((N)) || sin_fondos
    cur=$(actual); i=-1
    for k in "${!FONDOS[@]}"; do [[ "${FONDOS[k]}" == "$cur" ]] && { i=$k; break; }; done
    case "$1" in
      sig|siguiente|next) i=$(( (i + 1) % N )) ;;
      *)                  ((i < 0)) && i=0; i=$(( (i - 1 + N) % N )) ;;
    esac
    poner "${FONDOS[i]}" ;;

  menu)
    ((N)) || sin_fondos
    pkill -x rofi && exit 0   # si ya estaba abierto, lo cierra
    sel=$(for f in "${FONDOS[@]}"; do printf '%s\0icon\x1f%s\n' "$(basename "$f")" "$f"; done \
          | rofi -dmenu -i -p "Fondos" -show-icons -format i -theme "$TEMA") || exit 0
    [[ -n "$sel" ]] && poner "${FONDOS[sel]}" ;;

  restaurar|restore)
    cur=$(actual)
    if [[ -n "$cur" && -f "$cur" ]]; then poner "$cur" none
    elif ((N)); then poner "${FONDOS[RANDOM % N]}" none
    else sin_fondos; fi ;;

  -h|--help|ayuda)
    sed -n '2,8p' "$0" ;;

  *)
    src=$(realpath -- "$1" 2>/dev/null || true)
    [[ -f "$src" ]] || { echo "No existe: $1" >&2; exit 1; }
    case "$src" in
      "$DIR"/*) dest="$src" ;;
      *)        dest="$DIR/$(basename "$src")"; [[ -e "$dest" ]] || cp -- "$src" "$dest" ;;
    esac
    poner "$dest"
    notificar -i "$dest" "Fondo agregado" "$(basename "$dest")" ;;
esac
