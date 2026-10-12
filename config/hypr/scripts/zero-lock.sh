#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  zero-lock — pantalla de bloqueo personalizable (Hyprland)       ║
# ║  5 estilos · menú en rofi · fondo, colores y elementos a tu gusto ║
# ╚══════════════════════════════════════════════════════════════════╝
#
#   zero-lock instalar [--si]   instala dependencias, el comando y los atajos
#   zero-lock                   abre el MENÚ de personalización
#   zero-lock lock              bloquea la pantalla (Super + L)
#   zero-lock preview           vista previa de 6 s (mueve el mouse y sales)
#   zero-lock estilo <nombre>   tarjetas | minimal | centrado | terminal | panel
#   zero-lock siguiente         cambia al siguiente estilo
#   zero-lock fondo <ruta|auto|captura|#rrggbb>
#   zero-lock set <clave> <valor>   ajuste directo (ver ~/.config/zero-lock/config)
#   zero-lock estado            muestra tu configuración actual
#   zero-lock diagnostico       revisa por qué no bloquea (hyprlock, atajos, hypridle, log)
#   zero-lock desinstalar       quita todo (no borra paquetes)
#
# Colores: sigue la paleta de zero-rice (Super+Shift+P) o usa una propia.

shopt -u patsub_replacement 2>/dev/null
VERSION="1.2.1"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
DIR="$CFG/zero-lock"
CONF="$DIR/config"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/zero-lock"
GEN="$CACHE/hyprlock.conf"
RICE_COL="$CFG/hypr/hyprlock-colores.conf"
SEGURO="$CACHE/seguro.conf"
LOG="$CACHE/zero-lock.log"
SRC=$(readlink -f "${BASH_SOURCE[0]}")
SELF=$SRC   # los labels de hyprlock llaman SIEMPRE a este mismo archivo (~/.local/bin/zero-lock es solo un enlace)
mkdir -p "$DIR" "$CACHE"
USER=${USER:-$(id -un)}
# los iconos necesitan una locale UTF-8 (hyprlock a veces corre sin LANG)
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) ;; *) unset LC_ALL; export LC_CTYPE=C.UTF-8 ;; esac

F="JetBrainsMono Nerd Font"
FB="JetBrainsMono Nerd Font ExtraBold"

# ───────────────────────────── iconos (Nerd Font) ─────────────────────────────
I_MOON=$'\U000f0594'; I_POWER=$'\U000f0425'; I_RESTART=$'\U000f0709'; I_LOGOUT=$'\U000f0343'
I_BAT=$'\U000f0079';  I_CHG=$'\U000f0084';   I_WIFI=$'\U000f05a9';    I_NOWIFI=$'\U000f05aa'
I_ETH=$'\U000f0200';  I_BT=$'\U000f00af';    I_NOBT=$'\U000f00b2';    I_BELL=$'\U000f009a'
I_NOBELL=$'\U000f009b'; I_MUSIC=$'\U000f0387'; I_CAPS=$'\U000f0632'
I_CLOCK=$'\U000f0150'; I_CAL=$'\U000f00ed';  I_ARCH=$'\uf303'
I_LOCK=$'\U000f033e'; I_IMG=$'\U000f02e9';   I_PAL=$'\U000f03d8';     I_USER=$'\U000f0004'
I_EYE=$'\U000f0208';  I_PLAY=$'\U000f040a';  I_RESET=$'\U000f099b';   I_TUNE=$'\U000f062e'
I_SUN=$'\U000f00df';  I_BACK=$'\U000f0141'

# ───────────────────────────── configuración ─────────────────────────────
ESTILOS=(tarjetas minimal centrado terminal panel)
declare -A ESTILO_DESC=(
  [tarjetas]="Islas de cristal: reloj grande, login, música y notificaciones"
  [minimal]="Reloj de puntos, fondo nítido y \"press any key\""
  [centrado]="Todo al centro: hora enorme, foto y campo redondo"
  [terminal]="Una terminal flotante con tus datos y un prompt de sudo"
  [panel]="Panel lateral completo y tu fondo libre a la derecha"
)
declare -A EST_BLUR=([tarjetas]=4 [minimal]=0 [centrado]=3 [terminal]=2 [panel]=2)
declare -A EST_BRI=([tarjetas]=55 [minimal]=75 [centrado]=60 [terminal]=45 [panel]=70)

ESQUEMAS=(tokyo catppuccin rosepine nord sakura neon gruvbox latte)
declare -A ESQ_NOM=([rice]="Paleta del rice (zero-rice)" [tokyo]="Tokyo Night" [catppuccin]="Catppuccin Mocha"
  [rosepine]="Rosé Pine" [nord]="Nord" [sakura]="Sakura" [neon]="Neón" [gruvbox]="Gruvbox" [latte]="Catppuccin Latte (claro)")
#            bg     surface fg     dim    ac1    ac2    on-ac  error
declare -A ESQ=(
  [tokyo]="1a1b26 24283b c0caf5 737aa2 7aa2f7 bb9af7 16161e f7768e"
  [catppuccin]="1e1e2e 313244 cdd6f4 7f849c cba6f7 89b4fa 11111b f38ba8"
  [rosepine]="191724 26233a e0def4 908caa ebbcba c4a7e7 191724 eb6f92"
  [nord]="2e3440 3b4252 eceff4 8590a6 88c0d0 5e81ac 2e3440 bf616a"
  [sakura]="1f1720 33242f fbe9f0 b08ba0 ffb7c5 f78fb3 1f1720 ff6b81"
  [neon]="0b0b12 1a1a28 e6e6f0 8a8aa3 22d3ee ec4899 0b0b12 f87171"
  [gruvbox]="282828 3c3836 ebdbb2 a89984 fabd2f fe8019 282828 fb4934"
  [latte]="eff1f5 ccd0da 4c4f69 7c7f93 8839ef 1e66f5 eff1f5 d20f39"
)

defaults() {
  estilo=tarjetas; fondo=auto; blur=auto; brillo=auto; escala=auto; reloj=24; esquema=rice; foto=""
  mostrar_clima=1; mostrar_musica=1; mostrar_notis=1; mostrar_estado=1; mostrar_botones=1
}
cargar() {
  defaults
  # shellcheck disable=SC1090
  [[ -f $CONF ]] && source "$CONF"
  [[ $esquema == rice && ! -f $RICE_COL ]] && esquema=tokyo
  [[ -n ${ESQ[$esquema]:-} || $esquema == rice ]] || esquema=tokyo
  [[ " ${ESTILOS[*]} " == *" $estilo "* ]] || estilo=tarjetas
  return 0
}
guardar() {   # clave valor
  local t; t=$(grep -v "^$1=" "$CONF" 2>/dev/null)
  { [[ -n $t ]] && printf '%s\n' "$t"; printf '%s=%q\n' "$1" "$2"; } > "$CONF.tmp" && mv "$CONF.tmp" "$CONF"
}
notificar() { command -v notify-send >/dev/null 2>&1 && notify-send -a "Bloqueo" "$@"; return 0; }
# Nada de lo que se consulta puede trabar el bloqueo: todo con tiempo límite.
# (bluetoothctl, por ejemplo, se queda esperando PARA SIEMPRE si el servicio bluetooth está apagado)
t() { local s=${T:-2}; if command -v timeout >/dev/null 2>&1; then timeout -k 1 "$s" "$@"; else "$@"; fi; }
log() { printf '%s  %s\n' "$(date '+%F %T')" "$*" >> "$LOG" 2>/dev/null; return 0; }
recortar_log() { [[ -f $LOG ]] && (( $(wc -l < "$LOG") > 400 )) && { tail -n 200 "$LOG" > "$LOG.tmp" && mv -f "$LOG.tmp" "$LOG"; }; return 0; }
HOST=${HOSTNAME:-$(cat /etc/hostname 2>/dev/null)}; HOST=${HOST:-$(uname -n)}   # Arch no trae el comando hostname
esc() { local s=$1; s=${s//&/&amp;}; s=${s//</&lt;}; s=${s//>/&gt;}; printf '%s' "$s"; }

# ───────────────────────────── colores ─────────────────────────────
emitir_colores() {
  local blanco=$'$zl_w  = rgba(f6f6fbff)\n$zl_wd = rgba(f6f6fbc4)\n'
  if [[ $esquema == rice ]]; then printf 'source = %s\n%s\n' "$RICE_COL" "$blanco"; return; fi
  local bg sf fg dim a1 a2 on er
  read -r bg sf fg dim a1 a2 on er <<<"${ESQ[$esquema]}"
  cat <<EOF
\$zl_bg  = rgba(${bg}e0)
\$zl_sf  = rgba(${sf}ff)
\$zl_fg  = rgba(${fg}ff)
\$zl_dim = rgba(${dim}ff)
\$zl_ac1 = rgba(${a1}ff)
\$zl_ac2 = rgba(${a2}ff)
\$zl_on  = rgba(${on}ff)
\$zl_err = rgba(${er}ff)
\$zl_w  = rgba(f6f6fbff)
\$zl_wd = rgba(f6f6fbc4)

EOF
}
col_hex() {   # bg|sf|fg|dim|ac1|ac2|on|err  → rrggbb
  if [[ $esquema == rice ]]; then
    sed -n "s/^\$zl_$1 *= *rgba(\([0-9a-fA-F]\{6\}\).*/\1/p" "$RICE_COL" | head -1
  else
    local a; read -ra a <<<"${ESQ[$esquema]}"
    case $1 in bg) echo "${a[0]}";; sf) echo "${a[1]}";; fg) echo "${a[2]}";; dim) echo "${a[3]}";;
               ac1) echo "${a[4]}";; ac2) echo "${a[5]}";; on) echo "${a[6]}";; err) echo "${a[7]}";; esac
  fi
}

# ───────────────────────────── datos en vivo (los llama hyprlock) ─────────────────────────────
# Todos reciben un máximo de caracteres (N) para que el texto nunca se salga de su recuadro.
PIXEL='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='

corto() { local s=$1 n=$2; (( n < 2 )) && n=2; (( ${#s} > n )) && s="${s:0:n-1}…"; printf '%s' "$s"; }

wx() {   # codigo dia → "icono|descripción"
  local i d
  case "$1" in
    0)            i=$'\U000f0599'; d="Despejado"; [[ ${2:-1} == 0 ]] && i=$'\U000f0594' ;;
    1|2)          i=$'\U000f0595'; d="Algo nublado" ;;
    3)            i=$'\U000f0590'; d="Nublado" ;;
    45|48)        i=$'\U000f0591'; d="Niebla" ;;
    5[1-7]|6[1-7]|8[0-2]) i=$'\U000f0597'; d="Lluvia" ;;
    7[1-7]|8[56]) i=$'\U000f0598'; d="Nieve" ;;
    9[5-9])       i=$'\U000f0593'; d="Tormenta" ;;
    *)            i=$'\U000f0590'; d="—" ;;
  esac
  printf '%s|%s' "$i" "$d"
}
fetch_clima() {
  local f="$CACHE/clima" t="$CACHE/clima.try" j lat lon c
  [[ -f $f && $(( $(date +%s) - $(stat -c %Y "$f") )) -lt 1800 ]] && return 0
  [[ -f $t && $(( $(date +%s) - $(stat -c %Y "$t") )) -lt 120 ]] && return 0
  touch "$t"
  command -v curl >/dev/null && command -v jq >/dev/null || return 0
  j=$(curl -fsS --max-time 5 'http://ip-api.com/json/?fields=status,city,lat,lon') || return 0
  lat=$(jq -r .lat <<<"$j"); lon=$(jq -r .lon <<<"$j"); c=$(jq -r .city <<<"$j")
  j=$(curl -fsS --max-time 6 -G 'https://api.open-meteo.com/v1/forecast' -d "latitude=$lat" -d "longitude=$lon" \
      -d 'current=temperature_2m,weather_code,is_day' -d 'timezone=auto') || return 0
  jq -r --arg c "$c" '"ciudad=\($c)","temp=\(.current.temperature_2m|round)","codigo=\(.current.weather_code)","dia=\(.current.is_day)"' \
    <<<"$j" > "$f.tmp" && mv "$f.tmp" "$f"
}
clima_texto() {   # [N] usa primero el clima de zero-rice; si no, el propio
  local N=${1:-44} A="${XDG_CACHE_HOME:-$HOME/.cache}/zero-rice/clima/actual" ciudad="" temp="" codigo="" dia=1 k v r
  [[ -f $A ]] || { A="$CACHE/clima"; ( fetch_clima >/dev/null 2>&1 & ); }
  [[ -f $A ]] || return 0
  while IFS='=' read -r k v; do [[ $k =~ ^[a-z]+$ ]] && printf -v "$k" '%s' "$v"; done < "$A"
  [[ -n $temp ]] || return 0
  r=$(wx "$codigo" "$dia")
  esc "${r%%|*}  $(corto "${temp}°  ·  ${r#*|}  ·  ${ciudad%%,*}" $((N - 4)))"
}
cmd_clima() {
  local A="${XDG_CACHE_HOME:-$HOME/.cache}/zero-rice/clima/actual"
  [[ -f $A ]] || fetch_clima
  clima_texto "$@"
}
cmd_estado() {   # [N]
  local N=${1:-60} o="" b st w
  for b in /sys/class/power_supply/BAT*; do
    [[ -r $b/capacity ]] || continue
    st=$(<"$b/status"); [[ $st == Charging ]] && o="$I_CHG" || o="$I_BAT"
    o+=" $(<"$b/capacity")%"; break
  done
  [[ -n $o ]] || o="$I_BAT AC"
  w=$(T=2 t nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}')
  local sw=$(( N - 34 )); (( sw < 6 )) && sw=6; (( sw > 18 )) && sw=18
  if [[ -n $w ]]; then o+="   $I_WIFI $(esc "$(corto "$w" "$sw")")"
  elif T=2 t nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -q '^ethernet:connected'; then o+="   $I_ETH Cable"
  else o+="   $I_NOWIFI Sin red"; fi
  # Bluetooth: solo si hay adaptador. Sin el servicio corriendo no se le pregunta nada (bluetoothctl se colgaría).
  if compgen -G '/sys/class/bluetooth/hci*' >/dev/null; then
    if command -v bluetoothctl >/dev/null 2>&1 && systemctl is-active --quiet bluetooth 2>/dev/null \
       && T=1 t bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then o+="   $I_BT Bluetooth"
    else o+="   $I_NOBT Bluetooth"; fi
  fi
  printf '%s' "$o"
}
cmd_musica() {   # titulo|artista|linea [N]
  local N=${2:-30} ti a
  command -v playerctl >/dev/null 2>&1 || { [[ $1 == titulo ]] && echo "Sin música"; return 0; }
  ti=$(T=1 t playerctl metadata title 2>/dev/null); a=$(T=1 t playerctl metadata artist 2>/dev/null)
  case "$1" in
    titulo)  esc "$(corto "${ti:-Nada sonando}" "$N")" ;;
    artista) esc "$(corto "$a" "$N")" ;;
    linea)   [[ -n $ti ]] && esc "$I_MUSIC  $(corto "$ti${a:+  —  $a}" $((N - 3)))" ;;
  esac
}
cmd_portada() {
  local u tmp="$CACHE/portada.tmp" sig ext
  command -v playerctl >/dev/null 2>&1 && u=$(T=1 t playerctl metadata mpris:artUrl 2>/dev/null)
  rm -f "$tmp"
  case "$u" in
    file://*) u=${u#file://}; u=${u//%20/ }; cp -f "$u" "$tmp" 2>/dev/null ;;
    http*)    curl -fsS --max-time 3 -o "$tmp" "$u" 2>/dev/null ;;
  esac
  if [[ -s $tmp ]]; then
    sig=$(od -An -tx1 -N3 "$tmp" | tr -d ' \n'); [[ $sig == ffd8ff ]] && ext=jpg || ext=png
    rm -f "$CACHE"/portada.png "$CACHE"/portada.jpg; mv "$tmp" "$CACHE/portada.$ext"
  elif [[ ! -f $CACHE/portada.png && ! -f $CACHE/portada.jpg ]]; then
    printf '%s' "$PIXEL" | base64 -d > "$CACHE/portada.png"
  fi
  [[ -f $CACHE/portada.jpg ]] && echo "$CACHE/portada.jpg" || echo "$CACHE/portada.png"
}
portada_rapida() {   # para generar la config: nunca espera a internet; la portada nueva llega sola (reload_cmd)
  ( setsid -f bash "$SRC" _portada >/dev/null 2>&1 & ) 2>/dev/null
  if [[ -f $CACHE/portada.jpg ]]; then echo "$CACHE/portada.jpg"
  else [[ -f $CACHE/portada.png ]] || printf '%s' "$PIXEL" | base64 -d > "$CACHE/portada.png"; echo "$CACHE/portada.png"; fi
}
cmd_notis() {
  local n; n=$(T=1 t swaync-client -c 2>/dev/null)
  if [[ $n =~ ^[0-9]+$ && $n -gt 0 ]]; then printf '%s   Tienes %s sin leer' "$I_BELL" "$n"
  else printf '%s   Estás al día' "$I_NOBELL"; fi
}
cmd_teclado() {
  local f; for f in /sys/class/leds/*capslock/brightness; do
    [[ -r $f && $(<"$f") == 1 ]] && { printf '%s  Bloq Mayús activado' "$I_CAPS"; return 0; }
  done
}
cmd_saludo() {   # [N]
  local h s; h=$((10#$(date +%H)))
  if (( h < 6 )); then s="Buenas noches"; elif (( h < 13 )); then s="Buenos días"
  elif (( h < 20 )); then s="Buenas tardes"; else s="Buenas noches"; fi
  esc "$(corto "$s, $USER" "${1:-40}")"
}
cmd_terminal() {   # [N]  bloque multilínea con colores (markup) para el estilo "terminal"
  cargar
  local N=${1:-46} a b d fmt host c w m k
  a=$(col_hex ac1); b=$(col_hex ac2); d=$(col_hex dim)
  host=$HOST
  fmt='%H:%M:%S'; [[ $reloj == 12 ]] && fmt='%I:%M:%S %p'
  c() { printf '<span foreground="#%s">%s</span>' "$1" "$2"; }
  printf '%s%s%s  %s\n' "$(c "$a" "<b>$(esc "$(corto "$USER" 14)")</b>")" "$(c "$d" "@")" "$(c "$b" "<b>$(esc "$(corto "$host" 14)")</b>")" "$(c "$d" "· bloqueado")"
  printf '%s\n' "$(c "$d" "$(printf '─%.0s' $(seq 1 $(( N < 38 ? N : 38 ))))")"
  printf '%s  %s\n' "$(c "$a" "$I_CLOCK")" "$(date +"$fmt")"
  printf '%s  %s\n' "$(c "$a" "$I_CAL")" "$(date +'%A, %-d %B')"
  printf '%s\n' "$(cmd_estado "$N")"
  w=$(clima_texto "$N"); m=$(cmd_musica linea "$N"); k=$(cmd_teclado)
  [[ -n $w ]] && printf '%s\n' "$w"
  [[ -n $m ]] && printf '%s\n' "$m"
  [[ -n $k ]] && printf '%s\n' "$(c "$b" "$k")"
  return 0
}

# ───────────────────────────── generador de hyprlock.conf ─────────────────────────────
# Todo se diseña en un lienzo de 1920×1080 y se escala solo a tu pantalla (opción «Tamaño»).
# Medidas reales de la fuente: 1 pt = 4/3 px · cada caracter mide 0.6 em · cada línea 1.32 em.
prep() {
  local s Wr=1920 Hr=1080 sw sh
  if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    s=$(T=2 t hyprctl monitors -j 2>/dev/null | jq -r '(map(select(.focused))[0] // .[0]) | "\((.width/.scale)|floor) \((.height/.scale)|floor)"' 2>/dev/null)
    [[ $s =~ ^[0-9]+\ [0-9]+$ ]] && read -r Wr Hr <<<"$s"
  fi
  [[ ${ZL_TAM:-} =~ ^[0-9]+\ [0-9]+$ ]] && read -r Wr Hr <<<"$ZL_TAM"   # para probar otras pantallas: ZL_TAM="1366 768"
  sw=$((Wr * 100 / 1920)); sh=$((Hr * 100 / 1080)); S=$(( sw < sh ? sw : sh ))
  [[ $escala =~ ^[0-9]+$ ]] && S=$escala
  (( S < 50 )) && S=50; (( S > 220 )) && S=220
  VW=$((Wr * 100 / S)); VH=$((Hr * 100 / S))      # tamaño del lienzo virtual
  if [[ $reloj == 12 ]]; then fH='%I'; fHM='%I:%M'; else fH='%H'; fHM='%H:%M'; fi
  USUARIO=$(id -un)
  case "$foto" in ""|rice) FOTO="$HOME/.face" ;; none) FOTO="" ;; *) FOTO="$foto" ;; esac
  [[ -n $FOTO && ! -f $FOTO ]] && FOTO=""
  PORTADA=$(portada_rapida)
  WH='$zl_w'; WD='$zl_wd'; ACB=$(acento_visible)
  SOMBRA=$'    shadow_passes = 2\n    shadow_size = 3\n    shadow_color = rgba(000000b0)\n'
}
sc() { local v=$1; if (( v < 0 )); then echo $(( (v * S - 50) / 100 )); else echo $(( (v * S + 50) / 100 )); fi; }
rr() { [[ $1 == -1 ]] && echo -1 || sc "$1"; }
nmax() { echo $(( $1 * 10 / (8 * $2) )); }       # caracteres que caben en PX píxeles a tamaño SIZE
acento_visible() {   # el acento sobre el fondo oscurecido: si es muy oscuro, usa blanco
  local h r g b; h=$(col_hex ac1); [[ ${#h} == 6 ]] || { echo '$zl_ac1'; return; }
  r=$((16#${h:0:2})); g=$((16#${h:2:2})); b=$((16#${h:4:2}))
  (( (r * 299 + g * 587 + b * 114) / 1000 >= 120 )) && echo '$zl_ac1' || echo '$zl_w'
}

lbl() {   # texto tamaño fuente color x y halign valign [extra]
  printf 'label {\n    monitor =\n    text = %s\n    font_size = %s\n    font_family = %s\n    color = %s\n    position = %s, %s\n    halign = %s\n    valign = %s\n%s}\n\n' \
    "$1" "$(sc "$2")" "$3" "$4" "$(sc "$5")" "$(sc "$6")" "$7" "$8" "${9:-}"
}
shp() {   # ancho alto color radio x y halign valign [extra]
  printf 'shape {\n    monitor =\n    size = %s, %s\n    color = %s\n    rounding = %s\n    position = %s, %s\n    halign = %s\n    valign = %s\n%s}\n\n' \
    "$(sc "$1")" "$(sc "$2")" "$3" "$(rr "$4")" "$(sc "$5")" "$(sc "$6")" "$7" "$8" "${9:-}"
}
img() {   # ruta tamaño radio x y halign valign borde [extra]
  printf 'image {\n    monitor =\n    path = %s\n    size = %s\n    rounding = %s\n    border_size = %s\n    border_color = $zl_ac1\n    position = %s, %s\n    halign = %s\n    valign = %s\n%s}\n\n' \
    "$1" "$(sc "$2")" "$(rr "$3")" "$(sc "$8")" "$(sc "$4")" "$(sc "$5")" "$6" "$7" "${9:-}"
}
inp() {   # ancho alto x y halign valign texto radio contorno color-interior
  local dim; dim=$(col_hex dim)
  printf 'input-field {\n    monitor =\n    size = %s, %s\n    position = %s, %s\n    halign = %s\n    valign = %s\n    outline_thickness = %s\n    outer_color = $zl_ac1\n    inner_color = %s\n    font_color = $zl_fg\n    dots_size = 0.28\n    dots_spacing = 0.3\n    dots_center = true\n    dots_rounding = -1\n    rounding = %s\n    fade_on_empty = false\n    placeholder_text = <span foreground="##%s">%s</span>\n    hide_input = false\n    check_color = $zl_ac2\n    fail_color = $zl_err\n    fail_text = <i>$FAIL ($ATTEMPTS)</i>\n    capslock_color = $zl_ac2\n}\n\n' \
    "$(sc "$1")" "$(sc "$2")" "$(sc "$3")" "$(sc "$4")" "$5" "$6" "$(sc "$9")" "${10:-\$zl_sf}" "$(rr "$8")" "$dim" "$7"
}

grace_por_cli() {   # hyprlock nuevo: --grace N (general:grace ya no existe) · viejo: grace = N en la config
  [[ -n ${_GRACE_CLI:-} ]] || { hyprlock --help 2>&1 | grep -q -- '--grace' && _GRACE_CLI=1 || _GRACE_CLI=0; }
  [[ $_GRACE_CLI == 1 ]]
}
emitir_cabecera() {
  local g=""
  [[ ${1:-0} != 0 ]] && ! grace_por_cli && g="    grace = $1"$'\n'
  cat <<EOF
# Generado por zero-lock $VERSION — no lo edites a mano (usa: zero-lock)
general {
    hide_cursor = true
    ignore_empty_input = true
${g}}

animations {
    enabled = true
    bezier = out, 0.16, 1, 0.3, 1
    animation = fadeIn, 1, 4, out
    animation = fadeOut, 1, 3, out
    animation = inputFieldDots, 1, 2, out
}

EOF
}
# hyprlock solo lee png/jpg (y webp en versiones nuevas): gif, webp animado, avif, etc. se convierten a png
# (solo la primera vez: se reusa mientras la imagen no cambie)
fondo_compatible() {   # ruta → ruta que hyprlock puede abrir, o "screenshot"
  local a=$1 out="$CACHE/fondo.png" firma
  [[ -f $a ]] || { echo screenshot; return; }
  case "${a,,}" in *.png|*.jpg|*.jpeg) echo "$a"; return ;; esac
  firma="$a|$(stat -c %Y "$a" 2>/dev/null)"
  if [[ -s $out && $(cat "$out.de" 2>/dev/null) == "$firma" ]]; then echo "$out"; return; fi
  if   command -v magick  >/dev/null 2>&1 && T=4 t magick  "${a}[0]" "$out" 2>/dev/null; then printf '%s' "$firma" > "$out.de"; echo "$out"
  elif command -v convert >/dev/null 2>&1 && T=4 t convert "${a}[0]" "$out" 2>/dev/null; then printf '%s' "$firma" > "$out.de"; echo "$out"
  elif [[ ${a,,} == *.webp ]]; then echo "$a"
  else log "fondo $a: formato que hyprlock no lee y no hay imagemagick → uso captura"; echo screenshot; fi
}
ruta_fondo() {
  local a="" w
  case $fondo in
    auto)
      # el que se muestra AHORA (awww/swww); si no se puede, el último que puso el rice
      for w in awww swww; do
        command -v "$w" >/dev/null 2>&1 || continue
        a=$(T=2 t "$w" query 2>/dev/null | sed -n 's/.*image: //p' | head -1); [[ -f $a ]] && break; a=""
      done
      [[ -f $a ]] || { [[ -f $CFG/wallpapers/.actual ]] && a=$(<"$CFG/wallpapers/.actual"); }
      fondo_compatible "$a" ;;
    captura) echo screenshot ;;
    solido:*) echo "color:${fondo#solido:}" ;;
    *) fondo_compatible "$fondo" ;;
  esac
}
emitir_fondo() {
  local r b br; r=$(ruta_fondo)
  b=$blur;   [[ $b  == auto ]] && b=${EST_BLUR[$estilo]}
  br=$brillo; [[ $br == auto ]] && br=${EST_BRI[$estilo]}
  printf 'background {\n    monitor =\n'
  if [[ $r == color:* ]]; then printf '    color = rgba(%sff)\n' "${r#color:#}"; else printf '    path = %s\n' "$r"; fi
  printf '    blur_passes = %s\n    blur_size = 6\n    noise = 0.015\n    brightness = %s\n    vibrancy = 0.2\n}\n\n' \
    "$b" "$(awk "BEGIN{printf \"%.2f\", $br/100}")"
}

# ── piezas reutilizables (respetan los interruptores de «Elementos») ──
el_clima() { local n=$1; shift; [[ $mostrar_clima == 1 ]] && lbl "cmd[update:300000] $SELF _clima $n" "$@"; return 0; }
el_notis() { [[ $mostrar_notis == 1 ]] && lbl "cmd[update:4000] $SELF _notis" "$@"; return 0; }
el_musica_linea() { local n=$1; shift; [[ $mostrar_musica == 1 ]] && lbl "cmd[update:2000] $SELF _musica linea $n" "$@"; return 0; }
el_avatar() { [[ -n $FOTO ]] && img "$FOTO" "$1" -1 "$2" "$3" "$4" "$5" 3; return 0; }
el_estado() {   # x y halign valign [sin-pastilla]
  [[ $mostrar_estado == 1 ]] || return 0
  local t n w lx dy=0
  if [[ ${5:-} == sin-pastilla ]]; then
    lbl "cmd[update:5000] $SELF _estado 48" 12 "$F" "$WH" "$1" "$2" "$3" "$4" "$SOMBRA"; return 0
  fi
  t=$(cmd_estado 60); n=$(wc -m <<<"$t"); n=$((n - 1)); w=$(( (n + 4) * 96 / 10 + 44 ))   # +4: los iconos miden más de una celda
  shp "$w" 40 '$zl_bg' 20 "$1" "$2" "$3" "$4"
  case $3 in right) lx=$(($1 - 22)) ;; left) lx=$(($1 + 22)) ;; *) lx=$1 ;; esac
  case $4 in top) dy=-10 ;; bottom) dy=10 ;; esac
  lbl "cmd[update:5000] $SELF _estado 60" 12 "$F" '$zl_fg' "$lx" "$(($2 + dy))" "$3" "$4"
}
el_botones_barra() {   # barra de iconos abajo a la izquierda (decorativa)
  [[ $mostrar_botones == 1 ]] || return 0
  local i ic=("$I_MOON" "$I_LOGOUT" "$I_RESTART" "$I_POWER") col
  shp 236 54 '$zl_bg' 27 80 50 left bottom
  for i in 0 1 2 3; do
    col='$zl_dim'; [[ $i == 3 ]] && col='$zl_err'
    lbl "${ic[$i]}" 17 "$F" "$col" "$((98 + i * 59))" 65 left bottom
  done
}

# ───────────────────────────── estilos ─────────────────────────────
estilo_tarjetas() {
  local CCX=$((VW / 2 - 260)) TX=$((VW - 350)) ex
  # reloj (izquierda)
  lbl "cmd[update:1000] date +\"$fH\"" 150 "$FB" "$WH" 80 100 left center "$SOMBRA"
  lbl 'cmd[update:1000] date +"%M"' 150 "$FB" "$ACB" 80 -80 left center "$SOMBRA"
  [[ $reloj == 12 ]] && lbl 'cmd[update:1000] date +"%p"' 22 "$F" "$WD" 345 -110 left center "$SOMBRA"
  lbl 'cmd[update:60000] date +"%A, %-d %B"' 17 "$F" "$WD" 84 -200 left center "$SOMBRA"
  lbl "cmd[update:60000] $SELF _saludo 34" 13 "$F" "$WD" 84 -232 left center "$SOMBRA"
  el_clima 44 18 "$F" "$WH" 80 -60 left top "$SOMBRA"
  el_estado -60 -50 right top
  # tarjeta de login  (400×270 · centro y=136)
  shp 400 270 '$zl_bg' 28 -60 136 right center
  el_avatar 84 "$CCX" 211 center center
  lbl '$USER' 17 "$F" '$zl_fg' "$CCX" 144 center center
  lbl "cmd[update:500] $SELF _teclado" 11 "$F" '$zl_dim' "$CCX" 106 center center
  inp 340 52 "$CCX" 55 center center "  Contraseña" 26 0
  # música (400×112 · centro y=-71)
  if [[ $mostrar_musica == 1 ]]; then
    shp 400 112 '$zl_bg' 24 -60 -71 right center
    ex=$'    reload_time = 3\n    reload_cmd = '"$SELF _portada"$'\n'
    img "$PORTADA" 74 14 "$((VW - 440))" -71 left center 0 "$ex"
    lbl "cmd[update:2000] $SELF _musica titulo 24" 13 "$FB" '$zl_fg' "$TX" -55 left center
    lbl "cmd[update:2000] $SELF _musica artista 28" 11 "$F" '$zl_dim' "$TX" -83 left center
  fi
  # notificaciones (400×128 · centro y=-207)
  if [[ $mostrar_notis == 1 ]]; then
    shp 400 128 '$zl_bg' 24 -60 -207 right center
    lbl 'Notificaciones' 12 "$FB" '$zl_fg' "$((VW - 436))" -177 left center
    lbl "cmd[update:4000] $SELF _notis" 12 "$F" '$zl_dim' "$CCX" -220 center center
  fi
  el_botones_barra
}

estilo_minimal() {
  local DOT="$FB" i x bg fg ps ic=("$I_MOON" "$I_RESTART" "$I_POWER")
  ps=$(sc 9); (( ps < 6 )) && ps=6
  fc-list 2>/dev/null | grep -qi 'dotgothic16' && DOT="DotGothic16"
  lbl "cmd[update:1000] date +\"$fHM\"" 96 "$DOT" "$WH" 60 -40 left top "$SOMBRA"
  lbl 'cmd[update:60000] date +"%a, %d %b" | tr a-z A-Z' 18 "$DOT" "$WH" 64 -200 left top "$SOMBRA"
  lbl "$I_ARCH  $(esc "$USUARIO")@$(esc "$(corto "$HOST" 18)")" 13 "$F" "$WD" 66 -234 left top "$SOMBRA"
  el_clima 40 14 "$F" "$WD" 66 -262 left top "$SOMBRA"
  inp 300 46 0 40 center bottom "<span font_size=\"${ps}pt\">PRESS ANY KEY TO UNLOCK</span>" 23 0 '$zl_bg'
  el_musica_linea 56 12 "$F" "$WD" 0 105 center bottom "$SOMBRA"
  if [[ $mostrar_botones == 1 ]]; then
    for i in 0 1 2; do
      x=$((-50 - (2 - i) * 50)); bg='$zl_bg'; fg='$zl_fg'; [[ $i == 2 ]] && { bg='$zl_err'; fg='$zl_w'; }
      shp 42 42 "$bg" -1 "$x" 40 right bottom
      lbl "${ic[$i]}" 15 "$F" "$fg" "$((VW + x - 31))" 48 left bottom
    done
  fi
  el_estado -50 105 right bottom sin-pastilla
}

estilo_centrado() {
  el_clima 50 16 "$F" "$WD" 0 -40 center top "$SOMBRA"
  lbl "cmd[update:1000] date +\"$fHM\"" 170 "$FB" "$WH" 0 150 center center "$SOMBRA"
  lbl 'cmd[update:60000] date +"%A, %-d %B"' 20 "$F" "$ACB" 0 10 center center "$SOMBRA"
  el_avatar 96 0 -70 center center
  lbl '$USER' 16 "$F" "$WH" 0 -150 center center "$SOMBRA"
  inp 340 54 0 -215 center center "  Contraseña" 27 0 '$zl_bg'
  lbl "cmd[update:500] $SELF _teclado" 11 "$F" "$WD" 0 -262 center center "$SOMBRA"
  el_musica_linea 60 13 "$F" "$WD" 0 -300 center center "$SOMBRA"
  el_notis 12 "$F" "$WD" 0 -335 center center "$SOMBRA"
  el_estado 0 30 center bottom
}

estilo_terminal() {
  local borde=$'    border_size = 2\n    border_color = $zl_ac1\n'
  lbl "cmd[update:1000] date +\"$fHM\"" 90 "$FB" "$ACB" 80 270 left center "$SOMBRA"
  shp 600 230 '$zl_bg' 12 80 60 left center "$borde"
  lbl "cmd[update:1000] $SELF _terminal 46" 14 "$F" '$zl_fg' 106 60 left center $'    text_align = left\n'
  inp 600 50 80 -95 left center "[sudo] contraseña para $(esc "$USUARIO"):" 10 2 '$zl_bg'
  el_botones_barra
}

estilo_panel() {
  local PX=$((235 - VW / 2))
  shp 510 "$((VH + 200))" '$zl_bg' 40 -40 0 left center
  el_avatar 110 "$PX" -70 center top
  lbl '$USER' 20 "$FB" '$zl_fg' "$PX" -198 center top
  lbl "cmd[update:60000] $SELF _saludo 34" 13 "$F" '$zl_dim' "$PX" -238 center top
  lbl "cmd[update:1000] date +\"$fHM\"" 92 "$FB" '$zl_ac1' "$PX" 95 center center
  lbl 'cmd[update:60000] date +"%A, %-d %B"' 16 "$F" '$zl_fg' "$PX" 10 center center
  el_clima 34 14 "$F" '$zl_dim' "$PX" -22 center center
  el_musica_linea 38 13 "$F" '$zl_fg' "$PX" -75 center center
  el_notis 12 "$F" '$zl_dim' "$PX" -110 center center
  lbl "cmd[update:500] $SELF _teclado" 11 "$F" '$zl_dim' "$PX" 190 center bottom
  inp 380 52 "$PX" 130 center bottom "  Contraseña" 26 0
  if [[ $mostrar_estado == 1 ]]; then lbl "cmd[update:5000] $SELF _estado 40" 12 "$F" '$zl_fg' "$PX" 80 center bottom; fi
  [[ $mostrar_botones == 1 ]] && lbl "$I_MOON    $I_LOGOUT    $I_RESTART    $I_POWER" 18 "$F" '$zl_dim' "$PX" 30 center bottom
  return 0
}

generar() {   # [grace]
  cargar; prep
  { emitir_cabecera "${1:-0}"; emitir_colores; emitir_fondo; "estilo_$estilo"; } > "$GEN.tmp" && mv "$GEN.tmp" "$GEN"
}

# ───────────────────────────── menú ─────────────────────────────
ROFI_TEMA="$CFG/rofi/themes/zero.rasi"
MSG=""
usa_rofi() { command -v rofi >/dev/null 2>&1 && [[ -z ${ZL_TTY:-} && -n ${WAYLAND_DISPLAY:-}${DISPLAY:-} ]]; }

pick_i() {   # prompt items… → índice (vacío si cancelas)
  local p=$1; shift; local l=$#; (( l > 12 )) && l=12
  if usa_rofi; then
    local th=(); [[ -f $ROFI_TEMA ]] && th=(-theme "$ROFI_TEMA")
    printf '%s\n' "$@" | rofi -dmenu -i -format i -p "$p" "${th[@]}" ${MSG:+-mesg "$MSG"} \
      -theme-str "window { width: 620px; } listview { lines: $l; }"
  else
    local x PS3="$p › "
    select x in "$@"; do [[ -n $x ]] && { echo $((REPLY - 1)); break; }; done
  fi
}
pick() { local i p=$1; i=$(pick_i "$@"); [[ $i =~ ^[0-9]+$ ]] || return 1; shift; local a=("$@"); printf '%s' "${a[$i]}"; }
ask() {   # prompt → texto
  if usa_rofi; then
    local th=(); [[ -f $ROFI_TEMA ]] && th=(-theme "$ROFI_TEMA")
    : | rofi -dmenu -p "$1" "${th[@]}" -theme-str 'window { width: 620px; } listview { lines: 0; }'
  else local r; read -rp "$1: " r; printf '%s' "$r"; fi
}

carpeta_inicial() { local d; for d in "$CFG/wallpapers" "$HOME/Pictures/Wallpapers" "$HOME/Pictures" "$HOME/Imágenes" "$HOME"; do [[ -d $d ]] && { printf '%s' "$d"; return; }; done; }

# Explorador de archivos con VISTA PREVIA de la imagen (yad → kdialog → zenity → ruta escrita)
elegir_archivo() {   # título [carpeta] → ruta
  local t=${1:-Elige una imagen} ini=${2:-} f=""
  [[ -d $ini ]] || ini=$(carpeta_inicial)
  if command -v yad >/dev/null 2>&1; then
    f=$(yad --file --title="$t" --filename="$ini/" --width=1000 --height=650 --center \
        --file-filter='Imágenes | *.png *.jpg *.jpeg *.webp *.PNG *.JPG *.JPEG *.WEBP' \
        --add-preview 2>/dev/null)
  elif command -v kdialog >/dev/null 2>&1; then
    f=$(kdialog --title "$t" --getopenfilename "$ini" 'image/png image/jpeg image/webp|Imágenes' 2>/dev/null)
  elif command -v zenity >/dev/null 2>&1; then
    f=$(zenity --file-selection --title="$t" --filename="$ini/" --file-filter='Imágenes | *.png *.jpg *.jpeg *.webp' 2>/dev/null)
  else
    f=$(ask "$t (escribe la ruta)")
  fi
  f=${f%%|*}; f=${f/#\~/$HOME}; [[ -f $f ]] && printf '%s' "$f"
}
elegir_carpeta() {   # → ruta de una carpeta
  local f="" ini; ini=$(carpeta_inicial)
  if command -v yad >/dev/null 2>&1; then f=$(yad --file --directory --title="Elige una carpeta con imágenes" --filename="$ini/" --width=900 --height=600 --center 2>/dev/null)
  elif command -v kdialog >/dev/null 2>&1; then f=$(kdialog --getexistingdirectory "$ini" 2>/dev/null)
  elif command -v zenity >/dev/null 2>&1; then f=$(zenity --file-selection --directory --filename="$ini/" 2>/dev/null)
  else f=$(ask "Carpeta con imágenes (ruta)"); fi
  f=${f%%|*}; f=${f/#\~/$HOME}; [[ -d $f ]] && printf '%s' "$f"
}
galeria() {   # [carpetas…] → ruta (cuadrícula con miniaturas en rofi)
  local dirs=("$@") d p i imgs=() nombres=()
  if (( ! ${#dirs[@]} )); then
    for d in "$CFG/wallpapers" "$HOME/Pictures/Wallpapers" "$HOME/Pictures/wallpapers" "$HOME/Wallpapers" "$HOME/Pictures" "$HOME/Imágenes"; do
      [[ -d $d ]] && dirs+=("$d")
    done
  fi
  (( ${#dirs[@]} )) && mapfile -t imgs < <(find -L "${dirs[@]}" -maxdepth 2 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) ! -name '.*' 2>/dev/null | sort -u | head -300)
  if (( ! ${#imgs[@]} )); then notificar "Sin imágenes" "No encontré imágenes en esa carpeta"; return 1; fi
  if usa_rofi; then
    local th=(-theme-str 'window{width:1100px;} listview{columns:4;lines:3;spacing:10px;} element{orientation:vertical;padding:8px;} element-icon{size:150px;} element-text{horizontal-align:0.5;}')
    [[ -f $CFG/rofi/themes/wallpapers.rasi ]] && th=(-theme "$CFG/rofi/themes/wallpapers.rasi")
    i=$(for p in "${imgs[@]}"; do printf '%s\0icon\x1f%s\n' "$(basename "$p")" "$p"; done | rofi -dmenu -i -show-icons -format i -p "Fondo" "${th[@]}")
  else
    for p in "${imgs[@]}"; do nombres+=("$(basename "$p")"); done
    i=$(pick_i "Fondo" "${nombres[@]}")
  fi
  [[ $i =~ ^[0-9]+$ ]] && printf '%s' "${imgs[$i]}"
}

fondo_val() { case $fondo in auto) echo "automático" ;; captura) echo "captura del escritorio" ;; solido:*) echo "color ${fondo#solido:}" ;; *) basename "$fondo" ;; esac; }
elementos_val() { local n=0 k; for k in mostrar_clima mostrar_musica mostrar_notis mostrar_estado mostrar_botones; do [[ ${!k} == 1 ]] && n=$((n + 1)); done; echo "$n de 5"; }

menu_estilo() {
  local its=() e i
  for e in "${ESTILOS[@]}"; do its+=("$([[ $e == "$estilo" ]] && echo '●' || echo '○')  $e  —  ${ESTILO_DESC[$e]}"); done
  MSG="Elige cómo se ve tu pantalla de bloqueo"
  i=$(pick_i "Estilo" "${its[@]}"); MSG=""
  [[ $i =~ ^[0-9]+$ ]] && guardar estilo "${ESTILOS[$i]}"
}
menu_fondo() {
  local its=("$I_IMG  Automático (mi fondo actual)" "$I_EYE  Captura de mi escritorio" "$I_IMG  Explorador de archivos (con vista previa)…" "$I_IMG  Galería de mis fondos…" "$I_IMG  Galería de otra carpeta…" "$I_PAL  Color sólido…") i p d
  i=$(pick_i "Fondo" "${its[@]}")
  case $i in
    0) guardar fondo auto ;;
    1) guardar fondo captura ;;
    2) p=$(elegir_archivo "Elige tu fondo de bloqueo") && [[ -n $p ]] && guardar fondo "$p" ;;
    3) p=$(galeria) && [[ -n $p ]] && guardar fondo "$p" ;;
    4) d=$(elegir_carpeta) && [[ -n $d ]] && p=$(galeria "$d") && [[ -n $p ]] && guardar fondo "$p" ;;
    5) p=$(ask "Color (#rrggbb)"); [[ $p =~ ^#?[0-9a-fA-F]{6}$ ]] && guardar fondo "solido:#${p#\#}" ;;
  esac
}
menu_blur() {
  local v=(auto 0 1 2 3 4 5) its=("Según el estilo" "0  ·  nítido" "1  ·  muy suave" "2" "3" "4" "5  ·  muy borroso") i
  i=$(pick_i "Desenfoque" "${its[@]}"); [[ $i =~ ^[0-9]+$ ]] && guardar blur "${v[$i]}"
}
menu_brillo() {
  local v=(auto 30 40 50 60 70 80 90 100) its=("Según el estilo" "30 %  ·  muy oscuro" "40 %" "50 %" "60 %" "70 %" "80 %" "90 %" "100 %  ·  original") i
  i=$(pick_i "Brillo del fondo" "${its[@]}"); [[ $i =~ ^[0-9]+$ ]] && guardar brillo "${v[$i]}"
}
menu_escala() {
  local v=(auto 70 80 90 100 110 125 150 175) its=("Automático (según tu pantalla)" "70 %" "80 %" "90 %" "100 %  ·  1080p" "110 %" "125 %" "150 %" "175 %") i
  MSG="Si algo se ve muy grande o se sale de los recuadros, baja el tamaño"
  i=$(pick_i "Tamaño" "${its[@]}"); MSG=""
  [[ $i =~ ^[0-9]+$ ]] && guardar escala "${v[$i]}"
}
menu_colores() {
  local its=() ids=() e m
  if [[ -f $RICE_COL ]]; then ids+=(rice); fi
  ids+=("${ESQUEMAS[@]}")
  for e in "${ids[@]}"; do m='○'; [[ $e == "$esquema" ]] && m='●'; its+=("$m  ${ESQ_NOM[$e]}"); done
  if [[ -x $CFG/hypr/scripts/paleta.sh ]]; then ids+=(__paleta); its+=("$I_PAL  Abrir el selector de paletas del rice"); fi
  local i; MSG="«Paleta del rice» sigue la que elijas con Super+Shift+P"
  i=$(pick_i "Colores" "${its[@]}"); MSG=""
  [[ $i =~ ^[0-9]+$ ]] || return 0
  if [[ ${ids[$i]} == __paleta ]]; then "$CFG/hypr/scripts/paleta.sh" menu; [[ -f $RICE_COL ]] && guardar esquema rice
  else guardar esquema "${ids[$i]}"; fi
}
menu_foto() {
  local its=("$I_USER  Usar la foto del rice (~/.face)" "$I_USER  Elegir otra imagen (explorador con vista previa)…" "$I_USER  Sin foto") i p
  i=$(pick_i "Foto de perfil" "${its[@]}")
  case $i in
    0) guardar foto "" ;;
    1) p=$(elegir_archivo "Elige tu foto de perfil") && [[ -n $p ]] && guardar foto "$p" ;;
    2) guardar foto none ;;
  esac
}
menu_elementos() {
  local keys=(mostrar_clima mostrar_musica mostrar_notis mostrar_estado mostrar_botones)
  local nom=("Clima" "Música" "Notificaciones" "Estado (batería · red · bluetooth)" "Botones de energía") i k its
  while :; do
    cargar; its=()
    for i in 0 1 2 3 4; do k=${keys[$i]}; its+=("$([[ ${!k} == 1 ]] && echo '✔' || echo '✘')  ${nom[$i]}"); done
    its+=("$I_BACK  Volver")
    MSG="Selecciona uno para activarlo o apagarlo"
    i=$(pick_i "Elementos" "${its[@]}"); MSG=""
    [[ $i =~ ^[0-9]+$ ]] && (( i < 5 )) || return 0
    k=${keys[$i]}; [[ ${!k} == 1 ]] && guardar "$k" 0 || guardar "$k" 1
  done
}

menu() {
  local its i r
  while :; do
    cargar
    its=(
      "$I_LOCK  Estilo  ·  $estilo"
      "$I_IMG  Fondo  ·  $(fondo_val)"
      "$I_TUNE  Desenfoque  ·  ${blur/auto/según estilo}"
      "$I_SUN  Brillo del fondo  ·  ${brillo/auto/según estilo}"
      "$I_TUNE  Tamaño  ·  ${escala/auto/automático}"
      "$I_CLOCK  Reloj  ·  $reloj h"
      "$I_PAL  Colores  ·  ${ESQ_NOM[$esquema]}"
      "$I_USER  Foto de perfil  ·  $([[ $foto == none ]] && echo 'sin foto' || { [[ -z $foto ]] && echo 'la del rice' || basename "$foto"; })"
      "$I_EYE  Elementos  ·  $(elementos_val)"
      "$I_PLAY  Vista previa (6 s)"
      "$I_LOCK  Bloquear ahora"
      "$I_RESET  Restaurar valores"
      "$I_BACK  Salir"
    )
    MSG="zero-lock $VERSION  ·  los cambios se guardan solos"
    i=$(pick_i "Pantalla de bloqueo" "${its[@]}"); MSG=""
    [[ $i =~ ^[0-9]+$ ]] || return 0
    case $i in
      0) menu_estilo ;;  1) menu_fondo ;;  2) menu_blur ;;  3) menu_brillo ;;  4) menu_escala ;;
      5) [[ $reloj == 24 ]] && guardar reloj 12 || guardar reloj 24 ;;
      6) menu_colores ;; 7) menu_foto ;; 8) menu_elementos ;;
      9) cmd_preview_hijo ;;
      10) cmd_lock; return 0 ;;
      11) r=$(pick "¿Restaurar todo?" "Sí, restaurar" "No") && [[ $r == Sí* ]] && rm -f "$CONF" ;;
      12) return 0 ;;
    esac
  done
}

# ───────────────────────────── bloquear / vista previa ─────────────────────────────
tiene_hyprlock() { command -v hyprlock >/dev/null 2>&1 || { notificar -u critical "zero-lock" "Falta hyprlock: sudo pacman -S hyprlock"; echo "Falta hyprlock (sudo pacman -S hyprlock)" >&2; log "ERROR: hyprlock no está instalado"; return 1; }; }
hyprlock_corriendo() { pgrep -x hyprlock >/dev/null 2>&1; }

# Config mínima que no depende de nada (ni fuentes, ni scripts, ni paleta): si la bonita falla, se usa esta.
emitir_seguro() {
  cat > "$SEGURO" <<'EOF'
# zero-lock — config de emergencia (se usa solo si la normal no se pudo generar o hyprlock falló con ella)
general {
    hide_cursor = false
}
background {
    monitor =
    color = rgba(111118ff)
}
label {
    monitor =
    text = $TIME
    font_size = 72
    color = rgba(f6f6fbff)
    position = 0, 120
    halign = center
    valign = center
}
input-field {
    monitor =
    size = 320, 52
    outline_thickness = 2
    outer_color = rgba(7aa2f7ff)
    inner_color = rgba(1a1b26ff)
    font_color = rgba(c0caf5ff)
    fade_on_empty = false
    placeholder_text = Contraseña
    fail_text = $FAIL ($ATTEMPTS)
    position = 0, -20
    halign = center
    valign = center
}
EOF
}

# Genera la config en un proceso aparte y con tiempo límite: si algo se traba, se bloquea igual (con la de emergencia).
preparar_config() {   # grace → imprime la ruta de la config a usar
  local ini fin
  ini=$(date +%s%N)
  if T=5 t bash "$SRC" _generar "${1:-0}" 2>>"$LOG" && [[ -s $GEN ]]; then
    fin=$(date +%s%N); log "config lista en $(( (fin - ini) / 1000000 )) ms (estilo: $(cargar; printf '%s' "$estilo"))"
    printf '%s' "$GEN"
  else
    log "AVISO: no se pudo generar la config a tiempo → uso la de emergencia"
    emitir_seguro; printf '%s' "$SEGURO"
  fi
}

cmd_lock() {
  hyprlock_corriendo && return 0
  tiene_hyprlock || return 1
  recortar_log
  # un solo bloqueo a la vez (Super + L varias veces, hypridle y el botón de la barra al mismo tiempo…)
  exec 8>"$CACHE/.bloqueando"
  if command -v flock >/dev/null 2>&1 && ! flock -n 8; then log "ya se estaba bloqueando; ignoro este intento"; return 0; fi
  local cfg rc
  cfg=$(preparar_config 0)
  log "bloqueando con $cfg"
  hyprlock -c "$cfg" 8>&- 2>>"$LOG"; rc=$?
  if (( rc != 0 )) && [[ $cfg != "$SEGURO" ]] && ! hyprlock_corriendo; then
    # hyprlock no arrancó o se cayó con la config bonita: nunca te quedas sin bloqueo
    log "hyprlock salió con código $rc → reintento con la config de emergencia"
    emitir_seguro; hyprlock -c "$SEGURO" 8>&- 2>>"$LOG"; rc=$?
  fi
  log "desbloqueado (código $rc)"
  return 0
}
cmd_preview_hijo() {
  hyprlock_corriendo && return 0
  tiene_hyprlock || return 1
  local cfg extra=()
  grace_por_cli && extra=(--grace 6)
  cfg=$(preparar_config 6); notificar "Vista previa" "Mueve el mouse para volver (6 s)"
  hyprlock -c "$cfg" "${extra[@]}" 2>>"$LOG"
}

# ───────────────────────────── diagnóstico ─────────────────────────────
diagnostico() {
  local ok=$'\e[1;32m✔\e[0m' mal=$'\e[1;31m✘\e[0m' av=$'\e[1;33m!\e[0m' b ini fin p
  echo "zero-lock $VERSION  ·  $SRC"
  if command -v hyprlock >/dev/null 2>&1; then echo "$ok hyprlock: $(hyprlock --version 2>/dev/null | head -1)"
  else echo "$mal hyprlock NO está instalado  →  sudo pacman -S hyprlock"; fi
  if command -v hypridle >/dev/null 2>&1; then
    if pgrep -x hypridle >/dev/null; then echo "$ok hypridle corriendo (bloqueo automático)"
    else echo "$av hypridle instalado pero NO corre  →  hypridle & disown   (el rice lo arranca al iniciar sesión)"; fi
  else echo "$av hypridle no está instalado (sin bloqueo automático)  →  sudo pacman -S hypridle"; fi
  if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && command -v jq >/dev/null 2>&1; then
    b=$(T=2 t hyprctl binds -j 2>/dev/null | jq -r '.[] | select((.arg // "") | test("zero-lock|hyprlock|lock-session")) | "\(.modmask) \(.key) → \(.arg)"' 2>/dev/null)
    if [[ -n $b ]]; then echo "$ok atajos registrados en Hyprland:"; sed 's/^/     /' <<<"$b"
    else echo "$mal Hyprland NO tiene ningún atajo de bloqueo  →  corre ./install.sh --actualizar y luego hyprctl reload"; fi
  fi
  if compgen -G '/sys/class/bluetooth/hci*' >/dev/null && ! systemctl is-active --quiet bluetooth 2>/dev/null; then
    echo "$ok bluetooth apagado: se detecta sin colgarse (antes de la 1.2.0 esto trababa el bloqueo)"
  fi
  p=$(pgrep -fa 'zero-lock(\.sh)? lock' | grep -v "^$$ " || true)
  [[ -n $p ]] && { echo "$av procesos de bloqueo atorados de antes (se pueden matar con: pkill -f 'zero-lock.sh lock'):"; sed 's/^/     /' <<<"$p"; }
  ini=$(date +%s%N)
  if T=5 t bash "$SRC" _generar 0 2>/dev/null && [[ -s $GEN ]]; then fin=$(date +%s%N); echo "$ok la config se genera en $(( (fin - ini) / 1000000 )) ms → $GEN"
  else echo "$mal la config NO se genera (se usaría la de emergencia). Revisa: bash -x $SRC gen"; fi
  [[ -f $LOG ]] && { echo "── últimas líneas de $LOG"; tail -n 8 "$LOG"; }
  return 0
}

# ───────────────────────────── instalador ─────────────────────────────
plantilla_rice() {
  cat <<'TPL'
#@ destino: ~/.config/hypr/hyprlock-colores.conf
# Generado por paleta.sh — paleta: {{nombre}}  (lo usa zero-lock)
$zl_bg  = {{fondo.hypr88}}
$zl_sf  = {{fondo2.hypr}}
$zl_fg  = {{texto.hypr}}
$zl_dim = {{tenue.hypr}}
$zl_ac1 = {{acento.hypr}}
$zl_ac2 = {{acento2.hypr}}
$zl_on  = {{sobre.hypr}}
$zl_err = {{rojo.hypr}}
TPL
}
instalar() {
  local si=0 r c pk=() dest="$HOME/.local/bin/zero-lock" HI="$CFG/hypr/hypridle.conf" LUA="$CFG/hypr/hyprland.lua" MIO="$CFG/hypr/mio.lua"
  [[ ${1:-} == --si ]] && si=1
  say() { printf '\033[1;35m▸\033[0m %s\n' "$*"; }
  confirmar() { (( si )) && return 0; read -rp "$1 [S/n] " r; [[ -z $r || $r =~ ^[sSyY] ]]; }

  say "Revisando dependencias"
  for c in hyprlock jq curl playerctl rofi yad; do command -v "$c" >/dev/null 2>&1 || pk+=("$c"); done
  if (( ${#pk[@]} )); then
    if command -v pacman >/dev/null 2>&1; then
      say "Faltan: ${pk[*]}"; confirmar "¿Instalarlos con pacman?" && sudo pacman -S --needed "${pk[@]}"
    else echo "Instala a mano: ${pk[*]}"; fi
  fi
  fc-list 2>/dev/null | grep -qi 'JetBrainsMono.*Nerd' || say "Recomendado: sudo pacman -S ttf-jetbrains-mono-nerd (iconos)"
  fc-list 2>/dev/null | grep -qi 'dotgothic16' || say "Opcional (estilo minimal): yay -S ttf-dotgothic16"

  mkdir -p "$HOME/.local/bin"
  # enlace (no copia): así nunca queda una versión vieja suelta en ~/.local/bin
  [[ $SRC != "$dest" ]] && ln -sfn "$SRC" "$dest"
  say "Comando instalado → $dest → $SRC"
  case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) say "Agrega ~/.local/bin a tu PATH para usar 'zero-lock' desde la terminal" ;; esac
  [[ -f $CONF ]] || guardar estilo tarjetas

  if [[ -d $CFG/rice-plantillas ]]; then
    plantilla_rice > "$CFG/rice-plantillas/hyprlock-colores.conf.tpl"
    if [[ -x $CFG/hypr/scripts/paleta.sh ]]; then "$CFG/hypr/scripts/paleta.sh" regenerar >/dev/null 2>&1; fi
    say "Integrado con las paletas de zero-rice"
  fi

  if [[ -f $HI ]] && grep -q '^[[:space:]]*lock_cmd' "$HI" && ! grep -q zero-lock "$HI"; then
    if confirmar "¿Que el bloqueo automático (hypridle) use zero-lock?"; then
      cp "$HI" "$HI.bak.$(date +%s)"; sed -i "s|^\([[:space:]]*\)lock_cmd.*|\1lock_cmd = pidof hyprlock \|\| $SRC lock|" "$HI"
      say "hypridle actualizado (respaldo guardado)"
    fi
  fi

  if [[ -f $LUA ]]; then
    if grep -qs 'zero-lock' "$CFG/hypr/rice.lua"; then
      say "Los atajos Super+L / Super+Shift+L ya vienen en rice.lua"
    elif ! grep -qs 'zero-lock' "$MIO" && confirmar "¿Agregar atajos Super+L (bloquear) y Super+Shift+L (menú) en mio.lua?"; then
      cat >> "$MIO" <<EOF

-- zero-lock begin
hl.unbind("SUPER + L")
hl.unbind("SUPER + SHIFT + L")
hl.bind("SUPER + L",         hl.dsp.exec_cmd("$dest lock"))
hl.bind("SUPER + SHIFT + L", hl.dsp.exec_cmd("$dest"))
-- zero-lock end
EOF
      say "Atajos agregados en ~/.config/hypr/mio.lua"; hyprctl reload >/dev/null 2>&1
    fi
  else
    cat <<EOF
  Agrega estos atajos a tu config de Hyprland:
    bind = SUPER, L, exec, $dest lock
    bind = SUPER SHIFT, L, exec, $dest
EOF
  fi
  say "Listo. Abre el menú con:  zero-lock   ·   Super+Shift+L"
}
desinstalar() {
  local HI="$CFG/hypr/hypridle.conf" MIO="$CFG/hypr/mio.lua" bak
  rm -f "$HOME/.local/bin/zero-lock" "$CFG/rice-plantillas/hyprlock-colores.conf.tpl" "$RICE_COL"
  [[ -f $MIO ]] && sed -i '/-- zero-lock begin/,/-- zero-lock end/d' "$MIO"
  bak=$(ls -t "$HI".bak.* 2>/dev/null | head -1); [[ -n $bak ]] && cp "$bak" "$HI"
  rm -rf "$DIR" "$CACHE"
  echo "zero-lock desinstalado. (Los paquetes no se tocan.)"
}

# ───────────────────────────── entrada ─────────────────────────────
estado() {
  cargar
  printf 'estilo=%s\nfondo=%s\ndesenfoque=%s\nbrillo=%s\nescala=%s\nreloj=%s h\ncolores=%s\nfoto=%s\nelementos=%s\n' \
    "$estilo" "$(fondo_val)" "$blur" "$brillo" "$escala" "$reloj" "${ESQ_NOM[$esquema]}" "${foto:-rice}" "$(elementos_val)"
}
main() {
  local c=${1:-menu} i p
  case "$c" in
    menu|"")        menu ;;
    lock|bloquear)  cmd_lock ;;
    preview|vista)  cmd_preview_hijo ;;
    estilo)         [[ " ${ESTILOS[*]} " == *" ${2:-} "* ]] || { echo "Estilos: ${ESTILOS[*]}" >&2; exit 1; }; guardar estilo "$2"; echo "Estilo: $2" ;;
    siguiente)      cargar; for i in "${!ESTILOS[@]}"; do [[ ${ESTILOS[$i]} == "$estilo" ]] && break; done
                    guardar estilo "${ESTILOS[$(((i + 1) % ${#ESTILOS[@]}))]}"; cargar; notificar "Estilo: $estilo"; echo "Estilo: $estilo" ;;
    aleatorio)      guardar estilo "${ESTILOS[$((RANDOM % ${#ESTILOS[@]}))]}"; cargar; echo "Estilo: $estilo" ;;
    fondo)          case "${2:-}" in
                      auto|captura) guardar fondo "$2" ;;
                      --elegir|elegir) p=$(elegir_archivo "Elige tu fondo de bloqueo") && [[ -n $p ]] && guardar fondo "$p" || { echo "Cancelado"; exit 0; } ;;
                      \#*|[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) guardar fondo "solido:#${2#\#}" ;;
                      *) [[ -f ${2:-} ]] || { echo "Uso: zero-lock fondo <ruta|auto|captura|#rrggbb>" >&2; exit 1; }; guardar fondo "$(readlink -f "$2")" ;;
                    esac; echo "Fondo guardado" ;;
    set)            [[ -n ${2:-} && -n ${3:-} ]] || { echo "Uso: zero-lock set <clave> <valor>" >&2; exit 1; }; guardar "$2" "$3" ;;
    estado)         estado ;;
    gen)            generar "${2:-0}"; cat "$GEN" ;;
    _generar)       generar "${2:-0}" ;;
    diagnostico|doctor) diagnostico ;;
    instalar)       shift; instalar "$@" ;;
    desinstalar)    desinstalar ;;
    _clima)         cmd_clima "${2:-44}" ;; _estado)  cmd_estado "${2:-60}" ;; _musica) cmd_musica "${2:-titulo}" "${3:-30}" ;;
    _portada)       cmd_portada ;;    _notis)   cmd_notis ;;    _teclado) cmd_teclado ;;
    _saludo)        cmd_saludo "${2:-40}" ;; _terminal) cmd_terminal "${2:-46}" ;;
    -v|--version)   echo "zero-lock $VERSION" ;;
    -h|--help|ayuda) awk 'NR > 1 { if ($0 !~ /^#/) exit; print }' "$SRC" ;;
    *)              echo "Comando desconocido: $c (zero-lock --help)" >&2; exit 1 ;;
  esac
}
main "$@"
