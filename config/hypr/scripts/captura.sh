#!/usr/bin/env bash
# captura.sh — capturas de pantalla con notificación chida
#   captura.sh area          → seleccionas un pedazo con el mouse
#   captura.sh pantalla      → el monitor donde estás
#   captura.sh ventana       → la ventana activa
#   captura.sh pantalla 5    → con temporizador de 5 segundos (sirve con cualquier modo)
#   captura.sh carpeta       → abre la carpeta de capturas

SONIDO=1   # 1 = sonido de cámara al tomar la captura · 0 = en silencio

shopt -u patsub_replacement 2>/dev/null

# Carpeta: ~/Pictures/Capturas (o la carpeta de imágenes de tu idioma si la tienes configurada)
fotos=$(xdg-user-dir PICTURES 2>/dev/null)
[[ -z "$fotos" || "$fotos" == "$HOME" ]] && fotos="$HOME/Pictures"
CARPETA="${CAPTURAS_DIR:-$fotos/Capturas}"
mkdir -p "$CARPETA"

TEMA="$HOME/.config/rofi/themes/zero.rasi"
color() { grep -oE "$1: #[0-9a-fA-F]{6}" "$TEMA" 2>/dev/null | head -1 | cut -d' ' -f2; }
ACENTO=$(color acento); ACENTO=${ACENTO:-#88c0d0}

# Iconos (Font Awesome dentro de la Nerd Font)
I_CAMARA=$'\uf030'; I_OJO=$'\uf06e'; I_CARPETA=$'\uf07c'; I_LAPIZ=$'\uf040'; I_BASURA=$'\uf1f8'

notificar() { command -v notify-send >/dev/null 2>&1 && notify-send -a "Capturas" "$@"; return 0; }

for c in grim slurp; do
  command -v "$c" >/dev/null 2>&1 || { notificar -u critical "Falta $c" "Instálalo con: sudo pacman -S grim slurp wl-clipboard"; exit 1; }
done

modo=${1:-area}
espera=${2:-0}

if [[ "$modo" == "carpeta" ]]; then
  xdg-open "$CARPETA" >/dev/null 2>&1 &
  exit 0
fi

# ─────────── temporizador ───────────
if [[ "$espera" =~ ^[0-9]+$ ]] && ((espera > 0)); then
  for ((s = espera; s > 0; s--)); do
    notify-send -a "Capturas" -t 1100 -h string:x-canonical-private-synchronous:captura-timer \
      "Captura en $s…" "Modo: $modo" 2>/dev/null
    sleep 1
  done
fi

# ─────────── tomar la captura ───────────
base="$CARPETA/captura_$(date +%Y-%m-%d_%H-%M-%S)"
archivo="$base.png"; n=2
while [[ -e "$archivo" ]]; do archivo="${base}_$n.png"; n=$((n + 1)); done   # dos en el mismo segundo

congelar() {   # congela la pantalla mientras eliges área (si tienes hyprpicker)
  command -v hyprpicker >/dev/null 2>&1 || return 0
  hyprpicker -r -z >/dev/null 2>&1 & PID_CONGELAR=$!
  sleep 0.15
}
descongelar() { [[ -n "${PID_CONGELAR:-}" ]] && kill "$PID_CONGELAR" 2>/dev/null; }
trap descongelar EXIT

case "$modo" in
  area)
    congelar
    geom=$(slurp -d -b '#00000077' -c "${ACENTO}ff" -s "${ACENTO}22" -w 2 -F "JetBrainsMono Nerd Font") || exit 0
    grim -g "$geom" "$archivo" || exit 1
    descongelar ;;
  pantalla)
    mon=$(hyprctl monitors 2>/dev/null | awk '/^Monitor/{n=$2} /focused: yes/{print n; exit}')
    if [[ -n "$mon" ]]; then grim -o "$mon" "$archivo" || exit 1
    else grim "$archivo" || exit 1; fi ;;
  ventana)
    j=$(hyprctl activewindow -j 2>/dev/null | tr -d ' \n')
    at=$(grep -oE '"at":\[[-0-9]+,[-0-9]+\]' <<<"$j" | grep -oE '[-0-9]+,[-0-9]+')
    sz=$(grep -oE '"size":\[[0-9]+,[0-9]+\]' <<<"$j" | grep -oE '[0-9]+,[0-9]+')
    if [[ -n "$at" && -n "$sz" ]]; then
      grim -g "${at} ${sz/,/x}" "$archivo" || exit 1
    else
      exec "$0" pantalla   # no hay ventana activa: captura la pantalla
    fi ;;
  *)
    sed -n '2,7p' "$0"; exit 1 ;;
esac

[[ -s "$archivo" ]] || exit 1

# ─────────── portapapeles y sonido ───────────
copiada=""
if command -v wl-copy >/dev/null 2>&1; then
  wl-copy --type image/png < "$archivo" && copiada=" · copiada al portapapeles"
fi

if ((SONIDO)); then
  for s in /usr/share/sounds/freedesktop/stereo/camera-shutter.oga /usr/share/sounds/freedesktop/stereo/screen-capture.oga; do
    [[ -f "$s" ]] && { (pw-play "$s" || paplay "$s") >/dev/null 2>&1 & break; }
  done
fi

# ─────────── datos para la notificación ───────────
read -r ancho alto < <(od -An -tu1 -j16 -N8 "$archivo" | awk '{print $1*16777216+$2*65536+$3*256+$4, $5*16777216+$6*65536+$7*256+$8}')
peso=$(du -h "$archivo" | cut -f1)
nombre=$(basename "$archivo")
carpeta_corta=${CARPETA/#$HOME/\~}

editor=""
command -v satty  >/dev/null 2>&1 && editor=satty
[[ -z "$editor" ]] && command -v swappy >/dev/null 2>&1 && editor=swappy

acciones=(-A "abrir=$I_OJO  Abrir" -A "carpeta=$I_CARPETA  Carpeta")
[[ -n "$editor" ]] && acciones+=(-A "editar=$I_LAPIZ  Editar")
acciones+=(-A "borrar=$I_BASURA  Borrar")

# ─────────── notificación (en segundo plano, esperando que elijas una acción) ───────────
(
  accion=$(notify-send -a "Capturas" -i "$archivo" -t 8000 \
    -h string:x-canonical-private-synchronous:captura \
    "${acciones[@]}" \
    "$I_CAMARA  Captura guardada" \
    "<b>$nombre</b>
$carpeta_corta
${ancho}×${alto} px · ${peso}${copiada}
<img src=\"$archivo\" alt=\"captura\"/>")

  case "$accion" in
    abrir)   xdg-open "$archivo" >/dev/null 2>&1 ;;
    carpeta) xdg-open "$CARPETA" >/dev/null 2>&1 ;;
    editar)
      case "$editor" in
        satty)  satty --filename "$archivo" --output-filename "$archivo" --early-exit --copy-command wl-copy ;;
        swappy) swappy -f "$archivo" -o "$archivo" ;;
      esac ;;
    borrar)
      rm -f "$archivo"
      notify-send -a "Capturas" -t 2500 "$I_BASURA  Captura borrada" "$nombre" ;;
  esac
) >/dev/null 2>&1 &
disown
exit 0
