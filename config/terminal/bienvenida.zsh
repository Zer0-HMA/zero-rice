# bienvenida.zsh — lo que se ve al abrir una terminal   (zero-rice)
#
# Se carga desde ~/.zshrc, en la PRIMERA línea (antes del bloque "instant prompt" de Powerlevel10k).
#   bienvenida              → la muestra ahora
#   bienvenida panel        → el panel: tu foto + ZERO, sistema, discos, tus comandos y pendientes
#                             (el de siempre; también hay saludo, rice, corriendo y frase: bienvenida editar)
#   bienvenida info         → logo + datos del sistema + tu paleta (fastfetch con tus colores)
#   bienvenida saludo       → una línea: saludo, clima, tiempo encendida y RAM
#   bienvenida off          → no mostrar nada al abrir
#   bienvenida editar       → abre la config del panel (qué secciones salen y en qué orden)
#   bienvenida logo <x>     → el logo: auto (tu foto + ZERO) · foto · zero · arch · texto · ninguno · imagen /ruta
#   comandos                → tus alias, funciones y scripts, con lo que hace cada uno
#   pendiente "texto"       → agrega un pendiente al panel  (pendiente · pendiente hecho 2 · pendiente limpiar)
#   zero <cosa>             → atajos del rice desde la terminal (zero sin nada: la lista)
#   ff                      → fastfetch completo
# Solo sale en la ventana nueva (no en subshells, tmux, nvim, ni en ventanas muy chicas).
# Tus frases van en ~/.config/rice-terminal/frases.txt (una por línea) y tu logo en logo.txt.

_RT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rice-terminal"
_RT_SCRIPTS="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
_RT_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/zero-rice/terminal"
_RT_ESTADO="${XDG_STATE_HOME:-$HOME/.local/state}/zero-rice"

_rt_modo() { local m=panel; [[ -r "$_RT_DIR/modo" ]] && read -r m < "$_RT_DIR/modo"; print -r -- "${m:-panel}"; }

_rt_colores() {
  [[ -r "$_RT_DIR/colores.zsh" ]] && source "$_RT_DIR/colores.zsh"
  : ${RT_RESET:=$'\e[0m'} ${RT_ACENTO:=$'\e[38;5;208m'} ${RT_ACENTO2:=$'\e[38;5;215m'} ${RT_TEXTO:=$'\e[38;5;252m'}
  : ${RT_TENUE:=$'\e[38;5;244m'} ${RT_ROJO:=$'\e[31m'} ${RT_VERDE:=$'\e[32m'} ${RT_AMARILLO:=$'\e[33m'} ${RT_AZUL:=$'\e[34m'}
  RT_NEGRITA=$'\e[1m'
}

# las variables de panel.conf (se declaran locales antes de leerlo, para no ensuciar tu shell)
_RT_CONF_VARS=(SECCIONES LOGO FILAS_COMPACTO SECCIONES_COMPACTO ANCHO DISCOS_MAX DOCKER_MAX PESADOS_MAX
               REVISAR_ACTUALIZACIONES OCULTAR_COMANDOS)

# ════════════════════════════ modo info (fastfetch) ════════════════════════════
_rt_info() {
  command -v fastfetch >/dev/null 2>&1 || { print -r -- "Instala fastfetch:  sudo pacman -S fastfetch"; return 1; }
  if [[ -r "$_RT_DIR/fastfetch.jsonc" ]]; then fastfetch -c "$_RT_DIR/fastfetch.jsonc"; else fastfetch; fi
}

# ════════════════════════════ cosas compartidas ════════════════════════════
_rt_nombre() {   # el nombre de tu perfil (Super + Shift + F) o tu usuario
  local n="" f="${XDG_CONFIG_HOME:-$HOME/.config}/rice-perfil/nombre"
  [[ -r $f ]] && read -r n < $f
  REPLY=${n:-${USER:-${LOGNAME:-$(id -un)}}}
}

_rt_saludo_hora() {
  local h
  strftime -s h '%H' $EPOCHSECONDS
  h=$((10#$h))
  if   (( h >= 5  && h < 12 )); then REPLY="Buenos días"
  elif (( h >= 12 && h < 19 )); then REPLY="Buenas tardes"
  else                               REPLY="Buenas noches"; fi
}

_rt_tiempo_up() {   # → REPLY "2 h 17 min"
  local seg="" _x
  read -r seg _x < /proc/uptime 2>/dev/null; seg=${seg%.*}; : ${seg:=0}
  if   (( seg >= 86400 )); then REPLY="$((seg / 86400)) d $(( (seg % 86400) / 3600 )) h"
  elif (( seg >= 3600  )); then REPLY="$((seg / 3600)) h $(( (seg % 3600) / 60 )) min"
  else                          REPLY="$((seg / 60)) min"; fi
}

_rt_clima() {   # → REPLY "<icono> 18° Nublado · Ciudad" (vacío si no hay datos)
  # clima.sh (el mismo del lanzador) lo guarda en ~/.cache/zero-rice/clima; antes de la 0.3 vivía en ~/.config/rice-clima
  local cf="${XDG_CACHE_HOME:-$HOME/.cache}/zero-rice/clima/actual" k v icono desc
  [[ -r $cf ]] || cf="${XDG_CONFIG_HOME:-$HOME/.config}/rice-clima/actual"
  local -A cl
  REPLY=""
  [[ -r $cf ]] || return 1
  while IFS='=' read -r k v; do [[ $k == [a-z]## ]] && cl[$k]=$v; done < $cf
  [[ -n ${cl[temp]:-} && -n ${cl[codigo]:-} && -x $_RT_SCRIPTS/clima.sh ]] || return 1
  IFS='|' read -r icono desc <<< "$("$_RT_SCRIPTS/clima.sh" describir "${cl[codigo]}" "${cl[dia]:-1}" 2>/dev/null)"
  REPLY="${RT_ACENTO}${icono}${RT_RESET} ${RT_TEXTO}${cl[temp]}°${RT_RESET} ${RT_TENUE}${desc} · ${cl[ciudad]%%,*}${RT_RESET}"
}

# ════════════════════════════ modo saludo ════════════════════════════
_rt_saludo() {
  emulate -L zsh; setopt extended_glob
  zmodload -F zsh/datetime b:strftime p:EPOCHSECONDS 2>/dev/null
  _rt_colores
  local saludo up nombre mem linea2=""
  local i_arch=$'\uF303' i_up=$'\U000F051B' i_ram=$'\U000F035B'
  _rt_saludo_hora; saludo=$REPLY
  _rt_nombre; nombre=$REPLY
  _rt_tiempo_up; up=$REPLY
  mem=$(awk '/^MemTotal/{t=$2} /^MemAvailable/{a=$2} END{printf "%d", 100*(t-a)/t}' /proc/meminfo)
  _rt_clima && linea2="${REPLY}     "
  linea2+="${RT_ACENTO}${i_up}${RT_RESET} ${RT_TENUE}encendida ${up}${RT_RESET}     ${RT_ACENTO}${i_ram}${RT_RESET} ${RT_TENUE}RAM ${mem}%${RT_RESET}"
  print -r -- ""
  print -r -- "  ${RT_ACENTO}${i_arch}${RT_RESET}  ${RT_TEXTO}${saludo},${RT_RESET} ${RT_ACENTO2}${nombre}${RT_RESET}"
  print -r -- "  ${linea2}"
  print -r -- ""
}

# ════════════════════════════ modo panel ════════════════════════════
# Todo se arma en el arreglo _L y se imprime de un jalón al final (sin parpadeo).
# Cada sección es una función _rt_s_<nombre>; _rt_panel las llama en el orden de SECCIONES.

_rt_conf_default() {
  cat <<'EOF'
# Panel de la terminal (zero-rice) — se lee cada vez que abres una terminal.
# Secciones, en el orden en que salen. Las que hay:
#   logo        tu foto de perfil + ZERO + usuario, Arch, Hyprland, tiempo encendida
#   sistema     CPU, temperatura, carga, RAM, batería, red
#   discos      cuánto usas de cada disco
#   comandos    tus alias, funciones y scripts
#   pendientes  actualizaciones, huérfanos, servicios caídos y tus notas
#   saludo · rice · corriendo · frase   (también existen; agrégalas si las quieres)
SECCIONES="logo sistema discos comandos pendientes"

# Logo (también: bienvenida logo <opción>):
#   auto    → tu foto de perfil (Super + Shift + F) junto a ZERO. En kitty sale la foto de verdad;
#             en otras terminales, hecha de bloques si tienes chafa (sudo pacman -S chafa)
#   foto    → solo tu foto, sin ZERO   ·   imagen:/ruta/a/imagen.png → la imagen que quieras
#   zero    → ZERO en letras grandes   ·   arch → el logo de Arch   ·   texto → tu logo.txt   ·   ninguno
LOGO=auto

# En ventanas de menos de FILAS_COMPACTO filas salen estas (más corto):
FILAS_COMPACTO=28
SECCIONES_COMPACTO="sistema discos pendientes"

ANCHO=80                     # ancho máximo del panel
DISCOS_MAX=5                 # cuántos discos enseñar
DOCKER_MAX=8                 # cuántos contenedores enseñar (si usas docker)
PESADOS_MAX=4                # apps que más RAM usan
REVISAR_ACTUALIZACIONES=1    # 1 = revisa en segundo plano cada 3 h (checkupdates + yay/paru) · 0 = no
OCULTAR_COMANDOS=""          # nombres que no quieres ver en "Tus comandos", separados por espacio
EOF
}

# ── utilidades de dibujo ──
_rt_ancho() { local s=${1//$'\e'\[[0-9;]#m/}; s=${s//$'\e_'[^$'\e']#$'\e\\'/}; REPLY=${(m)#s}; }
_rt_pad()   { _rt_ancho "$1"; local -i f=$(( $2 - REPLY )); (( f < 0 )) && f=0; REPLY="$1${(l:f:: :)}"; }
_rt_corta() { if (( ${(m)#1} > $2 )); then REPLY="${1[1,$(( $2 - 1 ))]}…"; else REPLY=$1; fi; }
_rt_rgb()   { reply=(); [[ $1 == (#b)*38\;2\;([0-9]##)\;([0-9]##)\;([0-9]##)m* ]] && reply=($match[1] $match[2] $match[3]); }
_rt_tam()   {   # KiB → "830M" / "1.4G"
  local -i k=$1
  if (( k >= 1048576 )); then REPLY="$(( k / 1048576 )).$(( (k % 1048576) * 10 / 1048576 ))G"
  else REPLY="$(( k / 1024 ))M"; fi
}
_rt_color_pct() {   # $1 = % , $2 = amarillo desde, $3 = rojo desde
  if   (( $1 >= ${3:-85} )); then REPLY=$RT_ROJO
  elif (( $1 >= ${2:-60} )); then REPLY=$RT_AMARILLO
  else REPLY=$RT_VERDE; fi
}
_rt_barra() {   # $1 = %, $2 = ancho, $3 = color de lo lleno
  local -i p=$1 n=$2 llenos
  (( p < 0 )) && p=0; (( p > 100 )) && p=100
  llenos=$(( (p * n + 50) / 100 )); (( p > 0 && llenos == 0 )) && llenos=1
  REPLY="${3}${(pl:llenos::█:)}${RT_RESET}${RT_TENUE}${(pl:$((n - llenos))::░:)}${RT_RESET}"
}
_rt_seccion() {
  local t=" $1 "; _rt_ancho "$t"
  local -i resto=$(( _W - 4 - REPLY )); (( resto < 2 )) && resto=2
  _L+=("" "  ${RT_ACENTO}──${RT_NEGRITA}${t}${RT_RESET}${RT_ACENTO}${(pl:resto::─:)}${RT_RESET}")
}
_rt_kv() {   # $1 = ícono, $2 = clave, $3 = valor
  _rt_pad "$2" 10
  _L+=("  ${RT_ACENTO}$1 ${REPLY}${RT_RESET}$3")
}
_rt_envolver() {   # $1 = sangría, resto = piezas (con color) → líneas que caben en _W
  local sangria=$1 linea="" p; local -i w=0 pw; shift
  for p in "$@"; do
    _rt_ancho "$p"; pw=$REPLY
    if (( w > 0 && w + 2 + pw > _W - ${#sangria} )); then _L+=("${sangria}${linea}"); linea=""; w=0; fi
    if (( w > 0 )); then linea+="  "; w+=2; fi
    linea+=$p; w+=pw
  done
  [[ -n $linea ]] && _L+=("${sangria}${linea}")
}
_rt_buscar_id() {   # $1 = archivo, $2 = id  → REPLY = 2º campo de la línea "id|Nombre|..." (con o sin comillas)
  local -a l; REPLY=""
  [[ -r $1 ]] || return 1
  l=(${(M)${(f)"$(<$1)"}:#[[:space:]\"]#${2}\|*})
  (( ${#l} )) || return 1
  REPLY=${${(s:|:)l[1]}[2]}
  [[ -n $REPLY ]]
}

# ── datos del sistema que usan varias secciones ──
_rt_leer_sistema() {
  local k v _x linea l1 l5 l15 kern=""
  local -i mt=0 ma=0 st=0 sf=0
  local -a pk
  while read -r k v _x; do
    case $k in MemTotal:) mt=$v ;; MemAvailable:) ma=$v ;; SwapTotal:) st=$v ;; SwapFree:) sf=$v ;; esac
  done < /proc/meminfo
  _S[ram_t]=$mt; _S[ram_u]=$(( mt - ma )); _S[swap_t]=$st; _S[swap_u]=$(( st - sf ))
  while IFS=: read -r k v; do [[ $k == model\ name* ]] && { _S[cpu]=${v# }; break; }; done < /proc/cpuinfo
  _S[cpu]=${${${_S[cpu]:-?}// with Radeon Graphics/}//(\(R\)|\(TM\))/}
  _S[nucleos]=$(nproc 2>/dev/null)
  read -r l1 l5 l15 _x < /proc/loadavg; _S[c1]=$l1; _S[c5]=$l5; _S[c15]=$l15
  read -r kern < /proc/sys/kernel/osrelease; _S[kernel]=$kern
  _S[host]=${HOST:-$(</etc/hostname)}
  _S[os]="Arch Linux"
  if [[ -r /etc/os-release ]]; then
    for linea in "${(@f)$(</etc/os-release)}"; do [[ $linea == PRETTY_NAME=* ]] && _S[os]=${${linea#PRETTY_NAME=}//\"/}; done
  fi
  pk=(/var/lib/pacman/local/*(N/)); _S[pkgs]=${#pk}    # sin procesos: las carpetas de la base de datos de pacman
}

_rt_leer_procesos() {   # una sola foto de los procesos: servicios del rice + lo que más RAM usa
  local l cmd base app
  local -a w
  for l in "${(@f)$(ps -eww -o uid=,rss=,args= 2>/dev/null)}"; do
    w=(${=l})
    (( ${#w} >= 3 )) || continue
    cmd=${(j: :)w[3,-1]}; base=${w[3]:t}
    case $base in
      swaync)                   _P[notificaciones]=1 ;;
      hypridle)                 _P[hypridle]=1 ;;
      awww-daemon|swww-daemon)  _P[fondos]=1 ;;
      mpvpaper)                 _P[fondos]=1; _P[video]=1 ;;
      hyprpolkitagent)          _P[polkit]=1 ;;
      hyprsunset)               _P[hyprsunset]=1 ;;
      tailscaled)               _P[tailscale]=1 ;;
      dockerd)                  _P[docker]=1 ;;
    esac
    [[ $cmd == (gjs*ags*|ags\ run*|*/ags\ run*) ]] && _P[barra]=1
    [[ $cmd == *wl-paste*cliphist* ]] && _P[portapapeles]=1
    [[ ${w[1]} == $UID && ${w[3]} != \[* ]] || continue
    app=${base%:}
    case $app in
      electron*)  [[ -n ${w[4]:-} && ${w[4]} != -* ]] && app=${${w[4]#/usr/lib/}%%/*} ;;
      python*|node|bash|sh|zsh|perl|ruby|gjs)
                  [[ -n ${w[4]:-} && ${w[4]} != -* ]] && app=${${w[4]:t}%.*} ;;
    esac
    [[ $app == (ps|jq|hyprctl|timeout|cat|head) ]] && continue
    _M[$app]=$(( ${_M[$app]:-0} + ${w[2]} ))
  done
}

# ── revisar actualizaciones en segundo plano (nunca hace esperar a la terminal) ──
_rt_revisar_actualizaciones() {
  (( ${REVISAR_ACTUALIZACIONES:-1} )) || return 0
  (( $+commands[checkupdates] )) || return 0
  local f=$_RT_CACHE/actualizaciones lock=$_RT_CACHE/revisando aur=""
  local -a fresco viejo
  if [[ -f $f && ! /var/lib/pacman/local -nt $f ]]; then
    fresco=($f(Nmh-3)); (( ${#fresco} )) && return 0
  fi
  viejo=($lock(N/mm+10)); (( ${#viejo} )) && rmdir $lock 2>/dev/null
  mkdir $lock 2>/dev/null || return 0
  (( $+commands[yay] )) && aur=yay
  [[ -z $aur ]] && (( $+commands[paru] )) && aur=paru
  {
    local r a="" ; local -i rc
    local -a rr aa
    r=$(timeout 120 checkupdates 2>/dev/null); rc=$?
    if (( rc == 0 || rc == 2 )); then        # 2 = no hay actualizaciones; 1 = falló (sin internet)
      [[ -n $aur ]] && a=$(timeout 60 $aur -Qua 2>/dev/null)
      rr=(${(f)r}); aa=(${(f)a})
      print -r -- "repo=${#rr}"$'\n'"aur=${#aa}"$'\n'"ayudante=${aur}" > $f.tmp && mv -f $f.tmp $f
    fi
    rmdir $lock 2>/dev/null
  } &>/dev/null &!
}

_rt_info_pacman() {   # AUR, huérfanos y última actualización (se recalcula solo cuando cambia pacman)
  local f=$_RT_CACHE/pacman k v linea
  local -a aur huer
  local -i ult=0
  if [[ ! -f $f || /var/lib/pacman/local -nt $f || /var/log/pacman.log -nt $f ]]; then
    aur=(${(f)"$(pacman -Qmq 2>/dev/null)"})
    huer=(${(f)"$(pacman -Qdtq 2>/dev/null)"})
    linea=$(grep -a 'starting full system upgrade' /var/log/pacman.log 2>/dev/null | tail -n1)
    if [[ $linea == (#b)\[([0-9]##-[0-9]##-[0-9]##)[T\ ]([0-9]##:[0-9]##)* ]]; then
      strftime -r -s ult '%Y-%m-%d %H:%M' "$match[1] $match[2]" 2>/dev/null
    fi
    print -r -- "aur=${#aur}"$'\n'"huerfanos=${#huer}"$'\n'"ultima=${ult}" > $f.tmp && mv -f $f.tmp $f
  fi
  while IFS='=' read -r k v; do _S[pac_$k]=$v; done < $f
}

_rt_hace() {   # segundos → "hace 3 días"
  local -i s=$1
  if   (( s < 3600 ));   then REPLY="hace un rato"
  elif (( s < 86400 ));  then REPLY="hace $(( s / 3600 )) h"
  elif (( s < 172800 )); then REPLY="ayer"
  else                        REPLY="hace $(( s / 86400 )) días"; fi
}

# ════════════════════════════ secciones ════════════════════════════

# ── logo: ZERO, Arch, tu foto de perfil o cualquier imagen ──
_rt_kitty() {   # ¿la terminal sabe dibujar imágenes? (protocolo de kitty: kitty, ghostty, wezterm; no por SSH)
  [[ -n ${SSH_CONNECTION:-}${SSH_TTY:-} ]] && return 1
  [[ -n ${KITTY_WINDOW_ID:-} || $TERM == xterm-kitty || ${TERM_PROGRAM:-} == (ghostty|WezTerm) ]]
}

_rt_foto() {   # $1 = imagen, $2 = filas → reply = una línea por fila (ya con su ancho), _IMG_COLS = el ancho
  local l; local -i y filas=$2
  reply=()
  if _rt_kitty && _rt_logo_imagen "$1" $filas; then
    # la imagen se dibuja en la primera fila (sin mover el cursor) y las demás quedan en blanco debajo
    reply=("${REPLY}${(l:_IMG_COLS:: :)}")
    for (( y = 2; y <= filas; y++ )); do reply+=("${(l:_IMG_COLS:: :)}"); done
    return 0
  fi
  (( $+commands[chafa] )) || return 1            # otras terminales: la foto hecha de bloques de colores
  _IMG_COLS=$(( filas * 2 ))
  for l in "${(@f)$(chafa -f symbols -c full -s ${_IMG_COLS}x${filas} --animate off --polite on "$1" 2>/dev/null)}"; do
    _rt_pad "${l}${RT_RESET}" $_IMG_COLS; reply+=("$REPLY")
  done
  (( ${#reply} )) || return 1
  while (( ${#reply} < filas )); do reply+=("${(l:_IMG_COLS:: :)}"); done
  return 0
}

_rt_logo_imagen() {   # $1 = imagen, $2 = filas → REPLY = la imagen lista para imprimir, _IMG_COLS = su ancho
  local src=${1/#\~/$HOME} png="" ws
  local -i filas=$2 W H
  [[ -r $src ]] || return 1
  case ${src:e:l} in mp4|webm|mkv|mov|m4v|avi) return 1 ;; esac
  if [[ $src == ${XDG_CONFIG_HOME:-$HOME/.config}/rice-perfil/avatar.png ]]; then
    png=$src                                  # ya es un PNG cuadrado y redondo (lo hace perfil.sh)
  elif (( $+commands[magick] || $+commands[convert] )); then
    png=$_RT_CACHE/logo-${${src//[^A-Za-z0-9._-]/_}[-80,-1]}.png
    if [[ ! -f $png || $src -nt $png ]]; then  # se recorta en cuadrado una sola vez (ImageMagick 7 o 6)
      local im=magick; (( $+commands[magick] )) || im=convert
      $im "${src}[0]" -auto-orient -resize '256x256^' -gravity center -extent 256x256 "$png" 2>/dev/null || return 1
    fi
  elif [[ ${src:e:l} == png ]]; then
    png=$src
  else
    return 1
  fi
  # cuántas columnas mide un cuadrado de <filas> de alto (las celdas no son cuadradas)
  _IMG_COLS=$(( filas * 21 / 10 ))
  if (( $+commands[kitten] )); then
    ws=$(kitten icat --print-window-size 2>/dev/null)
    if [[ $ws == (#b)([0-9]##)x([0-9]##) ]] && (( match[1] > 0 && _FILAS > 0 )); then
      W=$match[1]; H=$match[2]
      _IMG_COLS=$(( (filas * H * _COLS + W * _FILAS / 2) / (W * _FILAS) ))
    fi
  fi
  (( _IMG_COLS >= 4 && _IMG_COLS <= 40 )) || _IMG_COLS=$(( filas * 21 / 10 ))
  # a=T transmite y muestra · f=100 PNG · t=f lo lee del archivo · C=1 no mueve el cursor · q=2 sin respuestas
  REPLY=$'\e_Ga=T,f=100,t=f,c='"${_IMG_COLS}"',r='"${filas}"',C=1,q=2;'"$(print -rn -- $png | base64 -w0)"$'\e\\'
}

_rt_s_logo() {
  local -a logo der c1 c2 pintado
  local linea ch out wm=Hyprland v up ver="" modo img="" esc="" sub=""
  local term=${TERM_PROGRAM:-${${KITTY_WINDOW_ID:+kitty}:-${TERM%%-*}}}
  local avatar=${XDG_CONFIG_HOME:-$HOME/.config}/rice-perfil/avatar.png
  local -i y x n lw=0 t r g b _IMG_COLS=0 con_foto=0 fw=0
  local -a foto

  # ¿qué logo? (LOGO en panel.conf · se cambia con: bienvenida logo …)
  #   auto = tu foto de perfil + ZERO (o tu logo.txt) · foto = solo la foto · zero/arch/texto = sin foto
  modo=${LOGO:-auto}
  if [[ $modo == auto ]]; then
    [[ -r $avatar ]] && con_foto=1
    if [[ -r $_RT_DIR/logo.txt ]]; then modo=texto; else modo=zero; fi
  fi
  case $modo in
    foto)           img=$avatar ;;
    imagen:*)       img=${modo#imagen:} ;;
    /*|\~/*)        img=$modo ;;
  esac
  if [[ -n $img ]]; then
    if _rt_kitty && _rt_logo_imagen "$img" 7; then
      esc=$REPLY; lw=$_IMG_COLS
      pintado=("${esc}${(l:lw:: :)}")
      for (( y = 2; y <= 7; y++ )); do pintado+=("${(l:lw:: :)}"); done
    else
      modo=zero                                # sin imágenes (o sin la foto): el logo de texto
    fi
  fi

  if [[ -z $esc && $modo != ninguno ]]; then
    case $modo in
      texto)  [[ -r $_RT_DIR/logo.txt ]] && logo=("${(@f)$(<$_RT_DIR/logo.txt)}") ;;
      arch)   logo=(
                '        ▟▙        '
                '       ▟██▙       '
                '      ▟████▙      '
                '     ▟▀▜████▙     '
                '    ▟███▄▄███▙    '
                '   ▟████▛▜████▙   '
                '  ▟███▛▘  ▝▜███▙  '
                ' ▟██▛▘      ▝▜██▙ '
              ) ;;
    esac
    if (( ! ${#logo} )); then
      logo=(
        '███████╗███████╗██████╗  ██████╗ '
        '╚══███╔╝██╔════╝██╔══██╗██╔═══██╗'
        '  ███╔╝ █████╗  ██████╔╝██║   ██║'
        ' ███╔╝  ██╔══╝  ██╔══██╗██║   ██║'
        '███████╗███████╗██║  ██║╚██████╔╝'
        '╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ '
      )
    fi
    n=${#logo}
    for linea in $logo; do (( ${(m)#linea} > lw )) && lw=${(m)#linea}; done
    _rt_rgb "$RT_ACENTO";  c1=($reply)
    _rt_rgb "$RT_ACENTO2"; c2=($reply)

    # degradado en diagonal acento → acento2; los bloques (█ ▟ ▙ ▀ …) van en color
    # y las líneas (╗ ║ ═ …) como sombra: el mismo color, más oscuro
    for (( y = 1; y <= n; y++ )); do
      linea=${logo[y]}; out=""
      for (( x = 1; x <= ${#linea}; x++ )); do
        ch=${linea[x]}
        if [[ $ch == ' ' ]]; then out+=' '; continue; fi
        if (( ${#c1} == 3 && ${#c2} == 3 )); then
          t=$(( (x + y * 2) * 1000 / (lw + n * 2) ))
          r=$(( c1[1] + (c2[1] - c1[1]) * t / 1000 ))
          g=$(( c1[2] + (c2[2] - c1[2]) * t / 1000 ))
          b=$(( c1[3] + (c2[3] - c1[3]) * t / 1000 ))
          if [[ $ch == [▀-▟] ]]; then out+=$'\e[38;2;'"$r;$g;$b"m$ch
          else out+=$'\e[38;2;'"$(( r * 55 / 100 ));$(( g * 55 / 100 ));$(( b * 55 / 100 ))"m$ch; fi
        else
          if [[ $ch == [▀-▟] ]]; then out+=$RT_ACENTO$ch; else out+=$RT_TENUE$ch; fi
        fi
      done
      _rt_pad "$out$RT_RESET" $lw
      pintado+=("$REPLY")
    done
    # el subtítulo solo cabe debajo de los logos anchos
    if (( lw >= 29 )); then sub="${RT_TENUE}A R C H  ·  H Y P R L A N D${RT_RESET}"; fi
    if (( n < 7 )); then _rt_pad "$sub" $lw; pintado+=("$REPLY"); fi
  fi

  # tu foto de perfil a la izquierda del logo (Super + Shift + F la cambia)
  if (( con_foto && ${#pintado} )) && _rt_foto "$avatar" ${#pintado}; then
    foto=("${reply[@]}"); fw=$_IMG_COLS
    if (( _COLS >= fw + 2 + lw + 4 )); then     # solo si cabe junto al logo
      for (( y = 1; y <= ${#pintado}; y++ )); do pintado[y]="${foto[y]}  ${pintado[y]}"; done
      lw+=$(( fw + 2 ))
    fi
  fi

  # a la derecha: quién eres y en qué estás
  if (( $+commands[hyprctl] )) && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    v=$(hyprctl version 2>/dev/null); v=${v%%$'\n'*}
    [[ $v == (#b)Hyprland\ ([0-9.]##)* ]] && wm+=" $match[1]"
  fi
  _rt_tiempo_up; up=$REPLY
  [[ -r $_RT_ESTADO/version ]] && read -r ver < $_RT_ESTADO/version
  der=(
    "${RT_NEGRITA}${RT_ACENTO2}${USER}${RT_RESET}${RT_TENUE}@${RT_RESET}${RT_NEGRITA}${RT_ACENTO2}${_S[host]}${RT_RESET}"
    "${RT_TENUE}${(pl:30::─:)}${RT_RESET}"
    "${RT_ACENTO}"$'\uF303'"${RT_RESET}  ${RT_TEXTO}${_S[os]}${RT_RESET} ${RT_TENUE}· ${_S[kernel]}${RT_RESET}"
    "${RT_ACENTO}"$'\uF2D0'"${RT_RESET}  ${RT_TEXTO}${wm}${RT_RESET} ${RT_TENUE}· ${term} · zsh ${ZSH_VERSION}${RT_RESET}"
    "${RT_ACENTO}"$'\uF017'"${RT_RESET}  ${RT_TEXTO}${up}${RT_RESET} ${RT_TENUE}encendida · ${_S[pkgs]} paquetes${RT_RESET}"
    "${RT_ACENTO}●${RT_RESET} ${RT_ACENTO2}●${RT_RESET} ${RT_ROJO}●${RT_RESET} ${RT_VERDE}●${RT_RESET} ${RT_AMARILLO}●${RT_RESET} ${RT_AZUL}●${RT_RESET} ${RT_TEXTO}●${RT_RESET} ${RT_TENUE}●${RT_RESET}"
    "${RT_TENUE}zero-rice${ver:+ $ver}${RT_RESET}"
  )

  # ¿caben los datos a la derecha? (se mide su ancho real)
  local -i dw=0
  for out in $der; do _rt_ancho "$out"; (( REPLY > dw )) && dw=$REPLY; done

  _L+=("")
  if (( ! ${#pintado} )); then                   # LOGO=ninguno: solo los datos
    for out in $der; do _L+=("  $out"); done
  elif (( _COLS >= lw + 4 + dw )); then
    for (( y = 1; y <= ${#pintado} || y <= ${#der}; y++ )); do
      if (( y <= ${#pintado} )); then out=${pintado[y]}; else out=${(l:lw:: :)}; fi
      _L+=("  ${out}  ${der[y]:-}")
    done
  else
    for out in $pintado; do _L+=("  $out"); done
    _L+=("")
    for out in $der; do _L+=("  $out"); done
  fi
}

_rt_s_saludo() {
  local saludo nombre fecha clima d m dd
  local -a dias meses
  dias=(lunes martes miércoles jueves viernes sábado domingo)
  meses=(enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre)
  _rt_saludo_hora; saludo=$REPLY
  _rt_nombre; nombre=$REPLY
  strftime -s d '%u' $EPOCHSECONDS; strftime -s dd '%d' $EPOCHSECONDS; strftime -s m '%m' $EPOCHSECONDS
  fecha="${dias[d]} $(( 10#$dd )) de ${meses[$(( 10#$m ))]}"
  _L+=("" "  ${RT_NEGRITA}${RT_TEXTO}${saludo},${RT_RESET} ${RT_NEGRITA}${RT_ACENTO2}${nombre}${RT_RESET} ${RT_TENUE}— hoy es ${fecha}${RT_RESET}")
  if _rt_clima; then
    clima=$REPLY
    _rt_ancho "${_L[-1]}${clima}"
    if (( REPLY + 5 <= _W )); then _L[-1]+="  ${RT_TENUE}·${RT_RESET}  $clima"; else _L+=("  $clima"); fi
  fi
}

_rt_s_sistema() {
  local temp="" val bar ip="" dev="" ssid="" icono ts linea est="" cap="" usado total
  local -i pct
  local -a w bats
  _rt_seccion "Sistema"

  # CPU + temperatura (la misma lectura que la barra)
  [[ -x $_RT_SCRIPTS/temp.sh ]] && temp=$("$_RT_SCRIPTS/temp.sh" 2>/dev/null)
  val="${RT_TEXTO}${_S[cpu]}${RT_RESET} ${RT_TENUE}· ${_S[nucleos]} hilos${RT_RESET}"
  if [[ $temp == <1-> ]]; then _rt_color_pct $temp 70 85; val+="  ${REPLY}"$'\uF2C9'" ${temp}°C${RT_RESET}"; fi
  _rt_kv $'\uF2DB' "CPU" "$val"

  # carga: amarilla si pasa del 60 % de tus hilos, roja si los rebasa
  _rt_color_pct $(( ${_S[c1]%.*} * 100 / (${_S[nucleos]:-1} > 0 ? ${_S[nucleos]:-1} : 1) )) 60 100
  _rt_kv $'\U000F0E7C' "Carga" "${REPLY}${_S[c1]}${RT_RESET} ${RT_TENUE}${_S[c5]} ${_S[c15]}   (1, 5 y 15 min)${RT_RESET}"

  # RAM y swap
  pct=$(( _S[ram_u] * 100 / (_S[ram_t] > 0 ? _S[ram_t] : 1) ))
  _rt_color_pct $pct 70 88; _rt_barra $pct 20 $REPLY; bar=$REPLY
  printf -v usado '%.1f' $(( _S[ram_u] / 1048576.0 )); printf -v total '%.1f' $(( _S[ram_t] / 1048576.0 ))
  _rt_kv $'\U000F035B' "RAM" "$bar  ${RT_TEXTO}${(l:3:)pct}%${RT_RESET}  ${RT_TENUE}${usado} / ${total} GiB${RT_RESET}"
  if (( _S[swap_u] > 102400 && _S[swap_t] > 0 )); then
    pct=$(( _S[swap_u] * 100 / _S[swap_t] ))
    _rt_color_pct $pct 50 80; _rt_barra $pct 20 $REPLY; bar=$REPLY
    _rt_tam ${_S[swap_u]}
    _rt_kv $'\U000F0BE1' "Swap" "$bar  ${RT_TEXTO}${(l:3:)pct}%${RT_RESET}  ${RT_TENUE}${REPLY} usados${RT_RESET}"
  fi

  # batería (si es laptop)
  bats=(/sys/class/power_supply/BAT*(N))
  if (( ${#bats} )); then
    read -r cap < $bats[1]/capacity 2>/dev/null; read -r est < $bats[1]/status 2>/dev/null
    if [[ $cap == <-> ]]; then
      icono=$'\U000F0079'
      case $est in
        Charging)      est="cargando"; icono=$'\U000F0084' ;;
        Full)          est="llena" ;;
        Not\ charging) est="conectada" ;;
        *)             est="usando batería" ;;
      esac
      if   (( cap <= 20 )); then val=$RT_ROJO
      elif (( cap <= 40 )); then val=$RT_AMARILLO
      else val=$RT_VERDE; fi
      _rt_barra $cap 20 $val
      _rt_kv "$icono" "Batería" "$REPLY  ${RT_TEXTO}${(l:3:)cap}%${RT_RESET}  ${RT_TENUE}${est}${RT_RESET}"
    fi
  fi

  # red
  linea=$(ip -4 -o route get 1.1.1.1 2>/dev/null)
  w=(${=linea})
  (( ${w[(i)src]} < ${#w} )) && ip=${w[${w[(i)src]}+1]}
  (( ${w[(i)dev]} < ${#w} )) && dev=${w[${w[(i)dev]}+1]}
  if [[ -n $ip ]]; then
    if [[ -d /sys/class/net/$dev/wireless ]]; then
      icono=$'\uF1EB'
      (( $+commands[nmcli] )) && ssid=$(nmcli -g GENERAL.CONNECTION dev show "$dev" 2>/dev/null)
      val="${RT_TEXTO}Wi-Fi${RT_RESET}${ssid:+ ${RT_ACENTO2}«${ssid}»${RT_RESET}}"
    else
      icono=$'\U000F0200'; val="${RT_TEXTO}Cable${RT_RESET} ${RT_TENUE}(${dev})${RT_RESET}"
    fi
    val+=" ${RT_TENUE}·${RT_RESET} ${RT_TEXTO}${ip}${RT_RESET}"
    if (( ${+_P[tailscale]} && $+commands[tailscale] )); then
      ts=$(timeout 1 tailscale ip -4 2>/dev/null); ts=${ts%%$'\n'*}
      [[ -n $ts ]] && val+=" ${RT_TENUE}· tailscale${RT_RESET} ${RT_AZUL}${ts}${RT_RESET}"
    fi
    _rt_kv "$icono" "Red" "$val"
  else
    _rt_kv $'\U000F05AA' "Red" "${RT_ROJO}sin conexión${RT_RESET}  ${RT_TENUE}(Super + Shift + N abre el menú de red)${RT_RESET}"
  fi
}

_rt_s_discos() {
  local l mnt etq bar
  local -a w vistos
  local -i n=0 p
  _rt_seccion "Discos"
  for l in "${(@f)$(df -h --output=source,target,pcent,used,size -x tmpfs -x devtmpfs -x efivarfs -x overlay -x squashfs -x fuse.portal -x fuse.gvfsd-fuse 2>/dev/null)}"; do
    w=(${=l})
    (( ${#w} == 5 )) && [[ ${w[3]} == <->% ]] || continue
    mnt=${w[2]}
    [[ $mnt == (/run/*|/var/lib/docker*|/snap/*|/sys/*|/proc/*|/dev/*|/var/lib/containers*) ]] && continue
    (( ${vistos[(Ie)${w[1]}]} )) && continue     # btrfs: varios subvolúmenes del mismo disco salen una vez
    vistos+=(${w[1]})
    p=${w[3]%\%}
    _rt_corta "$mnt" 12; _rt_pad "$REPLY" 13; etq=$REPLY
    _rt_color_pct $p 75 90; _rt_barra $p 24 $REPLY; bar=$REPLY
    _L+=("  ${RT_ACENTO}"$'\uF0A0'"${RT_RESET} ${RT_TEXTO}${etq}${RT_RESET}${bar}  ${RT_TEXTO}${(l:3:)p}%${RT_RESET}  ${RT_TENUE}${w[4]}/${w[5]}${RT_RESET}")
    (( ++n >= ${DISCOS_MAX:-5} )) && break
  done
  (( n )) || _L+=("  ${RT_TENUE}(no pude leer los discos)${RT_RESET}")
}

_rt_s_rice() {
  local cfg=${XDG_CONFIG_HOME:-$HOME/.config} id="" nom="" fondo="" tipo="" barra=islas anim=zero efecto="" k v
  _rt_seccion "Tu rice"

  # paleta (el nombre bonito, no el id)
  [[ -r $cfg/rice-paletas/actual ]] && read -r id < $cfg/rice-paletas/actual
  if [[ -n $id ]]; then
    if _rt_buscar_id $cfg/rice-paletas/paletas.txt "$id" || _rt_buscar_id $cfg/rice-paletas/imagenes.txt "$id"; then nom=$REPLY
    else nom="sacada de tu fondo"; fi
  fi
  _rt_kv $'\U000F03D8' "Paleta" "${RT_ACENTO2}${nom:-sin elegir}${RT_RESET}  ${RT_TENUE}(Super + Shift + P la cambia)${RT_RESET}"

  # fondo
  [[ -r $cfg/wallpapers/.actual ]] && read -r fondo < $cfg/wallpapers/.actual
  case ${fondo:e:l} in
    mp4|webm|mkv|mov|m4v|avi) tipo="  ${RT_AZUL}▶ video${RT_RESET}" ;;
    gif)                      tipo="  ${RT_AZUL}GIF animado${RT_RESET}" ;;
  esac
  if [[ -n $fondo ]]; then _rt_corta "${fondo:t}" 44; else REPLY="generado por la paleta"; fi
  _rt_kv $'\uF03E' "Fondo" "${RT_TEXTO}${REPLY}${RT_RESET}${tipo}"

  # barra, animaciones y efecto 3D (con el nombre que usan los menús)
  [[ -r $cfg/rice-barra/estilo ]] && read -r barra < $cfg/rice-barra/estilo
  _rt_buscar_id $_RT_SCRIPTS/barra-estilo.sh "$barra" && barra=$REPLY
  if [[ -r $cfg/rice-animaciones/estado ]]; then
    while IFS='=' read -r k v; do [[ $k == estilo ]] && anim=$v; done < $cfg/rice-animaciones/estado
  fi
  _rt_buscar_id $_RT_SCRIPTS/animaciones.sh "$anim" && anim=$REPLY
  if [[ -r $cfg/rice-ws3d/estado ]]; then
    while IFS='=' read -r k v; do [[ $k == efecto ]] && efecto=$v; done < $cfg/rice-ws3d/estado
  fi
  [[ -n $efecto && $efecto != ninguno ]] && _rt_buscar_id $_RT_SCRIPTS/ws3d.sh "$efecto" && efecto=$REPLY
  _rt_kv $'\uF2D0' "Estilo" "${RT_TENUE}barra${RT_RESET} ${RT_TEXTO}${barra}${RT_RESET} ${RT_TENUE}· animaciones${RT_RESET} ${RT_TEXTO}${anim}${RT_RESET}${efecto:+ ${RT_TENUE}· 3D${RT_RESET} ${RT_TEXTO}${efecto}${RT_RESET}}"
}

_rt_s_corriendo() {
  local raw l id nom cls foc activo="" c piezas marca txt pz
  local -a parts orden ord2 lineas top srv
  local -A apps wsn cnt
  local -i ancho pw nd=0 malos=0
  _rt_seccion "Corriendo ahora"

  # ventanas abiertas, por workspace (● = donde estás)
  if (( $+commands[hyprctl] && $+commands[jq] )) && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    raw=$(hyprctl -j clients 2>/dev/null | jq -r '.[] | select(.mapped != false) | "\(.workspace.id)\t\(.workspace.name)\t\(.class // "")\t\(.focusHistoryID)"' 2>/dev/null)
    for l in ${(f)raw}; do
      parts=("${(@ps:\t:)l}")
      id=$parts[1]; nom=$parts[2]; cls=${${parts[3]:l}##*.}; foc=$parts[4]
      [[ -z $cls ]] && cls="ventana"
      [[ $foc == 0 ]] && activo=$id
      if (( ! ${+apps[$id]} )); then orden+=($id); wsn[$id]=$nom; apps[$id]=""; fi
      apps[$id]+="${cls}"$'\n'
    done
    for id in ${(n)${orden:#-*}} ${(M)orden:#-*}; do
      cnt=(); ord2=()
      for c in ${(f)apps[$id]}; do (( ${+cnt[$c]} )) || ord2+=($c); cnt[$c]=$(( ${cnt[$c]:-0} + 1 )); done
      if [[ $id == -* ]]; then nom=$'\uF005'" ${${wsn[$id]#special:}:-esp}"; else nom=$id; fi
      if [[ $id == $activo ]]; then marca="${RT_ACENTO}●${RT_RESET} ${RT_NEGRITA}${RT_ACENTO}"; else marca="${RT_TENUE}○${RT_RESET} ${RT_ACENTO2}"; fi
      _rt_pad "$nom" 3
      txt="  ${marca}${REPLY}${RT_RESET} "; _rt_ancho "$txt"; ancho=$REPLY; piezas=""
      for c in $ord2; do
        pz="${RT_TEXTO}${c}${RT_RESET}"; (( cnt[$c] > 1 )) && pz+="${RT_TENUE} ×${cnt[$c]}${RT_RESET}"
        _rt_ancho "$pz"; pw=$REPLY
        if (( ancho + pw + 3 > _W - 2 )); then piezas+=" ${RT_TENUE}…${RT_RESET}"; break; fi
        piezas+="${piezas:+ ${RT_TENUE}·${RT_RESET} }$pz"; ancho+=pw+3
      done
      _L+=("${txt}${piezas}")
    done
    (( ${#orden} )) || _L+=("  ${RT_TENUE}No hay ventanas abiertas (aparte de esta terminal).${RT_RESET}")
  fi

  # música
  if (( $+commands[playerctl] )); then
    raw=$(timeout 1 playerctl metadata --format '{{status}}|{{artist}}|{{title}}|{{playerName}}' 2>/dev/null)
    parts=("${(@s:|:)raw}")
    if [[ ${parts[1]:-} == (Playing|Paused) && -n ${parts[3]:-} ]]; then
      txt="${parts[3]}"; [[ -n ${parts[2]} ]] && txt="${parts[2]} — ${parts[3]}"
      _rt_corta "$txt" $(( _W - 26 )); txt=$REPLY
      marca=""; [[ ${parts[1]} == Paused ]] && marca="${RT_TENUE}(en pausa) "
      _L+=("  ${RT_ACENTO}"$'\uF001'"${RT_RESET}  ${RT_TEXTO}${txt}${RT_RESET}  ${marca}${RT_TENUE}${parts[4]}${RT_RESET}")
    fi
  fi

  # lo que más RAM usa (tus apps, sumando todos sus procesos)
  for c in ${(k)_M}; do lineas+=("${_M[$c]} $c"); done
  for l in ${${(On)lineas}[1,${PESADOS_MAX:-4}]}; do
    _rt_tam ${l%% *}
    top+=("${RT_TEXTO}${l#* }${RT_RESET} ${RT_TENUE}${REPLY}${RT_RESET}")
  done
  (( ${#top} )) && _L+=("  ${RT_ACENTO}"$'\U000F035B'"${RT_RESET}  ${RT_TENUE}más pesados:${RT_RESET} ${(pj: · :)top}")

  # servicios del rice: verde = corriendo · rojo = debería estar y no está
  _rt_srv() {   # $1 = clave, $2 = nombre, $3 = 1 si debe estar corriendo
    if (( ${+_P[$1]} )); then srv+=("${RT_VERDE}●${RT_RESET} ${RT_TEXTO}$2${RT_RESET}")
    elif (( $3 )); then srv+=("${RT_ROJO}○ $2${RT_RESET}"); fi
  }
  if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    _rt_srv barra barra 1; _rt_srv notificaciones notificaciones 1; _rt_srv hypridle "bloqueo auto" 1
    _rt_srv fondos fondo 1; _rt_srv portapapeles portapapeles 1; _rt_srv polkit polkit 0
    _rt_srv hyprsunset "luz nocturna" 0
  fi
  (( $+commands[tailscale] )) && _rt_srv tailscale tailscale 1
  (( $+commands[docker] ))    && _rt_srv docker docker 0
  unfunction _rt_srv
  if (( ${#srv} )); then
    _L+=("  ${RT_ACENTO}"$'\uF013'"${RT_RESET}  ${RT_TENUE}servicios:${RT_RESET}")
    _rt_envolver "     " "${srv[@]}"
    [[ ${(j::)srv} == *○* ]] && _L+=("     ${RT_TENUE}lo rojo no está corriendo · la barra se levanta con Super + B${RT_RESET}")
  fi

  # contenedores de docker (como en tu NAS)
  if (( ${+_P[docker]} && $+commands[docker] )) && [[ -w /var/run/docker.sock ]]; then
    raw=$(timeout 2 docker ps -a --format '{{.Names}}\t{{.State}}\t{{.Status}}' 2>/dev/null)
    for l in ${(f)raw}; do
      parts=("${(@ps:\t:)l}")
      txt=${parts[3]}
      txt=${txt//Up /arriba }; txt=${txt//Exited /detenido }; txt=${txt//Created/creado}
      txt=${txt//About an hour/una hora}; txt=${txt//About a minute/un minuto}; txt=${txt//Less than a second/un segundo}
      txt=${txt//seconds/segundos}; txt=${txt//minutes/minutos}; txt=${txt//hours/horas}; txt=${txt//days/días}
      txt=${txt//weeks/semanas}; txt=${txt//months/meses}; txt=${txt// ago/}; txt=${txt//\(healthy\)/(sano)}
      if [[ ${parts[2]} == running ]]; then marca="${RT_VERDE}●"; else marca="${RT_ROJO}○"; (( malos++ )); fi
      if (( nd < ${DOCKER_MAX:-8} )); then
        (( nd == 0 )) && _L+=("  ${RT_ACENTO}"$'\uF308'"${RT_RESET}  ${RT_TENUE}contenedores:${RT_RESET}")
        _rt_pad "${parts[1]}" 26
        _L+=("     ${marca}${RT_RESET} ${RT_TEXTO}${REPLY}${RT_RESET}${RT_TENUE}${txt}${RT_RESET}")
      fi
      (( nd++ ))
    done
    (( nd > ${DOCKER_MAX:-8} )) && _L+=("     ${RT_TENUE}…y $(( nd - ${DOCKER_MAX:-8} )) más  (docker ps -a)${RT_RESET}")
    (( malos )) && _S[docker_malos]=$malos
  fi
}

# ── tus comandos: alias, funciones y scripts que tú hiciste ──
_rt_mis_comandos() {   # $1 = "rapido" (solo nombres) → reply = ("tipo|nombre|detalle" ...)
  emulate -L zsh; setopt extended_glob
  local f linea prev nom det dos tipo
  local -a archivos vistos ocultar
  local -i k
  reply=()
  ocultar=(${=OCULTAR_COMANDOS:-} bienvenida comandos pendiente zero ff
           precmd preexec chpwd periodic zshexit zshaddhistory command_not_found_handler TRAPINT TRAPEXIT)
  archivos=(${ZDOTDIR:-$HOME}/.zshrc(N) $HOME/.zsh_aliases(N) $HOME/.aliases(N) $HOME/.zsh_functions(N)
            ${XDG_CONFIG_HOME:-$HOME/.config}/zsh/**/*.zsh(N) $HOME/.zshrc.d/*(N.))
  for f in ${(u)archivos}; do
    prev=""
    for linea in "${(@f)$(<$f)}"; do
      nom=""; det=""
      if [[ $linea == (#b)[[:space:]]#alias[[:space:]]##(-[a-zA-Z]##[[:space:]]##)#([^=[:space:]]##)=(*) ]]; then
        nom=$match[2]; det=${match[3]%%[[:space:]]##\#*}; det=${${det#[\'\"]}%[\'\"]}; tipo=alias
      elif [[ $linea == (#b)[[:space:]]#(function[[:space:]]##|)([A-Za-z][A-Za-z0-9_.:-]#)[[:space:]]#\(\)* ]]; then
        nom=$match[2]; tipo=función
      elif [[ $linea == (#b)[[:space:]]#function[[:space:]]##([A-Za-z][A-Za-z0-9_.:-]#)[[:space:]]#(\{*|) ]]; then
        nom=$match[1]; tipo=función
      fi
      if [[ -n $nom && $nom != zle-* ]] && (( ! ${vistos[(Ie)$nom]} && ! ${ocultar[(Ie)$nom]} )); then
        if [[ $tipo == función ]]; then
          [[ $linea == *\#[[:space:]]* ]] && det=${linea##*\#[[:space:]]#}
          [[ -z $det && $prev == [[:space:]]#\#* ]] && det=${prev##[[:space:]]#\#[[:space:]]#}
        fi
        vistos+=($nom); reply+=("$tipo|$nom|$det")
      fi
      prev=$linea
    done
  done
  for f in $HOME/.local/bin/*(N-*) $HOME/bin/*(N-*); do
    nom=${f:t}
    (( ${vistos[(Ie)$nom]} || ${ocultar[(Ie)$nom]} )) && continue
    det=""
    if [[ ${1:-} != rapido && -r $f ]]; then
      dos=""; IFS= read -r dos < $f 2>/dev/null
      if [[ $dos == '#!'* ]]; then
        k=0
        while IFS= read -r linea && (( ++k <= 6 )); do
          [[ $linea == \#!* || $linea == \#[[:space:]]#(shellcheck*|-\*-*|) ]] && continue
          [[ $linea == \#* ]] && { det=${${linea##\#[[:space:]]#}#${nom}(.sh|) — }; break; }
        done < $f
      fi
    fi
    vistos+=($nom); reply+=("script|$nom|$det")
  done
}

_rt_s_comandos() {
  local e tipo nom c
  local -a piezas
  local -i total antes
  _rt_seccion "Tus comandos"
  _rt_mis_comandos rapido
  total=${#reply}
  for e in $reply; do
    tipo=${e%%|*}; nom=${${e#*|}%%|*}
    case $tipo in alias) c=$RT_ACENTO2 ;; función) c=$RT_ACENTO ;; *) c=$RT_VERDE ;; esac
    piezas+=("${c}${nom}${RT_RESET}")
  done
  if (( total )); then
    antes=${#_L}
    _rt_envolver "  " "${piezas[@]}"
    if (( ${#_L} - antes > 3 )); then
      _L=("${(@)_L[1,$(( antes + 3 ))]}")
      _L[-1]+="  ${RT_TENUE}…${RT_RESET}"
    fi
    _L+=("  ${RT_ACENTO2}■${RT_TENUE} alias  ${RT_ACENTO}■${RT_TENUE} funciones  ${RT_VERDE}■${RT_TENUE} scripts  ·  ${total} en total — ${RT_TEXTO}comandos${RT_TENUE} te dice qué hace cada uno${RT_RESET}")
  else
    _L+=("  ${RT_TENUE}Todavía no tienes alias ni scripts propios (en ~/.zshrc o ~/.local/bin).${RT_RESET}")
  fi
  _L+=("  ${RT_TENUE}del rice:${RT_RESET} ${RT_TEXTO}zero paleta${RT_TENUE} · ${RT_TEXTO}zero fondo${RT_TENUE} · ${RT_TEXTO}zero barra${RT_TENUE} · ${RT_TEXTO}zero clima${RT_TENUE} · ${RT_TEXTO}pendiente${RT_TENUE} · ${RT_TEXTO}zero${RT_TENUE} (todos)${RT_RESET}")
}

_rt_s_pendientes() {
  local f=$_RT_CACHE/actualizaciones k v l
  local -A act
  local -i n=0 i=0 ahora=$EPOCHSECONDS
  local -a notas fl w
  _rt_seccion "Pendientes"

  # actualizaciones (las revisa _rt_revisar_actualizaciones en segundo plano)
  if [[ -r $f ]]; then
    while IFS='=' read -r k v; do act[$k]=$v; done < $f
    n=$(( ${act[repo]:-0} + ${act[aur]:-0} ))
    if (( n > 0 )); then
      l="${RT_AMARILLO}"$'\uF021'" ${n} actualizaciones${RT_RESET}"
      (( ${act[aur]:-0} > 0 )) && l+=" ${RT_TENUE}(${act[aur]} del AUR)${RT_RESET}"
      l+=" ${RT_TENUE}— ${${act[ayudante]:-}:-sudo pacman -Syu}${RT_RESET}"
      _L+=("  $l")
    else
      _L+=("  ${RT_VERDE}✔ Todo actualizado${RT_RESET}")
    fi
  elif (( ! $+commands[checkupdates] )); then
    _L+=("  ${RT_TENUE}"$'\uF021'" Para ver tus actualizaciones aquí: sudo pacman -S pacman-contrib${RT_RESET}")
  elif (( ${REVISAR_ACTUALIZACIONES:-1} )); then
    _L+=("  ${RT_TENUE}"$'\uF021'" Revisando actualizaciones… (salen en la próxima terminal)${RT_RESET}")
  else
    _L+=("")
  fi
  # la última vez que actualizaste todo
  if (( ${_S[pac_ultima]:-0} > 0 )); then
    _rt_hace $(( ahora - _S[pac_ultima] ))
    if (( ahora - _S[pac_ultima] > 14 * 86400 )); then _L[-1]+="   ${RT_AMARILLO}⚠ último -Syu: ${REPLY}${RT_RESET}"
    else _L[-1]+="   ${RT_TENUE}último -Syu: ${REPLY}${RT_RESET}"; fi
  fi
  (( ${_S[pac_huerfanos]:-0} > 0 )) && _L+=("  ${RT_AMARILLO}⚠ ${_S[pac_huerfanos]} paquetes huérfanos${RT_RESET} ${RT_TENUE}— sudo pacman -Rns \$(pacman -Qdtq)${RT_RESET}")

  # servicios caídos
  fl=(${(f)"$(systemctl --failed --no-legend --plain 2>/dev/null)"} ${(f)"$(systemctl --user --failed --no-legend --plain 2>/dev/null)"})
  (( ${#fl} )) && _L+=("  ${RT_ROJO}"$'\uF00D'" ${#fl} servicio(s) fallaron${RT_RESET} ${RT_TENUE}— ${${fl[1]##[[:space:]]#}%% *}  (systemctl --failed)${RT_RESET}")
  (( ${_S[docker_malos]:-0} )) && _L+=("  ${RT_AMARILLO}⚠ ${_S[docker_malos]} contenedor(es) sin correr${RT_RESET} ${RT_TENUE}— revisa con: docker logs <nombre>${RT_RESET}")

  # disco casi lleno
  for l in "${(@f)$(df --output=pcent,target -x tmpfs -x devtmpfs -x efivarfs -x overlay -x squashfs 2>/dev/null)}"; do
    w=(${=l}); [[ ${w[1]:-} == <->% ]] || continue
    (( ${w[1]%\%} >= 90 )) && [[ ${w[2]} != (/run/*|/var/lib/docker*|/snap/*) ]] &&
      _L+=("  ${RT_ROJO}⚠ ${w[2]} está al ${w[1]}${RT_RESET} ${RT_TENUE}— libera espacio: sudo pacman -Sc · ncdu ${w[2]}${RT_RESET}")
  done

  # tus notas (pendiente "texto")
  [[ -r $_RT_DIR/pendientes.txt ]] && notas=(${(f)"$(<$_RT_DIR/pendientes.txt)"})
  for l in $notas; do
    (( ++i ))
    _L+=("  ${RT_ACENTO}"$'\uF096'"${RT_RESET} ${RT_TEXTO}${l}${RT_RESET} ${RT_TENUE}(${i})${RT_RESET}")
  done
  (( i )) && _L+=("    ${RT_TENUE}pendiente hecho <número> para tacharlo${RT_RESET}")
  [[ -z ${_L[-1]} ]] && _L[-1]="  ${RT_VERDE}✔ Nada pendiente${RT_RESET}"
}

_rt_s_frase() {
  local -a frases tips
  frases=(
    "Bienvenido de vuelta al cuartel general."
    "Hoy no se rompe nada… o eso dice el changelog."
    "En Arch no se instala, se construye."
    "Funciona en mi máquina. Y mi máquina es esta."
    "Primero haz que funcione, luego haz que se vea chido."
    "Un rice nunca se termina: solo se publica."
    "sudo pacman -Syu y que sea lo que Dios quiera."
    "La terminal es el único lugar donde menos clics es más poder."
    "Lee el log antes de culpar al kernel."
    "Cada error es un tutorial que nadie había escrito."
    "Si funciona, haz commit. Si no, también."
    "El que respalda no llora."
    "Hoy es buen día para borrar un paquete huérfano."
    "Los dotfiles son el diario de un programador."
    "No es un bug, es una paleta que todavía no existe."
    "Todo lo que necesitas cabe en ~/.config."
    "Arch: porque leer la wiki también es deporte."
    "El mejor atajo es el que ya te sabes de memoria."
    "Que tu uptime sea largo y tus kernel panics cortos."
    "Escribe el script hoy, ahórrate la chamba mañana."
    "La consola no juzga. Solo ejecuta."
    "git push y a dormir. Bueno, primero el push."
    "Una buena paleta arregla cualquier día."
    "Menos bloat, más flow."
    "Si lo haces dos veces, hazlo script."
  )
  tips=(
    "Super + Shift + P cambia la paleta de todo el escritorio."
    "Super + Alt + P pone una paleta al azar."
    "Super + W elige fondo; también acepta videos y GIF."
    "Super + Shift + B cambia el estilo de la barra."
    "Super + Shift + A elige el estilo de las animaciones."
    "Super + Shift + E cambia el efecto 3D de los workspaces."
    "Super + A abre el panel de control."
    "Super + Shift + V es tu historial del portapapeles."
    "Super + Shift + S captura un área de la pantalla."
    "Super + Shift + L personaliza la pantalla de bloqueo."
    "Super + Shift + F cambia tu foto de perfil y tu nombre."
    "Super + Shift + C cambia la ciudad del clima."
    "pendiente \"comprar SSD\" lo agrega a este panel."
    "comandos te enseña todos tus alias y scripts."
    "bienvenida editar elige qué secciones salen aquí."
    "bienvenida logo arch cambia el logo (o foto, zero, imagen /ruta)."
    "zero actualizar baja lo último de zero-rice."
    "tus frases van en ~/.config/rice-terminal/frases.txt"
  )
  [[ -r $_RT_DIR/frases.txt ]] && frases+=(${(f)"$(<$_RT_DIR/frases.txt)"})
  frases=(${frases:#[[:space:]]#(\#*|)})
  _L+=("" "  ${RT_ACENTO}»${RT_RESET} ${RT_ACENTO2}${frases[$(( RANDOM % ${#frases} + 1 ))]}${RT_RESET}")
  _L+=("  ${RT_TENUE}"$'\uF0EB'" ${tips[$(( RANDOM % ${#tips} + 1 ))]}${RT_RESET}")
}

_rt_conf_migrar() {   # la 0.7.0 traía más secciones por defecto: si nunca las cambiaste, pasan a las nuevas
  local conf=$_RT_DIR/panel.conf c
  [[ -r $conf ]] || return 0
  c=$(<$conf)
  [[ $c == *'SECCIONES="logo saludo sistema discos rice corriendo comandos pendientes frase"'* || $c == *'SECCIONES_COMPACTO="saludo sistema corriendo pendientes frase"'* ]] || return 0
  c=${c//'SECCIONES="logo saludo sistema discos rice corriendo comandos pendientes frase"'/'SECCIONES="logo sistema discos comandos pendientes"'}
  c=${c//'SECCIONES_COMPACTO="saludo sistema corriendo pendientes frase"'/'SECCIONES_COMPACTO="sistema discos pendientes"'}
  c=${c//'FILAS_COMPACTO=40'/'FILAS_COMPACTO=28'}
  print -r -- "$c" > $conf.tmp && mv -f $conf.tmp $conf
}

_rt_panel() {
  emulate -L zsh
  setopt extended_glob no_monitor no_notify no_bg_nice
  zmodload -F zsh/datetime b:strftime p:EPOCHSECONDS 2>/dev/null
  _rt_colores
  local $_RT_CONF_VARS
  local s lista
  local -a _L sz
  local -A _S _P _M
  local -i _W _COLS=80 _FILAS=40

  [[ -d $_RT_CACHE ]] || mkdir -p $_RT_CACHE
  [[ -f $_RT_DIR/panel.conf ]] || { mkdir -p $_RT_DIR && _rt_conf_default > $_RT_DIR/panel.conf; }
  _rt_conf_migrar
  source $_RT_DIR/panel.conf 2>/dev/null
  : ${SECCIONES:="logo sistema discos comandos pendientes"}

  sz=(${=$({ stty size < /dev/tty; } 2>/dev/null)})
  (( ${#sz} == 2 )) && { _FILAS=${sz[1]}; _COLS=${sz[2]}; }
  _W=$(( _COLS - 2 < ${ANCHO:-80} ? _COLS - 2 : ${ANCHO:-80} ))
  lista=$SECCIONES
  (( _FILAS < ${FILAS_COMPACTO:-28} )) && lista=${SECCIONES_COMPACTO:-"sistema discos pendientes"}

  _rt_leer_sistema
  _rt_leer_procesos
  (( $+commands[pacman] )) && _rt_info_pacman
  _rt_revisar_actualizaciones

  for s in ${=lista}; do (( $+functions[_rt_s_$s] )) && _rt_s_$s; done
  _L+=("")
  print -rl -- "${_L[@]}"
}

_rt_mostrar() {
  case "$1" in
    panel)  _rt_panel ;;
    info)   _rt_info ;;
    saludo) _rt_saludo ;;
    *)      ;;
  esac
}

bienvenida() {
  case "${1:-}" in
    panel|info|saludo|off)
      mkdir -p "$_RT_DIR"; print -r -- "$1" > "$_RT_DIR/modo"
      print -r -- "Al abrir la terminal: $1"; _rt_mostrar "$1" ;;
    editar|config)
      [[ -f "$_RT_DIR/panel.conf" ]] || { mkdir -p "$_RT_DIR"; _rt_conf_default > "$_RT_DIR/panel.conf"; }
      ${EDITOR:-nvim} "$_RT_DIR/panel.conf" ;;
    logo)
      local valor="" conf="$_RT_DIR/panel.conf" l
      local -a lineas
      case "${2:-}" in
        auto|foto|zero|arch|texto|ninguno) valor=$2 ;;
        imagen)
          [[ -r "${3:-}" ]] || { print -r -- "Uso: bienvenida logo imagen /ruta/a/tu-imagen.png   (png, jpg, webp o gif)"; return 1; }
          valor="imagen:${3:A}" ;;
        *)
          print -r -- "Uso: bienvenida logo auto | foto | zero | arch | texto | ninguno | imagen /ruta"
          print -r -- "  auto  = tu foto de perfil + ZERO   (la foto se cambia con Super + Shift + F)"
          print -r -- "  foto  = solo la foto · zero/arch/texto = sin foto · imagen = una imagen tuya"
          print -r -- "  En kitty sale la foto de verdad; en otras terminales, hecha de bloques si tienes chafa."
          return 1 ;;
      esac
      [[ -f "$conf" ]] || { mkdir -p "$_RT_DIR"; _rt_conf_default > "$conf"; }
      lineas=("${(@f)$(<$conf)}")
      if (( ${lineas[(I)LOGO=*]} )); then
        lineas[${lineas[(I)LOGO=*]}]="LOGO=\"${valor}\""
      else
        lineas+=("" "# Logo: auto · foto · zero · arch · texto · ninguno · imagen:/ruta" "LOGO=\"${valor}\"")
      fi
      print -rl -- "${lineas[@]}" > "$conf"
      print -r -- "Logo: ${valor}"
      _rt_panel ;;
    ""|mostrar) _rt_mostrar "$(_rt_modo)" ;;
    *) print -r -- "Uso: bienvenida [panel|info|saludo|off|editar|logo]" ;;
  esac
}

# ════════════════════════════ comandos extra ════════════════════════════

comandos() {   # tus alias, funciones y scripts, con lo que hace cada uno
  emulate -L zsh; setopt extended_glob
  _rt_colores
  local $_RT_CONF_VARS
  local e tipo nom det titulo
  local -a todos de
  [[ -r $_RT_DIR/panel.conf ]] && source $_RT_DIR/panel.conf 2>/dev/null
  _rt_mis_comandos
  todos=($reply)
  for tipo titulo in alias "Tus alias" función "Tus funciones" script "Tus scripts (~/.local/bin)"; do
    de=(${(M)todos:#${tipo}\|*})
    (( ${#de} )) || continue
    print -rl -- "" "  ${RT_ACENTO}── ${RT_NEGRITA}${titulo}${RT_RESET}"
    for e in $de; do
      nom=${${e#*|}%%|*}; det=${e#*|*|}
      _rt_pad "$nom" 18
      print -r -- "  ${RT_ACENTO2}${REPLY}${RT_RESET} ${RT_TENUE}${det}${RT_RESET}"
    done
  done
  print -rl -- "" "  ${RT_ACENTO}── ${RT_NEGRITA}Del rice${RT_RESET}  ${RT_TENUE}(zero <cosa>)${RT_RESET}"
  zero
  print
}

pendiente() {   # pendientes que salen en el panel
  emulate -L zsh
  local f=$_RT_DIR/pendientes.txt
  local -a l
  local -i i
  mkdir -p $_RT_DIR; [[ -f $f ]] && l=(${(f)"$(<$f)"})
  case "${1:-}" in
    "")       (( ${#l} )) || { print -r -- "Sin pendientes. Agrega uno: pendiente \"texto\""; return 0; }
              for (( i = 1; i <= ${#l}; i++ )); do print -r -- "  $i. ${l[i]}"; done ;;
    hecho|listo|-d)
              [[ ${2:-} == <1-> ]] && (( $2 <= ${#l} )) || { print -r -- "Uso: pendiente hecho <número>"; return 1; }
              print -r -- "✔ ${l[$2]}"; l[$2]=(); print -rl -- $l > $f ;;
    limpiar)  : > $f; print -r -- "Pendientes borrados." ;;
    *)        print -r -- "$*" >> $f; print -r -- "Agregado: $*" ;;
  esac
}

zero() {   # atajos del rice desde la terminal
  local s=$_RT_SCRIPTS cmd=${1:-} repo="" v="?"
  local -a l
  local -i i
  (( $# )) && shift
  case $cmd in
    paleta)      if (( $# )); then "$s/paleta.sh" "$@"; else "$s/paleta.sh" menu; fi ;;
    paletas)     "$s/paleta.sh" lista ;;
    fondo)       if (( $# )); then "$s/wall.sh" "$@"; else "$s/wall.sh" menu; fi ;;
    barra)       case ${1:-} in
                   reiniciar|parar|log) "$s/barra.sh" "$@" ;;
                   "") "$s/barra-estilo.sh" menu ;;
                   *)  "$s/barra-estilo.sh" "$@" ;;
                 esac ;;
    anim|animaciones) if (( $# )); then "$s/animaciones.sh" "$@"; else "$s/animaciones.sh" menu; fi ;;
    3d)          if (( $# )); then "$s/ws3d.sh" "$@"; else "$s/ws3d.sh" menu; fi ;;
    clima)       if (( $# )); then "$s/clima.sh" "$@"; else "$s/clima.sh" ver; fi ;;
    perfil)      if (( $# )); then "$s/perfil.sh" "$@"; else "$s/perfil.sh" menu; fi ;;
    red)         "$s/red.sh" "$@" ;;
    lock|bloquear) "$s/zero-lock.sh" lock ;;
    bloqueo)     "$s/zero-lock.sh" "$@" ;;
    captura)     if (( $# )); then "$s/captura.sh" "$@"; else "$s/captura.sh" area; fi ;;
    panel)       _rt_panel ;;
    actualizar)  [[ -r $_RT_ESTADO/repo ]] && read -r repo < $_RT_ESTADO/repo
                 [[ -x $repo/install.sh ]] || repo=$HOME/zero-rice
                 if [[ -x $repo/install.sh ]]; then "$repo/install.sh" --actualizar "$@"
                 else print -r -- "No encontré tu copia de zero-rice. Ve a la carpeta del repo y corre: ./install.sh --actualizar"; return 1; fi ;;
    version)     [[ -r $_RT_ESTADO/version ]] && read -r v < $_RT_ESTADO/version; print -r -- "zero-rice $v" ;;
    ""|ayuda|-h|--help)
      _rt_colores
      l=(
        "paleta [id|siguiente|aleatoria]" "cambia la paleta (sin nada: el menú)"
        "paletas"                         "todas las paletas en la terminal"
        "fondo [ruta|aleatorio]"          "fondo de pantalla (imagen, GIF o video)"
        "barra [estilo|reiniciar|log]"    "estilo de la barra, reiniciarla o ver su log"
        "anim"                            "estilo de las animaciones"
        "3d"                              "efecto 3D de los workspaces"
        "clima [ciudad]"                  "el clima de hoy (o cambiar de ciudad)"
        "perfil"                          "foto de perfil y nombre"
        "red"                             "menú de red"
        "lock · bloqueo"                  "bloquear ya · personalizar el bloqueo"
        "captura [area|pantalla|ventana]" "captura de pantalla"
        "panel"                           "volver a mostrar el panel de bienvenida"
        "actualizar · version"            "bajar lo último de zero-rice · ver tu versión"
      )
      for (( i = 1; i < ${#l}; i += 2 )); do
        _rt_pad "zero ${l[i]}" 38
        print -r -- "  ${RT_TEXTO}${REPLY}${RT_RESET}${RT_TENUE}${l[i+1]}${RT_RESET}"
      done ;;
    *) print -r -- "zero: no conozco «$cmd». Escribe zero para ver la lista."; return 1 ;;
  esac
}

(( $+commands[fastfetch] )) && (( ! $+aliases[ff] )) && alias ff='fastfetch'

# ¿toca mostrarla ahora?
_rt_debe() {
  [[ -o interactive && -t 1 ]] || return 1
  [[ -n "${RICE_BIENVENIDA_HECHA:-}" ]] && return 1                       # ya salió en esta ventana
  [[ -n "${TMUX:-}${NVIM:-}${INSIDE_NVIM:-}${VIM_TERMINAL:-}${INSIDE_EMACS:-}" ]] && return 1
  local filas cols
  read -r filas cols < <({ stty size < /dev/tty; } 2>/dev/null) || return 1
  (( ${filas:-0} >= 20 && ${cols:-0} >= 60 )) || return 1                 # ventana muy chica: no estorba
  return 0
}

if _rt_debe; then
  export RICE_BIENVENIDA_HECHA=1
  _rt_mostrar "$(_rt_modo)"
fi
