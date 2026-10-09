#!/usr/bin/env bash
# paleta.sh — cambia los colores de TODO tu rice en un clic
#   paleta.sh             → menú con rofi (muestra los colores)
#   paleta.sh tui         → menú dentro de la terminal
#   paleta.sh lista       → ver todas las paletas en la terminal
#   paleta.sh <id>        → aplicar una directo  (ej: paleta.sh tokyo)
#   paleta.sh aleatoria   → una al azar
# Tus paletas viven en ~/.config/rice-paletas/paletas.txt (agrega las tuyas ahí)

CAMBIAR_FONDO=1   # 1 = fondo de la paleta solo si tu fondo actual también es de paleta (respeta el que elegiste)
                  # 2 = siempre poner el fondo de la paleta · 0 = nunca tocar mi fondo
TEMA_KITTY=1      # 1 = la terminal también cambia de color         · 0 = no tocar kitty
TEMA_GTK=1        # 1 = apps GTK (Thunar, etc.) con tu paleta      · 0 = no tocar GTK
TEMA_BLOQUEO=1    # 1 = pantalla de bloqueo (hyprlock) con tu paleta · 0 = no tocarla

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
DIR="$CFG/rice-paletas"
LISTA="$DIR/paletas.txt"
ESTADO="${XDG_STATE_HOME:-$HOME/.local/state}/zero-rice"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/zero-rice"
ACTUAL="$ESTADO/paleta"
mkdir -p "$DIR" "$ESTADO" "$CACHE"
# antes la paleta actual se guardaba junto a las paletas
[[ -f "$DIR/actual" && ! -f "$ACTUAL" ]] && mv "$DIR/actual" "$ACTUAL"

[[ -f "$LISTA" ]] || { echo "No existe $LISTA — vuelve a correr ./install.sh desde el repo" >&2; exit 1; }

# ─────────── utilidades ───────────
trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; printf '%s' "${s%"${s##*[![:space:]]}"}"; }
rgb()  { local h=${1#\#}; printf '%d, %d, %d' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"; }
hex()  { printf '%s' "${1#\#}"; }
es_claro() { local h=${1#\#}; (( (0x${h:0:2}*299 + 0x${h:2:2}*587 + 0x${h:4:2}*114) / 1000 > 140 )); }
notificar() { command -v notify-send >/dev/null 2>&1 && notify-send -a "Paletas" "$@"; return 0; }

# ─────────── leer paletas.txt ───────────
IDS=(); NOMS=(); DESCS=(); SWS=(); DATA=()
while IFS= read -r linea || [[ -n "$linea" ]]; do
  [[ -z "${linea//[[:space:]]/}" || "$linea" =~ ^[[:space:]]*# ]] && continue
  IFS='|' read -r id nom desc sw f f2 ten tex a a2 so ina <<<"$linea"
  id=$(trim "$id"); nom=$(trim "$nom"); desc=$(trim "$desc"); sw=${sw//[[:space:]]/}
  colores=()
  for c in "$f" "$f2" "$ten" "$tex" "$a" "$a2" "$so" "$ina"; do
    c=${c//[[:space:]]/}
    [[ "$c" =~ ^#[0-9a-fA-F]{6}$ ]] || { echo "La paleta '$id' tiene un color mal escrito: '$c'" >&2; continue 2; }
    colores+=("$c")
  done
  IDS+=("$id"); NOMS+=("$nom"); DESCS+=("$desc"); SWS+=("$sw"); DATA+=("${colores[*]}")
done < "$LISTA"

N=${#IDS[@]}
((N)) || { echo "No hay paletas válidas en $LISTA" >&2; exit 1; }

actual_id() { [[ -f "$ACTUAL" ]] && cat "$ACTUAL"; }
indice_de() { local i; for i in "${!IDS[@]}"; do [[ "${IDS[i]}" == "$1" ]] && { echo "$i"; return 0; }; done; return 1; }

# ─────────── generadores de config ───────────
escribir_hypr() {
  mkdir -p "$CFG/hypr"
  cat > "$CFG/hypr/colores.lua" <<EOF
-- Generado por paleta.sh — paleta: $NOM (no lo edites: se sobrescribe al cambiar de paleta)
return {
    acento   = "rgba($(hex "$A")ff)",
    acento2  = "rgba($(hex "$A2")ff)",
    inactivo = "rgba($(hex "$INA")aa)",
}
EOF
  # rice.lua de versiones viejas (con los colores adentro): se sigue parchando para no romperlo
  local rice="$CFG/hypr/rice.lua"
  [[ -f "$rice" ]] && grep -q '^local cyan' "$rice" || return 0
  sed -i -E \
    -e "s/^(local cyan[[:space:]]*=[[:space:]]*)\"[^\"]*\"/\1\"rgba($(hex "$A")ff)\"/" \
    -e "s/^(local rosa[[:space:]]*=[[:space:]]*)\"[^\"]*\"/\1\"rgba($(hex "$A2")ff)\"/" \
    -e "s/inactive_border = \"[^\"]*\"/inactive_border = \"rgba($(hex "$INA")aa)\"/" \
    "$rice"
}

escribir_ags() {
  [[ -d "$CFG/ags" ]] || return 0
  # Barra v2: solo cambian los colores; la forma vive en style.css
  if grep -q 'colores.css' "$CFG/ags/app.tsx" 2>/dev/null; then
    cat > "$CFG/ags/colores.css" <<EOF
/* Generado por paleta.sh — paleta: $NOM */
@define-color fondo    $F;
@define-color fondo2   $F2;
@define-color tenue    $TEN;
@define-color texto    $TEX;
@define-color acento   $A;
@define-color acento2  $A2;
@define-color sobre    $SO;
@define-color inactivo $INA;
EOF
    return 0
  fi
  # Barra v1 (vieja): se reescribe todo el style.css
  cat > "$CFG/ags/style.css" <<EOF
/* Generado por paleta.sh — paleta: $NOM */
window.barra {
  background: transparent;
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 13px;
  font-weight: bold;
  color: $TEX;
}
.contenedor { margin: 8px 12px 0 12px; }

.barra button,
.barra menubutton > button {
  background: none; border: none; box-shadow: none; outline: none;
  padding: 0; min-height: 0; min-width: 0; color: inherit;
}

.barra .modulo {
  background-color: rgba($(rgb "$F"), 0.82);
  border: 1px solid rgba($(rgb "$A"), 0.30);
  border-radius: 12px;
  padding: 4px 14px;
  min-height: 26px;
}
.barra menubutton.modulo > button { padding: 0; }

.barra .lanzador { color: $A; font-size: 18px; padding: 2px 14px; transition: color 200ms ease; }
.barra .lanzador:hover { color: $TEX; }

.barra .workspaces { padding: 4px 6px; }
.barra .workspaces button {
  color: $TEN; min-width: 26px; padding: 2px 8px; border-radius: 8px; transition: all 200ms ease;
}
.barra .workspaces button:hover { color: $TEX; background-color: $F2; }
.barra .workspaces button.activo {
  color: $SO; min-width: 40px;
  background-image: linear-gradient(to right, $A, $A2);
}

.barra .titulo { color: $TEN; padding: 0 8px; }
.barra .reloj .icono { color: $A; }
.barra .stats   { color: $A; }
.barra .volumen { color: $A; }
.barra .bateria { color: $TEX; }
.barra .bateria.baja { color: #f87171; }
.barra .notis, .barra .paletas { font-size: 15px; transition: color 200ms ease; }
.barra .notis:hover, .barra .paletas:hover { color: $A; }
.barra .bandeja { padding: 4px 10px; }

popover > contents {
  background-color: rgba($(rgb "$F"), 0.95);
  border: 1px solid rgba($(rgb "$A"), 0.5);
  border-radius: 14px; padding: 10px; color: $TEX;
}
popover > arrow { background-color: rgba($(rgb "$F"), 0.95); }
.pop-volumen scale trough { background-color: $F2; border-radius: 8px; min-height: 6px; }
.pop-volumen scale highlight { background-image: linear-gradient(to right, $A, $A2); border-radius: 8px; }
.pop-volumen scale slider { background-color: $TEX; border-radius: 50%; min-width: 14px; min-height: 14px; box-shadow: none; }
calendar { background: transparent; border: none; color: $TEX; }
calendar > grid > label.today { background-image: linear-gradient(to right, $A, $A2); color: $SO; border-radius: 8px; }
tooltip { background-color: rgba($(rgb "$F"), 0.95); border: 1px solid $A; border-radius: 10px; color: $TEX; }
EOF
}

escribir_rofi() {
  mkdir -p "$CFG/rofi/themes"
  local vars
  vars="    bg: $(printf '#%sf0' "$(hex "$F")"); bg-alt: $F2; fg: $TEX; fg-dim: $TEN;
    acento: $A; acento2: $A2; sobre: $SO;
    background-color: transparent;
    text-color: @fg;"

  # Colores sueltos para el lanzador (lanzador.rasi los importa)
  cat > "$CFG/rofi/themes/colores.rasi" <<EOF
/* Generado por paleta.sh — paleta: $NOM */
* {
    bg:       $(printf '#%sf2' "$(hex "$F")");
    bg-alt:   $F2;
    fg:       $TEX;
    fg-dim:   $TEN;
    acento:   $A;
    acento2:  $A2;
    sobre:    $SO;
    sombra:   $(printf '#%sb0' "$(hex "$F")");
    degradado: linear-gradient(to bottom, $A, $A2);
}
EOF

  cat > "$CFG/rofi/themes/zero.rasi" <<EOF
/* Generado por paleta.sh — paleta: $NOM */
* {
$vars
    font: "JetBrainsMono Nerd Font 12";
}
window { width: 620px; background-color: @bg; border: 2px; border-color: @acento; border-radius: 16px; padding: 18px; }
mainbox { spacing: 14px; children: [ inputbar, listview ]; }
inputbar { children: [ prompt, entry ]; spacing: 12px; padding: 12px 16px; border-radius: 12px; background-color: @bg-alt; }
prompt { text-color: @acento; }
entry { placeholder: "Buscar..."; placeholder-color: @fg-dim; cursor: text; }
listview { lines: 8; columns: 1; spacing: 6px; fixed-height: true; scrollbar: false; }
element { padding: 9px 14px; spacing: 14px; border-radius: 10px; cursor: pointer; }
element selected.normal { background-image: linear-gradient(to right, $(printf '#%s40' "$(hex "$A")"), $(printf '#%s20' "$(hex "$A2")")); border: 0 0 0 3px; border-color: @acento; }
element-icon { size: 30px; cursor: inherit; }
element-text { vertical-align: 0.5; text-color: inherit; cursor: inherit; }
EOF

  cat > "$CFG/rofi/themes/wallpapers.rasi" <<EOF
/* Generado por paleta.sh — paleta: $NOM */
* {
$vars
    font: "JetBrainsMono Nerd Font 11";
}
window { width: 1040px; background-color: @bg; border: 2px; border-color: @acento2; border-radius: 18px; padding: 20px; }
mainbox { spacing: 16px; children: [ inputbar, listview ]; }
inputbar { children: [ prompt, entry ]; spacing: 12px; padding: 12px 16px; border-radius: 12px; background-color: @bg-alt; }
prompt { text-color: @acento; }
entry { placeholder: "Buscar fondo..."; placeholder-color: @fg-dim; }
listview { columns: 4; lines: 2; spacing: 14px; fixed-columns: true; scrollbar: false; }
element { orientation: vertical; children: [ element-icon, element-text ]; padding: 10px; spacing: 8px; border-radius: 14px; cursor: pointer; }
element selected.normal { background-color: @bg-alt; border: 2px; border-color: @acento; }
element-icon { size: 210px; horizontal-align: 0.5; cursor: inherit; }
element-text { horizontal-align: 0.5; text-color: inherit; cursor: inherit; }
EOF

  cat > "$CFG/rofi/themes/paletas.rasi" <<EOF
/* Menú de paletas — generado por paleta.sh */
* {
$vars
    font: "JetBrainsMono Nerd Font 12";
}
window { width: 820px; background-color: @bg; border: 2px; border-color: @acento; border-radius: 18px; padding: 20px; }
mainbox { spacing: 16px; children: [ inputbar, listview ]; }
inputbar { children: [ prompt, entry ]; spacing: 12px; padding: 12px 16px; border-radius: 12px; background-color: @bg-alt; }
prompt { text-color: @acento; }
entry { placeholder: "Busca una paleta... (Enter para aplicar)"; placeholder-color: @fg-dim; }
listview { lines: 9; columns: 1; spacing: 6px; fixed-height: true; scrollbar: false; }
element { padding: 10px 16px; border-radius: 12px; cursor: pointer; }
element selected.normal { background-color: @bg-alt; border: 0 0 0 4px; border-color: @acento; }
element-text { font: "JetBrainsMono Nerd Font 14"; vertical-align: 0.5; text-color: @fg; cursor: inherit; }
EOF
}

escribir_swaync() {
  mkdir -p "$CFG/swaync"
  cat > "$CFG/swaync/style.css" <<EOF
/* Generado por paleta.sh — paleta: $NOM */
* { font-family: "JetBrainsMono Nerd Font", sans-serif; }
.floating-notifications, .blank-window, .notification-row,
.notification-background, .control-center-list { background: transparent; outline: none; box-shadow: none; }
.notification { background: rgba($(rgb "$F"), 0.94); border: 2px solid $A; border-radius: 14px; margin: 6px 10px; padding: 0; box-shadow: 0 4px 14px rgba(0,0,0,0.45); }
.notification.critical { border-color: #f87171; }
.notification-content { background: transparent; padding: 10px; }
.notification-default-action, .notification-action { background: transparent; border: none; border-radius: 12px; color: $TEX; }
.notification-default-action:hover, .notification-action:hover { background: rgba($(rgb "$A"), 0.10); }
.summary { color: $TEX; font-weight: bold; font-size: 14px; }
.body { color: $TEN; font-size: 13px; }
.time { color: $A; font-size: 11px; margin-right: 26px; }
.close-button { background: $A; color: $SO; border: none; border-radius: 100px; min-width: 22px; min-height: 22px; margin: 8px; padding: 0; }
.close-button:hover { background: $A2; }
.control-center { background: rgba($(rgb "$F"), 0.94); border: 2px solid $A2; border-radius: 18px; padding: 10px; color: $TEX; }
.widget-title { color: $TEX; font-size: 16px; font-weight: bold; margin: 8px; }
.widget-title > button { background: $F2; color: $TEX; border: none; border-radius: 10px; padding: 4px 12px; }
.widget-title > button:hover { background: $A; color: $SO; }
.widget-dnd { margin: 8px; color: $TEX; font-size: 14px; }
.widget-dnd > switch { background: $F2; border: none; border-radius: 12px; }
.widget-dnd > switch:checked { background: $A; }
.widget-dnd > switch slider { background: $TEX; border-radius: 12px; }
.widget-mpris { margin: 8px; }
.widget-mpris-player { background: $F2; border-radius: 14px; padding: 10px; }
/* Botones de acción (ej. Abrir / Carpeta / Editar / Borrar de las capturas) */
.notification-action { background: $F2; border-radius: 10px; margin: 4px; padding: 0; }
.notification-action > button { background: transparent; border: none; box-shadow: none; color: $TEX; font-weight: bold; padding: 6px 10px; }
.notification-action:hover { background: $A; }
.notification-action:hover > button { color: $SO; }
/* Vista previa de imágenes dentro de la notificación */
.notification picture { border-radius: 12px; margin-top: 8px; }
EOF
}

escribir_kitty() {
  ((TEMA_KITTY)) || return 0
  [[ -d "$CFG/kitty" ]] || return 0
  local kbg="$F" kfg="$TEX"
  if es_claro "$F"; then kbg="$TEX"; kfg="$F"; fi   # en paletas claras la terminal va invertida
  cat > "$CFG/kitty/paleta.conf" <<EOF
# Generado por paleta.sh — paleta: $NOM
background $kbg
foreground $kfg
cursor $A
cursor_text_color $SO
selection_background $A
selection_foreground $SO
url_color $A
active_border_color $A
inactive_border_color $INA
EOF
  local conf="$CFG/kitty/kitty.conf"
  touch "$conf"
  grep -q '^include paleta.conf' "$conf" || printf '\n# Colores de paleta.sh\ninclude paleta.conf\n' >> "$conf"
  pkill -USR1 -x kitty 2>/dev/null || true   # kitty recarga su config con esta señal
}

escribir_gtk() {
  ((TEMA_GTK)) || return 0
  local claro=0 v d css
  es_claro "$F" && claro=1
  for v in 3.0 4.0; do
    d="$CFG/gtk-$v"; mkdir -p "$d"
    if [[ $v == 3.0 ]]; then
      cat > "$d/zero-paleta.css" <<EOF
/* Generado por paleta.sh — paleta: $NOM (tema Adwaita de GTK 3: Thunar, etc.) */
@define-color theme_bg_color $F2;
@define-color theme_fg_color $TEX;
@define-color theme_base_color $F;
@define-color theme_text_color $TEX;
@define-color theme_selected_bg_color $A;
@define-color theme_selected_fg_color $SO;
@define-color theme_unfocused_bg_color $F2;
@define-color theme_unfocused_fg_color $TEX;
@define-color theme_unfocused_base_color $F;
@define-color theme_unfocused_text_color $TEX;
@define-color theme_unfocused_selected_bg_color $A;
@define-color theme_unfocused_selected_fg_color $SO;
@define-color insensitive_fg_color $TEN;
@define-color borders $INA;
@define-color unfocused_borders $INA;
EOF
    else
      cat > "$d/zero-paleta.css" <<EOF
/* Generado por paleta.sh — paleta: $NOM (GTK 4 / libadwaita) */
@define-color accent_color $A;
@define-color accent_bg_color $A;
@define-color accent_fg_color $SO;
@define-color window_bg_color $F;
@define-color window_fg_color $TEX;
@define-color view_bg_color $F;
@define-color view_fg_color $TEX;
@define-color headerbar_bg_color $F2;
@define-color headerbar_fg_color $TEX;
@define-color sidebar_bg_color $F2;
@define-color sidebar_fg_color $TEX;
@define-color card_bg_color $F2;
@define-color card_fg_color $TEX;
@define-color popover_bg_color $F2;
@define-color popover_fg_color $TEX;
@define-color dialog_bg_color $F2;
@define-color dialog_fg_color $TEX;
:root {
  --accent-color: $A; --accent-bg-color: $A; --accent-fg-color: $SO;
  --window-bg-color: $F; --window-fg-color: $TEX;
  --view-bg-color: $F; --view-fg-color: $TEX;
  --headerbar-bg-color: $F2; --headerbar-fg-color: $TEX;
  --sidebar-bg-color: $F2; --sidebar-fg-color: $TEX;
  --card-bg-color: $F2; --card-fg-color: $TEX;
  --popover-bg-color: $F2; --popover-fg-color: $TEX;
  --dialog-bg-color: $F2; --dialog-fg-color: $TEX;
}
EOF
    fi
    # se importa al principio de tu gtk.css (lo demás que tengas ahí se queda)
    css="$d/gtk.css"
    if ! grep -qF '@import url("zero-paleta.css");' "$css" 2>/dev/null; then
      { echo '@import url("zero-paleta.css");'; [[ -f "$css" ]] && cat "$css"; true; } > "$css.tmp" && mv "$css.tmp" "$css"
    fi
  done
  # modo oscuro/claro para las apps que lo preguntan
  if command -v gsettings >/dev/null 2>&1; then
    if ((claro)); then
      gsettings set org.gnome.desktop.interface color-scheme prefer-light 2>/dev/null
      gsettings set org.gnome.desktop.interface gtk-theme Adwaita 2>/dev/null
    else
      gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null
      gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark 2>/dev/null
    fi
  fi
  return 0
}

escribir_hyprlock() {
  ((TEMA_BLOQUEO)) || return 0
  local conf="$CFG/hypr/hyprlock.conf"
  # si ya tenías tu propio hyprlock.conf, no se toca
  [[ -f "$conf" ]] && ! head -1 "$conf" | grep -q 'Generado por paleta.sh' && return 0
  mkdir -p "$CFG/hypr"
  cat > "$conf" <<EOF
# Generado por paleta.sh — paleta: $NOM  (bórrale esta línea si no quieres que paleta.sh lo cambie)
general {
    hide_cursor = true
    ignore_empty_input = true
}

background {
    monitor =
    path = screenshot
    blur_passes = 3
    blur_size = 8
    brightness = 0.6
}

label {
    monitor =
    text = \$TIME
    color = rgb($(hex "$TEX"))
    font_size = 96
    font_family = JetBrainsMono Nerd Font
    position = 0, 170
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:60000] date +"%A %d de %B"
    color = rgba($(hex "$TEX")cc)
    font_size = 18
    font_family = JetBrainsMono Nerd Font
    position = 0, 80
    halign = center
    valign = center
}

input-field {
    monitor =
    size = 320, 56
    outline_thickness = 2
    outer_color = rgb($(hex "$A")) rgb($(hex "$A2")) 45deg
    inner_color = rgba($(hex "$F")dd)
    font_color = rgb($(hex "$TEX"))
    check_color = rgb($(hex "$A2"))
    fail_color = rgb(f87171)
    fail_text = Contraseña incorrecta
    placeholder_text = Contraseña…
    fade_on_empty = false
    dots_center = true
    rounding = 14
    position = 0, -40
    halign = center
    valign = center
}
EOF
}

generar_fondo() {
  ((CAMBIAR_FONDO)) || return 0
  if ((CAMBIAR_FONDO == 1)); then
    # solo si el fondo actual es de paleta (o no hay); si tú elegiste uno, se respeta
    local cur; cur=$(cat "$CFG/wallpapers/.actual" 2>/dev/null)
    [[ -n "$cur" && -f "$cur" && "$(basename "$cur")" != paleta-*.png ]] && return 0
  fi
  local W=1920 H=1080 res svg="$CACHE/fondo.svg" png="$CFG/wallpapers/paleta-$ID.png"
  # el monitor más grande, para que en ninguno se vea pixeleado
  res=$(hyprctl monitors 2>/dev/null | grep -oE '[0-9]+x[0-9]+@' | tr -d '@' | sort -t x -k1,1nr | head -1)
  [[ -n "$res" ]] && { W=${res%x*}; H=${res#*x}; }
  local ya0=$((H - 200)) ya1=$((H - 200 - W * 55 / 100))
  local yb0=$((H - 40))  yb1=$((H - 40 - W * 55 / 100))
  local brillo=0.5 medio=0.28 suave=0.08
  es_claro "$F" && { brillo=0.38; medio=0.2; suave=0.06; }

  mkdir -p "$CFG/wallpapers"
  cat > "$svg" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="$W" height="$H" viewBox="0 0 $W $H">
  <defs>
    <radialGradient id="g1" cx="12%" cy="98%" r="60%">
      <stop offset="0" stop-color="$A" stop-opacity="$brillo"/>
      <stop offset="0.35" stop-color="$A" stop-opacity="$medio"/>
      <stop offset="0.7" stop-color="$A" stop-opacity="$suave"/>
      <stop offset="1" stop-color="$A" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="g2" cx="92%" cy="4%" r="62%">
      <stop offset="0" stop-color="$A2" stop-opacity="$brillo"/>
      <stop offset="0.35" stop-color="$A2" stop-opacity="$medio"/>
      <stop offset="0.7" stop-color="$A2" stop-opacity="$suave"/>
      <stop offset="1" stop-color="$A2" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="l1" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="$W" y2="0">
      <stop offset="0" stop-color="$A" stop-opacity="0"/>
      <stop offset="0.55" stop-color="$A" stop-opacity="0.85"/>
      <stop offset="1" stop-color="$A" stop-opacity="0.1"/>
    </linearGradient>
    <linearGradient id="l2" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="$W" y2="0">
      <stop offset="0" stop-color="$A2" stop-opacity="0"/>
      <stop offset="0.6" stop-color="$A2" stop-opacity="0.7"/>
      <stop offset="1" stop-color="$A2" stop-opacity="0.1"/>
    </linearGradient>
    <filter id="grano" x="0" y="0" width="100%" height="100%">
      <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" stitchTiles="stitch"/>
      <feColorMatrix type="saturate" values="0"/>
    </filter>
  </defs>
  <rect width="100%" height="100%" fill="$F"/>
  <rect width="100%" height="100%" fill="url(#g1)"/>
  <rect width="100%" height="100%" fill="url(#g2)"/>
  <line x1="0" y1="$ya0" x2="$W" y2="$ya1" stroke="url(#l1)" stroke-width="3"/>
  <line x1="0" y1="$yb0" x2="$W" y2="$yb1" stroke="url(#l2)" stroke-width="2"/>
  <rect width="100%" height="100%" filter="url(#grano)" opacity="0.035"/>
</svg>
EOF

  if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w "$W" -h "$H" -o "$png" "$svg" || return 0
  elif command -v magick >/dev/null 2>&1; then
    magick "$svg" "$png" || return 0
  else
    echo "Para generar fondos instala librsvg:  sudo pacman -S librsvg" >&2
    return 0
  fi
  poner_fondo "$png"
}

poner_fondo() {
  local W=swww
  command -v awww >/dev/null 2>&1 && W=awww
  command -v "$W" >/dev/null 2>&1 || return 0
  "$W" query &>/dev/null || { setsid -f "$W-daemon" >/dev/null 2>&1; sleep 1; }
  "$W" img "$1" --transition-type grow --transition-fps 60 --transition-duration 1.2 || return 0
  printf '%s\n' "$1" > "$CFG/wallpapers/.actual"
}

recargar() {
  [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || return 0
  hyprctl reload >/dev/null 2>&1 || true
  swaync-client -rs >/dev/null 2>&1 || true
  # la barra nueva ve que cambió colores.css y se repinta sola, sin reiniciarse (sin parpadeo)
  grep -q 'monitorFile' "$CFG/ags/app.tsx" 2>/dev/null && return 0
  if [[ -x "$CFG/hypr/scripts/barra.sh" ]]; then
    "$CFG/hypr/scripts/barra.sh" reiniciar
  elif [[ -f "$CFG/ags/app.tsx" ]] && command -v ags >/dev/null 2>&1; then
    ags quit >/dev/null 2>&1 || true
    sleep 0.4
    setsid -f ags run >/dev/null 2>&1
  fi
}

aplicar() {
  local i=$1
  ID=${IDS[i]}; NOM=${NOMS[i]}
  read -r F F2 TEN TEX A A2 SO INA <<<"${DATA[i]}"
  escribir_hypr
  escribir_ags
  escribir_rofi
  escribir_swaync
  escribir_kitty
  escribir_gtk
  escribir_hyprlock
  printf '%s\n' "$ID" > "$ACTUAL"
  recargar
  generar_fondo
  notificar "Paleta: $NOM" "${DESCS[i]}"
  echo "Paleta aplicada: $NOM"
}

# ─────────── vistas ───────────
bloques_markup() {   # franja de colores para rofi (siempre del mismo ancho)
  local total=18 i n k out=""
  IFS=',' read -ra cs <<<"$1"; n=${#cs[@]}
  for i in "${!cs[@]}"; do
    k=$(( total / n + (i < total % n ? 1 : 0) ))
    out+="<span foreground='${cs[i]}'>$(printf '█%.0s' $(seq 1 "$k"))</span>"
  done
  printf '%s' "$out"
}

bloques_terminal() { # franja de colores con truecolor (siempre del mismo ancho)
  local total=24 i n k h
  IFS=',' read -ra cs <<<"$1"; n=${#cs[@]}
  for i in "${!cs[@]}"; do
    k=$(( total / n + (i < total % n ? 1 : 0) )); h=${cs[i]#\#}
    printf '\e[38;2;%d;%d;%dm' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
    printf '█%.0s' $(seq 1 "$k"); printf '\e[0m'
  done
}

menu_rofi() {
  local cur sel i marca tenue
  cur=$(actual_id)
  # el menú usa la paleta actual; si nunca has elegido, usa la primera
  if [[ ! -f "$CFG/rofi/themes/paletas.rasi" ]]; then
    ID=${IDS[0]}; NOM=${NOMS[0]}; read -r F F2 TEN TEX A A2 SO INA <<<"${DATA[0]}"; escribir_rofi
  fi
  tenue=$(grep -oE 'fg-dim: #[0-9a-fA-F]{6}' "$CFG/rofi/themes/paletas.rasi" | head -1 | cut -d' ' -f2)
  pkill -x rofi && return 0
  sel=$(
    for i in "${!IDS[@]}"; do
      marca=""; [[ "${IDS[i]}" == "$cur" ]] && { marca="  <span foreground='${tenue:-#888888}'>● actual</span>"; }
      printf '%s   <b>%s</b>  <span size="small" foreground="%s">%s</span>%s\n' \
        "$(bloques_markup "${SWS[i]}")" "${NOMS[i]}" "${tenue:-#888888}" "${DESCS[i]}" "$marca"
    done | rofi -dmenu -i -markup-rows -format i -p "$(printf '\U000F03D8') Paletas" \
                -selected-row "$(indice_de "$cur" || echo 0)" \
                -theme "$CFG/rofi/themes/paletas.rasi"
  ) || return 0
  [[ -n "$sel" ]] && aplicar "$sel"
}

lista_terminal() {
  local cur i; cur=$(actual_id)
  echo
  for i in "${!IDS[@]}"; do
    printf '  \e[1m%2d\e[0m  ' "$((i + 1))"
    bloques_terminal "${SWS[i]}"
    local nom=${NOMS[i]}
    printf '  \e[1m%s%*s\e[0m \e[2m%s\e[0m' "$nom" $((17 - ${#nom})) '' "${DESCS[i]}"
    [[ "${IDS[i]}" == "$cur" ]] && printf '  \e[1;32m● actual\e[0m'
    echo
  done
  echo
}

menu_tui() {
  lista_terminal
  local n
  read -rp "  Elige un número (Enter para cancelar): " n
  [[ "$n" =~ ^[0-9]+$ ]] && ((n >= 1 && n <= N)) || { echo "  Cancelado."; return 0; }
  aplicar $((n - 1))
}

case "${1:-menu}" in
  menu)              menu_rofi ;;
  tui|terminal)      menu_tui ;;
  lista|ls)          lista_terminal ;;
  aleatoria|random)
    cur=$(actual_id)
    while :; do i=$((RANDOM % N)); [[ "${IDS[i]}" != "$cur" || $N -eq 1 ]] && break; done
    aplicar "$i" ;;
  regenerar)         # reaplica la paleta actual a todo MENOS el fondo de pantalla (lo usa el instalador)
    i=$(indice_de "$(actual_id)") || i=0
    ID=${IDS[i]}; NOM=${NOMS[i]}
    read -r F F2 TEN TEX A A2 SO INA <<<"${DATA[i]}"
    escribir_hypr; escribir_ags; escribir_swaync; escribir_rofi; escribir_kitty; escribir_gtk; escribir_hyprlock
    printf '%s\n' "$ID" > "$ACTUAL"
    swaync-client -rs >/dev/null 2>&1 || true ;;
  colores-barra)     # solo regenera los colores de la barra con la paleta actual (lo usa el instalador)
    i=$(indice_de "$(actual_id)") || i=0
    ID=${IDS[i]}; NOM=${NOMS[i]}
    read -r F F2 TEN TEX A A2 SO INA <<<"${DATA[i]}"
    escribir_ags ;;
  -h|--help|ayuda)   sed -n '2,8p' "$0" ;;
  *)
    i=$(indice_de "$1") || { echo "No existe la paleta '$1'. Usa: paleta.sh lista" >&2; exit 1; }
    aplicar "$i" ;;
esac
