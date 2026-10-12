#!/usr/bin/env bash
# lib/plantillas.sh — motor de plantillas del rice
#
# Cada archivo  ~/.config/rice-plantillas/*.tpl  es una plantilla de una app.
# Al aplicar una paleta, se reemplazan los {{variables}} y se escribe el resultado en su destino.
# Para tematizar una app nueva basta con agregar un .tpl; no hay que tocar código.
#
# Cabecera (líneas que empiezan con "#@ "; no salen en el resultado):
#   #@ destino: ~/.config/app/colores.conf     ← dónde se escribe (obligatorio)
#   #@ requiere: dir ~/.config/app              ← solo si existe esa carpeta  (o: cmd btop)
#   #@ opcion: TEMA_KITTY                       ← solo si esa opción de ajustes vale 1
#   #@ despues: pkill -USR1 -x kitty            ← comando a correr después de escribirla
#
# Variables:  {{acento}} → #7593af      {{acento.hex}} → 7593af      {{acento.rgb}} → 117, 147, 175
#             {{acento.a30}} → #7593af4d  (30 % de opacidad, estilo rofi)
#             {{acento.rgba30}} → rgba(117, 147, 175, 0.30)   (estilo CSS)
#             {{acento.hypr}} → rgba(7593afff)   ·   {{acento.hypr67}} → rgba(7593afaa)
#             {{acento.ansi}} → 38;2;117;147;175   (color de texto para la terminal: \e[38;2;…m)  ·  {{acento.ansibg}} → 48;2;…
#   Colores:  fondo fondo2 tenue texto acento acento2 sobre inactivo rojo verde amarillo azul
#             magenta cyan medio sombra root_fondo root_texto root_borde term_fondo term_texto
#             term_acento term_acento2 term_tenue   (los mismos, pero legibles sobre el fondo de la terminal)
#             ansi0 … ansi15
#   Texto:    id nombre modo (oscuro|claro)

shopt -u patsub_replacement 2>/dev/null || true

PLANTILLAS_DIR="${PLANTILLAS_DIR:-$HOME/.config/rice-plantillas}"
ERRORES_PLANTILLA=()
DESPUES=()

# valor_token "nombre[.forma]" → deja el resultado en $REPLY
valor_token() {
  local n=${1%%.*} f="" c kind pct a255
  [[ "$1" == *.* ]] && f=${1#*.}
  [[ -v "V[$n]" ]] || return 1
  c=${V[$n]}
  if [[ -z "$f" ]]; then REPLY=$c; return 0; fi
  [[ "$c" =~ ^#[0-9a-fA-F]{6}$ ]] || return 1
  case "$f" in
    hex) REPLY=${c#\#}; return 0 ;;
    rgb) REPLY=$(rgb "$c"); return 0 ;;
    ansi)   REPLY=$(rgb "$c"); REPLY="38;2;${REPLY//, /;}"; return 0 ;;   # texto de color en la terminal
    ansibg) REPLY=$(rgb "$c"); REPLY="48;2;${REPLY//, /;}"; return 0 ;;   # fondo de color en la terminal
  esac
  if [[ "$f" =~ ^(a|rgba|hypr)([0-9]{1,3})?$ ]]; then
    kind=${BASH_REMATCH[1]}; pct=${BASH_REMATCH[2]}
    [[ -z "$pct" ]] && { [[ "$kind" == hypr ]] && pct=100 || return 1; }
    pct=$((10#$pct)); ((pct > 100)) && pct=100
    a255=$(( (pct * 255 + 50) / 100 ))
    case "$kind" in
      a)    printf -v REPLY '%s%02x' "$c" "$a255" ;;
      hypr) printf -v REPLY 'rgba(%s%02x)' "${c#\#}" "$a255" ;;
      rgba) printf -v REPLY 'rgba(%s, %d.%02d)' "$(rgb "$c")" $((pct / 100)) $((pct % 100)) ;;
    esac
    return 0
  fi
  return 1
}

# renderizar_texto "texto con {{variables}}" → texto con los valores puestos
renderizar_texto() {
  local txt=$1 tok name
  local re='\{\{[[:space:]]*([a-z0-9_]+(\.[a-z0-9]+)?)[[:space:]]*\}\}'
  while [[ $txt =~ $re ]]; do
    tok=${BASH_REMATCH[0]}; name=${BASH_REMATCH[1]}
    if valor_token "$name"; then
      txt=${txt//"$tok"/$REPLY}
    else
      ERRORES_PLANTILLA+=("$name")
      txt=${txt//"$tok"/"«$name?»"}
    fi
  done
  printf '%s' "$txt"
}

# renderizar_plantillas [filtro] → aplica todas las plantillas (o las que contengan "filtro" en el nombre)
renderizar_plantillas() {
  local f nombre dest omitir cuerpo linea clave valor tipo arg cmd
  local locales=() hechas=0
  DESPUES=(); ERRORES_PLANTILLA=()
  [[ -d "$PLANTILLAS_DIR" ]] || { echo "No existe $PLANTILLAS_DIR (corre ./install.sh)" >&2; return 1; }

  for f in "$PLANTILLAS_DIR"/*.tpl; do
    [[ -f "$f" ]] || continue
    nombre=$(basename "$f" .tpl)
    [[ -n "${1:-}" && "$nombre" != *"$1"* ]] && continue

    dest=""; omitir=0; cuerpo=""; locales=()
    while IFS= read -r linea || [[ -n "$linea" ]]; do
      if [[ "$linea" == "#@ "* ]]; then
        clave=${linea#"#@ "}; valor=${clave#*:}; clave=${clave%%:*}
        valor=${valor#"${valor%%[![:space:]]*}"}; valor=${valor%"${valor##*[![:space:]]}"}
        case "$clave" in
          destino)  dest=${valor/#\~/$HOME} ;;
          requiere) tipo=${valor%% *}; arg=${valor#* }; arg=${arg/#\~/$HOME}
                    case "$tipo" in
                      dir) [[ -d "$arg" ]] || omitir=1 ;;
                      cmd) command -v "$arg" >/dev/null 2>&1 || omitir=1 ;;
                    esac ;;
          opcion)   [[ "${!valor:-1}" == 1 ]] || omitir=1 ;;
          despues)  locales+=("$valor") ;;
        esac
      else
        cuerpo+="$linea"$'\n'
      fi
    done < "$f"

    ((omitir)) && continue
    [[ -n "$dest" ]] || { echo "Plantilla sin destino: $nombre" >&2; continue; }
    mkdir -p "$(dirname "$dest")"
    renderizar_texto "$cuerpo" > "$dest.tmp" && mv -f "$dest.tmp" "$dest"
    hechas=$((hechas + 1))
    for cmd in "${locales[@]}"; do DESPUES+=("$cmd"); done
  done

  if ((${#ERRORES_PLANTILLA[@]})); then
    echo "Variables desconocidas en plantillas: $(printf '%s\n' "${ERRORES_PLANTILLA[@]}" | sort -u | tr '\n' ' ')" >&2
  fi

  # comandos "despues": sin repetir, y sin que uno trabe a los demás
  local -A visto=()
  for cmd in "${DESPUES[@]}"; do
    [[ -n "${visto[$cmd]:-}" ]] && continue
    visto[$cmd]=1
    bash -c "$cmd" >/dev/null 2>&1 || true
  done
  return 0
}
