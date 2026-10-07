#!/usr/bin/env bash
# lanzador.sh — abre rofi con el panel de saludo, reloj, clima y estadísticas de tu PC
#   lanzador.sh             → apps
#   lanzador.sh run         → comandos
#   lanzador.sh filebrowser → archivos
pkill -x rofi && exit 0

modo=${1:-drun}
S="$HOME/.config/hypr/scripts"

# escala del monitor (para que el panel se vea nítido en pantallas HiDPI)
escala=$(hyprctl monitors 2>/dev/null | awk '/focused: yes/{f=1} /scale:/{s=$2} f&&s{print s; exit}')
escala=${escala:-1}; [[ "$escala" == 1.00 || "$escala" == 1.0 ]] && escala=1

extra=()
if panel=$(PANEL_ESCALA="$escala" "$S/panel.sh" 2>/dev/null) && [[ -f "$panel" ]]; then
  extra=(-theme-str "imagebox { background-image: url(\"$panel\", both); }")
else
  # sin librsvg: al menos tu fondo de pantalla
  fondo=$(cat "$HOME/.config/wallpapers/.actual" 2>/dev/null)
  case "${fondo,,}" in
    *.png|*.jpg|*.jpeg) [[ -f "$fondo" ]] && extra=(-theme-str "imagebox { background-image: url(\"$fondo\", height); }") ;;
  esac
fi

exec rofi -show "$modo" -theme lanzador "${extra[@]}"
