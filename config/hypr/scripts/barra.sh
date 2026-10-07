#!/usr/bin/env bash
# barra.sh — mantiene viva la barra: si se cae, la vuelve a levantar
#   barra.sh             → arranca la barra con su guardián (lo usa Hyprland al iniciar)
#   barra.sh reiniciar   → reinicia la barra (Super+B)
#   barra.sh parar       → la apaga y el guardián no la revive
#   barra.sh log         → muestra los últimos mensajes/errores de la barra

LOG="/tmp/barra-$USER.log"
LOCK="/tmp/barra-$USER.lock"
PARAR="/tmp/barra-$USER.parar"
REINICIO="/tmp/barra-$USER.reinicio"

notificar() { command -v notify-send >/dev/null 2>&1 && notify-send -a "Barra" "$@"; return 0; }
guardian_vivo() { ! flock -n "$LOCK" true 2>/dev/null; }

guardian() {
  exec 9>"$LOCK"
  flock -n 9 || exit 0            # ya hay un guardián cuidando la barra
  rm -f "$PARAR" "$REINICIO"
  # que el log no crezca para siempre
  [[ -f "$LOG" ]] && (( $(stat -c %s "$LOG") > 1048576 )) && tail -n 400 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"

  local caidas=() ahora rc t recientes
  while :; do
    hyprctl version >/dev/null 2>&1 || break     # Hyprland ya no está (cerraste sesión)
    printf '\n=== %s · arrancando la barra ===\n' "$(date '+%F %T')" >> "$LOG"
    ags run >> "$LOG" 2>&1
    rc=$?

    [[ -f "$PARAR" ]] && { rm -f "$PARAR"; break; }
    if [[ -f "$REINICIO" ]]; then rm -f "$REINICIO"; sleep 0.3; continue; fi

    printf '=== %s · la barra se cerró (código %s) ===\n' "$(date '+%F %T')" "$rc" >> "$LOG"
    ahora=$(date +%s); caidas+=("$ahora"); recientes=()
    for t in "${caidas[@]}"; do (( ahora - t < 60 )) && recientes+=("$t"); done
    caidas=("${recientes[@]}")

    if (( ${#caidas[@]} >= 4 )); then
      notificar -u critical "La barra se cayó varias veces seguidas" \
        "Dejé de revivirla. Corre 'barra.sh log' en la terminal y mándale el error a Claude."
      break
    fi
    notificar "La barra se cerró sola" "Ya la volví a levantar"
    sleep 1
  done
}

case "${1:-}" in
  reiniciar)
    if guardian_vivo; then
      touch "$REINICIO"
      ags quit >/dev/null 2>&1 || pkill -f "gjs.*ags" 2>/dev/null
    else
      ags quit >/dev/null 2>&1
      setsid -f bash "$0" >/dev/null 2>&1
    fi ;;
  parar)
    touch "$PARAR"
    ags quit >/dev/null 2>&1 ;;
  log)
    tail -n 60 "$LOG" 2>/dev/null || echo "Todavía no hay log." ;;
  "")
    guardian ;;
  *)
    sed -n '2,6p' "$0" ;;
esac
