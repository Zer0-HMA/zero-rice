# bienvenida.zsh — lo que se ve al abrir una terminal   (zero-rice)
#
# Se carga desde ~/.zshrc, en la PRIMERA línea (antes del bloque "instant prompt" de Powerlevel10k).
#   bienvenida              → la muestra ahora
#   bienvenida info         → logo + datos del sistema + tu paleta (fastfetch con tus colores)
#   bienvenida saludo       → una línea: saludo, clima, tiempo encendida y RAM
#   bienvenida off          → no mostrar nada al abrir
#   ff                      → fastfetch completo
# Solo sale en la ventana nueva (no en subshells, tmux, nvim, ni en ventanas muy chicas).

_RT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rice-terminal"
_RT_SCRIPTS="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"

_rt_modo() { local m=info; [[ -r "$_RT_DIR/modo" ]] && read -r m < "$_RT_DIR/modo"; print -r -- "${m:-info}"; }

_rt_info() {
  command -v fastfetch >/dev/null 2>&1 || { print -r -- "Instala fastfetch:  sudo pacman -S fastfetch"; return 1; }
  if [[ -r "$_RT_DIR/fastfetch.jsonc" ]]; then fastfetch -c "$_RT_DIR/fastfetch.jsonc"; else fastfetch; fi
}

_rt_saludo() {
  [[ -r "$_RT_DIR/colores.zsh" ]] && source "$_RT_DIR/colores.zsh"
  local h saludo seg up mem cf k v icono desc linea2
  local i_arch=$'\uF303' i_up=$'\U000F051B' i_ram=$'\U000F035B'
  local -A cl
  h=$(date +%H); h=$((10#$h))
  if   (( h >= 5  && h < 12 )); then saludo="Buenos días"
  elif (( h >= 12 && h < 19 )); then saludo="Buenas tardes"
  else                               saludo="Buenas noches"; fi

  read -r seg _ < /proc/uptime; seg=${seg%.*}
  if   (( seg >= 86400 )); then up="$((seg / 86400)) d $(( (seg % 86400) / 3600 )) h"
  elif (( seg >= 3600  )); then up="$((seg / 3600)) h $(( (seg % 3600) / 60 )) min"
  else                          up="$((seg / 60)) min"; fi
  mem=$(awk '/^MemTotal/{t=$2} /^MemAvailable/{a=$2} END{printf "%d", 100*(t-a)/t}' /proc/meminfo)

  # clima: lo guarda clima.sh (el mismo del lanzador); si no hay, simplemente no se muestra
  cf="${XDG_CONFIG_HOME:-$HOME/.config}/rice-clima/actual"
  if [[ -r "$cf" ]]; then
    while IFS='=' read -r k v; do [[ "$k" =~ '^[a-z]+$' ]] && cl[$k]=$v; done < "$cf"
    if [[ -n "${cl[temp]:-}" && -n "${cl[codigo]:-}" && -x "$_RT_SCRIPTS/clima.sh" ]]; then
      IFS='|' read -r icono desc <<< "$("$_RT_SCRIPTS/clima.sh" describir "${cl[codigo]}" "${cl[dia]:-1}" 2>/dev/null)"
      linea2="${RT_ACENTO}${icono}${RT_RESET} ${RT_TEXTO}${cl[temp]}°${RT_RESET} ${RT_TENUE}${desc} · ${cl[ciudad]%%,*}${RT_RESET}     "
    fi
  fi
  linea2+="${RT_ACENTO}${i_up}${RT_RESET} ${RT_TENUE}encendida ${up}${RT_RESET}     ${RT_ACENTO}${i_ram}${RT_RESET} ${RT_TENUE}RAM ${mem}%${RT_RESET}"

  print -r -- ""
  print -r -- "  ${RT_ACENTO}${i_arch}${RT_RESET}  ${RT_TEXTO}${saludo},${RT_RESET} ${RT_ACENTO2}${USER:-${LOGNAME:-$(id -un)}}${RT_RESET}"
  print -r -- "  ${linea2}"
  print -r -- ""
}

_rt_mostrar() {
  case "$1" in
    info)   _rt_info ;;
    saludo) _rt_saludo ;;
    *)      ;;
  esac
}

bienvenida() {
  case "${1:-}" in
    info|saludo|off)
      mkdir -p "$_RT_DIR"; print -r -- "$1" > "$_RT_DIR/modo"
      print -r -- "Al abrir la terminal: $1"; _rt_mostrar "$1" ;;
    ""|mostrar) _rt_mostrar "$(_rt_modo)" ;;
    *) print -r -- "Uso: bienvenida [info|saludo|off]" ;;
  esac
}
(( $+commands[fastfetch] )) && (( ! $+aliases[ff] )) && alias ff='fastfetch'

# ¿toca mostrarla ahora?
_rt_debe() {
  [[ -o interactive && -t 1 ]] || return 1
  [[ -n "${RICE_BIENVENIDA_HECHA:-}" ]] && return 1                       # ya salió en esta ventana
  [[ -n "${TMUX:-}${NVIM:-}${INSIDE_NVIM:-}${VIM_TERMINAL:-}${INSIDE_EMACS:-}" ]] && return 1
  local filas cols
  read -r filas cols < <(stty size < /dev/tty 2>/dev/null) || return 1
  (( ${filas:-0} >= 20 && ${cols:-0} >= 60 )) || return 1                 # ventana muy chica: no estorba
  return 0
}

if _rt_debe; then
  export RICE_BIENVENIDA_HECHA=1
  _rt_mostrar "$(_rt_modo)"
fi
