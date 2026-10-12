#!/usr/bin/env bash
# wall.sh — tus fondos de pantalla: imágenes y GIF con awww (antes swww), videos con mpvpaper
#   wall.sh                 → fondo aleatorio
#   wall.sh menu            → elegir con rofi (con miniaturas; los videos llevan ▶)
#   wall.sh sig | ant       → siguiente / anterior
#   wall.sh restaurar       → pone el último que usaste (se usa al iniciar)
#   wall.sh /ruta/archivo   → lo pone de fondo y lo agrega a tu carpeta de fondos
#   wall.sh video pausa | seguir | alternar   → pausa o reanuda el fondo en video
#   wall.sh video parar     → quita el video y deja su cuadro como imagen
# Carpeta de fondos: ~/.config/wallpapers
#   imágenes: jpg, png, webp, bmp · animados: gif · videos: mp4, webm, mkv, mov, m4v, avi
# Ajustes (en ~/.config/rice-paletas/ajustes.conf):
#   VIDEO_PAUSA=FULL    cuándo se pausa el video: FULL (ventana a pantalla completa) · MAX (también
#                       maximizadas) · ACTIVE (cualquier ventana enfocada) · no (nunca)
#   VIDEO_SONIDO=0      1 = el video suena

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
DIR="${WALL_DIR:-$CFG/wallpapers}"
ESTADO="$DIR/.actual"
TEMA="$CFG/rofi/themes/wallpapers.rasi"
RUN="${XDG_RUNTIME_DIR:-/tmp}/zero-rice"; mkdir -p "$RUN"
LOG="$RUN/wall-daemon.log"
LOG_VIDEO="$RUN/wall-video.log"
SOCK="$RUN/fondo-video.sock"
TRANS=(grow outer wipe wave center)
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER=${USER:-$(id -un)}

VIDEO_PAUSA=FULL; VIDEO_SONIDO=0
# shellcheck source=/dev/null
[[ -f $CFG/rice-paletas/ajustes.conf ]] && source "$CFG/rice-paletas/ajustes.conf"
# shellcheck source=lib/video.sh
source "$SCRIPTS/lib/video.sh"

mkdir -p "$DIR"

# swww se renombró a awww; usamos el que tengas instalado
if command -v awww >/dev/null 2>&1; then
  W=awww
elif command -v swww >/dev/null 2>&1; then
  W=swww
else
  echo "No tienes awww ni swww instalado. Instálalo con:  yay -S awww" >&2
  exit 1
fi

notificar() { command -v notify-send >/dev/null 2>&1 && notify-send -a "Fondos" "$@"; return 0; }

daemon() {
  "$W" query &>/dev/null && return 0
  setsid -f "$W-daemon" >"$LOG" 2>&1
  for _ in {1..50}; do "$W" query &>/dev/null && return 0; sleep 0.1; done
  echo "No arrancó $W-daemon. Esto fue lo que dijo:" >&2
  sed 's/^/   /' "$LOG" >&2
  exit 1
}

listar() {
  find -L "$DIR" -maxdepth 2 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
       -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.bmp' \
       -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.m4v' -o -iname '*.avi' \) | sort
}

# ── video ──
parar_video() {
  video_sonando || return 0
  pkill -u "$USER" -x mpvpaper 2>/dev/null
  for _ in {1..30}; do video_sonando || break; sleep 0.05; done
  video_sonando && pkill -KILL -u "$USER" -x mpvpaper 2>/dev/null
  rm -f "$SOCK"
}

# opciones de pausa que entiende TU mpvpaper (--auto-mode es reciente)
opciones_pausa() {
  local ayuda m
  [[ ${VIDEO_PAUSA^^} == NO ]] && return 0
  printf '%s\n' --auto-pause
  ayuda=$(mpvpaper --help 2>&1)
  grep -q -- '--auto-mode' <<<"$ayuda" || return 0
  # el modo que pediste, o el más cercano que tu mpvpaper conozca (ACTIVE es de julio de 2026)
  for m in ACTIVE MAX FULL; do
    case "${VIDEO_PAUSA^^}:$m" in ACTIVE:*|MAX:MAX|MAX:FULL|FULL:FULL) ;; *) continue ;; esac
    grep -q "<$m>" <<<"$ayuda" && { printf '%s\n' --auto-mode "$m"; return 0; }
  done
}

arrancar_video() {   # arrancar_video RUTA
  local v=$1 mpv pausa=()
  if ! command -v mpvpaper >/dev/null 2>&1; then
    notificar -u critical "Falta mpvpaper" "Para fondos en video corre ./install.sh (o: yay -S mpvpaper)"
    echo "Falta mpvpaper: corre ./install.sh o instálalo con  yay -S mpvpaper" >&2
    return 1
  fi
  # mpvpaper escribe estas opciones como un archivo de config de mpv: una por línea
  mpv="loop-file=inf"$'\n'"panscan=1.0"$'\n'"hwdec=auto-safe"$'\n'"input-ipc-server=$SOCK"
  [[ $VIDEO_SONIDO == 1 ]] || mpv+=$'\n'"no-audio"
  mapfile -t pausa < <(opciones_pausa)
  parar_video
  # capa "bottom": encima del fondo de awww (capa background) y debajo de las ventanas
  printf '\n=== %s · %s ===\n' "$(date '+%F %T')" "$v" >> "$LOG_VIDEO"
  setsid -f mpvpaper --layer bottom "${pausa[@]}" -o "$mpv" ALL "$v" >> "$LOG_VIDEO" 2>&1 < /dev/null
  for _ in {1..20}; do video_sonando && return 0; sleep 0.1; done
  notificar -u critical "El video no arrancó" "Revisa: $LOG_VIDEO"
  return 1
}

# mandar un comando al video que está sonando (pausa, etc.)
mpv_cmd() {
  [[ -S $SOCK ]] || { echo "No hay un fondo en video sonando." >&2; return 1; }
  if command -v socat >/dev/null 2>&1; then printf '%s\n' "$1" | socat - "$SOCK" >/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import socket,sys; s=socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); s.sendall((sys.argv[2]+"\n").encode())' "$SOCK" "$1"
  else echo "Para pausar el video hace falta socat:  sudo pacman -S socat" >&2; return 1; fi
}

# ── poner un fondo ──
# poner RUTA [transición] [sin-paleta]
#   la transición "none" es para restaurar al iniciar sesión (sin animación ni paleta automática)
poner() {
  local f="$1" trans="${2:-}" sin_paleta=${3:-} img
  daemon
  [[ -z "$trans" ]] && trans="${TRANS[RANDOM % ${#TRANS[@]}]}"
  if es_video "$f"; then
    # primero su cuadro con la transición de siempre (y queda debajo del video como respaldo),
    # luego el video encima: el cambio se ve suave y nunca hay un parpadeo negro
    img=$(cuadro_de "$f") || { notificar -u critical "No pude leer el video" "$(basename "$f") (¿falta ffmpeg?)"; return 1; }
  else
    img="$f"
  fi
  "$W" img "$img" \
    --transition-type "$trans" \
    --transition-fps 60 \
    --transition-duration 1.2 \
    --transition-angle $((RANDOM % 360))
  if es_video "$f"; then
    [[ $trans != none ]] && sleep 1.2   # que termine la transición antes de que aparezca el video
    arrancar_video "$f" || return 1
  else
    parar_video
  fi
  printf '%s\n' "$f" > "$ESTADO"
  # Paleta automática (paleta.sh auto on): los colores salen del fondo nuevo.
  # Solo cuando tú cambias el fondo, no al restaurarlo al iniciar sesión.
  if [[ "$trans" != none && -z $sin_paleta && -f "$CFG/rice-paletas/auto-fondo" ]]; then
    setsid -f "$SCRIPTS/paleta.sh" desde-fondo "$f" >/dev/null 2>&1
  fi
  return 0
}

actual() { [[ -f "$ESTADO" ]] && cat "$ESTADO"; }

sin_fondos() {
  echo "No hay fondos en $DIR — mete tus imágenes o videos ahí." >&2
  notificar "No hay fondos" "Mete imágenes o videos en $DIR"
  daemon; "$W" clear 0b0b12
  exit 0
}

# agregar ARCHIVO → ruta dentro de tu carpeta de fondos
# Las imágenes se copian. Los videos (que pesan mucho) se enlazan: no se duplican en tu disco.
agregar() {
  local src=$1 dest base
  case "$src" in "$DIR"/*) printf '%s' "$src"; return 0 ;; esac
  base=${src##*/}; dest="$DIR/$base"
  if [[ -e $dest || -L $dest ]] && [[ "$(realpath -- "$dest" 2>/dev/null)" != "$src" ]] && ! cmp -s "$src" "$dest"; then
    dest="$DIR/${base%.*}-$(date +%s).${base##*.}"     # otro archivo con el mismo nombre: no se pisa
  fi
  if [[ ! -e $dest ]]; then
    if es_video "$src"; then ln -s -- "$src" "$dest"; else cp -- "$src" "$dest"; fi
  fi
  printf '%s' "$dest"
}

mapfile -t FONDOS < <(listar)
N=${#FONDOS[@]}

case "${1:-aleatorio}" in
  aleatorio|random)
    ((N)) || sin_fondos
    cur=$(actual)
    img=${FONDOS[0]}
    if ((N > 1)); then
      while :; do img=${FONDOS[RANDOM % N]}; [[ "$img" != "$cur" ]] && break; done
    fi
    poner "$img" ;;

  sig|siguiente|next|ant|anterior|prev)
    ((N)) || sin_fondos
    cur=$(actual); i=-1
    for k in "${!FONDOS[@]}"; do [[ "${FONDOS[k]}" == "$cur" ]] && { i=$k; break; }; done
    case "$1" in
      sig|siguiente|next) i=$(( (i + 1) % N )) ;;
      *)                  ((i < 0)) && i=0; i=$(( (i - 1 + N) % N )) ;;
    esac
    poner "${FONDOS[i]}" ;;

  menu)
    ((N)) || sin_fondos
    pkill -x rofi && exit 0   # si ya estaba abierto, lo cierra
    hay_videos=0; for f in "${FONDOS[@]}"; do es_video "$f" && { hay_videos=1; break; }; done
    ((hay_videos)) && notificar -h string:x-canonical-private-synchronous:wall-minis "Preparando miniaturas…" "Solo la primera vez para cada video"
    sel=$(for f in "${FONDOS[@]}"; do
            if es_video "$f"; then printf '▶ %s\0icon\x1f%s\n' "$(basename "$f")" "$(miniatura_de "$f")"
            else printf '%s\0icon\x1f%s\n' "$(basename "$f")" "$f"; fi
          done | rofi -dmenu -i -p "Fondos" -show-icons -format i -theme "$TEMA") || exit 0
    [[ -n "$sel" ]] && poner "${FONDOS[sel]}" ;;

  restaurar|restore)
    cur=$(actual)
    if [[ -n "$cur" && -f "$cur" ]]; then poner "$cur" none
    elif ((N)); then poner "${FONDOS[RANDOM % N]}" none
    else sin_fondos; fi ;;

  _poner)   # lo usan las paletas: pone el fondo sin disparar la paleta automática
    [[ -f ${2:-} ]] || { echo "No existe: ${2:-}" >&2; exit 1; }
    poner "$2" "${3:-grow}" sin-paleta ;;

  video)
    case "${2:-alternar}" in
      pausa|pausar|pause)    mpv_cmd '{"command":["set_property","pause",true]}' ;;
      seguir|play|reanudar)  mpv_cmd '{"command":["set_property","pause",false]}' ;;
      alternar|toggle)       mpv_cmd 'cycle pause' ;;
      parar|stop)            parar_video; echo "Video quitado (queda su cuadro como fondo)" ;;
      *) echo "Usa: wall.sh video pausa | seguir | alternar | parar" >&2; exit 1 ;;
    esac ;;

  -h|--help|ayuda)
    sed -n '2,17p' "$0" ;;

  *)
    src=$(realpath -- "$1" 2>/dev/null || true)
    [[ -f "$src" ]] || { echo "No existe: $1" >&2; exit 1; }
    dest=$(agregar "$src")
    poner "$dest" || exit 1
    if es_video "$dest"; then notificar -i "$(miniatura_de "$dest")" "Fondo en video" "$(basename "$dest")"
    else notificar -i "$dest" "Fondo agregado" "$(basename "$dest")"; fi ;;
esac
