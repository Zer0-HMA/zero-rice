#!/usr/bin/env bash
# lib/fondoactual.sh — ruta del fondo de pantalla que se está mostrando AHORA
# (pregunta a awww/swww; si no puede, usa el último que puso el rice)
# Con un video de fondo devuelve el video: quien necesite una imagen usa cuadro_de (lib/video.sh).
fondo_actual() {
  local w a="" c="${XDG_CONFIG_HOME:-$HOME/.config}" p
  for p in $(pgrep -u "${USER:-$(id -un)}" -x mpvpaper 2>/dev/null); do
    [[ $(ps -o stat= -p "$p" 2>/dev/null) == Z* ]] && continue
    a=$(cat "$c/wallpapers/.actual" 2>/dev/null); [[ -f $a ]] && { printf '%s' "$a"; return 0; }
  done
  a=""
  for w in awww swww; do
    command -v "$w" >/dev/null 2>&1 || continue
    a=$("$w" query 2>/dev/null | sed -n 's/.*image: //p' | head -1)
    [[ -f $a ]] && break; a=""
  done
  [[ -n $a ]] || a=$(cat "$c/wallpapers/.actual" 2>/dev/null)
  printf '%s' "$a"
}
