#!/usr/bin/env bash
# shellcheck disable=SC2154  # (c_max, c_min, c_humedad) se crean al leer el clima guardado con printf -v
# panel.sh — dibuja el panel izquierdo del lanzador (fondo + saludo + reloj + clima + estadísticas)
# Imprime la ruta del PNG generado. Lo usa lanzador.sh.
shopt -u patsub_replacement 2>/dev/null

W=${PANEL_W:-300}
H=${PANEL_H:-556}
DIR="$HOME/.config/rice-lanzador"
CLIMA="$HOME/.config/rice-clima/actual"
COLORES="$HOME/.config/rofi/themes/colores.rasi"
SCRIPTS="$HOME/.config/hypr/scripts"
mkdir -p "$DIR"

command -v rsvg-convert >/dev/null 2>&1 || exit 1

# ─────────── colores de tu paleta ───────────
color() { grep -oE "^[[:space:]]*$1:[[:space:]]*#[0-9a-fA-F]{6}" "$COLORES" 2>/dev/null | grep -oE '#[0-9a-fA-F]{6}' | head -1; }
F=$(color bg);       F=${F:-#0d0e0e}
F2=$(color bg-alt);  F2=${F2:-#353839}
TEX=$(color fg);     TEX=${TEX:-#e6e6f0}
TEN=$(color fg-dim); TEN=${TEN:-#8a8aa3}
A=$(color acento);   A=${A:-#22d3ee}
A2=$(color acento2); A2=${A2:-#ec4899}

esc() { local s=${1//&/&amp;}; s=${s//</&lt;}; printf '%s' "${s//>/&gt;}"; }
corta() { local s=$1 n=$2; (( ${#s} > n )) && s="${s:0:n-1}…"; printf '%s' "$s"; }

# ─────────── saludo ───────────
h=$((10#$(date +%H)))
if   (( h >= 5  && h < 12 )); then saludo="Buenos días,"
elif (( h >= 12 && h < 19 )); then saludo="Buenas tardes,"
else                               saludo="Buenas noches,"; fi
usuario=$(corta "$USER" 16)
hora=$(date +%H:%M)
fecha=$(date '+%A %d de %B')

# ─────────── estadísticas ───────────
read -r _ u1 n1 s1 i1 w1 x1 y1 z1 _ < /proc/stat
sleep 0.15
read -r _ u2 n2 s2 i2 w2 x2 y2 z2 _ < /proc/stat
tot=$(( (u2+n2+s2+i2+w2+x2+y2+z2) - (u1+n1+s1+i1+w1+x1+y1+z1) ))
idle=$(( (i2+w2) - (i1+w1) ))
cpu=$(( tot > 0 ? (100 * (tot - idle)) / tot : 0 ))

mt=$(awk '/^MemTotal/{print $2}' /proc/meminfo); ma=$(awk '/^MemAvailable/{print $2}' /proc/meminfo)
ram=$(( 100 * (mt - ma) / mt ))
ram_txt=$(awk -v u=$((mt - ma)) -v t="$mt" 'BEGIN{printf "%.1f / %.0f GB", u/1048576, t/1048576}')

read -r disco disco_txt < <(df -P / | awk 'NR==2{gsub("%","",$5); printf "%s %.0f / %.0f GB", $5, $3/1048576, $2/1048576}')

temp=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1)
temp=$(( ${temp:-0} / 1000 ))

bat=""; bat_estado=""
for b in /sys/class/power_supply/BAT*; do
  [[ -f "$b/capacity" ]] || continue
  bat=$(cat "$b/capacity"); bat_estado=$(cat "$b/status" 2>/dev/null); break
done

seg=$(cut -d. -f1 /proc/uptime)
if (( seg >= 86400 )); then encendida="$((seg / 86400)) d $(( (seg % 86400) / 3600 )) h"
elif (( seg >= 3600 )); then encendida="$((seg / 3600)) h $(( (seg % 3600) / 60 )) min"
else encendida="$((seg / 60)) min"; fi

# ─────────── clima ───────────
[[ -x "$SCRIPTS/clima.sh" ]] && "$SCRIPTS/clima.sh" >/dev/null 2>&1   # actualiza en segundo plano si hace falta
c_ok=0
if [[ -f "$CLIMA" ]]; then
  while IFS='=' read -r k v; do
    [[ "$k" =~ ^[a-z]+$ ]] && printf -v "c_$k" '%s' "$v"
  done < "$CLIMA"
  if [[ -n "${c_temp:-}" && -n "${c_codigo:-}" ]]; then
    c_ok=1
    IFS='|' read -r c_ico c_desc <<<"$("$SCRIPTS/clima.sh" describir "$c_codigo" "${c_dia:-1}")"
    c_lugar=$(corta "${c_ciudad:-}" 30)
    [[ "${c_modo:-}" == auto ]] && c_lugar=$(corta "${c_ciudad:-}" 22)" (aprox.)"
  fi
fi

# ─────────── fondo (recortado al tamaño del panel; solo se rehace cuando cambias de fondo) ───────────
escala=${PANEL_ESCALA:-1}
fondo=$(cat "$HOME/.config/wallpapers/.actual" 2>/dev/null)
recorte="$DIR/fondo-panel.png"

hacer_recorte() {
  [[ -f "$fondo" ]] || return 1
  case "${fondo,,}" in *.png|*.jpg|*.jpeg) ;; *) return 1 ;; esac
  local ext=${fondo##*.}; local copia="$DIR/original.${ext,,}"
  rm -f "$DIR"/original.*; cp -f "$fondo" "$copia"     # librsvg solo lee imágenes de la misma carpeta
  cat > "$DIR/recorte.svg" <<EOR
<svg xmlns="http://www.w3.org/2000/svg" width="$W" height="$H" viewBox="0 0 $W $H">
  <image href="$(basename "$copia")" x="0" y="0" width="$W" height="$H" preserveAspectRatio="xMinYMid slice"/>
</svg>
EOR
  rsvg-convert -z "$escala" -o "$recorte.tmp" "$DIR/recorte.svg" && mv "$recorte.tmp" "$recorte" \
    && printf '%s|%s|%s' "$fondo" "$(stat -c %Y "$fondo")" "$escala" > "$DIR/.recorte"
  rm -f "$copia"
}

if [[ "${1:-}" == "fondo" ]]; then hacer_recorte; exit $?; fi

clave="$fondo|$(stat -c %Y "$fondo" 2>/dev/null)|$escala"
if [[ "$(cat "$DIR/.recorte" 2>/dev/null)" != "$clave" ]]; then
  if [[ -f "$recorte" ]]; then
    setsid -f "$0" fondo >/dev/null 2>&1      # se rehace en segundo plano; mientras, usa el anterior
  else
    hacer_recorte                              # primera vez: hay que esperarlo
  fi
fi
img_fondo=""
[[ -f "$recorte" ]] && img_fondo="<image href=\"fondo-panel.png\" x=\"0\" y=\"0\" width=\"$W\" height=\"$H\"/>"

# ─────────── dibujo ───────────
barra() {   # $1=y  $2=porcentaje  → barra de progreso
  local y=$1 p=$2 ancho=$((W - 76))
  (( p > 100 )) && p=100; (( p < 0 )) && p=0
  local lleno=$(( ancho * p / 100 )); (( lleno < 6 )) && lleno=6
  printf '<rect x="38" y="%s" width="%s" height="6" rx="3" fill="%s" fill-opacity="0.9"/>' "$y" "$ancho" "$F2"
  printf '<rect x="38" y="%s" width="%s" height="6" rx="3" fill="url(#grad)"/>' "$y" "$lleno"
}
fila() {    # $1=y  $2=icono  $3=nombre  $4=valor  $5=porcentaje
  printf '<text x="38" y="%s" class="ico">%s</text>' "$1" "$2"
  printf '<text x="60" y="%s" class="lbl">%s</text>' "$1" "$3"
  printf '<text x="%s" y="%s" class="val" text-anchor="end">%s</text>' "$((W - 38))" "$1" "$(esc "$4")"
  barra "$(( $1 + 9 ))" "$5"
}

filas=3; (( temp > 0 )) && filas=$((filas + 1))
alto_stats=$(( 40 + filas * 38 + 30 ))
y_stats=$(( H - 16 - alto_stats ))
y_clima=$(( y_stats - 12 - 92 ))
svg="$DIR/panel.svg"
png="$DIR/panel.png"

{
cat <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="$W" height="$H" viewBox="0 0 $W $H">
<defs>
  <linearGradient id="grad" x1="0" x2="1" y1="0" y2="0"><stop offset="0" stop-color="$A"/><stop offset="1" stop-color="$A2"/></linearGradient>
  <linearGradient id="velo" x1="0" x2="0" y1="0" y2="1">
    <stop offset="0" stop-color="$F" stop-opacity="0.55"/><stop offset="0.45" stop-color="$F" stop-opacity="0.25"/><stop offset="1" stop-color="$F" stop-opacity="0.6"/>
  </linearGradient>
  <linearGradient id="fallback" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="$A" stop-opacity="0.5"/><stop offset="1" stop-color="$A2" stop-opacity="0.5"/></linearGradient>
  <style>
    text { font-family: 'JetBrainsMono Nerd Font', 'JetBrains Mono', monospace; fill: $TEX; }
    .saludo { font-size: 15px; fill-opacity: 0.85; }
    .user   { font-size: 25px; font-weight: 800; }
    .hora   { font-size: 50px; font-weight: 800; letter-spacing: -1px; }
    .fecha  { font-size: 12.5px; fill: $TEX; fill-opacity: 0.75; }
    .tit    { font-size: 10.5px; font-weight: 700; fill: $A; letter-spacing: 1.5px; }
    .ico    { font-size: 14px; fill: $A; }
    .lbl    { font-size: 12px; fill-opacity: 0.8; }
    .val    { font-size: 12px; font-weight: 700; }
    .peq    { font-size: 11px; fill-opacity: 0.75; }
    .grande { font-size: 34px; font-weight: 800; }
    .wico   { font-size: 38px; fill: $A; }
    .acc    { font-size: 11px; fill: $A; font-weight: 700; }
  </style>
</defs>
<rect width="$W" height="$H" fill="$F"/>
<rect width="$W" height="$H" fill="url(#fallback)"/>
$img_fondo
<rect width="$W" height="$H" fill="url(#velo)"/>

<text x="24" y="42" class="saludo">$(esc "$saludo")</text>
<text x="24" y="72" class="user">$(esc "$usuario")</text>

<text x="22" y="140" class="hora">$hora</text>
<text x="24" y="164" class="fecha">$(esc "$fecha")</text>

<rect x="16" y="$y_clima" width="$((W - 32))" height="92" rx="16" fill="$F" fill-opacity="0.62" stroke="$A" stroke-opacity="0.25"/>
EOF

if ((c_ok)); then
cat <<EOF
<text x="32" y="$((y_clima + 50))" class="wico">$c_ico</text>
<text x="86" y="$((y_clima + 44))" class="grande">${c_temp}°</text>
<text x="$((W - 30))" y="$((y_clima + 28))" class="peq" text-anchor="end">↑ ${c_max}°  ↓ ${c_min}°</text>
<text x="$((W - 30))" y="$((y_clima + 46))" class="peq" text-anchor="end">$(printf '\ue373') ${c_humedad}%</text>
<text x="86" y="$((y_clima + 62))" class="lbl">$(esc "$(corta "$c_desc" 22)")</text>
<text x="32" y="$((y_clima + 80))" class="peq">$(printf '\U000f034e') $(esc "$c_lugar")</text>
EOF
else
cat <<EOF
<text x="32" y="$((y_clima + 50))" class="wico">$(printf '\ue312')</text>
<text x="86" y="$((y_clima + 40))" class="val">Clima no disponible</text>
<text x="86" y="$((y_clima + 58))" class="peq">Elige tu ciudad con</text>
<text x="86" y="$((y_clima + 74))" class="acc">Super + Shift + C</text>
EOF
fi

cat <<EOF
<rect x="16" y="$y_stats" width="$((W - 32))" height="$alto_stats" rx="16" fill="$F" fill-opacity="0.62" stroke="$A" stroke-opacity="0.25"/>
<text x="38" y="$((y_stats + 26))" class="tit">TU PC</text>
EOF
yy=$((y_stats + 52))
fila $yy $'\uf2db'      "CPU"   "${cpu}%" "$cpu";               yy=$((yy + 38))
fila $yy $'\U000f035b'  "RAM"   "$ram_txt" "$ram";              yy=$((yy + 38))
fila $yy $'\U000f02ca'  "Disco" "$disco_txt" "$disco";          yy=$((yy + 38))
if (( temp > 0 )); then
  fila $yy $'\U000f050f' "Temp" "${temp}°C" "$temp";            yy=$((yy + 38))
fi
yy=$((yy + 4))
if [[ -n "$bat" ]]; then
  [[ "$bat_estado" == Charging ]] && bico=$'\U000f0084' || bico=$'\U000f0079'
  printf '<text x="38" y="%s" class="ico">%s</text><text x="60" y="%s" class="lbl">%s%%</text>' "$yy" "$bico" "$yy" "$bat"
fi
printf '<text x="%s" y="%s" class="peq" text-anchor="end">%s encendida %s</text>' "$((W - 38))" "$yy" $'\U000f051b' "$(esc "$encendida")"
echo '</svg>'
} > "$svg"

rsvg-convert -z "$escala" -o "$png.tmp" "$svg" 2>/dev/null && mv "$png.tmp" "$png" && echo "$png"
