#!/usr/bin/env bash
# animaciones.sh — elige cómo se mueve tu escritorio
#   animaciones.sh                    → menú con rofi (Super + Shift + A)
#   animaciones.sh lista              → ver los estilos en la terminal
#   animaciones.sh <estilo>           → aplicar uno directo (ej: animaciones.sh elastico)
#   animaciones.sh aleatoria          → uno al azar
#   animaciones.sh velocidad <v>      → lenta | normal | rapida
#   animaciones.sh borde si|no        → borde de colores girando
#   animaciones.sh probar             → abre una ventana y cambia de workspace para que las veas
#   animaciones.sh regenerar          → reescribe animaciones.lua con lo guardado (sin recargar)
# Lo que eliges se guarda en ~/.config/rice-animaciones/estado

CFG="$HOME/.config"
DIR="$CFG/rice-animaciones"
ESTADO="$DIR/estado"
LUA="$CFG/hypr/animaciones.lua"
TEMA="$CFG/rofi/themes/zero.rasi"
mkdir -p "$DIR"

# ─────────── los estilos ───────────
# id | nombre | descripción
ESTILOS=(
  "zero|Zero|la de siempre: ventanas que brotan y workspaces que se deslizan"
  "elastico|Elástico|física de resorte: todo rebota como gelatina"
  "profundidad|Profundidad|efecto 3D: las ventanas salen del fondo y los workspaces se apilan"
  "cortina|Cortina|las ventanas se despliegan como persiana, workspaces en vertical"
  "deslizar|Deslizar|todo entra de lado, como pasar pantallas en el cel"
  "rapida|Rápida|para trabajar: casi instantáneo, sin brincos"
  "cine|Cine|lento y elegante, para presumir el rice"
  "rebote|Rebote|las ventanas caen desde arriba y botan al llegar"
  "zoom|Zoom|las apps crecen desde un puntito, como en el cel"
  "fluido|Fluido|resortes suaves sin rebote, se siente muy natural"
  "portal|Portal|las ventanas se abren desde una línea y los workspaces se funden"
  "fantasma|Fantasma|nada se mueve: todo aparece y desaparece en transparencia"
  "retro|Retro|seco y sin suavizado, como compu de los 90"
  "ninguna|Sin animaciones|máximo rendimiento"
)

# Cada estilo llena estas variables con "velocidad|curva|estilo"
#   velocidad: en décimas de segundo (5 = medio segundo)
#   curva: nombre de una curva de abajo, o "resorte:nombre" para física
#   W_IN/W_OUT ventanas que abren/cierran · W_MOVE moverlas · WS workspaces · SP workspace especial
#   L_IN/L_OUT barra, menús y notificaciones · F_IN/F_OUT/F_SW desvanecidos · BORDE color del borde
estilo_zero() {
  W_IN="5|zeroSuave|popin 80%";     W_OUT="3|salida|popin 80%";        W_MOVE="5|zeroSuave|"
  WS="5|zeroSuave|slidefade 20%";   SP="5|zeroSuave|slidefadevert 20%"
  L_IN="4|expo|popin 90%";          L_OUT="2.5|salida|popin 90%"
  F_IN="3|expo|"; F_OUT="2.5|salida|"; F_SW="4|expo|"; BORDE="5|expo|"
}
estilo_elastico() {
  W_IN="4.5|resorte:gelatina|popin 60%"; W_OUT="2.5|salida|popin 80%";  W_MOVE="4.5|resorte:gelatina|"
  WS="5|resorte:firme|slide";            SP="4.5|resorte:gelatina|slidevert"
  L_IN="4|resorte:gelatina|popin 80%";   L_OUT="2|salida|popin 90%"
  F_IN="3|expo|"; F_OUT="2|salida|"; F_SW="4|expo|"; BORDE="5|expo|"
}
estilo_profundidad() {
  W_IN="5.5|rebote|popin 30%";      W_OUT="3.5|salida|popin 30%";      W_MOVE="5|expo|"
  WS="6|expo|slidefadevert 15%";    SP="6|rebote|slidefadevert 40%"
  L_IN="4.5|rebote|popin 70%";      L_OUT="2.5|salida|popin 85%"
  F_IN="4.5|expo|"; F_OUT="3|salida|"; F_SW="5|expo|"; BORDE="6|expo|"
}
estilo_cortina() {
  W_IN="4.5|expo|gnomed";           W_OUT="3|salida|gnomed";           W_MOVE="4.5|expo|"
  WS="5|suaveIO|slidevert";         SP="5|expo|slidefadevert 30%"
  L_IN="4|expo|slide";              L_OUT="3|salida|slide"
  F_IN="3|expo|"; F_OUT="2.5|salida|"; F_SW="4|expo|"; BORDE="5|expo|"
}
estilo_deslizar() {
  W_IN="4.5|expo|slide bottom";     W_OUT="3|salida|slide bottom";     W_MOVE="4|expo|"
  WS="5|expo|slide";                SP="5|expo|slidevert"
  L_IN="4|expo|slide";              L_OUT="3|salida|slide"
  F_IN="3|expo|"; F_OUT="2.5|salida|"; F_SW="4|expo|"; BORDE="5|expo|"
}
estilo_rapida() {
  W_IN="2|rapida|popin 95%";        W_OUT="1.5|rapida|popin 95%";      W_MOVE="2.5|rapida|"
  WS="2.5|rapida|fade";             SP="2.5|rapida|slidefadevert 10%"
  L_IN="1.5|rapida|fade";           L_OUT="1.2|rapida|fade"
  F_IN="1.5|rapida|"; F_OUT="1.2|rapida|"; F_SW="2|rapida|"; BORDE="3|rapida|"
}
estilo_cine() {
  W_IN="8|suaveIO|popin 70%";       W_OUT="5|suaveIO|popin 70%";       W_MOVE="7|suaveIO|"
  WS="9|suaveIO|slidefade 40%";     SP="8|suaveIO|slidefadevert 40%"
  L_IN="6|expo|popin 85%";          L_OUT="4|suaveIO|fade"
  F_IN="6|expo|"; F_OUT="4|suaveIO|"; F_SW="6|expo|"; BORDE="8|suaveIO|"
}

estilo_rebote() {
  W_IN="5|resorte:boing|slide top";       W_OUT="3|salida|slide bottom";      W_MOVE="5|resorte:boing|"
  WS="5.5|resorte:boing|slidevert";       SP="5|resorte:boing|slidevert"
  L_IN="4.5|resorte:boing|slide";         L_OUT="2.5|salida|slide"
  F_IN="3|expo|"; F_OUT="2.5|salida|"; F_SW="4|expo|"; BORDE="5|expo|"
}
estilo_zoom() {
  W_IN="4.5|expo|popin 10%";              W_OUT="3|salida|popin 10%";         W_MOVE="4.5|expo|"
  WS="5|expo|slidefade 10%";              SP="5|rebote|slidefadevert 20%"
  L_IN="4|expo|popin 40%";                L_OUT="2.5|salida|popin 60%"
  F_IN="3.5|expo|"; F_OUT="2.5|salida|"; F_SW="4|expo|"; BORDE="5|expo|"
}
estilo_fluido() {
  W_IN="4.5|resorte:suave|popin 85%";     W_OUT="2.5|salida|popin 90%";       W_MOVE="4.5|resorte:suave|"
  WS="5|resorte:suave|slide";             SP="5|resorte:suave|slidefadevert 25%"
  L_IN="4|resorte:suave|popin 90%";       L_OUT="2|salida|fade"
  F_IN="3|expo|"; F_OUT="2|salida|"; F_SW="4|expo|"; BORDE="5|expo|"
}
estilo_portal() {
  W_IN="5|rebote|gnomed";                 W_OUT="3|salida|gnomed";            W_MOVE="5|expo|"
  WS="6|suaveIO|slidefadevert 50%";       SP="6|rebote|slidefadevert 60%"
  L_IN="4.5|rebote|popin 60%";            L_OUT="2.5|salida|popin 80%"
  F_IN="4|expo|"; F_OUT="3|salida|"; F_SW="5|expo|"; BORDE="6|expo|"
}
estilo_fantasma() {
  W_IN="4|suaveIO|popin 100%";            W_OUT="3|suaveIO|popin 100%";       W_MOVE="3|suaveIO|"
  WS="5|suaveIO|fade";                    SP="5|suaveIO|fade"
  L_IN="3.5|suaveIO|fade";                L_OUT="2.5|suaveIO|fade"
  F_IN="5|suaveIO|"; F_OUT="3.5|suaveIO|"; F_SW="5|suaveIO|"; BORDE="5|suaveIO|"
}
estilo_retro() {
  W_IN="1.5|zeroLineal|popin 50%";        W_OUT="1|zeroLineal|popin 50%";     W_MOVE="1.5|zeroLineal|"
  WS="2|zeroLineal|slide";                SP="2|zeroLineal|slidevert"
  L_IN="1|zeroLineal|slide";              L_OUT="1|zeroLineal|slide"
  F_IN="1|zeroLineal|"; F_OUT="1|zeroLineal|"; F_SW="1|zeroLineal|"; BORDE="1|zeroLineal|"
}

# Hojas que se apagan en "Sin animaciones" (las hijas también: si no, las del hyprland.lua de ejemplo siguen vivas)
HOJAS=(windows windowsIn windowsOut windowsMove layers layersIn layersOut fade fadeIn fadeOut fadeSwitch
       fadeDim fadeLayersIn fadeLayersOut workspaces workspacesIn workspacesOut specialWorkspace
       specialWorkspaceIn specialWorkspaceOut border borderangle)

VELOCIDADES=(lenta normal rapida)
factor_de() { case "$1" in lenta) echo 1.6 ;; rapida) echo 0.6 ;; *) echo 1 ;; esac; }
nombre_vel() { case "$1" in lenta) echo "Lenta" ;; rapida) echo "Rápida" ;; *) echo "Normal" ;; esac; }

# ─────────── utilidades ───────────
notificar() { command -v notify-send >/dev/null 2>&1 && notify-send -a "Animaciones" "$@"; return 0; }
en_hyprland() { [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; }
color() { grep -oE "$1: #[0-9a-fA-F]{6}" "$TEMA" 2>/dev/null | head -1 | cut -d' ' -f2; }

ids() { local e; for e in "${ESTILOS[@]}"; do printf '%s\n' "${e%%|*}"; done; }
existe() { ids | grep -qx -- "$1"; }
campo() {   # campo <id> <2=nombre|3=descripción>
  local e; for e in "${ESTILOS[@]}"; do [[ "${e%%|*}" == "$1" ]] && { cut -d'|' -f"$2" <<<"$e"; return; }; done
}

leer_estado() {
  ESTILO=zero; VEL=normal; BORDE_GIRA=si
  [[ -f "$ESTADO" ]] || return 0
  local k v
  while IFS='=' read -r k v; do
    case "$k" in
      estilo)    existe "$v" && ESTILO=$v ;;
      velocidad) [[ " ${VELOCIDADES[*]} " == *" $v "* ]] && VEL=$v ;;
      borde)     [[ "$v" == no ]] && BORDE_GIRA=no ;;
    esac
  done < "$ESTADO"
}
guardar_estado() { printf 'estilo=%s\nvelocidad=%s\nborde=%s\n' "$ESTILO" "$VEL" "$BORDE_GIRA" > "$ESTADO"; }

# ─────────── generar animaciones.lua ───────────
hoja() {    # hoja <leaf> "velocidad|curva|estilo"
  local leaf=$1 vel curva estilo curvalua
  IFS='|' read -r vel curva estilo <<<"$2"
  vel=$(LC_ALL=C awk -v v="$vel" -v f="$FACTOR" 'BEGIN { x = v * f; if (x < 0.1) x = 0.1; if (x > 100) x = 100; printf "%.2f", x }')
  if [[ "$curva" == resorte:* ]]; then curvalua="spring = \"${curva#resorte:}\""
  else curvalua="bezier = \"$curva\""; fi
  if [[ -n "$estilo" ]]; then
    printf 'hl.animation({ leaf = "%s", enabled = true, speed = %s, %s, style = "%s" })\n' "$leaf" "$vel" "$curvalua" "$estilo"
  else
    printf 'hl.animation({ leaf = "%s", enabled = true, speed = %s, %s })\n' "$leaf" "$vel" "$curvalua"
  fi
}
apagar() { printf 'hl.animation({ leaf = "%s", enabled = false })\n' "$1"; }

generar() {
  FACTOR=$(factor_de "$VEL")
  cat <<EOF
-- Generado por animaciones.sh — estilo: $(campo "$ESTILO" 2) · velocidad: $(nombre_vel "$VEL") · borde girando: $BORDE_GIRA
-- No lo edites a mano: cámbialo con Super + Shift + A (o ~/.config/hypr/scripts/animaciones.sh)

hl.curve("zeroSuave",  { type = "bezier", points = { {0.05, 0.9},  {0.1, 1.05} } })
hl.curve("zeroLineal", { type = "bezier", points = { {0, 0},       {1, 1}      } })
hl.curve("salida",     { type = "bezier", points = { {0.3, 0},     {0.8, 0.15} } })
hl.curve("expo",       { type = "bezier", points = { {0.16, 1},    {0.3, 1}    } })
hl.curve("rebote",     { type = "bezier", points = { {0.34, 1.56}, {0.64, 1}   } })
hl.curve("suaveIO",    { type = "bezier", points = { {0.65, 0},    {0.35, 1}   } })
hl.curve("rapida",     { type = "bezier", points = { {0.15, 0},    {0.1, 1}    } })
hl.curve("gelatina",   { type = "spring", mass = 1, stiffness = 200, dampening = 15 })
hl.curve("firme",      { type = "spring", mass = 1, stiffness = 238, dampening = 24 })
hl.curve("boing",      { type = "spring", mass = 1, stiffness = 300, dampening = 11 })
hl.curve("suave",      { type = "spring", mass = 1, stiffness = 170, dampening = 26 })

EOF
  if [[ "$ESTILO" == ninguna ]]; then
    local h; for h in "${HOJAS[@]}"; do apagar "$h"; done
    return 0
  fi

  "estilo_$ESTILO"
  echo "-- Ventanas"
  hoja windows "$W_MOVE";  hoja windowsIn "$W_IN";  hoja windowsOut "$W_OUT";  hoja windowsMove "$W_MOVE"
  if ws3d_activo; then
    echo "-- Workspaces: los anima la barra en 3D (ws3d.sh), así que Hyprland no los mueve"
    apagar workspaces; apagar workspacesIn; apagar workspacesOut
  else
    echo "-- Workspaces (las hijas también, para que no las pise el hyprland.lua de ejemplo)"
    hoja workspaces "$WS";   hoja workspacesIn "$WS"; hoja workspacesOut "$WS"
  fi
  hoja specialWorkspace "$SP"; hoja specialWorkspaceIn "$SP"; hoja specialWorkspaceOut "$SP"
  echo "-- Barra, menús y notificaciones"
  hoja layers "$L_IN";     hoja layersIn "$L_IN";   hoja layersOut "$L_OUT"
  echo "-- Desvanecidos y borde"
  hoja fade "$F_IN";       hoja fadeIn "$F_IN";     hoja fadeOut "$F_OUT"
  hoja fadeSwitch "$F_SW"; hoja fadeDim "$F_SW"
  hoja fadeLayersIn "$F_IN"; hoja fadeLayersOut "$F_OUT"
  hoja border "$BORDE"
  if [[ "$BORDE_GIRA" == si ]]; then
    printf 'hl.animation({ leaf = "borderangle", enabled = true, speed = 100, bezier = "zeroLineal", style = "loop" })\n'
  else
    apagar borderangle
  fi
}

ws3d_activo() {
  local e; e=$(sed -n 's/^efecto=//p' "$CFG/rice-ws3d/estado" 2>/dev/null)
  [[ -n "$e" && "$e" != ninguno ]]
}

escribir() { generar > "$LUA.tmp" && mv "$LUA.tmp" "$LUA"; }

# Aplica lo que esté en ESTILO/VEL/BORDE_GIRA. Si Hyprland marca error, regresa a lo anterior;
# si no hay nada bueno a qué regresar, borra animaciones.lua y rice.lua usa sus animaciones de respaldo.
errores_animaciones() { hyprctl configerrors 2>/dev/null | grep -F "animaciones.lua" | head -5; }

aplicar() {
  local respaldo="$DIR/anterior.lua" estado_resp="$DIR/anterior.estado" errores
  rm -f "$respaldo" "$estado_resp"
  [[ -f "$LUA" ]] && cp -f "$LUA" "$respaldo"
  [[ -f "$ESTADO" ]] && cp -f "$ESTADO" "$estado_resp"
  escribir || { notificar -u critical "No pude escribir $LUA"; return 1; }
  guardar_estado
  en_hyprland || return 0

  rm -f "$DIR/error"
  hyprctl reload >/dev/null 2>&1
  sleep 0.5
  errores=$( { errores_animaciones; cat "$DIR/error" 2>/dev/null; } | head -5)
  [[ -z "$errores" ]] && return 0

  # algo falló: regresar a lo anterior, pero solo si es distinto (y no está roto también)
  if [[ -f "$respaldo" ]] && ! cmp -s "$respaldo" "$LUA"; then
    cp -f "$respaldo" "$LUA"
    [[ -f "$estado_resp" ]] && cp -f "$estado_resp" "$ESTADO"
  else
    rm -f "$LUA"
  fi
  hyprctl reload >/dev/null 2>&1
  sleep 0.5
  if [[ -f "$LUA" && -n "$(errores_animaciones)" ]]; then
    rm -f "$LUA"
    hyprctl reload >/dev/null 2>&1
  fi
  notificar -u critical "No se pudo aplicar «$(campo "$ESTILO" 2)»" "Regresé a las animaciones anteriores. Hyprland dijo:
$errores"
  return 1
}

# Abre una ventanita en un workspace vacío y regresa, para ver las animaciones en acción
probar() {
  en_hyprland || { echo "Esto solo funciona dentro de Hyprland." >&2; return 1; }
  local origen
  origen=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty' 2>/dev/null)
  hyprctl dispatch 'hl.dsp.focus({ workspace = "r+1" })' >/dev/null 2>&1
  sleep 0.8
  if command -v kitty >/dev/null 2>&1; then
    setsid -f kitty --class animaciones-demo \
      sh -c 'printf "\n\n   Así se ven tus animaciones\n"; sleep 1.6' >/dev/null 2>&1
    sleep 2.8
  fi
  if [[ "$origen" =~ ^-?[0-9]+$ ]]; then
    hyprctl dispatch "hl.dsp.focus({ workspace = $origen })" >/dev/null 2>&1
  else
    hyprctl dispatch 'hl.dsp.focus({ workspace = "r-1" })' >/dev/null 2>&1
  fi
}

# ─────────── vistas ───────────
lista_terminal() {
  leer_estado
  local id n=1
  echo
  while read -r id; do
    local nom; nom=$(campo "$id" 2)
    printf '  \e[1m%d  %s%*s\e[0m \e[2m%s\e[0m' "$n" "$nom" $((17 - ${#nom})) '' "$(campo "$id" 3)"
    [[ "$id" == "$ESTILO" ]] && printf '  \e[1;32m● actual\e[0m'
    echo; n=$((n + 1))
  done < <(ids)
  printf '\n  Velocidad: %s · Borde girando: %s\n\n' "$(nombre_vel "$VEL")" "$BORDE_GIRA"
}

menu_rofi() {
  pkill -x rofi && return 0
  command -v rofi >/dev/null 2>&1 || { echo "Falta rofi" >&2; return 1; }
  local tenue acento tema=() fila=0
  tenue=$(color fg-dim); tenue=${tenue:-#888888}
  acento=$(color acento); acento=${acento:-#88c0d0}
  [[ -f "$TEMA" ]] && tema=(-theme "$TEMA" -theme-str 'window { width: 760px; } mainbox { children: [ inputbar, message, listview ]; } message { padding: 10px 16px; border-radius: 12px; background-color: @bg-alt; } textbox { text-color: @fg; } listview { lines: 12; }')

  local I_MAGIA=$'\uf0d0' I_VEL=$'\uf0e4' I_BORDE=$'\uf1fc' I_PLAY=$'\uf04b'
  while :; do
    leer_estado
    local filas=() acciones=() id marca sel
    while read -r id; do
      marca=""; [[ "$id" == "$ESTILO" ]] && marca="  <span foreground='$acento'>● actual</span>"
      filas+=("<b>$(campo "$id" 2)</b>   <span size='small' foreground='$tenue'>$(campo "$id" 3)</span>$marca")
      acciones+=("estilo:$id")
    done < <(ids)
    filas+=("$I_VEL   Velocidad: <b>$(nombre_vel "$VEL")</b>   <span size='small' foreground='$tenue'>Enter para cambiar</span>")
    acciones+=("velocidad")
    filas+=("$I_BORDE   Borde de colores girando: <b>$([[ $BORDE_GIRA == si ]] && echo sí || echo no)</b>   <span size='small' foreground='$tenue'>Enter para cambiar</span>")
    acciones+=("borde")
    filas+=("$I_PLAY   Probar ahora   <span size='small' foreground='$tenue'>abre una ventana en otro workspace y regresa</span>")
    acciones+=("probar")
    if [[ -x "$CFG/hypr/scripts/ws3d.sh" ]]; then
      filas+=($'\U000f01a7'"   Cambio de workspace en 3D…   <span size='small' foreground='$tenue'>cubo, carrusel, puerta y más (Super + Shift + E)</span>")
      acciones+=("ws3d")
    fi

    sel=$(printf '%s\n' "${filas[@]}" | rofi -dmenu -i -markup-rows -format i -selected-row "$fila" \
            -p "$I_MAGIA  Animaciones" \
            -mesg "Se aplican al momento y el menú sigue abierto para que pruebes otras. Esc para salir." \
            "${tema[@]}") || return 0
    [[ "$sel" =~ ^[0-9]+$ ]] || return 0
    fila=$sel

    case "${acciones[sel]}" in
      estilo:*)  ESTILO=${acciones[sel]#estilo:}; aplicar ;;
      velocidad)
        case "$VEL" in lenta) VEL=normal ;; normal) VEL=rapida ;; *) VEL=lenta ;; esac
        aplicar ;;
      borde)     [[ "$BORDE_GIRA" == si ]] && BORDE_GIRA=no || BORDE_GIRA=si; aplicar ;;
      probar)    probar ;;
      ws3d)      setsid -f "$CFG/hypr/scripts/ws3d.sh" menu >/dev/null 2>&1; return 0 ;;
    esac
  done
}

# ─────────── comandos ───────────
quitar_acentos() { local s=${1,,}; s=${s//á/a}; s=${s//é/e}; s=${s//í/i}; s=${s//ó/o}; s=${s//ú/u}; printf '%s' "${s// /}"; }

case "${1:-menu}" in
  menu)          menu_rofi ;;
  lista|ls)      lista_terminal ;;
  probar|demo)   probar ;;
  aleatoria|random)
    leer_estado
    mapfile -t todos < <(ids | grep -vx -e "$ESTILO" -e ninguna)
    ESTILO=${todos[RANDOM % ${#todos[@]}]}; aplicar && echo "Animaciones: $(campo "$ESTILO" 2)" ;;
  regenerar)     leer_estado; escribir ;;
  velocidad)
    leer_estado; v=$(quitar_acentos "${2:-}")
    [[ " ${VELOCIDADES[*]} " == *" $v "* ]] || { echo "Usa: animaciones.sh velocidad lenta|normal|rapida" >&2; exit 1; }
    VEL=$v; aplicar && echo "Velocidad: $(nombre_vel "$VEL")" ;;
  borde)
    leer_estado
    case "${2:-}" in si|on|1) BORDE_GIRA=si ;; no|off|0) BORDE_GIRA=no ;; *) echo "Usa: animaciones.sh borde si|no" >&2; exit 1 ;; esac
    aplicar && echo "Borde girando: $BORDE_GIRA" ;;
  -h|--help|ayuda) sed -n '2,11p' "$0" ;;
  *)
    leer_estado; id=$(quitar_acentos "$1")
    existe "$id" || { echo "No existe el estilo '$1'. Mira los que hay con: animaciones.sh lista" >&2; exit 1; }
    ESTILO=$id; aplicar && echo "Animaciones: $(campo "$ESTILO" 2)" ;;
esac
