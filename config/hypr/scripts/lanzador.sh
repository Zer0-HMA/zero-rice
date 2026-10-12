#!/usr/bin/env bash
# lanzador.sh — abre rofi con el panel de saludo, reloj, clima y estadísticas de tu PC
#   lanzador.sh             → apps
#   lanzador.sh run         → comandos
#   lanzador.sh filebrowser → archivos
pkill -x rofi && exit 0

modo=${1:-drun}
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
S="$CFG/hypr/scripts"
DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zero-rice/lanzador"
PANEL="$DIR/panel.png"
# shellcheck source=lib/fondoactual.sh
source "$S/lib/fondoactual.sh" 2>/dev/null || fondo_actual() { cat "$CFG/wallpapers/.actual" 2>/dev/null; }

# escala del monitor (para que el panel se vea nítido en pantallas HiDPI)
escala=$(hyprctl monitors 2>/dev/null | awk '/focused: yes/{f=1} /scale:/{s=$2} f&&s{print s; exit}')
escala=${escala:-1}; [[ "$escala" == 1.00 || "$escala" == 1.0 ]] && escala=1

fondo=$(fondo_actual)

# el panel se reusa solo si es reciente (mismo minuto, <20 s) Y se dibujó con el fondo que tienes AHORA
reusar() {
  [[ -f "$PANEL" ]] || return 1
  [[ "$(cat "$DIR/.recorte" 2>/dev/null)" == "$fondo|$(stat -c %Y "$fondo" 2>/dev/null)|$escala" ]] || return 1
  local t; t=$(stat -c %Y "$PANEL")
  (( $(date +%s) - t < 20 )) && [[ "$(date -d "@$t" +%H%M)" == "$(date +%H%M)" ]]
}

extra=()
if reusar; then panel=$PANEL; else panel=$(PANEL_ESCALA="$escala" "$S/panel.sh" 2>/dev/null); fi
if [[ -n "$panel" && -f "$panel" ]]; then
  extra=(-theme-str "imagebox { background-image: url(\"$panel\", both); }")
else
  # sin librsvg: al menos tu fondo de pantalla
  case "${fondo,,}" in
    *.png|*.jpg|*.jpeg) [[ -f "$fondo" ]] && extra=(-theme-str "imagebox { background-image: url(\"$fondo\", height); }") ;;
  esac
fi

exec rofi -show "$modo" -theme lanzador "${extra[@]}"
