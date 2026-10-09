#!/usr/bin/env bash
# perfil.sh — tu foto de perfil y tu nombre (barra, lanzador y otros programas)
#   perfil.sh                  → menú con miniaturas (Super + Shift + F, o clic en tu nombre en la barra)
#   perfil.sh /ruta/foto.jpg   → agrega esa foto a tu colección y la pone
#   perfil.sh nombre "Humber"  → el nombre que se muestra (sin texto: vuelve a tu usuario)
#   perfil.sh quitar           → sin foto (vuelve el ícono)
#   perfil.sh carpeta          → abre la carpeta con tus fotos de perfil
# Tus fotos viven en ~/.config/rice-perfil/fotos (jpg, png, webp). Se recortan en círculo solas.

shopt -u patsub_replacement 2>/dev/null

USER=${USER:-$(id -un)}
DIR="$HOME/.config/rice-perfil"
FOTOS="$DIR/fotos"
AVATAR="$DIR/avatar.png"
ACTUAL="$DIR/actual"
NOMBRE="$DIR/nombre"
TEMA="$HOME/.config/rofi/themes/wallpapers.rasi"
mkdir -p "$FOTOS"

I_PERFIL=$'\uf2bd'

notificar() { command -v notify-send >/dev/null 2>&1 && notify-send -a "Perfil" "$@"; return 0; }
es_imagen() { case "${1,,}" in *.jpg|*.jpeg|*.png|*.webp) return 0 ;; esac; return 1; }
listar() {
  find -L "$FOTOS" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
    -printf '%T@\t%p\n' 2>/dev/null | sort -rn | cut -f2-
}

# ─────────── foto → avatar.png redondo de 256 px ───────────
recortar() {
  local foto=$1 tmp ext salida
  tmp=$(mktemp -d); salida="$tmp/avatar.png"

  # ImageMagick, si lo tienes, endereza las fotos del cel (EXIF) y lee webp
  if command -v magick >/dev/null 2>&1; then
    magick "$foto" -auto-orient -resize '256x256^' -gravity center -extent 256x256 \
      \( +clone -alpha extract -fill black -colorize 100 -fill white -draw 'circle 128,128 128,0' \) \
      -alpha off -compose copy_opacity -composite "$salida" 2>/dev/null
  fi

  # Si no, librsvg (ya viene con el rice); solo lee imágenes de su misma carpeta
  if [[ ! -s "$salida" ]] && command -v rsvg-convert >/dev/null 2>&1; then
    ext=${foto##*.}; ext=${ext,,}
    cp -f "$foto" "$tmp/foto.$ext"
    cat > "$tmp/recorte.svg" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <defs><clipPath id="c"><circle cx="128" cy="128" r="128"/></clipPath></defs>
  <image href="foto.$ext" x="0" y="0" width="256" height="256" preserveAspectRatio="xMidYMid slice" clip-path="url(#c)"/>
</svg>
EOF
    rsvg-convert -o "$salida" "$tmp/recorte.svg" 2>/dev/null || rm -f "$salida"
    # si librsvg no pudo leer la foto, deja un círculo vacío de pocos bytes
    [[ -s "$salida" ]] && (( $(stat -c %s "$salida") < 3000 )) && rm -f "$salida"
  fi

  if [[ ! -s "$salida" ]]; then
    rm -rf "$tmp"
    notificar -u critical "No pude usar esa foto" "Prueba con un JPG o PNG. Para WebP o fotos del cel: sudo pacman -S imagemagick"
    return 1
  fi
  mv -f "$salida" "$AVATAR.tmp" && mv -f "$AVATAR.tmp" "$AVATAR"
  rm -rf "$tmp"
}

poner() {   # $1 = foto dentro de la colección
  recortar "$1" || return 1
  printf '%s\n' "$1" > "$ACTUAL"
  # otros programas (pantallas de inicio de sesión, hyprlock...) buscan la foto aquí
  cp -f "$AVATAR" "$HOME/.face" 2>/dev/null && ln -sfn .face "$HOME/.face.icon" 2>/dev/null
  notificar -i "$AVATAR" "Foto de perfil lista" "$(basename "$1")"
}

agregar() {  # copia una imagen a la colección (sin duplicar) y la pone
  local src dest base nueva=0
  src=$(realpath -- "$1" 2>/dev/null) || { echo "No existe: $1" >&2; return 1; }
  [[ -f "$src" ]] && es_imagen "$src" || { echo "Eso no es una imagen jpg, png o webp: $1" >&2; return 1; }
  case "$src" in
    "$FOTOS"/*) dest=$src ;;
    *)
      base=$(basename "$src"); dest="$FOTOS/$base"
      if [[ -e "$dest" ]] && ! cmp -s "$src" "$dest"; then dest="$FOTOS/$(date +%Y%m%d-%H%M%S)-$base"; fi
      [[ -e "$dest" ]] || { cp -- "$src" "$dest" && nueva=1; } ;;
  esac
  poner "$dest" && return 0
  ((nueva)) && rm -f -- "$dest"   # no guardar en tu colección una foto que no sirvió
  return 1
}

quitar() {
  rm -f "$AVATAR" "$ACTUAL"
  notificar "Foto de perfil quitada" "La barra vuelve a mostrar el ícono"
}

nombre_actual() { local n; n=$(head -1 "$NOMBRE" 2>/dev/null); printf '%s' "${n:-$USER}"; }
poner_nombre() {
  local n=$1
  n=${n//$'\n'/ }; n=${n:0:24}
  n="${n#"${n%%[![:space:]]*}"}"; n="${n%"${n##*[![:space:]]}"}"
  if [[ -z "$n" || "$n" == "$USER" ]]; then rm -f "$NOMBRE"; notificar "Nombre" "Se muestra tu usuario: $USER"
  else printf '%s\n' "$n" > "$NOMBRE"; notificar "Nombre" "Ahora se muestra: $n"; fi
}

carpetas_de_imagenes() {   # dónde buscar fotos para agregar
  local d
  {
    command -v xdg-user-dir >/dev/null 2>&1 && { xdg-user-dir PICTURES; xdg-user-dir DOWNLOAD; xdg-user-dir DESKTOP; }
    printf '%s\n' "$HOME/Pictures" "$HOME/Imágenes" "$HOME/Downloads" "$HOME/Descargas" "$HOME/Desktop" "$HOME/Escritorio" "$HOME/.config/wallpapers"
  } | while IFS= read -r d; do [[ -n "$d" && "$d" != "$HOME" && -d "$d" ]] && realpath -- "$d"; done | sort -u
}

# ─────────── menús ───────────
rofi_cuadricula() {   # $1 = prompt, $2 = mensaje; filas "texto\0icon\x1fruta" por stdin
  local tema=()
  [[ -f "$TEMA" ]] && tema=(-theme "$TEMA" -theme-str 'window { width: 900px; } mainbox { children: [ inputbar, message, listview ]; } message { padding: 10px 16px; border-radius: 12px; background-color: @bg-alt; } textbox { text-color: @fg; } listview { columns: 5; lines: 2; } element-icon { size: 132px; } element-text { font: "JetBrainsMono Nerd Font 10"; }')
  rofi -dmenu -i -show-icons -format i -p "$1" -mesg "$2" "${tema[@]}"
}

menu_agregar() {
  local -a imgs carpetas
  mapfile -t carpetas < <(carpetas_de_imagenes)
  ((${#carpetas[@]})) && mapfile -t imgs < <(
    find -L "${carpetas[@]}" -maxdepth 3 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
      -not -path "$DIR/*" -printf '%T@\t%p\n' 2>/dev/null | sort -rn | head -80 | cut -f2-)
  local sel
  sel=$( {
      printf '%s\0icon\x1f%s\n' "Abrir la carpeta" "folder-pictures"
      local f; for f in "${imgs[@]}"; do printf '%s\0icon\x1f%s\n' "$(basename "$f")" "$f"; done
    } | rofi_cuadricula "$I_PERFIL  Agregar" "Tus imágenes más recientes (Imágenes, Descargas, Escritorio, fondos). Elige una y se vuelve tu foto.") || return 1
  [[ "$sel" =~ ^[0-9]+$ ]] || return 1
  if ((sel == 0)); then carpeta; return 0; fi
  agregar "${imgs[sel - 1]}"
}

carpeta() {
  notificar "Mete aquí tus fotos de perfil" "Luego ábrelas con Super + Shift + F"
  xdg-open "$FOTOS" >/dev/null 2>&1 &
}

menu() {
  pkill -x rofi && return 0
  command -v rofi >/dev/null 2>&1 || { echo "Falta rofi" >&2; return 1; }
  local -a fotos; local cur sel n
  mapfile -t fotos < <(listar)
  cur=$(head -1 "$ACTUAL" 2>/dev/null)
  n=${#fotos[@]}

  # 0 = agregar · 1..n = tus fotos · luego nombre, carpeta y quitar
  sel=$( {
      printf '%s\0icon\x1f%s\n' "Agregar foto" "list-add"
      local f; for f in "${fotos[@]}"; do
        if [[ "$f" == "$cur" ]]; then printf '● %s\0icon\x1f%s\n' "$(basename "$f")" "$f"
        else printf '%s\0icon\x1f%s\n' "$(basename "$f")" "$f"; fi
      done
      printf '%s\0icon\x1f%s\n' "Nombre: $(nombre_actual)" "accessories-text-editor"
      printf '%s\0icon\x1f%s\n' "Abrir carpeta" "folder-pictures"
      [[ -f "$AVATAR" ]] && printf '%s\0icon\x1f%s\n' "Quitar foto" "edit-delete"
    } | rofi_cuadricula "$I_PERFIL  Perfil" "Elige tu foto: se recorta en círculo y aparece en la barra y el lanzador.") || return 0
  [[ "$sel" =~ ^[0-9]+$ ]] || return 0

  if   ((sel == 0));     then menu_agregar
  elif ((sel <= n));     then poner "${fotos[sel - 1]}"
  elif ((sel == n + 1)); then
    local nuevo
    nuevo=$(rofi -dmenu -p "$I_PERFIL  Nombre" -filter "$(nombre_actual)" \
              -mesg "¿Cómo quieres que te salude? (vacío = tu usuario: $USER)" \
              -theme "$HOME/.config/rofi/themes/zero.rasi" \
              -theme-str 'window { width: 520px; } mainbox { children: [ message, inputbar ]; } message { padding: 10px 16px; border-radius: 12px; background-color: @bg-alt; } textbox { text-color: @fg; }' < /dev/null) || return 0
    poner_nombre "$nuevo"
  elif ((sel == n + 2)); then carpeta
  else quitar; fi
}

case "${1:-menu}" in
  menu)            menu ;;
  quitar)          quitar ;;
  carpeta)         carpeta ;;
  nombre)          poner_nombre "${2:-}" ;;
  -h|--help|ayuda) sed -n '2,8p' "$0" ;;
  *)               agregar "$1" ;;
esac
