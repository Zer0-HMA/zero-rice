#!/usr/bin/env bash
# lib/fondoactual.sh — ruta del fondo de pantalla que se está mostrando AHORA
# (pregunta a awww/swww; si no puede, usa el último que puso el rice)
fondo_actual() {
  local w a="" c="${XDG_CONFIG_HOME:-$HOME/.config}"
  for w in awww swww; do
    command -v "$w" >/dev/null 2>&1 || continue
    a=$("$w" query 2>/dev/null | sed -n 's/.*image: //p' | head -1)
    [[ -f $a ]] && break; a=""
  done
  [[ -n $a ]] || a=$(cat "$c/wallpapers/.actual" 2>/dev/null)
  printf '%s' "$a"
}
