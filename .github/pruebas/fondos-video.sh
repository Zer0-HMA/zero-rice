#!/usr/bin/env bash
# Prueba de los fondos en video (wall.sh + lib/video.sh) con awww, mpvpaper y ffmpeg simulados.
set -u
RAIZ=$(cd "$(dirname "$0")/../.." && pwd)
W="$RAIZ/config/hypr/scripts/wall.sh"
T=$(mktemp -d); trap 'pkill -9 -x mpvpaper 2>/dev/null; rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/home/.config/wallpapers" "$T/run" "$T/videos"
export HOME="$T/home" PATH="$T/bin:$PATH" XDG_RUNTIME_DIR="$T/run" REG="$T/registro"

# shebang directo: así los procesos se llaman como los de verdad (pgrep -x mpvpaper)
cat > "$T/bin/awww" <<'H'
#!/bin/bash
case "$1" in query) exit 0 ;; img) echo "img $2" >> "$REG" ;; esac
H
cat > "$T/bin/mpvpaper" <<'H'
#!/bin/bash
[[ "$1" == --help ]] && { echo "--auto-mode"; exit 0; }
echo "mpvpaper ${*: -1}" >> "$REG"
sleep 60
H
cat > "$T/bin/ffmpeg" <<'H'
#!/bin/bash
# escribe un PNG de 1×1 en el último argumento (el archivo de salida)
printf 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==' | base64 -d > "${@: -1}"
H
printf '#!/bin/sh\nexit 0\n' > "$T/bin/notify-send"
chmod +x "$T/bin/"*
printf 'video' > "$T/videos/mar.mp4"
printf 'jpg' > "$HOME/.config/wallpapers/foto.jpg"

fallas=0
espera() { [[ "$1" == "$2" ]] && echo "  ✔ $3" || { echo "  ✘ $3 (esperaba «$2», salió «$1»)"; fallas=1; }; }
# shellcheck source=/dev/null
source "$RAIZ/config/hypr/scripts/lib/video.sh"
sonando() { video_sonando && echo sí || echo no; }

echo "lib/video.sh reconoce los videos"
espera "$(es_video /x/Mar.MP4 && echo sí || echo no)" sí "MP4 en mayúsculas es video"
espera "$(es_video /x/foto.webp && echo sí || echo no)" no "webp es imagen"

echo "poner un video de otra carpeta"
bash "$W" "$T/videos/mar.mp4" >/dev/null 2>&1; sleep 0.3
espera "$([[ -L $HOME/.config/wallpapers/mar.mp4 ]] && echo enlace || echo copia)" enlace "el video se enlaza, no se copia"
espera "$(sonando)" sí "el video está sonando"
espera "$(grep -c '^img .*cuadros/.*\.png$' "$REG")" 1 "awww pone el cuadro del video debajo"

echo "pasar a una imagen apaga el video"
bash "$W" "$HOME/.config/wallpapers/foto.jpg" >/dev/null 2>&1; sleep 0.3
espera "$(sonando)" no "el video se apagó"
espera "$(cat "$HOME/.config/wallpapers/.actual")" "$HOME/.config/wallpapers/foto.jpg" ".actual apunta a la imagen"

echo "restaurar al iniciar sesión vuelve a poner el video"
printf '%s\n' "$HOME/.config/wallpapers/mar.mp4" > "$HOME/.config/wallpapers/.actual"
bash "$W" restaurar >/dev/null 2>&1; sleep 0.3
espera "$(sonando)" sí "el video volvió"
bash "$W" video parar >/dev/null 2>&1; sleep 0.3
espera "$(sonando)" no "wall.sh video parar lo apaga"

exit $fallas
