#!/usr/bin/env bash
# aplicar-imagenes.sh — actualiza zero-rice: paleta propia por cada imagen, en una pestaña aparte
# Uso:  bash aplicar-imagenes.sh        (desde cualquier carpeta; es seguro correrlo más de una vez)
# Escribe en  ~/zero-rice  (tu repo)  y en  ~/.config  (lo instalado), y respalda lo que reemplaza.
set -u
REPO="$HOME/zero-rice"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
RESP="$CFG/rice-respaldo-imagenes-$(date +%Y%m%d-%H%M%S)"
ok()   { printf '\e[1;32m[✓]\e[0m %s\n' "$*"; }
info() { printf '\e[1;36m[i]\e[0m %s\n' "$*"; }
err()  { printf '\e[1;31m[✗]\e[0m %s\n' "$*"; }

[ -d "$REPO/config/hypr/scripts" ] || { err "No encuentro $REPO (tu repo zero-rice)."; exit 1; }
[ -d "$CFG/hypr/scripts" ]        || { err "No encuentro $CFG/hypr/scripts (¿ya instalaste el rice?)."; exit 1; }

# ── respaldo ──
mkdir -p "$RESP"
for f in "$CFG/hypr/scripts/paleta.sh" "$CFG/hypr/scripts/lib/dinamica.sh" "$CFG/hypr/rice.lua" \
         "$REPO/config/hypr/scripts/paleta.sh" "$REPO/config/hypr/scripts/lib/dinamica.sh" \
         "$REPO/config/hypr/rice.lua" "$REPO/README.md" "$REPO/install.sh"; do
  [ -f "$f" ] && { mkdir -p "$RESP/$(dirname "${f#/}")"; cp -a "$f" "$RESP/${f#/}"; }
done
ok "Respaldo en $RESP"

# ── 1) los dos scripts nuevos (en tu repo y en lo instalado) ──
tmp=$(mktemp -d)
cat > "$tmp/paleta.sh" <<'IMG_PALETA_EOF'
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
ESTILO_FONDO=lineas    # lineas · malla · aurora · rejilla · circulos · aleatorio
MODO_IMAGENES=oscuro   # oscuro · claro: tema de las paletas sacadas de tus imágenes

shopt -u patsub_replacement 2>/dev/null

CFG="$HOME/.config"
DIR="$CFG/rice-paletas"
LISTA="$DIR/paletas.txt"
ACTUAL="$DIR/actual"
LIB="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib"
mkdir -p "$DIR"

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
IMG_PALETA_EOF
cat > "$tmp/dinamica.sh" <<'IMG_DINAMICA_EOF'
#!/usr/bin/env bash
# lib/dinamica.sh — una paleta guardada por cada una de tus imágenes (necesita ImageMagick)
#
#   colores_de_imagen IMG [oscuro|claro]  → imprime los 14 colores de la paleta de esa imagen
#   indexar_imagenes [IMG...]             → calcula y guarda la paleta de cada imagen
#
# Guarda:  ~/.config/rice-paletas/imagenes.txt   mismo formato que paletas.txt + la ruta de la imagen
#          ~/.config/rice-paletas/imagenes.idx   qué ya se calculó (ruta|fecha|tamaño|modo|id)
#          ~/.cache/rice-paletas/miniaturas/     miniaturas para el menú
# Solo se recalcula lo que cambió; borrar una imagen quita su paleta.

IMG_LISTA="$DIR/imagenes.txt"
IMG_INDICE="$DIR/imagenes.idx"
MINIS="${XDG_CACHE_HOME:-$HOME/.cache}/rice-paletas/miniaturas"
IMG_REGEX='.*\.(jpe?g|png|webp|gif|bmp)$'

_im() { if command -v magick >/dev/null 2>&1; then echo magick; elif command -v convert >/dev/null 2>&1; then echo convert; else return 1; fi; }

# colores_de_imagen IMAGEN [oscuro|claro] → "F F2 TEN TEX A A2 SO INA rojo verde amarillo azul magenta cyan"
colores_de_imagen() {
  local img=$1 modo=${2:-oscuro} IM hist
  IM=$(_im) || return 1
  hist=$("$IM" "${img}[0]" -alpha off -resize 200x200 -colors 16 -depth 8 -format '%c' histogram:info:- 2>/dev/null \
         | sed -nE 's/^ *([0-9]+): *\([^)]*\) *(#[0-9A-Fa-f]{6}).*/\1 \2/p')
  [[ -n "$hist" ]] || return 1
  awk -v modo="$modo" '
    function max(a,b){return a>b?a:b} function min(a,b){return a<b?a:b}
    function clamp(x,lo,hi){return min(hi,max(lo,x))}
    function h2d(s,  i,v,c){v=0;s=tolower(s);for(i=1;i<=length(s);i++){c=index("0123456789abcdef",substr(s,i,1))-1;v=v*16+c}return v}
    function dh(a,b,  d){d=a-b;if(d<0)d=-d;return d>180?360-d:d}
    function hsl2hex(h,s,l,  c,x,m,r,g,b,hp){
      h=(h%360+360)%360; c=(1-((2*l-1)<0?-(2*l-1):(2*l-1)))*s; hp=h/60
      x=c*(1-((hp%2-1)<0?-(hp%2-1):(hp%2-1))); m=l-c/2
      if(hp<1){r=c;g=x;b=0}else if(hp<2){r=x;g=c;b=0}else if(hp<3){r=0;g=c;b=x}
      else if(hp<4){r=0;g=x;b=c}else if(hp<5){r=x;g=0;b=c}else{r=c;g=0;b=x}
      return sprintf("#%02x%02x%02x",(r+m)*255+0.5,(g+m)*255+0.5,(b+m)*255+0.5)}
    {
      n++; cnt[n]=$1; total+=$1
      R=h2d(substr($2,2,2))/255; G=h2d(substr($2,4,2))/255; B=h2d(substr($2,6,2))/255
      mx=max(R,max(G,B)); mn=min(R,min(G,B)); L=(mx+mn)/2; d=mx-mn
      if(d==0){S=0;Hh=0}else{
        S=d/(1-((2*L-1)<0?-(2*L-1):(2*L-1)))
        if(mx==R)Hh=60*(((G-B)/d)%6); else if(mx==G)Hh=60*((B-R)/d+2); else Hh=60*((R-G)/d+4)
        if(Hh<0)Hh+=360}
      hh[n]=Hh; ss[n]=S; ll[n]=L; if(S>maxs)maxs=S
    }
    END{
      ia=0;best=0
      for(i=1;i<=n;i++) if(ss[i]>=0.22 && ll[i]>=0.22 && ll[i]<=0.88){sc=ss[i]*(0.35+sqrt(cnt[i]/total)); if(sc>best){best=sc;ia=i}}
      gris=(maxs<0.12 || ia==0)
      if(gris){ha=210;sa=0.28}else{ha=hh[ia];sa=ss[ia]}
      h2=(ha+40)%360;s2=sa;best=0
      for(i=1;i<=n;i++) if(!gris && ss[i]>=0.2 && ll[i]>=0.22 && ll[i]<=0.88 && dh(hh[i],ha)>=35){sc=ss[i]*(0.3+sqrt(cnt[i]/total)); if(sc>best){best=sc;h2=hh[i];s2=ss[i]}}
      sb=gris?0.08:min(0.32,sa*0.5)
      if(modo=="claro"){
        A=hsl2hex(ha,clamp(sa,0.5,0.85),0.38); A2=hsl2hex(h2,clamp(s2,0.45,0.8),0.42)
        F=hsl2hex(ha,sb,0.95); F2=hsl2hex(ha,sb,0.88); INA=hsl2hex(ha,sb,0.84)
        TEX=hsl2hex(ha,0.28,0.17); TEN=hsl2hex(ha,0.12,0.42); SO=F
        sl=0.38; sv=0.34
        ro=hsl2hex(355,0.70,sl); ve=hsl2hex(140,0.55,sv); am=hsl2hex(42,0.85,0.36)
        az=hsl2hex(215,0.70,sl); mg=hsl2hex(295,0.55,sl); ci=hsl2hex(185,0.75,0.30)
      } else {
        A=hsl2hex(ha,clamp(sa,0.5,0.9),0.66); A2=hsl2hex(h2,clamp(s2,0.45,0.85),0.70)
        F=hsl2hex(ha,sb,0.07); F2=hsl2hex(ha,sb,0.13); INA=hsl2hex(ha,sb,0.17)
        TEX=hsl2hex(ha,0.25,0.93); TEN=hsl2hex(ha,0.14,0.62); SO=F
        ro=hsl2hex(355,0.75,0.68); ve=hsl2hex(140,0.50,0.62); am=hsl2hex(45,0.85,0.65)
        az=hsl2hex(215,0.80,0.68); mg=hsl2hex(295,0.60,0.72); ci=hsl2hex(185,0.70,0.62)
      }
      print F,F2,TEN,TEX,A,A2,SO,INA,ro,ve,am,az,mg,ci
    }' <<<"$hist"
}

# id estable para una imagen: img-nombre-xxxx
imagen_id() {
  local base=${1##*/} slug h
  base=${base%.*}
  slug=$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-24)
  h=$(printf '%s' "$1" | cksum | cut -d' ' -f1)
  printf 'img-%s-%s' "${slug:-imagen}" "$(printf '%x' "$h" | cut -c1-4)"
}

imagen_nombre() {   # nombre bonito (sin extensión, sin "|")
  local b=${1##*/}; b=${b%.*}; b=${b//|//}
  printf '%.32s' "$b"
}

# linea_imagen ID NOMBRE DESC RUTA  <14 colores>  → una línea de imagenes.txt
linea_imagen() {
  local id=$1 nom=$2 desc=$3 ruta=$4; shift 4
  local f f2 ten tex a a2 so ina ro ve am az mg ci
  read -r f f2 ten tex a a2 so ina ro ve am az mg ci <<<"$*"
  printf '%s|%s|%s|%s,%s,%s,%s,%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
    "$id" "$nom" "$desc" "$f" "$f2" "$a" "$a2" "$tex" \
    "$f" "$f2" "$ten" "$tex" "$a" "$a2" "$so" "$ina" "$ro" "$ve" "$am" "$az" "$mg" "$ci" "$ruta"
}

# indexar_imagenes [IMAGEN...]
#   sin argumentos: revisa ~/.config/wallpapers (+ lo que ya estaba indexado)
#   con argumentos: agrega/actualiza solo esas imágenes
indexar_imagenes() {
  local IM modo=${MODO_IMAGENES:-oscuro} ruta clave k linea mt sz md id r
  IM=$(_im) || { echo "Falta ImageMagick:  sudo pacman -S imagemagick" >&2; return 1; }
  local -A viejo_clave=() viejo_id=() viejo_linea=() visto=()
  local -a rutas=() pend=()
  mkdir -p "$MINIS" "$DIR"

  if [[ -f "$IMG_INDICE" ]]; then
    while IFS='|' read -r ruta mt sz md id; do
      [[ -n "$ruta" ]] && { viejo_clave[$ruta]="$mt|$sz|$md"; viejo_id[$ruta]=$id; }
    done < "$IMG_INDICE"
  fi
  if [[ -f "$IMG_LISTA" ]]; then
    while IFS= read -r linea; do [[ -n "$linea" ]] && viejo_linea[${linea##*|}]=$linea; done < "$IMG_LISTA"
  fi

  # qué imágenes revisar
  if (($#)); then
    for ruta in "$@"; do [[ -z "${visto[$ruta]:-}" ]] && { visto[$ruta]=1; rutas+=("$ruta"); }; done
  else
    while IFS= read -r -d '' ruta; do
      [[ -z "${visto[$ruta]:-}" ]] && { visto[$ruta]=1; rutas+=("$ruta"); }
    done < <(find -L "$HOME/.config/wallpapers" -maxdepth 2 -type f -regextype posix-extended -iregex "$IMG_REGEX" \
               ! -name 'paleta-*' -print0 2>/dev/null | sort -z)
  fi
  for ruta in "${!viejo_clave[@]}"; do     # lo que ya estaba (de otras carpetas) se conserva si el archivo sigue ahí
    [[ -z "${visto[$ruta]:-}" ]] && { visto[$ruta]=1; rutas+=("$ruta"); }
  done

  # qué hay que calcular
  local -a validas=()
  for ruta in "${rutas[@]}"; do
    [[ -f "$ruta" && "$ruta" != *"|"* ]] || continue
    clave="$(stat -c '%Y|%s' "$ruta")|$modo"
    validas+=("$ruta")
    if [[ "${viejo_clave[$ruta]:-}" == "$clave" ]] && { [[ "${viejo_id[$ruta]}" == "-" ]] || [[ -f "$MINIS/${viejo_id[$ruta]}.png" ]]; }; then
      continue
    fi
    pend+=("$ruta")
  done

  local tmp; tmp=$(mktemp -d)
  if ((${#pend[@]} >= 4)) && command -v notify-send >/dev/null 2>&1; then
    notify-send -a "Paletas" -h string:x-canonical-private-synchronous:paleta-indexar \
      "Leyendo los colores de ${#pend[@]} imágenes…" "Solo pasa la primera vez" 2>/dev/null
  fi

  k=0
  for ruta in "${pend[@]}"; do
    while (( $(jobs -rp | wc -l) >= 4 )); do wait -n; done
    (
      local cols id
      id=$(imagen_id "$ruta")
      if cols=$(colores_de_imagen "$ruta" "$modo") && [[ -n "$cols" ]]; then
        # shellcheck disable=SC2086  # (cols son 14 palabras a propósito)
        "$IM" "${ruta}[0]" -alpha off -thumbnail 192x108^ -gravity center -extent 192x108 "$MINIS/$id.png" 2>/dev/null
        # shellcheck disable=SC2086
        linea_imagen "$id" "$(imagen_nombre "$ruta")" "imagen · $(basename "$(dirname "$ruta")")" "$ruta" $cols > "$tmp/$k.ok"
      fi
    ) &
    k=$((k + 1))
  done
  wait

  # armar los archivos finales
  local -a lineas=() indice=()
  k=0
  for ruta in "${validas[@]}"; do
    clave="$(stat -c '%Y|%s' "$ruta")|$modo"
    r=""
    for p in "${pend[@]}"; do [[ "$p" == "$ruta" ]] && r=1; done
    if [[ -n "$r" ]]; then
      # recién calculada (el índice k sigue el orden de pend)
      local j=0 idx=-1
      for p in "${pend[@]}"; do [[ "$p" == "$ruta" ]] && idx=$j; j=$((j + 1)); done
      if [[ -f "$tmp/$idx.ok" ]]; then
        linea=$(cat "$tmp/$idx.ok"); lineas+=("$linea"); indice+=("$ruta|$clave|${linea%%|*}")
      else
        indice+=("$ruta|$clave|-")          # no se pudo leer: no se reintenta hasta que cambie
      fi
    else
      [[ "${viejo_id[$ruta]:-}" == "-" ]] && { indice+=("$ruta|$clave|-"); continue; }
      [[ -n "${viejo_linea[$ruta]:-}" ]] && { lineas+=("${viejo_linea[$ruta]}"); indice+=("$ruta|$clave|${viejo_id[$ruta]}"); }
    fi
  done
  rm -rf "$tmp"

  { printf '%s\n' "${lineas[@]}" | sed '/^$/d' | sort -t'|' -k2,2 -f; } > "$IMG_LISTA.tmp" && mv -f "$IMG_LISTA.tmp" "$IMG_LISTA"
  { printf '%s\n' "${indice[@]}" | sed '/^$/d'; } > "$IMG_INDICE.tmp" && mv -f "$IMG_INDICE.tmp" "$IMG_INDICE"
  return 0
}
IMG_DINAMICA_EOF
cat > "$tmp/readme_seccion.txt" <<'IMG_README_EOF'
### Paletas de tus imágenes

El menú de paletas (`Super + Shift + P`) tiene **dos pestañas**:

- **Paletas:** las 48 de siempre (y las que tú agregues).
- **Imágenes:** una paleta **por cada fondo tuyo**, con su miniatura. Al elegir una se aplican sus colores y se pone esa imagen de fondo.

Cambias de pestaña con `Alt + 1` / `Alt + 2` o con la primera fila. `Super + Alt + I` abre directo en tus imágenes.

Las imágenes salen de `~/.config/wallpapers/` y de las que agregas con `Super + Shift + I`. Los colores se calculan una sola vez por imagen (y de nuevo solo si la cambias) y se guardan en `~/.config/rice-paletas/imagenes.txt`.

```bash
paleta.sh imagenes                 # ver la lista
paleta.sh imagen playa             # esa imagen de fondo + sus colores (por nombre)
paleta.sh desde-fondo              # solo los colores del fondo que tienes puesto
paleta.sh desde-fondo foto.jpg     # o de una imagen en específico
paleta.sh auto on                  # cada fondo nuevo (Super + W) cambia también los colores
```

`siguiente`, `anterior` y `aleatoria` solo recorren las paletas, no tus imágenes. Para que las paletas de tus imágenes sean de tema claro pon `MODO_IMAGENES=claro` en `~/.config/rice-paletas/ajustes.conf`. Necesita `imagemagick` (el instalador lo pone).

IMG_README_EOF
for destino in "$REPO/config/hypr/scripts" "$CFG/hypr/scripts"; do
  install -Dm755 "$tmp/paleta.sh"    "$destino/paleta.sh"
  install -Dm755 "$tmp/dinamica.sh"  "$destino/lib/dinamica.sh"
done
bash -n "$CFG/hypr/scripts/paleta.sh" && bash -n "$CFG/hypr/scripts/lib/dinamica.sh" && ok "paleta.sh y lib/dinamica.sh actualizados" || { err "Algo salió mal con los scripts"; exit 1; }

# ── 2) atajo Super + Alt + I → pestaña Imágenes ──
for f in "$REPO/config/hypr/rice.lua" "$CFG/hypr/rice.lua"; do
  [ -f "$f" ] && ! grep -q 'menu imagenes' "$f" && sed -i '/"SUPER + SHIFT + I"/a\
hl.bind("SUPER + ALT + I",   hl.dsp.exec_cmd(scripts .. "/paleta.sh menu imagenes"))   -- paletas de tus imágenes' "$f"
done
grep -q 'menu imagenes' "$CFG/hypr/rice.lua" && ok "Atajo Super + Alt + I" || info "No pude agregar el atajo en rice.lua (agrégalo a mano o en mio.lua)"

# ── 3) README ──
f="$REPO/README.md"
if [ -f "$f" ]; then
  if grep -q '^### Paletas de tus imágenes' "$f"; then :
  elif grep -q '^### Paleta desde tu fondo de pantalla' "$f"; then
    awk 'FNR==NR { nuevo = nuevo $0 "\n"; next }
         /^### Paleta desde tu fondo de pantalla/ { printf "%s", nuevo; saltar = 1; next }
         /^### Fondos generados/ { saltar = 0 }
         !saltar { print }' "$tmp/readme_seccion.txt" "$f" > "$f.nuevo" && mv "$f.nuevo" "$f"
  fi
  grep -q 'Paletas de tus imágenes (cada fondo con sus colores)' "$f" || sed -i '/^| `Super + Shift + I`/a\
| `Super + Alt + I` | Paletas de tus imágenes (cada fondo con sus colores) |' "$f"
  sed -i 's/^- \*\*Paleta desde tu fondo:\*\*.*/- **Paleta por cada imagen:** cada fondo tuyo guarda su propia paleta (pestaña "Imágenes" del menú); elegirla aplica sus colores y pone esa imagen./' "$f"
  ok "README actualizado"
fi

# ── 4) install.sh: calcular las paletas de las imágenes al instalar ──
f="$REPO/install.sh"
if [ -f "$f" ]; then
  grep -q 'imagenes indexar' "$f" || sed -i '/"\$S\/panel.sh" fondo >\/dev\/null 2>&1 || true/a\
  setsid -f "$S/paleta.sh" imagenes indexar >/dev/null 2>\&1 || true   # una paleta por cada imagen tuya' "$f"
  grep -q 'paletas de tus imágenes' "$f" || sed -i '/Super + Shift + I      elegir una imagen tuya como fondo/a\
  Super + Alt + I        paletas de tus imágenes (cada fondo con sus colores)' "$f"
  bash -n "$f" && ok "install.sh actualizado" || err "install.sh quedó con un error de sintaxis; revísalo (respaldo en $RESP)"
fi

rm -rf "$tmp"
rm -f "$CFG/rice-paletas/dinamica.txt"      # la paleta "dinamica" vieja ya no existe: ahora hay una por imagen

# ── 5) calcular las paletas de tus imágenes y recargar ──
info "Leyendo los colores de tus imágenes (puede tardar unos segundos la primera vez)..."
"$CFG/hypr/scripts/paleta.sh" imagenes indexar 2>&1 | tail -1
command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1
ok "Listo. Prueba:  Super + Shift + P  (pestañas Paletas / Imágenes con Alt+1 / Alt+2)  ·  Super + Alt + I"
