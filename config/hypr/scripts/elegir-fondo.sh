#!/usr/bin/env bash
# elegir-fondo.sh — elige una imagen tuya, de CUALQUIER carpeta, y la pone de fondo de pantalla
#   elegir-fondo.sh      → navegador con miniaturas (rofi): entra a carpetas, elige la imagen
# Atajo: Super + Shift + I.  La imagen se copia a ~/.config/wallpapers, así que sigue
# disponible (Super + W, Super + Ctrl + W...) aunque después la borres de su carpeta.
# Directo desde la terminal:  wall.sh /ruta/a/mi-imagen.jpg

S="$HOME/.config/hypr/scripts"
DESTINO="${WALL_DIR:-$HOME/.config/wallpapers}"
ESTADO="$DESTINO/.ultima-carpeta"
TEMA="$HOME/.config/rofi/themes/wallpapers.rasi"
EXT='.*\.(jpe?g|png|webp|gif|bmp)$'

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
      for i in "${imagenes[@]}"; do printf '%s\0icon\x1f%s\n' "${i##*/}" "$i"; done
    } | rofi -dmenu -i -p "Imagen" -show-icons -format i \
             -mesg "$dir  —  ${#imagenes[@]} imágenes · Enter: elegir / abrir carpeta" "${tema[@]}"
  ) || exit 0
  [[ "$sel" =~ ^[0-9]+$ ]] || exit 0

  if   (( sel == 0 ));          then dir=$(dirname "$dir")
  elif (( sel == 1 ));           then dir=$HOME
  elif (( sel < 2 + nc ));       then dir=${carpetas[sel - 2]}
  else
    img=${imagenes[sel - 2 - nc]}
    printf '%s\n' "$dir" > "$ESTADO"
    # si ya hay OTRA imagen con el mismo nombre en tus fondos, no la pisa: guarda esta con nombre nuevo
    base=${img##*/}
    if [[ "$(dirname "$img")" != "$DESTINO" && -e "$DESTINO/$base" ]] && ! cmp -s "$img" "$DESTINO/$base"; then
      base="${base%.*}-$(date +%s).${base##*.}"
      cp -- "$img" "$DESTINO/$base" && img="$DESTINO/$base"
    fi
    exec "$S/wall.sh" "$img"
  fi
  printf '%s\n' "$dir" > "$ESTADO"
done
