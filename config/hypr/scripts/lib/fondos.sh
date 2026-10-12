#!/usr/bin/env bash
# lib/fondos.sh — fondos de pantalla generados con los colores de la paleta (SVG → PNG)
# Estilos: lineas (el original) · malla · aurora · rejilla (synthwave) · circulos
# Usa las variables de la paleta: ID F F2 TEN TEX A A2  (las pone paleta.sh)

ESTILOS_FONDO=(lineas malla aurora rejilla circulos)

# ── números "al azar" repetibles: la misma paleta siempre da el mismo dibujo ──
semilla_de() { SEMILLA=$(printf '%s%s' "$ID" "${1:-}" | cksum | cut -d' ' -f1); }
rnd() { SEMILLA=$(( (SEMILLA * 1103515245 + 12345) & 0x7fffffff )); R=$(( (SEMILLA >> 8) % 100 )); }

_grano() {
  cat <<EOF
  <filter id="grano" x="0" y="0" width="100%" height="100%">
    <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" stitchTiles="stitch"/>
    <feColorMatrix type="saturate" values="0"/>
  </filter>
EOF
}

# ───────────────────────── lineas (el original) ─────────────────────────
fondo_svg_lineas() {
  local ya0=$((H - 200)) ya1=$((H - 200 - W * 55 / 100))
  local yb0=$((H - 40))  yb1=$((H - 40 - W * 55 / 100))
  local brillo=0.5 medio=0.28 suave=0.08
  es_claro "$F" && { brillo=0.38; medio=0.2; suave=0.06; }
  cat <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="$W" height="$H" viewBox="0 0 $W $H">
  <defs>
    <radialGradient id="g1" cx="12%" cy="98%" r="60%">
      <stop offset="0" stop-color="$A" stop-opacity="$brillo"/>
      <stop offset="0.35" stop-color="$A" stop-opacity="$medio"/>
      <stop offset="0.7" stop-color="$A" stop-opacity="$suave"/>
      <stop offset="1" stop-color="$A" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="g2" cx="92%" cy="4%" r="62%">
      <stop offset="0" stop-color="$A2" stop-opacity="$brillo"/>
      <stop offset="0.35" stop-color="$A2" stop-opacity="$medio"/>
      <stop offset="0.7" stop-color="$A2" stop-opacity="$suave"/>
      <stop offset="1" stop-color="$A2" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="l1" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="$W" y2="0">
      <stop offset="0" stop-color="$A" stop-opacity="0"/>
      <stop offset="0.55" stop-color="$A" stop-opacity="0.85"/>
      <stop offset="1" stop-color="$A" stop-opacity="0.1"/>
    </linearGradient>
    <linearGradient id="l2" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="$W" y2="0">
      <stop offset="0" stop-color="$A2" stop-opacity="0"/>
      <stop offset="0.6" stop-color="$A2" stop-opacity="0.7"/>
      <stop offset="1" stop-color="$A2" stop-opacity="0.1"/>
    </linearGradient>
$(_grano)
  </defs>
  <rect width="100%" height="100%" fill="$F"/>
  <rect width="100%" height="100%" fill="url(#g1)"/>
  <rect width="100%" height="100%" fill="url(#g2)"/>
  <line x1="0" y1="$ya0" x2="$W" y2="$ya1" stroke="url(#l1)" stroke-width="3"/>
  <line x1="0" y1="$yb0" x2="$W" y2="$yb1" stroke="url(#l2)" stroke-width="2"/>
  <rect width="100%" height="100%" filter="url(#grano)" opacity="0.035"/>
</svg>
EOF
}

# ───────────────────────── malla (manchas de color suaves) ─────────────────────────
fondo_svg_malla() {
  local i cx cy rad op=0.55 defs="" body=""
  es_claro "$F" && op=0.42
  local cols=("$A" "$A2" "$(mezcla "$A" "$A2" 50)" "$A" "$A2")
  semilla_de malla
  for i in 0 1 2 3 4; do
    rnd; cx=$(( W * R / 100 ))
    rnd; cy=$(( H * R / 100 ))
    rnd; rad=$(( W * (28 + R * 22 / 100) / 100 ))
    defs+="<radialGradient id=\"b$i\" gradientUnits=\"userSpaceOnUse\" cx=\"$cx\" cy=\"$cy\" r=\"$rad\"><stop offset=\"0\" stop-color=\"${cols[i]}\" stop-opacity=\"$op\"/><stop offset=\"0.5\" stop-color=\"${cols[i]}\" stop-opacity=\"$(awk -v o="$op" 'BEGIN{printf "%.2f", o*0.35}')\"/><stop offset=\"1\" stop-color=\"${cols[i]}\" stop-opacity=\"0\"/></radialGradient>"$'\n'
    body+="  <rect width=\"100%\" height=\"100%\" fill=\"url(#b$i)\"/>"$'\n'
  done
  cat <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="$W" height="$H" viewBox="0 0 $W $H">
  <defs>
$defs
    <radialGradient id="vig" cx="50%" cy="50%" r="75%">
      <stop offset="0.55" stop-color="$F" stop-opacity="0"/>
      <stop offset="1" stop-color="$F" stop-opacity="0.65"/>
    </radialGradient>
$(_grano)
  </defs>
  <rect width="100%" height="100%" fill="$F"/>
$body  <rect width="100%" height="100%" fill="url(#vig)"/>
  <rect width="100%" height="100%" filter="url(#grano)" opacity="0.04"/>
</svg>
EOF
}

# ───────────────────────── aurora (cintas de luz con blur y estrellas) ─────────────────────────
fondo_svg_aurora() {
  local k y amp sw op=0.55 estrellas="" cintas="" i x yy r
  es_claro "$F" && op=0.4
  semilla_de aurora
  for k in 0 1 2 3; do
    y=$(( H * (20 + k * 10) / 100 )); amp=$(( H * (9 + k * 3) / 100 )); sw=$(( H * (8 + k * 2) / 100 ))
    cintas+="  <path d=\"M -80,$y C $((W / 5)),$((y - amp)) $((W * 35 / 100)),$((y + amp)) $((W / 2)),$y S $((W * 80 / 100)),$((y - amp)) $((W + 80)),$((y + amp / 2))\" stroke=\"url(#c$((k % 2)))\" stroke-width=\"$sw\" fill=\"none\" stroke-linecap=\"round\" opacity=\"$(awk -v o="$op" -v k="$k" 'BEGIN{printf "%.2f", o*(1-k*0.14)}')\"/>"$'\n'
  done
  if ! es_claro "$F"; then
    for i in $(seq 1 45); do
      rnd; x=$(( W * R / 100 )); rnd; yy=$(( H * R * 6 / 10000 )); rnd; r=$(( 6 + R / 8 ))
      estrellas+="  <circle cx=\"$x\" cy=\"$yy\" r=\"$(awk -v r="$r" 'BEGIN{printf "%.1f", r/10}')\" fill=\"$TEX\" opacity=\"$(awk -v r="$r" 'BEGIN{printf "%.2f", 0.12+r/45}')\"/>"$'\n'
    done
  fi
  cat <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="$W" height="$H" viewBox="0 0 $W $H">
  <defs>
    <linearGradient id="cielo" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="$F"/>
      <stop offset="1" stop-color="$(mezcla "$F" "$A" 14)"/>
    </linearGradient>
    <linearGradient id="c0" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="$W" y2="0">
      <stop offset="0" stop-color="$A" stop-opacity="0"/><stop offset="0.4" stop-color="$A"/>
      <stop offset="0.75" stop-color="$A2"/><stop offset="1" stop-color="$A2" stop-opacity="0"/>
    </linearGradient>
    <linearGradient id="c1" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="$W" y2="0">
      <stop offset="0" stop-color="$A2" stop-opacity="0"/><stop offset="0.35" stop-color="$A2"/>
      <stop offset="0.7" stop-color="$A"/><stop offset="1" stop-color="$A" stop-opacity="0"/>
    </linearGradient>
    <filter id="blur" x="-20%" y="-60%" width="140%" height="220%"><feGaussianBlur stdDeviation="$((H / 20))"/></filter>
$(_grano)
  </defs>
  <rect width="100%" height="100%" fill="url(#cielo)"/>
$estrellas  <g filter="url(#blur)">
$cintas  </g>
  <rect width="100%" height="100%" filter="url(#grano)" opacity="0.04"/>
</svg>
EOF
}

# ───────────────────────── rejilla (sol y cuadrícula estilo synthwave) ─────────────────────────
fondo_svg_rejilla() {
  local yh=$(( H * 58 / 100 )) r=$(( H * 21 / 100 )) cx=$(( W / 2 )) cy
  local t y k x2 j sy sh horiz="" verti="" franjas="" gop=0.55 dop=0.25
  es_claro "$F" && { gop=0.7; dop=0.18; }
  cy=$(( yh - r * 55 / 100 ))
  for t in $(seq 1 14); do
    y=$(( yh + (H - yh) * t * t / 196 ))
    horiz+="    <line x1=\"0\" y1=\"$y\" x2=\"$W\" y2=\"$y\"/>"$'\n'
  done
  for k in $(seq -16 16); do
    x2=$(( cx + k * W * 10 / 100 ))
    verti+="    <line x1=\"$cx\" y1=\"$yh\" x2=\"$x2\" y2=\"$H\"/>"$'\n'
  done
  for j in 0 1 2 3 4 5; do
    sy=$(( cy + r * (18 + j * 14) / 100 )); sh=$(( r * (3 + j * 2) / 100 + 1 ))
    franjas+="    <rect x=\"$((cx - r))\" y=\"$sy\" width=\"$((r * 2))\" height=\"$sh\" fill=\"black\"/>"$'\n'
  done
  cat <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="$W" height="$H" viewBox="0 0 $W $H">
  <defs>
    <linearGradient id="cielo" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="$F"/><stop offset="1" stop-color="$(mezcla "$F" "$A2" 22)"/>
    </linearGradient>
    <linearGradient id="suelo" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="$(mezcla "$F" "$A" 20)"/><stop offset="0.5" stop-color="$F"/><stop offset="1" stop-color="$F"/>
    </linearGradient>
    <linearGradient id="sol" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="$A2"/><stop offset="1" stop-color="$A"/>
    </linearGradient>
    <mask id="mascara">
      <rect x="0" y="0" width="$W" height="$yh" fill="white"/>
$franjas    </mask>
    <filter id="brillo" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="$((H / 60))"/></filter>
    <clipPath id="suelo-clip"><rect x="0" y="$yh" width="$W" height="$((H - yh))"/></clipPath>
$(_grano)
  </defs>
  <rect width="100%" height="100%" fill="url(#cielo)"/>
  <circle cx="$cx" cy="$cy" r="$((r * 13 / 10))" fill="$A2" opacity="0.18" filter="url(#brillo)"/>
  <circle cx="$cx" cy="$cy" r="$r" fill="url(#sol)" mask="url(#mascara)"/>
  <rect x="0" y="$yh" width="$W" height="$((H - yh))" fill="url(#suelo)"/>
  <g clip-path="url(#suelo-clip)" stroke="$A" stroke-width="1.6" opacity="$gop" fill="none">
$horiz$verti  </g>
  <g clip-path="url(#suelo-clip)" stroke="$A" stroke-width="5" opacity="$dop" fill="none" filter="url(#brillo)">
$horiz$verti  </g>
  <line x1="0" y1="$yh" x2="$W" y2="$yh" stroke="$A2" stroke-width="2" opacity="0.9"/>
  <rect width="100%" height="100%" filter="url(#grano)" opacity="0.04"/>
</svg>
EOF
}

# ───────────────────────── circulos (anillos concéntricos) ─────────────────────────
fondo_svg_circulos() {
  local i rad op col anillos="" cx=$(( W * 78 / 100 )) cy=$(( H * 28 / 100 )) base=0.6
  es_claro "$F" && base=0.45
  for i in $(seq 1 16); do
    rad=$(( i * H * 8 / 100 ))
    op=$(awk -v b="$base" -v i="$i" 'BEGIN{o=b-i*0.034; if(o<0.04)o=0.04; printf "%.2f", o}')
    if (( i % 3 == 0 )); then col=$A2; else col=$A; fi
    anillos+="  <circle cx=\"$cx\" cy=\"$cy\" r=\"$rad\" fill=\"none\" stroke=\"$col\" stroke-width=\"$(( i % 4 == 0 ? 3 : 1 ))\" opacity=\"$op\"/>"$'\n'
  done
  cat <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="$W" height="$H" viewBox="0 0 $W $H">
  <defs>
    <radialGradient id="halo" gradientUnits="userSpaceOnUse" cx="$cx" cy="$cy" r="$((H * 80 / 100))">
      <stop offset="0" stop-color="$A" stop-opacity="0.38"/><stop offset="0.5" stop-color="$A2" stop-opacity="0.10"/><stop offset="1" stop-color="$A2" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="halo2" gradientUnits="userSpaceOnUse" cx="$((W * 8 / 100))" cy="$((H * 95 / 100))" r="$((W * 45 / 100))">
      <stop offset="0" stop-color="$A2" stop-opacity="0.3"/><stop offset="1" stop-color="$A2" stop-opacity="0"/>
    </radialGradient>
$(_grano)
  </defs>
  <rect width="100%" height="100%" fill="$F"/>
  <rect width="100%" height="100%" fill="url(#halo)"/>
  <rect width="100%" height="100%" fill="url(#halo2)"/>
$anillos  <circle cx="$cx" cy="$cy" r="$((H * 3 / 100))" fill="$A"/>
  <rect width="100%" height="100%" filter="url(#grano)" opacity="0.035"/>
</svg>
EOF
}

# ───────────────────────── generar y poner ─────────────────────────
poner_fondo() {
  # wall.sh sabe poner imágenes y videos (y apagar el video si pasas a una imagen)
  if [[ -x "$LIB/../wall.sh" ]]; then "$LIB/../wall.sh" _poner "$1" grow >/dev/null 2>&1 && return 0; fi
  local W_BIN; command -v awww >/dev/null 2>&1 && W_BIN=awww || W_BIN=swww
  command -v "$W_BIN" >/dev/null 2>&1 || return 0
  "$W_BIN" query &>/dev/null || { setsid -f "$W_BIN-daemon" >/dev/null 2>&1; sleep 1; }
  "$W_BIN" img "$1" --transition-type grow --transition-fps 60 --transition-duration 1.2 || return 0
  printf '%s\n' "$1" > "$CFG/wallpapers/.actual"
}

# generar_fondo [estilo]  (estilo = lineas|malla|aurora|rejilla|circulos|aleatorio)
generar_fondo() {
  ((CAMBIAR_FONDO)) || return 0
  local estilo=${1:-$ESTILO_FONDO} res svg="$DIR/fondo.svg" png="$CFG/wallpapers/paleta-$ID.png"
  W=1920; H=1080
  [[ "$estilo" == aleatorio ]] && estilo=${ESTILOS_FONDO[RANDOM % ${#ESTILOS_FONDO[@]}]}
  declare -F "fondo_svg_$estilo" >/dev/null || { echo "Estilo de fondo desconocido: $estilo (uso lineas)" >&2; estilo=lineas; }

  res=$(hyprctl monitors 2>/dev/null | grep -oE '[0-9]+x[0-9]+@' | head -1 | tr -d '@')
  [[ -n "$res" ]] && { W=${res%x*}; H=${res#*x}; }

  mkdir -p "$CFG/wallpapers"
  "fondo_svg_$estilo" > "$svg"

  if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w "$W" -h "$H" -o "$png" "$svg" || return 0
  elif command -v magick >/dev/null 2>&1; then
    magick "$svg" "$png" || return 0
  else
    echo "Para generar fondos instala librsvg:  sudo pacman -S librsvg" >&2
    return 0
  fi
  poner_fondo "$png"
}
