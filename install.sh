#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
#                      ZERO — rice para Hyprland
#        Hyprland (Lua) · AGS v3 · Rofi · SwayNC · awww · paletas
#
#   ./install.sh                   instala todo (pregunta antes de cada paso)
#   ./install.sh --si              dice que sí a todo, sin preguntar
#   ./install.sh --solo-configs    no instala paquetes, solo las configuraciones
#   ./install.sh --paleta=tokyo    paleta inicial (ver lista abajo)
#   ./install.sh --actualizar      baja lo último del repo y actualiza (conserva tu paleta y fondo)
#   ./install.sh --desinstalar     quita el rice (no borra paquetes)
#   ./install.sh --version         muestra la versión
#   ./install.sh --enlazar         en vez de copiar, enlaza ~/.config al repo (para desarrollar el rice)
#   ./install.sh --copiar          vuelve a copias normales después de --enlazar
#
#   Paletas: 48 (acero, tokyo, dracula, kanagawa, synthwave...). Lista completa: paleta.sh lista
# ╚══════════════════════════════════════════════════════════════════╝
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO/config"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
S="$CFG/hypr/scripts"
ESTADO="${XDG_STATE_HOME:-$HOME/.local/state}/zero-rice"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/zero-rice"
RESPALDO="$CFG/rice-respaldo-$(date +%Y%m%d-%H%M%S)"
VERSION=$(cat "$REPO/VERSION" 2>/dev/null || echo "?")

# scripts y archivos de la barra que instala el rice (una sola lista para instalar y desinstalar)
SCRIPTS=(wall paleta red barra captura lanzador panel clima elegir-fondo temp portapapeles ws3d perfil animaciones zero-lock)
LIBS=(color plantillas fondos dinamica)
AGS=(app.tsx style.css ws3d.tsx efectos3d.ts)

SI=0; SOLO_CONFIGS=0; PALETA=""; MODO="instalar"
# modo enlazado: se recuerda entre corridas (así --actualizar no lo deshace)
ENLAZAR=$(cat "$ESTADO/modo-enlazado" 2>/dev/null || echo 0)
for arg in "$@"; do
  case "$arg" in
    --si|-y)        SI=1 ;;
    --solo-configs) SOLO_CONFIGS=1 ;;
    --paleta=*)     PALETA="${arg#--paleta=}" ;;
    --actualizar)   MODO="actualizar"; SOLO_CONFIGS=1 ;;
    --desinstalar)  MODO="desinstalar" ;;
    --enlazar)      ENLAZAR=1 ;;
    --copiar)       ENLAZAR=0 ;;
    -h|--help)      sed -n '2,18p' "$0"; exit 0 ;;
    -v|--version)   echo "zero-rice $VERSION"; exit 0 ;;
    *) echo "Opción desconocida: $arg (usa --help)"; exit 1 ;;
  esac
done

# ─────────────────────────── utilidades ───────────────────────────
titulo() { printf '\n\e[1;35m━━━ %s ━━━\e[0m\n' "$*"; }
ok()     { printf '\e[1;32m[✓]\e[0m %s\n' "$*"; }
info()   { printf '\e[1;36m[i]\e[0m %s\n' "$*"; }
warn()   { printf '\e[1;33m[!]\e[0m %s\n' "$*"; }
error()  { printf '\e[1;31m[✗]\e[0m %s\n' "$*"; }
preguntar() {
  ((SI)) && return 0
  local r; read -rp "$(printf '\e[1;36m[?]\e[0m') $1 [S/n] " r || r="n"
  [[ ! "$r" =~ ^[nN]$ ]]
}
respaldar() {   # copia algo existente a la carpeta de respaldo, conservando la ruta
  [[ -e "$1" ]] || return 0
  local rel="${1#"$CFG"/}"
  mkdir -p "$RESPALDO/$(dirname "$rel")"
  cp -aL "$1" "$RESPALDO/$rel" 2>/dev/null || cp -a "$1" "$RESPALDO/$rel"
}
instalar() {    # instalar ORIGEN(relativo a config/) DESTINO [x]
  local origen="$SRC/$1" destino="$2"
  [[ -f "$origen" ]] || { error "Falta $1 en el repo"; exit 1; }
  if ((ENLAZAR)); then
    [[ "${3:-}" == x && ! -x "$origen" ]] && { chmod +x "$origen" 2>/dev/null || true; }
    # modo enlazado: ~/.config apunta al repo, así lo que edites queda directo en git
    [[ -L "$destino" && "$(readlink -f "$destino")" == "$(readlink -f "$origen")" ]] && return 0
    respaldar "$destino"
    mkdir -p "$(dirname "$destino")"
    ln -sfn "$origen" "$destino"
    return 0
  fi
  [[ -L "$destino" ]] && rm -f "$destino"   # venía del modo enlazado: se vuelve copia normal
  if [[ -f "$destino" ]] && cmp -s "$origen" "$destino"; then return 0; fi
  respaldar "$destino"
  mkdir -p "$(dirname "$destino")"
  cp "$origen" "$destino"
  [[ "${3:-}" == x ]] && chmod +x "$destino"
  return 0
}
en_hyprland() { [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; }

banner() {
cat <<'BANNER'

   ███████╗███████╗██████╗  ██████╗
   ╚══███╔╝██╔════╝██╔══██╗██╔═══██╗     rice para Hyprland
     ███╔╝ █████╗  ██████╔╝██║   ██║
    ███╔╝  ██╔══╝  ██╔══██╗██║   ██║
   ███████╗███████╗██║  ██║╚██████╔╝
   ╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝
BANNER
printf '   versión %s\n' "$VERSION"
}

# ═════════════════════════ Desinstalar ═════════════════════════
desinstalar() {
  titulo "Desinstalando el rice"
  preguntar "Esto quita las configuraciones del rice (no borra paquetes). ¿Seguro?" || exit 0
  [[ -x "$S/barra.sh" ]] && "$S/barra.sh" parar >/dev/null 2>&1 || true
  pkill -x swaync 2>/dev/null || true

  local HL="$CFG/hypr/hyprland.lua"
  if [[ -f "$HL" ]] && grep -q 'require("rice")' "$HL"; then
    respaldar "$HL"
    sed -i '/^-- Rice "zero"/d; /^require("rice")$/d' "$HL"
    ok "Quité require(\"rice\") de hyprland.lua"
  fi
  local cosas=(
    "$CFG/hypr/rice.lua" "$CFG/hypr/colores.lua" "$CFG/hypr/animaciones.lua" "$CFG/hypr/hyprlock-colores.conf" "$S/lib"
    "$CFG/ags" "$CFG/rofi" "$CFG/swaync" "$CFG/kitty/paleta.conf"
    "$CFG/rice-paletas" "$CFG/rice-plantillas" "$CFG/rice-terminal" "$CFG/rice-clima" "$CFG/rice-lanzador"
    "$CFG/rice-ws3d" "$CFG/rice-animaciones" "$CFG/zero-lock"
    "$CFG/gtk-3.0/zero-paleta.css" "$CFG/gtk-4.0/zero-paleta.css"
  )
  for s in "${SCRIPTS[@]}"; do cosas+=("$S/$s.sh"); done
  # hyprlock/hypridle solo si son los del rice (si eran tuyos, se quedan)
  head -1 "$CFG/hypr/hyprlock.conf" 2>/dev/null | grep -q 'Generado por paleta.sh' && cosas+=("$CFG/hypr/hyprlock.conf")
  grep -q '(zero-rice)' "$CFG/hypr/hypridle.conf" 2>/dev/null && cosas+=("$CFG/hypr/hypridle.conf")
  for c in "${cosas[@]}"; do
    [[ -e "$c" || -L "$c" ]] || continue
    respaldar "$c"; rm -rf "$c"
  done
  [[ -L "$HOME/.local/bin/zero-lock" ]] && rm -f "$HOME/.local/bin/zero-lock"
  [[ -f "$CFG/kitty/kitty.conf" ]] && sed -i '/^# Colores de paleta.sh$/d; /^include paleta.conf$/d' "$CFG/kitty/kitty.conf"
  [[ -f "$HOME/.zshrc" ]] && sed -i '/rice-terminal\/bienvenida.zsh/d' "$HOME/.zshrc"
  for v in 3.0 4.0; do
    [[ -f "$CFG/gtk-$v/gtk.css" ]] || continue
    sed -i '/^@import url("zero-paleta.css");$/d' "$CFG/gtk-$v/gtk.css"
    [[ -s "$CFG/gtk-$v/gtk.css" ]] || rm -f "$CFG/gtk-$v/gtk.css"
  done
  rm -rf "$ESTADO" "$CACHE" "${XDG_CACHE_HOME:-$HOME/.cache}/zero-lock"
  en_hyprland && hyprctl reload >/dev/null 2>&1 || true
  ok "Rice quitado. Todo quedó respaldado en: $RESPALDO"
  info "Tus fondos (~/.config/wallpapers) y tus fotos de perfil (~/.config/rice-perfil) no se tocaron."
  exit 0
}

# ═════════════════════════ Inicio ═════════════════════════
banner
[[ $EUID -eq 0 ]] && { error "No lo corras como root; usa tu usuario normal (pedirá sudo cuando haga falta)."; exit 1; }
command -v pacman >/dev/null 2>&1 || { error "Esto es para Arch Linux (no encontré pacman)."; exit 1; }
[[ -d "$SRC" ]] || { error "No encuentro la carpeta config/ junto a install.sh. Córrelo desde el repo clonado."; exit 1; }

[[ "$MODO" == desinstalar ]] && desinstalar

if [[ "$MODO" == actualizar ]]; then
  titulo "Actualizando desde el repo"
  if command -v git >/dev/null 2>&1 && git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
    if git -C "$REPO" pull --ff-only; then ok "Repo al día"
    else warn "No se pudo hacer git pull (¿cambios locales?). Sigo con lo que hay."; fi
  else
    warn "Esta carpeta no es un repo de git; uso los archivos tal como están."
  fi
  # se relanza la versión recién bajada de este mismo script (por si cambió)
  otras=(--solo-configs); ((SI)) && otras+=(--si); [[ -n "$PALETA" ]] && otras+=("--paleta=$PALETA")
  exec bash "$REPO/install.sh" "${otras[@]}"
fi

# ═════════════════════════ 1. Paquetes ═════════════════════════
if ((SOLO_CONFIGS)); then
  [[ "$MODO" == instalar ]] && info "Saltando instalación de paquetes (--solo-configs)"
else
  titulo "Paquetes oficiales (pacman)"
  PAQUETES=(
    hyprland kitty rofi swaync                                     # escritorio
    networkmanager pipewire wireplumber pipewire-pulse             # red y audio
    upower brightnessctl playerctl                                 # batería, brillo, música
    grim slurp wl-clipboard libnotify satty hyprpicker sound-theme-freedesktop   # capturas
    curl jq libarchive                                             # clima
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji papirus-icon-theme librsvg   # fuentes e íconos
    imagemagick fastfetch                                          # paleta desde tu fondo y fotos de perfil · bienvenida de la terminal
    thunar gvfs tumbler                                            # archivos
    hyprlock hypridle hyprpolkitagent xdg-desktop-portal-hyprland  # bloqueo, contraseñas, compartir pantalla
    cliphist                                                       # historial del portapapeles
    kernel-modules-hook                                            # actualizar el kernel sin romper nada hasta reiniciar
    base-devel git                                                 # para el AUR
  )
  if command -v rofi >/dev/null 2>&1; then   # si ya hay un rofi (ej. rofi-wayland), no lo cambiamos
    filtrados=(); for x in "${PAQUETES[@]}"; do [[ "$x" == rofi ]] || filtrados+=("$x"); done
    PAQUETES=("${filtrados[@]}")
  fi
  info "Se instalarán los que falten de: ${PAQUETES[*]}"
  if preguntar "¿Instalo los paquetes con pacman?"; then
    noconf=(); ((SI)) && noconf=(--noconfirm)
    sudo pacman -S --needed "${noconf[@]}" "${PAQUETES[@]}"
    ok "Paquetes oficiales listos"
  else
    warn "Saltado: sin estos paquetes varias cosas no van a funcionar."
  fi

  titulo "Paquetes del AUR"
  AUR=""
  command -v yay  >/dev/null 2>&1 && AUR=yay
  [[ -z "$AUR" ]] && command -v paru >/dev/null 2>&1 && AUR=paru
  if [[ -z "$AUR" ]]; then
    info "No tienes yay ni paru (se necesitan para AGS, la barra)."
    if preguntar "¿Instalo yay?"; then
      tmp=$(mktemp -d)
      git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
      (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
      rm -rf "$tmp"; AUR=yay; ok "yay instalado"
    fi
  else
    ok "Ayudante del AUR: $AUR"
  fi
  if [[ -n "$AUR" ]]; then
    AUR_PAQ=()
    ags_ver=$(ags --version 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)
    [[ "${ags_ver:-0}" -ge 3 ]] || AUR_PAQ+=(aylurs-gtk-shell-git)
    AUR_PAQ+=(libastal-meta)
    command -v awww >/dev/null 2>&1 || AUR_PAQ+=(awww)
    info "Del AUR: ${AUR_PAQ[*]}"
    if preguntar "¿Los instalo con $AUR? (tarda unos minutos)"; then
      noconf=(); ((SI)) && noconf=(--noconfirm)
      "$AUR" -S --needed "${noconf[@]}" "${AUR_PAQ[@]}" || warn "Algo del AUR falló; revisa arriba."
    fi
  else
    warn "Sin ayudante del AUR no se instalan AGS (la barra) ni awww."
  fi
  if ! command -v awww >/dev/null 2>&1 && ! command -v swww >/dev/null 2>&1; then
    info "Instalando swww como respaldo para los fondos..."
    sudo pacman -S --needed --noconfirm swww || warn "No se pudo instalar swww"
  fi
  if pacman -Q kernel-modules-hook >/dev/null 2>&1 && ! systemctl is-enabled linux-modules-cleanup >/dev/null 2>&1; then
    sudo systemctl enable linux-modules-cleanup >/dev/null 2>&1 && ok "kernel-modules-hook activo: actualizar el kernel ya no rompe nada hasta que reinicies"
  fi
  if ! systemctl is-enabled NetworkManager >/dev/null 2>&1; then
    warn "NetworkManager no está activado (el menú de red y la barra lo usan)."
    info "Si usas otra cosa para la red (iwd, systemd-networkd), contesta que no."
    preguntar "¿Activo NetworkManager?" && sudo systemctl enable --now NetworkManager && ok "NetworkManager activado"
  fi
fi

# ═════════════════════════ 2. Versiones ═════════════════════════
titulo "Revisando versiones"
faltan=()
for c in hyprlock hypridle cliphist; do command -v "$c" >/dev/null 2>&1 || faltan+=("$c"); done
if ((${#faltan[@]})); then
  warn "Falta: ${faltan[*]} (sin hyprlock, Super + L no puede bloquear)"
  if preguntar "¿Los instalo ahora con pacman?"; then
    sudo pacman -S --needed "${faltan[@]}" && ok "Instalados: ${faltan[*]}" || warn "No se pudieron instalar"
  fi
fi
HYPRLUA="$CFG/hypr/hyprland.lua"
if [[ ! -f "$HYPRLUA" ]]; then
  if [[ -f /usr/share/hypr/hyprland.lua ]]; then
    mkdir -p "$CFG/hypr"; cp /usr/share/hypr/hyprland.lua "$HYPRLUA"
    ok "Creé hyprland.lua a partir de la config de ejemplo de Hyprland"
  elif [[ -f "$CFG/hypr/hyprland.conf" || -f /usr/share/hypr/hyprland.conf ]]; then
    error "Tu Hyprland usa el formato viejo (hyprland.conf); este rice es para Hyprland con config en Lua."
    error "Actualiza primero:  sudo pacman -Syu hyprland"
    exit 1
  else
    warn "No encontré hyprland.lua; se creará al abrir Hyprland. Vuelve a correr ./install.sh después."
  fi
else
  ok "Hyprland con config en Lua"
fi
if command -v ags >/dev/null 2>&1; then
  v=$(ags --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)*' | head -1 || true)
  if [[ "${v%%.*}" =~ ^[0-9]+$ ]] && (( ${v%%.*} >= 3 )); then ok "AGS $v"
  else warn "AGS ${v:-?}: la barra necesita AGS 3 o más nuevo"; fi
else
  warn "AGS no está instalado: no habrá barra (yay -S aylurs-gtk-shell-git libastal-meta)"
fi

# ═════════════════════════ 3. Configuraciones ═════════════════════════
titulo "Copiando configuraciones"
mkdir -p "$S" "$CFG/wallpapers" "$CFG/rice-paletas" "$CFG/kitty"

instalar hypr/rice.lua "$CFG/hypr/rice.lua"
if [[ -f "$HYPRLUA" ]] && ! grep -qE '^[[:space:]]*require\(["'\'']rice["'\'']\)' "$HYPRLUA"; then
  respaldar "$HYPRLUA"
  printf '\n-- Rice "zero" (va al final para que gane)\nrequire("rice")\n' >> "$HYPRLUA"
fi
[[ -f "$CFG/hypr/rice.conf" ]] && { respaldar "$CFG/hypr/rice.conf"; rm -f "$CFG/hypr/rice.conf"; }
ok "Hyprland → rice.lua  (tus ajustes personales van en ~/.config/hypr/mio.lua)"

for s in "${SCRIPTS[@]}"; do
  instalar "hypr/scripts/$s.sh" "$S/$s.sh" x
done
for l in "${LIBS[@]}"; do
  instalar "hypr/scripts/lib/$l.sh" "$S/lib/$l.sh" x
done
ok "Scripts → ~/.config/hypr/scripts"

# comando zero-lock en la terminal: un enlace (nunca una copia que se quede vieja)
mkdir -p "$HOME/.local/bin"
[[ -e "$HOME/.local/bin/zero-lock" && ! -L "$HOME/.local/bin/zero-lock" ]] && { respaldar "$HOME/.local/bin/zero-lock"; rm -f "$HOME/.local/bin/zero-lock"; }
ln -sfn "$S/zero-lock.sh" "$HOME/.local/bin/zero-lock"
ok "Pantalla de bloqueo → zero-lock  (Super + L bloquea · Super + Shift + L la personaliza)"

# plantillas de colores: una por app (agregar una app nueva = agregar un .tpl)
mkdir -p "$CFG/rice-plantillas"
for t in "$SRC"/rice-plantillas/*.tpl; do
  instalar "rice-plantillas/$(basename "$t")" "$CFG/rice-plantillas/$(basename "$t")"
done
ok "Plantillas de colores → ~/.config/rice-plantillas  (puedes agregar las tuyas ahí)"

# bienvenida de la terminal (logo + datos + tu paleta al abrir una terminal)
instalar terminal/bienvenida.zsh "$CFG/rice-terminal/bienvenida.zsh"
ok "Bienvenida de la terminal → ~/.config/rice-terminal"
if [[ -f "$HOME/.zshrc" ]] && ! grep -q 'rice-terminal/bienvenida.zsh' "$HOME/.zshrc"; then
  if preguntar "¿Muestro logo, datos y tu paleta al abrir la terminal? (agrega 1 línea al inicio de ~/.zshrc; respaldo: ~/.zshrc.pre-zero)"; then
    cp -a "$HOME/.zshrc" "$HOME/.zshrc.pre-zero"
    sed -i '1i source "$HOME/.config/rice-terminal/bienvenida.zsh"   # zero-rice: bienvenida de la terminal (quita esta línea si no la quieres)' "$HOME/.zshrc"
    ok "Agregué la bienvenida al inicio de ~/.zshrc  (cámbiala con: bienvenida info | saludo | off)"
  fi
fi

for f in "${AGS[@]}"; do
  instalar "ags/$f" "$CFG/ags/$f"
done
ok "Barra → ~/.config/ags (con OSD, perfil y workspaces 3D)"

instalar rofi/config.rasi          "$CFG/rofi/config.rasi"
instalar rofi/themes/lanzador.rasi "$CFG/rofi/themes/lanzador.rasi"
ok "Rofi → lanzador"

instalar swaync/config.json "$CFG/swaync/config.json"
ok "SwayNC → notificaciones"

if [[ -f "$CFG/hypr/hypridle.conf" ]] && ! grep -q '(zero-rice)' "$CFG/hypr/hypridle.conf"; then
  info "Ya tenías hypridle.conf: no lo toqué (para usar zero-lock pon:  lock_cmd = pidof hyprlock || $S/zero-lock.sh lock)"
else
  instalar hypr/hypridle.conf "$CFG/hypr/hypridle.conf"
  ok "Bloqueo automático → hypridle (10 min) · Super + L para bloquear"
fi

# animaciones: si nunca elegiste, se genera el estilo por defecto (Super + Shift + A para cambiarlo)
if [[ ! -f "$CFG/hypr/animaciones.lua" ]]; then
  "$S/animaciones.sh" regenerar >/dev/null 2>&1 && ok "Animaciones → estilo Zero (cámbialo con Super + Shift + A)"
fi

# hyprland.lua: que nada se arranque dos veces (una barra suelta choca con el guardián)
if [[ -f "$HYPRLUA" ]]; then
  dobles=$(grep -nE '^[[:space:]]*(hl\.exec_cmd\("(swww-daemon|awww-daemon|ags|ags run|swaync)( &)?"\)|spawn_if\("(hypridle|cliphist)")' "$HYPRLUA" || true)
  if [[ -n "$dobles" ]]; then
    warn "Tu hyprland.lua arranca cosas que el rice ya arranca:"
    printf '      %s\n' "${dobles//$'\n'/$'\n      '}"
    if preguntar "¿Las comento (no se borran, solo se desactivan)?"; then
      respaldar "$HYPRLUA"
      sed -i -E \
        -e 's/^([[:space:]]*)(hl\.exec_cmd\("(swww-daemon|awww-daemon|ags|ags run|swaync)( &)?"\))/\1-- \2   -- (zero-rice ya lo arranca)/' \
        -e 's/^([[:space:]]*)(spawn_if\("(hypridle|cliphist)".*)$/\1-- \2   -- (zero-rice ya lo arranca)/' "$HYPRLUA"
      ok "hyprland.lua: listo, ya no se arranca nada dos veces"
    fi
  fi
fi

# estado y caché fuera de ~/.config
mkdir -p "$ESTADO" "$CACHE"
printf '%s\n' "$ENLAZAR" > "$ESTADO/modo-enlazado"
((ENLAZAR)) && ok "Modo enlazado: ~/.config apunta a $REPO (lo que edites queda en git)"
# la 0.2.0 movía la paleta actual a ~/.local/state; paleta.sh la vuelve a buscar en rice-paletas/actual
[[ -f "$ESTADO/paleta" && ! -f "$CFG/rice-paletas/actual" ]] && mv "$ESTADO/paleta" "$CFG/rice-paletas/actual"
[[ -d "$CFG/rice-lanzador" ]] && rm -rf "$CFG/rice-lanzador"

# paletas: agrega las nuevas sin borrar las que el usuario haya creado
LISTA="$CFG/rice-paletas/paletas.txt"
if ((ENLAZAR)); then
  # las paletas que creaste se pasan al repo antes de enlazar
  if [[ -f "$LISTA" && ! -L "$LISTA" ]]; then
    while IFS= read -r linea; do
      [[ -z "$linea" || "$linea" == \#* ]] && continue
      grep -q "^${linea%%|*}|" "$SRC/rice-paletas/paletas.txt" || printf '%s\n' "$linea" >> "$SRC/rice-paletas/paletas.txt"
    done < "$LISTA"
  fi
  instalar rice-paletas/paletas.txt "$LISTA"
  ok "Paletas → enlazadas al repo"
elif [[ -L "$LISTA" ]]; then
  rm -f "$LISTA"; cp "$SRC/rice-paletas/paletas.txt" "$LISTA"
  ok "Paletas → ~/.config/rice-paletas/paletas.txt"
elif [[ -f "$LISTA" ]]; then
  nuevas=0
  while IFS= read -r linea; do
    [[ -z "$linea" || "$linea" == \#* ]] && continue
    grep -q "^${linea%%|*}|" "$LISTA" || { printf '%s\n' "$linea" >> "$LISTA"; nuevas=$((nuevas + 1)); }
  done < "$SRC/rice-paletas/paletas.txt"
  # paletas viejas (sin rojo/verde/...) que no tocaste: se actualizan al formato nuevo
  migradas=0
  while IFS= read -r linea; do
    [[ -z "$linea" || "$linea" == \#* ]] && continue
    id=${linea%%|*}
    vieja=$(grep -m1 "^${id}|" "$LISTA" || true)
    [[ -n "$vieja" && "$vieja" != "$linea" ]] || continue
    if (( $(awk -F'|' '{print NF}' <<<"$vieja") < 18 )) && [[ "$(cut -d'|' -f1-12 <<<"$vieja")" == "$(cut -d'|' -f1-12 <<<"$linea")" ]]; then
      awk -F'|' -v id="$id" -v nueva="$linea" '$1==id{print nueva; next} {print}' "$LISTA" > "$LISTA.tmp" && mv "$LISTA.tmp" "$LISTA"
      migradas=$((migradas + 1))
    fi
  done < "$SRC/rice-paletas/paletas.txt"
  ((migradas)) && info "Paletas: $migradas actualizadas con colores de alerta y terminal"
  case $nuevas in
    0) ok "Paletas: conservé las tuyas (no hay nuevas)" ;;
    1) ok "Paletas: conservé las tuyas y agregué 1 nueva" ;;
    *) ok "Paletas: conservé las tuyas y agregué $nuevas nuevas" ;;
  esac
else
  cp "$SRC/rice-paletas/paletas.txt" "$LISTA"
  ok "Paletas → ~/.config/rice-paletas/paletas.txt"
fi
[[ -f "$CFG/kitty/kitty.conf" ]] || printf '# Configuración de kitty\n' > "$CFG/kitty/kitty.conf"

# ajustes propios de paleta.sh (las actualizaciones nunca tocan este archivo)
[[ -f "$CFG/rice-paletas/ajustes.conf" ]] || cat > "$CFG/rice-paletas/ajustes.conf" <<'AJUSTES'
# Ajustes de paleta.sh — quita el # de lo que quieras cambiar
#CAMBIAR_FONDO=1        # 1 = generar un fondo que combine con la paleta · 0 = no tocar mi fondo
#TEMA_KITTY=1           # 1 = la terminal también cambia de color         · 0 = no tocar kitty
#ESTILO_FONDO=lineas    # lineas · malla · aurora · rejilla · circulos · aleatorio
#TEMA_GTK=1             # 1 = apps GTK (Thunar…) con tu paleta              · 0 = no tocarlas
AJUSTES

# ═════════════════════════ 4. Paleta ═════════════════════════
titulo "Paleta de colores"
ACTUAL=$(cat "$CFG/rice-paletas/actual" 2>/dev/null || true)
if [[ -z "$PALETA" && -n "$ACTUAL" ]]; then
  # ya tenía una: se reaplica sin tocar su fondo de pantalla
  "$S/paleta.sh" regenerar >/dev/null 2>&1 || true
  ok "Conservé tu paleta: $ACTUAL (cámbiala con Super + Shift + P)"
else
  if [[ -z "$PALETA" ]]; then
    PALETA=acero
    if ((SI == 0)); then
      "$S/paleta.sh" lista
      read -rp "$(printf '\e[1;36m[?]\e[0m') Número o nombre de la paleta para empezar [acero]: " r || r=""
      [[ -n "$r" ]] && PALETA="$r"
    fi
  fi
  if [[ "$PALETA" =~ ^[0-9]+$ ]]; then
    PALETA=$(grep -vE '^[[:space:]]*(#|$)' "$LISTA" | sed -n "${PALETA}p" | cut -d'|' -f1)
  fi
  PALETA=${PALETA,,}; PALETA=${PALETA// /}
  PALETA=${PALETA//á/a}; PALETA=${PALETA//é/e}; PALETA=${PALETA//í/i}; PALETA=${PALETA//ó/o}; PALETA=${PALETA//ú/u}
  if "$S/paleta.sh" "${PALETA:-acero}" >/dev/null; then
    ok "Paleta: ${PALETA:-acero} (con su propio fondo de pantalla)"
  else
    warn "No existe la paleta '$PALETA'; uso acero"; "$S/paleta.sh" acero >/dev/null || true
  fi
fi

# ═════════════════════════ 5. Clima ═════════════════════════
titulo "Clima"
if command -v jq >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
  # clima.sh guarda tu ciudad en ~/.local/state/zero-rice/clima (y mueve ahí la de versiones viejas)
  [[ -d "$CFG/rice-clima" ]] && { "$S/clima.sh" >/dev/null 2>&1 || true; }
  UBI="$ESTADO/clima/ubicacion"
  if [[ -s "$UBI" ]]; then
    ok "Ciudad guardada: $(cut -d'|' -f1 "$UBI")"
  elif "$S/clima.sh" actualizar 2>/dev/null && [[ -s "$UBI" ]]; then
    ok "Ubicación detectada: $(cut -d'|' -f1 "$UBI") (aprox.; cámbiala con Super + Shift + C)"
  else
    warn "No pude detectar la ubicación; elige tu ciudad con Super + Shift + C"
  fi
  if "$S/clima.sh" preparar >/dev/null 2>&1; then ok "Lista de ciudades lista"
  else info "La lista de ciudades se descargará la primera vez que uses Super + Shift + C"; fi
else
  warn "Faltan curl/jq para el clima"
fi

# ═════════════════════════ 6. Aplicar ═════════════════════════
titulo "Aplicando"
if en_hyprland; then
  hyprctl reload >/dev/null 2>&1 || true
  "$S/wall.sh" restaurar >/dev/null 2>&1 || true
  if pgrep -x swaync >/dev/null; then
    swaync-client -R >/dev/null 2>&1 || true; swaync-client -rs >/dev/null 2>&1 || true
  else
    setsid -f swaync >/dev/null 2>&1 || true
  fi
  "$S/panel.sh" fondo >/dev/null 2>&1 || true
  # bloqueo automático: se reinicia para que lea su config nueva
  if command -v hypridle >/dev/null 2>&1; then
    pkill -x hypridle 2>/dev/null || true
    setsid -f hypridle >/dev/null 2>&1 && ok "hypridle corriendo (bloqueo automático a los 10 min)"
  fi
  pgrep -f 'cliphist store' >/dev/null || {
    command -v cliphist >/dev/null 2>&1 && setsid -f wl-paste --type text --watch cliphist store >/dev/null 2>&1
    command -v cliphist >/dev/null 2>&1 && setsid -f wl-paste --type image --watch cliphist store >/dev/null 2>&1
    true
  }
  setsid -f "$S/paleta.sh" imagenes indexar >/dev/null 2>&1 || true   # una paleta por cada imagen tuya
  if command -v ags >/dev/null 2>&1; then
    "$S/barra.sh" reiniciar
    info "Levantando la barra..."
    sleep 5
    if pgrep -x ags >/dev/null || pgrep -f "gjs.*ags" >/dev/null; then ok "Barra corriendo"
    else warn "La barra no arrancó; revisa con: ~/.config/hypr/scripts/barra.sh log"; fi
  fi
  ok "Todo aplicado en vivo"
else
  info "No estás dentro de Hyprland: todo arranca solo cuando inicies sesión."
fi

# ═════════════════════════ Resumen ═════════════════════════
titulo "¡Listo!"
cat <<'RESUMEN'
  Super + R              lanzador de apps
  Super + Shift + P      cambiar paleta de colores
  Super + Ctrl + P       siguiente paleta  ·   Super + Alt + P  aleatoria
  Super + Shift + C      elegir ciudad del clima
  Super + W              elegir fondo   ·   Super + Shift + W  fondo aleatorio
  Super + N              notificaciones ·   Super + Shift + N  menú de red
  Super + L              bloquear       ·   Super + Shift + L  personalizar el bloqueo
  Super + Shift + V      portapapeles   ·   Super + Shift + F  foto de perfil
  Super + Shift + A      animaciones    ·   Super + Shift + E  efecto 3D de los workspaces
  Super + B              reiniciar la barra
  Impr Pant              captura de área ·  Shift/Super + Impr Pant  pantalla/ventana

  Actualizar el rice:    ./install.sh --actualizar
  ¿No bloquea?           zero-lock diagnostico
RESUMEN
[[ -d "$RESPALDO" ]] && echo "  Respaldo de lo que había antes: $RESPALDO"
echo
exit 0
