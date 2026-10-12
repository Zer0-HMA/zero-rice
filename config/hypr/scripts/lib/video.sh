#!/usr/bin/env bash
# lib/video.sh — fondos en video (mpvpaper) y su "cuadro" para todo lo que necesita una imagen
#
#   es_video RUTA        → ¿es un video? (mp4, webm, mkv, mov, m4v, avi)
#   cuadro_de RUTA       → imprime una imagen que represente ese fondo: la misma ruta si ya es imagen,
#                          o un cuadro del video sacado con ffmpeg (se guarda en caché: solo se saca una vez)
#   miniatura_de RUTA    → como cuadro_de, pero chiquito (para los menús de rofi)
#   video_sonando        → ¿hay un fondo en video corriendo ahora?
#
# Las paletas por imagen, el panel del lanzador y la pantalla de bloqueo usan cuadro_de:
# así un video funciona en todos lados como si fuera una imagen.

# shellcheck disable=SC2034  # (VIDEO_REGEX lo usan elegir-fondo.sh y dinamica.sh)
VIDEO_EXT='mp4|webm|mkv|mov|m4v|avi'
VIDEO_REGEX=".*\\.($VIDEO_EXT)\$"
CUADROS="${XDG_CACHE_HOME:-$HOME/.cache}/zero-rice/cuadros"

es_video() {
  local r=${1,,}
  [[ $r =~ \.($VIDEO_EXT)$ ]]
}

# _cuadro_id RUTA → nombre del cuadro en caché (cambia si el video cambia)
_cuadro_id() {
  printf '%s|%s|%s' "$1" "$(stat -c %Y "$1" 2>/dev/null)" "$(stat -c %s "$1" 2>/dev/null)" | md5sum | cut -c1-16
}

# _sacar_cuadro VIDEO SALIDA [filtro]
# Primero a 1 s (el primer cuadro suele ser negro); si el video dura menos, el primero que haya.
_sacar_cuadro() {
  local v=$1 out=$2 vf=${3:-} args=()
  [[ -n $vf ]] && args=(-vf "$vf")
  command -v ffmpeg >/dev/null 2>&1 || return 1
  rm -f "$out.tmp.png"
  timeout 20 ffmpeg -nostdin -loglevel error -y -ss 1 -i "$v" -frames:v 1 "${args[@]}" "$out.tmp.png" 2>/dev/null
  [[ -s $out.tmp.png ]] || timeout 20 ffmpeg -nostdin -loglevel error -y -i "$v" -frames:v 1 "${args[@]}" "$out.tmp.png" 2>/dev/null
  [[ -s $out.tmp.png ]] || { rm -f "$out.tmp.png"; return 1; }
  mv -f "$out.tmp.png" "$out"
}

cuadro_de() {
  local v=$1 out
  es_video "$v" || { printf '%s' "$v"; return 0; }
  [[ -f $v ]] || return 1
  mkdir -p "$CUADROS"
  out="$CUADROS/$(_cuadro_id "$v").png"
  [[ -s $out ]] || _sacar_cuadro "$v" "$out" || return 1
  printf '%s' "$out"
}

miniatura_de() {
  local v=$1 out
  es_video "$v" || { printf '%s' "$v"; return 0; }
  [[ -f $v ]] || return 1
  mkdir -p "$CUADROS"
  out="$CUADROS/$(_cuadro_id "$v")-mini.png"
  [[ -s $out ]] || _sacar_cuadro "$v" "$out" "scale=384:-2" || return 1
  printf '%s' "$out"
}

video_sonando() {   # (ignora procesos zombis: ya terminaron, aunque sigan en la lista)
  local p
  for p in $(pgrep -u "${USER:-$(id -un)}" -x mpvpaper 2>/dev/null); do
    [[ $(ps -o stat= -p "$p" 2>/dev/null) == Z* ]] || return 0
  done
  return 1
}
