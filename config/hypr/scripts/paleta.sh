#!/usr/bin/env bash
# shellcheck disable=SC2034  # (variables globales que leen las librerías de lib/)
# paleta.sh — cambia los colores de TODO tu rice en un clic
#   paleta.sh              → menú con 2 pestañas: Paletas e Imágenes (Alt+1 / Alt+2)
#   paleta.sh menu imagenes → abre directo en tus imágenes
#   paleta.sh <id>         → aplicar una paleta directo  (ej: paleta.sh tokyo)
#   paleta.sh siguiente | anterior | aleatoria     (solo entre las paletas)
#   paleta.sh lista | tui | actual
#   paleta.sh imagenes [indexar]   → una paleta guardada por cada imagen de tus fondos
#   paleta.sh imagen <nombre>      → pone esa imagen de fondo con SUS colores
#   paleta.sh desde-fondo [img]    → aplica los colores de tu fondo actual (o de otra imagen)
#   paleta.sh fondo [estilo]       → regenera el fondo de la paleta (lineas malla aurora rejilla circulos)
#   paleta.sh auto on|off          → colores automáticos cada vez que cambias de fondo
# Tus paletas viven en ~/.config/rice-paletas/paletas.txt (agrega las tuyas ahí)
# Tus ajustes van en ~/.config/rice-paletas/ajustes.conf (así las actualizaciones no los pisan)

CAMBIAR_FONDO=1        # 1 = generar un fondo que combine con la paleta · 0 = no tocar mi fondo
TEMA_KITTY=1           # 1 = la terminal también cambia de color         · 0 = no tocar kitty
TEMA_GTK=1             # 1 = apps GTK (Thunar…) con tu paleta y modo claro/oscuro · 0 = no tocarlas
ESTILO_FONDO=lineas    # lineas · malla · aurora · rejilla · circulos · aleatorio
MODO_IMAGENES=oscuro   # oscuro · claro: tema de las paletas sacadas de tus imágenes

shopt -u patsub_replacement 2>/dev/null

CFG="$HOME/.config"
DIR="$CFG/rice-paletas"
LISTA="$DIR/paletas.txt"
ACTUAL="$DIR/actual"
# la 0.2.0 guardaba la paleta actual en ~/.local/state/zero-rice/paleta: se regresa a su lugar una sola vez
ACTUAL_020="${XDG_STATE_HOME:-$HOME/.local/state}/zero-rice/paleta"
LIB="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib"
mkdir -p "$DIR"
[[ -f "$ACTUAL_020" && ! -f "$ACTUAL" ]] && mv -f "$ACTUAL_020" "$ACTUAL"

# shellcheck source=/dev/null
[[ -f "$DIR/ajustes.conf" ]] && source "$DIR/ajustes.conf"

# shellcheck source=lib/color.sh
source "$LIB/color.sh"
# shellcheck source=lib/plantillas.sh
source "$LIB/plantillas.sh"
# shellcheck source=lib/fondos.sh
source "$LIB/fondos.sh"
# shellcheck source=lib/dinamica.sh
source "$LIB/dinamica.sh"

[[ -f "$LISTA" ]] || { echo "No existe $LISTA — corre ./install.sh" >&2; exit 1; }

trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; printf '%s' "${s%"${s##*[![:space:]]}"}"; }
notificar() { command -v notify-send >/dev/null 2>&1 && notify-send -a "Paletas" "$@"; return 0; }

# ─────────── leer paletas ───────────
IDS=(); NOMS=(); DESCS=(); SWS=(); DATA=(); CLAROS=(); IMGS=()
PRESETS=(); IMG_IDX=()

cargar_paletas() {   # $1 = archivo
  local linea id nom desc sw f f2 ten tex a a2 so ina r v am az mg ci ruta c colores extras claro d i
  while IFS= read -r linea || [[ -n "$linea" ]]; do
    [[ -z "${linea//[[:space:]]/}" || "$linea" =~ ^[[:space:]]*# ]] && continue
    IFS='|' read -r id nom desc sw f f2 ten tex a a2 so ina r v am az mg ci ruta <<<"$linea"
    id=$(trim "$id"); nom=$(trim "$nom"); desc=$(trim "$desc"); sw=${sw//[[:space:]]/}; ruta=$(trim "$ruta")
    for i in "${!IDS[@]}"; do [[ "${IDS[i]}" == "$id" ]] && continue 2; done   # id repetido: gana el primero
    colores=()
    for c in "$f" "$f2" "$ten" "$tex" "$a" "$a2" "$so" "$ina"; do
      c=${c//[[:space:]]/}
      [[ "$c" =~ ^#[0-9a-fA-F]{6}$ ]] || { echo "La paleta '$id' tiene un color mal escrito: '$c'" >&2; continue 2; }
      colores+=("$c")
    done
    claro=oscuro; es_claro "${colores[0]}" && claro=claro
    read -ra d <<<"$(defaults_semanticos "$claro")"
    extras=("$r" "$v" "$am" "$az" "$mg" "$ci"); i=0
    for c in "${extras[@]}"; do
      c=${c//[[:space:]]/}
      [[ "$c" =~ ^#[0-9a-fA-F]{6}$ ]] || c=${d[i]}      # si falta o está mal, uno genérico
      colores+=("$c"); i=$((i + 1))
    done
    IDS+=("$id"); NOMS+=("$nom"); DESCS+=("$desc"); SWS+=("$sw"); DATA+=("${colores[*]}"); CLAROS+=("$claro"); IMGS+=("$ruta")
  done < "$1"
}

clasificar() {   # separa las paletas "de catálogo" de las que vienen de una imagen
  local i
  N=${#IDS[@]}; PRESETS=(); IMG_IDX=()
  for i in "${!IDS[@]}"; do
    if [[ -n "${IMGS[i]}" ]]; then IMG_IDX+=("$i"); else PRESETS+=("$i"); fi
  done
}

recargar_listas() {
  IDS=(); NOMS=(); DESCS=(); SWS=(); DATA=(); CLAROS=(); IMGS=()
  cargar_paletas "$LISTA"
  [[ -f "$IMG_LISTA" ]] && cargar_paletas "$IMG_LISTA"
  clasificar
}

recargar_listas
((${#PRESETS[@]})) || { echo "No hay paletas válidas en $LISTA" >&2; exit 1; }

actual_id() { [[ -f "$ACTUAL" ]] && cat "$ACTUAL"; }
indice_de() { local i; for i in "${!IDS[@]}"; do [[ "${IDS[i]}" == "$1" ]] && { echo "$i"; return 0; }; done; return 1; }
indice_de_imagen() { local i; for i in "${IMG_IDX[@]}"; do [[ "${IMGS[i]}" == "$1" ]] && { echo "$i"; return 0; }; done; return 1; }

seleccionar() {   # pone en variables globales la paleta número $1
  local i=$1
  ID=${IDS[i]}; NOM=${NOMS[i]}
  read -r F F2 TEN TEX A A2 SO INA ROJO VERDE AMAR AZUL MAG CIAN <<<"${DATA[i]}"
  definir_variables
}

# ─────────── aplicar ───────────
preparar_kitty() {
  ((TEMA_KITTY)) || return 0
  [[ -d "$CFG/kitty" ]] || return 0
  local conf="$CFG/kitty/kitty.conf"
  touch "$conf"
  grep -q '^include paleta.conf' "$conf" || printf '\n# Colores de paleta.sh\ninclude paleta.conf\n' >> "$conf"
}

recargar() {
  [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || return 0
  hyprctl reload >/dev/null 2>&1 || true
  swaync-client -rs >/dev/null 2>&1 || true
  if [[ -x "$CFG/hypr/scripts/barra.sh" ]]; then
    "$CFG/hypr/scripts/barra.sh" reiniciar
  elif [[ -f "$CFG/ags/app.tsx" ]] && command -v ags >/dev/null 2>&1; then
    ags quit >/dev/null 2>&1 || true
    sleep 0.4
    setsid -f ags run >"/tmp/ags-$USER.log" 2>&1
  fi
}

# aplicar INDICE [1]   →  con "1" y si es una paleta de imagen, también pone esa imagen de fondo
aplicar() {
  local i=$1 con_fondo=${2:-0}
  exec 8>"$DIR/.lock"
  flock -w 10 8 || { echo "Ya se está aplicando otra paleta" >&2; return 1; }
  seleccionar "$i"
  preparar_kitty
  renderizar_plantillas || return 1
  printf '%s\n' "$ID" > "$ACTUAL"
  recargar
  if [[ -n "${IMGS[i]}" ]]; then
    ((con_fondo)) && poner_fondo "${IMGS[i]}"        # la imagen ES el fondo: no se genera otro
    notificar "Imagen: $NOM" "Sus colores ya están en todo el escritorio"
  else
    generar_fondo
    notificar "Paleta: $NOM" "${DESCS[i]}"
  fi
  echo "Paleta aplicada: $NOM"
}

cambiar_relativo() {   # +1 / -1, solo entre las paletas (no entre las imágenes)
  local cur pos=-1 k n=${#PRESETS[@]}
  cur=$(actual_id)
  for k in "${!PRESETS[@]}"; do [[ "${IDS[${PRESETS[k]}]}" == "$cur" ]] && pos=$k; done
  if ((pos < 0)); then
    (($1 > 0)) && pos=0 || pos=$((n - 1))        # venías de una imagen: arranca por un extremo
  else
    pos=$(( (pos + $1 + n) % n ))
  fi
  aplicar "${PRESETS[pos]}"
}

aleatoria() {
  local cur k i n=${#PRESETS[@]}; cur=$(actual_id)
  while :; do k=$((RANDOM % n)); i=${PRESETS[k]}; [[ "${IDS[i]}" != "$cur" || $n -le 1 ]] && break; done
  aplicar "$i"
}

# ─────────── paletas de imágenes ───────────
indexar_y_recargar() {
  indexar_imagenes "$@" || notificar -u critical "Falta ImageMagick" "Instálalo con: sudo pacman -S imagemagick"
  recargar_listas
}

desde_fondo() {
  local img="" arg
  for arg in "$@"; do
    case "$arg" in
      --sin-fondo) ;;                                  # (ya no hace falta: nunca cambia tu fondo)
      --claro) echo "Para temas claros de tus imágenes pon MODO_IMAGENES=claro en ~/.config/rice-paletas/ajustes.conf" >&2 ;;
      *) img=$arg ;;
    esac
  done
  [[ -n "$img" ]] || img=$(cat "$CFG/wallpapers/.actual" 2>/dev/null)
  [[ -f "$img" ]] || { echo "No sé qué imagen usar. Ponle una:  paleta.sh desde-fondo foto.jpg" >&2; return 1; }
  img=$(realpath -- "$img")
  case "${img##*/}" in paleta-*) echo "Ese fondo lo generó una paleta; elige una imagen tuya." >&2; return 1 ;; esac
  indexar_y_recargar "$img" || return 1
  local i; i=$(indice_de_imagen "$img") || { echo "No pude sacar los colores de esa imagen." >&2; return 1; }
  aplicar "$i" 0
}

imagen_cmd() {   # imagen_cmd id|nombre|ruta
  local ref=$1 i found=-1 lc=${1,,}
  indexar_y_recargar
  for i in "${IMG_IDX[@]}"; do
    [[ "${IDS[i]}" == "$ref" || "${IMGS[i]}" == "$ref" ]] && { found=$i; break; }
  done
  if ((found < 0)); then
    for i in "${IMG_IDX[@]}"; do [[ "${NOMS[i],,}" == *"$lc"* ]] && { found=$i; break; }; done
  fi
  ((found >= 0)) || { echo "No encuentro una imagen que se llame '$ref'. Mira:  paleta.sh imagenes" >&2; return 1; }
  aplicar "$found" 1
}

# ─────────── vistas ───────────
bloques_markup() {   # franja de colores para rofi (siempre del mismo ancho)
  local total=18 i n k out=""
  IFS=',' read -ra cs <<<"$1"; n=${#cs[@]}
  for i in "${!cs[@]}"; do
    k=$(( total / n + (i < total % n ? 1 : 0) ))
    out+="<span foreground='${cs[i]}'>$(printf '█%.0s' $(seq 1 "$k"))</span>"
  done
  printf '%s' "$out"
}

bloques_terminal() { # franja de colores con truecolor (siempre del mismo ancho)
  local total=24 i n k h
  IFS=',' read -ra cs <<<"$1"; n=${#cs[@]}
  for i in "${!cs[@]}"; do
    k=$(( total / n + (i < total % n ? 1 : 0) )); h=${cs[i]#\#}
    printf '\e[38;2;%d;%d;%dm' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
    printf '█%.0s' $(seq 1 "$k"); printf '\e[0m'
  done
}

TENUE="#888888"
ROFI_TECLAS=(-kb-custom-1 "Alt+1" -kb-custom-2 "Alt+2")   # Alt+1 → pestaña Paletas · Alt+2 → pestaña Imágenes
ROFI_MSG='mainbox { children: [ inputbar, message, listview ]; } message { padding: 10px 16px; border-radius: 12px; background-color: @bg-alt; } textbox { text-color: @fg; }'
ROFI_IMG='element { spacing: 16px; } element-icon { size: 54px; vertical-align: 0.5; cursor: inherit; } listview { lines: 7; }'

vista_paletas() {   # deja el resultado en SEL (fila) y RC (código de salida de rofi)
  local cur i k marca sol sel_row=0
  cur=$(actual_id); sol=$(printf '\U000F0599')
  for k in "${!PRESETS[@]}"; do [[ "${IDS[${PRESETS[k]}]}" == "$cur" ]] && sel_row=$((k + 3)); done
  SEL=$(
    {
      printf '%s   <b>Mis imágenes</b>  <span size="small" foreground="%s">%d paletas sacadas de tus fondos  →</span>\n' \
        "$(printf '\U000F0976')" "$TENUE" "${#IMG_IDX[@]}"
      printf '%s   <b>Desde mi fondo de pantalla</b>  <span size="small" foreground="%s">saca los colores de lo que tienes puesto</span>\n' \
        "$(printf '\U000F0E09')" "$TENUE"
      printf '%s   <b>Aleatoria</b>  <span size="small" foreground="%s">sorpresa</span>\n' "$(printf '\U000F0E5F')" "$TENUE"
      for i in "${PRESETS[@]}"; do
        marca=""; [[ "${IDS[i]}" == "$cur" ]] && marca="  <span foreground='$TENUE'>● actual</span>"
        printf '%s   <b>%s</b>%s  <span size="small" foreground="%s">%s</span>%s\n' \
          "$(bloques_markup "${SWS[i]}")" "${NOMS[i]}" "$([[ "${CLAROS[i]}" == claro ]] && printf ' %s' "$sol")" \
          "$TENUE" "${DESCS[i]}" "$marca"
      done
    } | rofi -dmenu -i -markup-rows -format i -p "$(printf '\U000F03D8') Paletas" \
             -mesg "<b>Paletas</b>  ·  Alt+2 o la primera fila: Mis imágenes" "${ROFI_TECLAS[@]}" \
             -selected-row "$sel_row" -theme "$CFG/rofi/themes/paletas.rasi" -theme-str "$ROFI_MSG"
  )
  RC=$?
}

vista_imagenes() {
  local cur i k marca sel_row=0 mini
  cur=$(actual_id)
  for k in "${!IMG_IDX[@]}"; do [[ "${IDS[${IMG_IDX[k]}]}" == "$cur" ]] && sel_row=$((k + 2)); done
  SEL=$(
    {
      printf '%s   <b>Paletas</b>  <span size="small" foreground="%s">%d paletas  ←</span>\n' \
        "$(printf '\U000F03D8')" "$TENUE" "${#PRESETS[@]}"
      printf '%s   <b>Agregar una imagen tuya</b>  <span size="small" foreground="%s">elige una de cualquier carpeta</span>\n' \
        "$(printf '\U000F0415')" "$TENUE"
      for i in "${IMG_IDX[@]}"; do
        marca=""; [[ "${IDS[i]}" == "$cur" ]] && marca="  <span foreground='$TENUE'>● actual</span>"
        mini="$MINIS/${IDS[i]}.png"; [[ -f "$mini" ]] || mini="${IMGS[i]}"
        printf '%s   <b>%s</b>  <span size="small" foreground="%s">%s</span>%s\0icon\x1f%s\n' \
          "$(bloques_markup "${SWS[i]}")" "${NOMS[i]}" "$TENUE" "${DESCS[i]}" "$marca" "$mini"
      done
    } | rofi -dmenu -i -markup-rows -show-icons -format i -p "$(printf '\U000F0976') Imágenes" \
             -mesg "<b>Imágenes</b>  ·  cada una trae sus propios colores  ·  Alt+1 o la primera fila: Paletas" "${ROFI_TECLAS[@]}" \
             -selected-row "$sel_row" -theme "$CFG/rofi/themes/paletas.rasi" -theme-str "$ROFI_MSG $ROFI_IMG"
  )
  RC=$?
}

menu_rofi() {   # menu_rofi [paletas|imagenes]
  local seccion=${1:-paletas}
  [[ "$seccion" == imagenes || "$seccion" == imagen ]] && seccion=imagenes || seccion=paletas
  pkill -x rofi && return 0
  # el menú usa la paleta actual; si nunca has elegido, usa la primera
  if [[ ! -f "$CFG/rofi/themes/paletas.rasi" ]]; then seleccionar "${PRESETS[0]}"; renderizar_plantillas rofi; fi
  TENUE=$(grep -oE 'fg-dim: #[0-9a-fA-F]{6}' "$CFG/rofi/themes/paletas.rasi" | head -1 | cut -d' ' -f2); TENUE=${TENUE:-#888888}

  while :; do
    if [[ "$seccion" == imagenes ]]; then
      indexar_y_recargar                      # solo calcula lo que sea nuevo o haya cambiado
      vista_imagenes
    else
      vista_paletas
    fi
    case "$RC" in
      0)  ;;
      10) seccion=paletas;  continue ;;
      11) seccion=imagenes; continue ;;
      *)  return 0 ;;                          # Esc
    esac
    [[ "$SEL" =~ ^[0-9]+$ ]] || return 0

    if [[ "$seccion" == imagenes ]]; then
      case "$SEL" in
        0) seccion=paletas ;;
        1) [[ -x "$CFG/hypr/scripts/elegir-fondo.sh" ]] && exec "$CFG/hypr/scripts/elegir-fondo.sh"; return 0 ;;
        *) aplicar "${IMG_IDX[SEL - 2]}" 1; return 0 ;;
      esac
    else
      case "$SEL" in
        0) seccion=imagenes ;;
        1) desde_fondo; return 0 ;;
        2) aleatoria; return 0 ;;
        *) aplicar "${PRESETS[SEL - 3]}"; return 0 ;;
      esac
    fi
  done
}

lista_terminal() {   # lista_terminal [imagenes]
  local cur i nom ancho=20 conjunto=("${PRESETS[@]}"); cur=$(actual_id)
  [[ "${1:-}" == imagenes ]] && conjunto=("${IMG_IDX[@]}")
  echo
  for i in "${conjunto[@]}"; do
    printf '  \e[1m%2d\e[0m  ' "$((i + 1))"
    bloques_terminal "${SWS[i]}"
    nom=${NOMS[i]}
    printf '  \e[1m%s%*s\e[0m \e[2m%s\e[0m' "$nom" $((ancho - ${#nom} > 0 ? ancho - ${#nom} : 1)) '' "${DESCS[i]}"
    [[ "${IDS[i]}" == "$cur" ]] && printf '  \e[1;32m● actual\e[0m'
    echo
  done
  echo
}

menu_tui() {
  lista_terminal
  local n
  read -rp "  Elige un número (Enter para cancelar): " n
  [[ "$n" =~ ^[0-9]+$ ]] && ((n >= 1 && n <= N)) || { echo "  Cancelado."; return 0; }
  aplicar $((n - 1))
}

case "${1:-menu}" in
  menu)              menu_rofi "${2:-paletas}" ;;
  tui|terminal)      menu_tui ;;
  lista|ls)          [[ "${2:-}" == imagenes ]] && indexar_y_recargar; lista_terminal "${2:-}" ;;
  actual)            actual_id ;;
  siguiente|next)    cambiar_relativo 1 ;;
  anterior|prev)     cambiar_relativo -1 ;;
  aleatoria|random)  aleatoria ;;
  imagenes)
    if [[ "${2:-}" == indexar ]]; then indexar_y_recargar && echo "Paletas de imágenes: ${#IMG_IDX[@]}"
    else indexar_y_recargar; lista_terminal imagenes; fi ;;
  imagen)            [[ -n "${2:-}" ]] || { echo "Uso: paleta.sh imagen <nombre>   (mira: paleta.sh imagenes)" >&2; exit 1; }
                     imagen_cmd "$2" ;;
  fondo)             # solo regenera el fondo de pantalla con la paleta actual
    i=$(indice_de "$(actual_id)") || i=${PRESETS[0]}
    if [[ -n "${IMGS[i]}" ]]; then echo "La paleta actual viene de una imagen (ella es tu fondo). Elige antes una paleta normal." >&2; exit 1; fi
    seleccionar "$i"; CAMBIAR_FONDO=1; generar_fondo "${2:-}" ;;
  desde-fondo)       shift; desde_fondo "$@" ;;
  auto)
    case "${2:-}" in
      on)  : > "$DIR/auto-fondo"; echo "Colores automáticos: activados (cada fondo nuevo que pongas cambia también los colores)" ;;
      off) rm -f "$DIR/auto-fondo"; echo "Colores automáticos: desactivados" ;;
      *)   [[ -f "$DIR/auto-fondo" ]] && echo "Colores automáticos: activados" || echo "Colores automáticos: desactivados" ;;
    esac ;;
  regenerar)         # reaplica la paleta actual a todo MENOS el fondo de pantalla (lo usa el instalador)
    i=$(indice_de "$(actual_id)") || i=${PRESETS[0]}
    seleccionar "$i"; preparar_kitty; renderizar_plantillas
    printf '%s\n' "$ID" > "$ACTUAL"
    swaync-client -rs >/dev/null 2>&1 || true ;;
  colores-barra)     # solo regenera los colores de la barra con la paleta actual (lo usa el instalador)
    i=$(indice_de "$(actual_id)") || i=${PRESETS[0]}
    seleccionar "$i"; renderizar_plantillas ags ;;
  -h|--help|ayuda)   awk 'NR > 2 { if ($0 !~ /^#/) exit; print }' "$0" ;;
  *)
    i=$(indice_de "$1") || { echo "No existe la paleta '$1'. Usa: paleta.sh lista" >&2; exit 1; }
    aplicar "$i" 1 ;;
esac
