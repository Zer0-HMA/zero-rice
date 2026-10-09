#!/usr/bin/env bash
# ws3d.sh — workspaces con transiciones 3D
#   ws3d.sh                 → menú para elegir el efecto (Super + Shift + E)
#   ws3d.sh <n|e+1|e-1>     → cambiar de workspace (lo usan Super + número y Super + rueda)
#   ws3d.sh lista           → ver los efectos en la terminal
#   ws3d.sh efecto <id>     → elegir uno (ej: ws3d.sh efecto cubo · aleatorio · ninguno)
#   ws3d.sh velocidad <v>   → rapida | normal | lenta
#   ws3d.sh probar          → ir al siguiente workspace y regresar, para verlo
# El efecto lo dibuja la barra; si la barra no está corriendo, el cambio es normal.

DIR="$HOME/.config/rice-ws3d"
ESTADO="$DIR/estado"
TEMA="$HOME/.config/rofi/themes/zero.rasi"
mkdir -p "$DIR"

# id | nombre | descripción  (los dibujos viven en ~/.config/ags/efectos3d.ts)
EFECTOS=(
  "cubo|Cubo|el clásico: los workspaces son caras de un cubo que gira"
  "cubovertical|Cubo vertical|el cubo gira hacia arriba y hacia abajo"
  "voltear|Voltear|la pantalla se voltea como carta y atrás está la otra"
  "carrusel|Carrusel|se alejan y giran como portadas de discos"
  "puerta|Puerta|la pantalla se abre como puerta y la otra te espera atrás"
  "caida|Caída|la pantalla se cae hacia atrás y la otra sube del fondo"
  "tunel|Túnel|atraviesas la pantalla y llegas a la otra"
  "inclinado|Inclinado|se desliza de lado, inclinándose en 3D"
  "remolino|Remolino|la pantalla se va girando al fondo y la otra regresa girando"
  "persianas|Persianas|franjas que se voltean una tras otra"
  "mosaico|Mosaico|cuadritos que se voltean en ola diagonal"
  "domino|Dominó|franjas horizontales que caen en cascada"
  "aleatorio|Aleatorio|uno distinto cada vez que cambias"
  "ninguno|Sin efecto 3D|usa las animaciones normales de Hyprland"
)

notificar() { command -v notify-send >/dev/null 2>&1 && notify-send -a "Workspaces 3D" "$@"; return 0; }
color() { grep -oE "$1: #[0-9a-fA-F]{6}" "$TEMA" 2>/dev/null | head -1 | cut -d' ' -f2; }
ids() { local e; for e in "${EFECTOS[@]}"; do printf '%s\n' "${e%%|*}"; done; }
existe() { ids | grep -qx -- "$1"; }
campo() { local e; for e in "${EFECTOS[@]}"; do [[ "${e%%|*}" == "$1" ]] && { cut -d'|' -f"$2" <<<"$e"; return; }; done; }
nombre_vel() { case "$1" in lenta) echo "Lenta" ;; rapida) echo "Rápida" ;; *) echo "Normal" ;; esac; }
quitar_acentos() { local s=${1,,}; s=${s//á/a}; s=${s//é/e}; s=${s//í/i}; s=${s//ó/o}; s=${s//ú/u}; printf '%s' "${s// /}"; }

leer_estado() {
  EFECTO=cubo; VEL=normal
  [[ -f "$ESTADO" ]] || return 0
  local k v
  while IFS='=' read -r k v; do
    case "$k" in
      efecto)    existe "$v" && EFECTO=$v ;;
      velocidad) [[ "$v" =~ ^(lenta|normal|rapida)$ ]] && VEL=$v ;;
    esac
  done < "$ESTADO"
}

# Guarda y, si se prendió o apagó el 3D, regenera las animaciones de Hyprland
# (con 3D, Hyprland no anima los workspaces para no encimarse con la capa)
guardar() {
  local antes=ninguno
  [[ -f "$ESTADO" ]] && antes=$(sed -n 's/^efecto=//p' "$ESTADO")
  printf 'efecto=%s\nvelocidad=%s\n' "$EFECTO" "$VEL" > "$ESTADO"
  local era3d=1 es3d=1
  [[ "$antes" == ninguno || -z "$antes" ]] && era3d=0
  [[ "$EFECTO" == ninguno ]] && es3d=0
  if ((era3d != es3d)) && [[ -x "$HOME/.config/hypr/scripts/animaciones.sh" ]]; then
    local est; est=$(sed -n 's/^estilo=//p' "$HOME/.config/rice-animaciones/estado" 2>/dev/null)
    "$HOME/.config/hypr/scripts/animaciones.sh" "${est:-zero}" >/dev/null 2>&1
  fi
}

# ─────────── cambiar de workspace ───────────
directo() {
  local ws=$1
  [[ "$ws" =~ ^-?[0-9]+$ ]] || ws="\"$ws\""
  hyprctl dispatch "hl.dsp.focus({ workspace = $ws })" >/dev/null 2>&1
}

cambiar() {
  leer_estado
  if [[ "$EFECTO" != ninguno ]] && command -v ags >/dev/null 2>&1; then
    local r
    r=$(timeout 2 ags request ws "$1" 2>/dev/null)
    [[ "$r" == ok* ]] && return 0
  fi
  directo "$1"   # sin barra (o barra vieja): cambio normal
}

probar() {
  local cur dur
  cur=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty' 2>/dev/null)
  [[ "$cur" =~ ^[0-9]+$ ]] || { echo "No pude saber en qué workspace estás" >&2; return 1; }
  leer_estado
  case "$VEL" in rapida) dur=0.9 ;; lenta) dur=2 ;; *) dur=1.3 ;; esac
  cambiar $((cur + 1)); sleep "$dur"; cambiar "$cur"
}

# ─────────── vistas ───────────
lista_terminal() {
  leer_estado
  local id n=1 nom
  echo
  while read -r id; do
    nom=$(campo "$id" 2)
    printf '  \e[1m%2d  %s%*s\e[0m \e[2m%s\e[0m' "$n" "$nom" $((16 - ${#nom})) '' "$(campo "$id" 3)"
    [[ "$id" == "$EFECTO" ]] && printf '  \e[1;32m● actual\e[0m'
    echo; n=$((n + 1))
  done < <(ids)
  printf '\n  Velocidad: %s\n\n' "$(nombre_vel "$VEL")"
}

menu_rofi() {
  pkill -x rofi && return 0
  command -v rofi >/dev/null 2>&1 || { echo "Falta rofi" >&2; return 1; }
  local tenue acento tema=() fila=0
  tenue=$(color fg-dim); tenue=${tenue:-#888888}
  acento=$(color acento); acento=${acento:-#88c0d0}
  [[ -f "$TEMA" ]] && tema=(-theme "$TEMA" -theme-str 'window { width: 780px; } mainbox { children: [ inputbar, message, listview ]; } message { padding: 10px 16px; border-radius: 12px; background-color: @bg-alt; } textbox { text-color: @fg; } listview { lines: 12; }')
  local I_CUBO=$'\U000f01a7' I_VEL=$'\uf0e4' I_PLAY=$'\uf04b'

  while :; do
    leer_estado
    local filas=() acciones=() id marca sel
    while read -r id; do
      marca=""; [[ "$id" == "$EFECTO" ]] && marca="  <span foreground='$acento'>● actual</span>"
      filas+=("<b>$(campo "$id" 2)</b>   <span size='small' foreground='$tenue'>$(campo "$id" 3)</span>$marca")
      acciones+=("efecto:$id")
    done < <(ids)
    filas+=("$I_VEL   Velocidad: <b>$(nombre_vel "$VEL")</b>   <span size='small' foreground='$tenue'>Enter para cambiar</span>")
    acciones+=("velocidad")
    filas+=("$I_PLAY   Probar ahora   <span size='small' foreground='$tenue'>va al siguiente workspace y regresa</span>")
    acciones+=("probar")

    sel=$(printf '%s\n' "${filas[@]}" | rofi -dmenu -i -markup-rows -format i -selected-row "$fila" \
            -p "$I_CUBO  Workspaces 3D" \
            -mesg "Elige cómo se cambia entre workspaces (Super + número). Se guarda al momento; Esc para salir." \
            "${tema[@]}") || return 0
    [[ "$sel" =~ ^[0-9]+$ ]] || return 0
    fila=$sel
    case "${acciones[sel]}" in
      efecto:*)  EFECTO=${acciones[sel]#efecto:}; guardar
                 notificar "Workspaces: $(campo "$EFECTO" 2)" "Pruébalo con Super + número" ;;
      velocidad) case "$VEL" in lenta) VEL=normal ;; normal) VEL=rapida ;; *) VEL=lenta ;; esac; guardar ;;
      probar)    probar ;;
    esac
  done
}

case "${1:-menu}" in
  menu)             menu_rofi ;;
  lista|ls)         lista_terminal ;;
  probar|demo)      probar ;;
  efecto)
    leer_estado; e=$(quitar_acentos "${2:-}")
    existe "$e" || { echo "No existe '$2'. Mira los que hay con: ws3d.sh lista" >&2; exit 1; }
    EFECTO=$e; guardar; echo "Workspaces: $(campo "$EFECTO" 2)" ;;
  velocidad)
    leer_estado; v=$(quitar_acentos "${2:-}")
    [[ "$v" =~ ^(lenta|normal|rapida)$ ]] || { echo "Usa: ws3d.sh velocidad rapida|normal|lenta" >&2; exit 1; }
    VEL=$v; guardar; echo "Velocidad: $(nombre_vel "$VEL")" ;;
  -h|--help|ayuda)  sed -n '2,9p' "$0" ;;
  *)
    [[ "$1" =~ ^(-?[0-9]+|e[+-]1)$ ]] || { echo "No entendí '$1' (usa --help)" >&2; exit 1; }
    cambiar "$1" ;;
esac
