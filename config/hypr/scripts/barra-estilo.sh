#!/usr/bin/env bash
# barra-estilo.sh — elige la forma de la barra (los colores siguen siendo los de tu paleta)
#   barra-estilo.sh                  → menú con rofi (Super + Shift + B, o clic derecho en el botón de paletas)
#   barra-estilo.sh lista            → ver los estilos en la terminal
#   barra-estilo.sh <estilo>         → aplicar uno directo (ej: barra-estilo.sh neon)
#   barra-estilo.sh siguiente        → el que sigue (también: anterior, aleatorio)
#   barra-estilo.sh actual           → muestra el que tienes
# Lo que eliges se guarda en ~/.config/rice-barra/estilo; la barra lo aplica en vivo, sin reiniciarse.

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
DIR="$CFG/rice-barra"
ESTADO="$DIR/estilo"
ESTILOS_DIR="$CFG/ags/estilos"
TEMA="$CFG/rofi/themes/zero.rasi"
mkdir -p "$DIR"

# id | nombre | descripción  (cada uno es ~/.config/ags/estilos/<id>.css)
ESTILOS=(
  "islas|Islas|cada módulo flota por su cuenta (el de siempre)"
  "flotante|Flotante|toda la barra es una sola cápsula flotando"
  "bloque|Bloque|barra sólida clásica, pegada arriba, con línea de acento"
  "neon|Neón|islas con bordes que brillan en tu color de acento"
  "vidrio|Vidrio|islas casi transparentes con el desenfoque de Hyprland"
  "minimal|Minimal|sin fondos: solo texto e iconos sobre tu fondo de pantalla"
)

notificar() { command -v notify-send >/dev/null 2>&1 && notify-send -a "Barra" "$@"; return 0; }
color() { grep -oE "$1: #[0-9a-fA-F]{6}" "$TEMA" 2>/dev/null | head -1 | cut -d' ' -f2; }
ids() { local e; for e in "${ESTILOS[@]}"; do printf '%s\n' "${e%%|*}"; done; }
existe() { ids | grep -qx -- "$1"; }
campo() { local e; for e in "${ESTILOS[@]}"; do [[ "${e%%|*}" == "$1" ]] && { cut -d'|' -f"$2" <<<"$e"; return; }; done; }
actual() { local e; e=$(cat "$ESTADO" 2>/dev/null); existe "$e" && printf '%s' "$e" || printf 'islas'; }
quitar_acentos() { local s=${1,,}; s=${s//á/a}; s=${s//é/e}; s=${s//í/i}; s=${s//ó/o}; s=${s//ú/u}; printf '%s' "${s// /}"; }

aplicar() {   # aplicar <id>
  local id=$1
  existe "$id" || { echo "No existe el estilo '$id'. Mira los que hay con: barra-estilo.sh lista" >&2; return 1; }
  if [[ "$id" != islas && ! -f "$ESTILOS_DIR/$id.css" ]]; then
    echo "Falta $ESTILOS_DIR/$id.css (corre ./install.sh --actualizar)" >&2; return 1
  fi
  # se escribe en un temporal y se mueve: la barra nunca lee un archivo a medias
  printf '%s\n' "$id" > "$ESTADO.tmp" && mv -f "$ESTADO.tmp" "$ESTADO"
}

vecino() {    # vecino +1|-1 → id del estilo de al lado
  local lista cur i n
  mapfile -t lista < <(ids)
  cur=$(actual); n=${#lista[@]}
  for i in "${!lista[@]}"; do [[ "${lista[i]}" == "$cur" ]] && break; done
  printf '%s' "${lista[$(( (i + $1 + n) % n ))]}"
}

lista_terminal() {
  local cur id; cur=$(actual)
  printf '\n  Estilos de la barra (Super + Shift + B)\n\n'
  while read -r id; do
    if [[ "$id" == "$cur" ]]; then printf '  \e[1;32m●\e[0m \e[1m%-10s\e[0m %s\n' "$id" "$(campo "$id" 3)"
    else printf '    %-10s %s\n' "$id" "$(campo "$id" 3)"; fi
  done < <(ids)
  echo
}

menu_rofi() {
  pkill -x rofi && return 0
  command -v rofi >/dev/null 2>&1 || { echo "Falta rofi" >&2; return 1; }
  local tenue acento tema=() fila=0
  tenue=$(color fg-dim); tenue=${tenue:-#888888}
  acento=$(color acento); acento=${acento:-#88c0d0}
  [[ -f "$TEMA" ]] && tema=(-theme "$TEMA" -theme-str 'window { width: 760px; } mainbox { children: [ inputbar, message, listview ]; } message { padding: 10px 16px; border-radius: 12px; background-color: @bg-alt; } textbox { text-color: @fg; } listview { lines: 8; }')
  local I_BARRA=$'\uf0c9' I_PALETA=$'\U000f03d8'

  while :; do
    local filas=() acciones=() id marca sel cur
    cur=$(actual)
    while read -r id; do
      marca=""; [[ "$id" == "$cur" ]] && marca="  <span foreground='$acento'>● actual</span>"
      filas+=("<b>$(campo "$id" 2)</b>   <span size='small' foreground='$tenue'>$(campo "$id" 3)</span>$marca")
      acciones+=("estilo:$id")
    done < <(ids)
    filas+=("$I_PALETA   Cambiar la paleta de colores…   <span size='small' foreground='$tenue'>Super + Shift + P</span>")
    acciones+=("paleta")

    sel=$(printf '%s\n' "${filas[@]}" | rofi -dmenu -i -markup-rows -format i -selected-row "$fila" \
            -p "$I_BARRA  Estilo de la barra" \
            -mesg "La forma de la barra; los colores siguen tu paleta. Se aplica al momento; Esc para salir." \
            "${tema[@]}") || return 0
    [[ "$sel" =~ ^[0-9]+$ ]] || return 0
    fila=$sel
    case "${acciones[sel]}" in
      estilo:*) aplicar "${acciones[sel]#estilo:}" ;;
      paleta)   setsid -f "$CFG/hypr/scripts/paleta.sh" menu >/dev/null 2>&1; return 0 ;;
    esac
  done
}

case "${1:-menu}" in
  menu)                menu_rofi ;;
  lista|ls)            lista_terminal ;;
  actual)              actual; echo ;;
  siguiente|next)      e=$(vecino 1);  aplicar "$e" && { echo "Barra: $(campo "$e" 2)"; notificar "Barra: $(campo "$e" 2)" "$(campo "$e" 3)"; } ;;
  anterior|prev)       e=$(vecino -1); aplicar "$e" && { echo "Barra: $(campo "$e" 2)"; notificar "Barra: $(campo "$e" 2)" "$(campo "$e" 3)"; } ;;
  aleatorio|aleatoria|random)
    mapfile -t otros < <(ids | grep -vx -- "$(actual)")
    e=${otros[RANDOM % ${#otros[@]}]}; aplicar "$e" && echo "Barra: $(campo "$e" 2)" ;;
  -h|--help|ayuda)     sed -n '2,8p' "$0" ;;
  *)
    e=$(quitar_acentos "$1")
    aplicar "$e" && echo "Barra: $(campo "$e" 2)" ;;
esac
