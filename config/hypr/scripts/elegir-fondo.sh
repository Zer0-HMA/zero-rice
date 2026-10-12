#!/usr/bin/env bash
# elegir-fondo.sh — elige una imagen o un video tuyo, de CUALQUIER carpeta, y lo pone de fondo
#   elegir-fondo.sh      → navegador con miniaturas (rofi): entra a carpetas, elige el archivo
# Atajo: Super + Shift + I.  Las imágenes se copian a ~/.config/wallpapers, así que siguen
# disponibles (Super + W...) aunque después las borres de su carpeta. Los videos se ENLAZAN
# (pesan mucho y no tiene caso duplicarlos): si borras o mueves el video, sale de tu lista.
# Directo desde la terminal:  wall.sh /ruta/a/mi-imagen.jpg   ·   wall.sh /ruta/a/mi-video.mp4

S="$HOME/.config/hypr/scripts"
DESTINO="${WALL_DIR:-$HOME/.config/wallpapers}"
ESTADO="$DESTINO/.ultima-carpeta"
TEMA="$HOME/.config/rofi/themes/wallpapers.rasi"
EXT='.*\.(jpe?g|png|webp|gif|bmp|mp4|webm|mkv|mov|m4v|avi)$'
# shellcheck source=lib/video.sh
source "$S/lib/video.sh"

pkill -x rofi && exit 0     # si ya estaba abierto, lo cierra
command -v rofi >/dev/null 2>&1 || { echo "Falta rofi" >&2; exit 1; }
mkdir -p "$DESTINO"

# carpeta donde empieza: la última que usaste, o Imágenes
dir=$(cat "$ESTADO" 2>/dev/null)
if [[ ! -d "$dir" ]]; then
  dir=$(xdg-user-dir PICTURES 2>/dev/null)
  [[ -d "$dir" && "$dir" != "$HOME" ]] || dir="$HOME/Pictures"
  [[ -d "$dir" ]] || dir="$HOME"
fi

ESTILO='mainbox { children: [ inputbar, message, listview ]; }
message { padding: 8px 14px; border-radius: 10px; background-color: @bg-alt; }
textbox { text-color: @fg; }'
tema=(); [[ -f "$TEMA" ]] && tema=(-theme "$TEMA" -theme-str "$ESTILO")

while :; do
  mapfile -d '' -t carpetas < <(find "$dir" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -print0 2>/dev/null | sort -z)
  mapfile -d '' -t imagenes < <(find "$dir" -mindepth 1 -maxdepth 1 -type f -regextype posix-extended -iregex "$EXT" -print0 2>/dev/null | sort -z)
  nc=${#carpetas[@]}

  sel=$(
    {
      printf '%s\0icon\x1f%s\n' ".. (carpeta de arriba)" "go-up"
      printf '%s\0icon\x1f%s\n' "~ Inicio" "user-home"
      for c in "${carpetas[@]}"; do printf '%s\0icon\x1f%s\n' "${c##*/}/" "folder"; done
      for i in "${imagenes[@]}"; do
        if es_video "$i"; then printf '▶ %s\0icon\x1f%s\n' "${i##*/}" "$(miniatura_de "$i" || echo video-x-generic)"
        else printf '%s\0icon\x1f%s\n' "${i##*/}" "$i"; fi
      done
    } | rofi -dmenu -i -p "Fondo" -show-icons -format i \
             -mesg "$dir  —  ${#imagenes[@]} imágenes y videos · Enter: elegir / abrir carpeta" "${tema[@]}"
  ) || exit 0
  [[ "$sel" =~ ^[0-9]+$ ]] || exit 0

  if   (( sel == 0 ));          then dir=$(dirname "$dir")
  elif (( sel == 1 ));           then dir=$HOME
  elif (( sel < 2 + nc ));       then dir=${carpetas[sel - 2]}
  else
    img=${imagenes[sel - 2 - nc]}
    printf '%s\n' "$dir" > "$ESTADO"
    # wall.sh la agrega a tus fondos (copia la imagen o enlaza el video; si ya hay otro archivo
    # con el mismo nombre, no lo pisa) y la pone
    exec "$S/wall.sh" "$img"
  fi
  printf '%s\n' "$dir" > "$ESTADO"
done
