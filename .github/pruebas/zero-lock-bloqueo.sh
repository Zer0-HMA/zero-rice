#!/usr/bin/env bash
# Prueba de regresión de zero-lock con un hyprlock y un hyprctl simulados.
# Cubre el bug de hyprlock 0.9.6 (se congela o se cae al desbloquear, issue #1055).
set -u
RAIZ=$(cd "$(dirname "$0")/../.." && pwd)
Z="$RAIZ/config/hypr/scripts/zero-lock.sh"
T=$(mktemp -d); trap 'for p in $(pgrep -x hyprlock); do kill -9 "$p"; done 2>/dev/null; rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/home/.config"
export HOME="$T/home" EST="$T/estado" LLAMADAS="$T/llamadas" PATH="$T/bin:$PATH" HYPRLAND_INSTANCE_SIGNATURE=ci

# shebang directo (no "env bash"): así el proceso se llama "hyprlock", como el de verdad
cat > "$T/bin/hyprlock" <<'H'
#!/bin/bash
case "$1" in --version) echo "Hyprlock version v0.9.6"; exit 0 ;; --help) echo "--grace"; exit 0 ;; esac
echo "$*" >> "$LLAMADAS"; echo true > "$EST"
case "${HL_MODO:-normal}" in
  normal)      sleep 0.5; echo false > "$EST"; exit 0 ;;
  congelar)    sleep 0.5; echo false > "$EST"; sleep 30; exit 0 ;;
  cae_bloq)    sleep 0.3; exit 1 ;;
  cae_desbloq) sleep 0.3; echo false > "$EST"; exit 139 ;;
esac
H
cat > "$T/bin/hyprctl" <<'H'
#!/usr/bin/env bash
case "$1" in locked) cat "$EST" ;; monitors) echo '[{"focused":true,"width":1920,"height":1080,"scale":1}]' ;; *) exit 1 ;; esac
H
printf '#!/bin/sh\nexit 0\n' > "$T/bin/notify-send"
chmod +x "$T/bin/"*

fallas=0
reset() { for p in $(pgrep -x hyprlock); do kill -9 "$p"; done 2>/dev/null; sleep 0.2; echo false > "$EST"; : > "$LLAMADAS"; }
n() { wc -l < "$LLAMADAS" | tr -d ' '; }
espera() { [[ "$1" == "$2" ]] && echo "  ✔ $3" || { echo "  ✘ $3 (esperaba $2, salió $1)"; fallas=1; }; }

echo "hyprlock colgado tras desbloquear → Super + L lo cierra y vuelve a bloquear"
reset; (HL_MODO=congelar bash "$Z" lock &); sleep 1.5
HL_MODO=normal timeout 20 bash "$Z" lock; sleep 0.3
espera "$(n)" 2 "se bloqueó de nuevo"
espera "$(grep -c seguro "$LLAMADAS")" 0 "sin pasar por la config de emergencia"

echo "hypridle con la sesión bloqueada de verdad → no hace nada"
reset; (HL_MODO=congelar bash "$Z" lock &); sleep 0.2
HL_MODO=normal timeout 20 bash "$Z" lock --auto
espera "$(n)" 1 "no abrió un segundo hyprlock"

echo "hyprlock se cae con la sesión bloqueada → reintenta con la de emergencia"
reset; HL_MODO=cae_bloq timeout 20 bash "$Z" lock
espera "$(grep -c seguro "$LLAMADAS")" 1 "reintentó con la de emergencia"

echo "hyprlock se cae al desbloquear → no te vuelve a bloquear"
reset; HL_MODO=cae_desbloq timeout 20 bash "$Z" lock
espera "$(n)" 1 "no reintentó"

((fallas)) && { echo "--- log de zero-lock:"; cat "$HOME/.cache/zero-lock/zero-lock.log"; }
exit $fallas
