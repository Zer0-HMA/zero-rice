#!/usr/bin/env bash
# red.sh — menú de red con rofi (Wi-Fi y cable), usa los colores de tu paleta
#   red.sh            → abre el menú
#   red.sh avanzado   → editor completo de conexiones (nmtui sin el azul feo)

shopt -u patsub_replacement 2>/dev/null   # que "&" en los reemplazos sea literal (bash 5.2+)

TEMA="$HOME/.config/rofi/themes/zero.rasi"
LOG="/tmp/red-$USER.log"

# ─────────── colores de la paleta actual (salen del tema de rofi) ───────────
color() { grep -oE "$1: #[0-9a-fA-F]{6}" "$TEMA" 2>/dev/null | head -1 | cut -d' ' -f2; }
ACENTO=$(color acento);  ACENTO=${ACENTO:-#88c0d0}
TENUE=$(color fg-dim);   TENUE=${TENUE:-#888888}

ESTILO='window { width: 620px; }
mainbox { children: [ inputbar, message, listview ]; }
message { padding: 10px 16px; border-radius: 12px; background-color: @bg-alt; }
textbox { text-color: @fg; }
listview { lines: 10; }'

# Iconos (Font Awesome dentro de la Nerd Font)
I_WIFI=$'\uf1eb'; I_CABLE=$'\uf1e6'; I_POWER=$'\uf011'; I_BUSCAR=$'\uf021'
I_AJUSTES=$'\uf013'; I_CANDADO=$'\uf023'; I_DESCONECTAR=$'\uf127'; I_BORRAR=$'\uf1f8'
I_OK=$'\uf00c'; I_ATRAS=$'\uf060'

# nm en inglés para poder leer los estados ("connected" en vez de "conectado"); el texto sigue en UTF-8
nm() { LC_ALL='' LANGUAGE='' LC_MESSAGES=C command nmcli "$@"; }

notificar() { command -v notify-send >/dev/null 2>&1 && notify-send -a "Red" -i network-wireless "$@"; return 0; }
esc() { local s=${1//&/&amp;}; s=${s//</&lt;}; printf '%s' "${s//>/&gt;}"; }
desescapar() { local s=${1//\\:/:}; printf '%s' "${s//\\\\/\\}"; }   # nm -t escapa los ":"

menu() {   # $1 = prompt, $2 = mensaje; filas por stdin → imprime el índice elegido
  rofi -dmenu -i -markup-rows -format i -p "$1" -mesg "$2" -theme "$TEMA" -theme-str "$ESTILO"
}

CUADRO='window { width: 500px; } mainbox { children: [ message, inputbar ]; } message { padding: 10px 16px; border-radius: 12px; background-color: @bg-alt; } textbox { text-color: @fg; }'

pedir_contrasena() {   # $1 = red
  rofi -dmenu -password -p "$I_CANDADO  Contraseña" \
       -mesg "Red: <b>$(esc "$1")</b>" -theme "$TEMA" -theme-str "$CUADRO" < /dev/null
}

pedir_texto() {        # $1 = prompt, $2 = mensaje
  rofi -dmenu -p "$1" -mesg "$2" -theme "$TEMA" -theme-str "$CUADRO" < /dev/null
}

barras() {   # señal 0-100 → ▂▄▆█ con las que faltan en tenue
  local s=$1 n i out="" B=(▂ ▄ ▆ █)
  n=$(( s >= 75 ? 4 : s >= 50 ? 3 : s >= 25 ? 2 : 1 ))
  for i in 0 1 2 3; do
    if (( i < n )); then out+="<span foreground='$ACENTO'>${B[i]}</span>"
    else                 out+="<span foreground='$TENUE'>${B[i]}</span>"; fi
  done
  printf '%s' "$out"
}

# ─────────── acciones ───────────
conectar_wifi() {
  local ssid=$1 seg=$2 pw err rc
  notificar "Conectando a $ssid…"

  # ¿Ya la conocemos? Entonces solo levantarla
  if nm -t -f NAME con show 2>/dev/null | sed 's/\\:/:/g' | grep -Fxq -- "$ssid"; then
    if err=$(nm --wait 25 con up id "$ssid" 2>&1); then
      notificar "Conectado a $ssid"; return 0
    fi
    [[ -z "$seg" ]] && { notificar -u critical "No se pudo conectar a $ssid" "$err"; return 1; }
    # la contraseña guardada ya no sirve: pedir otra
    nm con delete id "$ssid" >/dev/null 2>&1
  fi

  if [[ -n "$seg" ]]; then
    pw=$(pedir_contrasena "$ssid") || return 0
    [[ -z "$pw" ]] && return 0
    err=$(nm --wait 25 dev wifi connect "$ssid" password "$pw" 2>&1); rc=$?
  else
    err=$(nm --wait 25 dev wifi connect "$ssid" 2>&1); rc=$?
  fi

  if ((rc == 0)); then
    notificar "Conectado a $ssid"
  else
    echo "$err" >> "$LOG"
    # si falló, no dejar guardada una conexión con contraseña mala
    nm con delete id "$ssid" >/dev/null 2>&1
    notificar -u critical "No se pudo conectar a $ssid" "¿Contraseña incorrecta? $err"
  fi
}

conectar_oculta() {
  local ssid tipo pw err
  [[ -n "$wifi_dev" ]] || { notificar "No encontré tarjeta Wi-Fi"; return 1; }
  ssid=$(pedir_texto "$I_WIFI  Red oculta" "Escribe el nombre <b>exacto</b> de la red (respeta mayúsculas)") || return 0
  [[ -z "$ssid" ]] && return 0

  tipo=$(printf '%s\n' "$I_CANDADO   Tiene contraseña (WPA/WPA2)" "$I_WIFI   Es abierta, sin contraseña" \
         | menu "$I_WIFI  $ssid" "¿La red <b>$(esc "$ssid")</b> tiene contraseña?") || return 0
  if [[ "$tipo" == "0" ]]; then
    pw=$(pedir_contrasena "$ssid") || return 0
    [[ -z "$pw" ]] && return 0
  fi

  notificar "Conectando a $ssid (oculta)…"
  nm con delete id "$ssid" >/dev/null 2>&1   # por si había una guardada mal
  if ! err=$(nm con add type wifi con-name "$ssid" ifname "$wifi_dev" ssid "$ssid" 802-11-wireless.hidden yes 2>&1); then
    notificar -u critical "No se pudo crear la conexión" "$err"; return 1
  fi
  if [[ -n "${pw:-}" ]]; then
    nm con modify id "$ssid" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$pw" >/dev/null 2>&1
  fi
  if err=$(nm --wait 30 con up id "$ssid" 2>&1); then
    notificar "Conectado a $ssid" "Red oculta guardada; la próxima vez se conecta sola"
  else
    echo "$err" >> "$LOG"
    nm con delete id "$ssid" >/dev/null 2>&1
    notificar -u critical "No se pudo conectar a $ssid" "Revisa el nombre y la contraseña. $err"
  fi
}

submenu_conectada() {
  local ssid=$1 sel
  sel=$(printf '%s\n' \
    "$I_DESCONECTAR   Desconectar" \
    "$I_BORRAR   Olvidar esta red <span size='small' foreground='$TENUE'>(borra la contraseña guardada)</span>" \
    "$I_ATRAS   Regresar" \
    | menu "$I_WIFI  $ssid" "Estás conectado a <b>$(esc "$ssid")</b>") || return 0
  case "$sel" in
    0) nm con down id "$ssid" >/dev/null 2>&1 && notificar "Desconectado de $ssid" ;;
    1) nm con delete id "$ssid" >/dev/null 2>&1 && notificar "Olvidé la red $ssid" ;;
    2) principal ;;
  esac
}

avanzado() {
  # nmtui con colores neutros que respetan el fondo de tu terminal (adiós azul)
  local newt='root=white,default window=white,default shadow=default,default border=gray,default
title=white,default roottext=gray,default helpline=gray,default textbox=white,default
label=white,default listbox=white,default sellistbox=white,default actlistbox=black,white
actsellistbox=black,white button=white,gray compactbutton=white,default actbutton=black,white
checkbox=white,default actcheckbox=black,white entry=white,gray disentry=gray,default
emptyscale=,gray fullscale=,white'
  NEWT_COLORS="$newt" setsid -f kitty --class red-avanzado --title "Conexiones" \
    -o remember_window_size=no -o initial_window_width=96c -o initial_window_height=30c \
    nmtui >/dev/null 2>&1
}

# ─────────── menú principal ───────────
principal() {
  local filas=() acciones=() radio msg="" l tipo nombre activa_wifi=""
  local -a SSID SEG USO

  wifi_dev=$(nm -t -f DEVICE,TYPE dev 2>/dev/null | awk -F: '$2=="wifi"{print $1; exit}')
  radio=$(nm radio wifi 2>/dev/null)

  # Estado actual arriba del menú
  while IFS= read -r l; do
    tipo=${l%%:*}; nombre=$(desescapar "${l#*:}")
    case "$tipo" in
      802-11-wireless) msg+="$I_WIFI  Wi-Fi: <b>$(esc "$nombre")</b>\n"; activa_wifi=$nombre ;;
      802-3-ethernet)  msg+="$I_CABLE  Cable: <b>$(esc "$nombre")</b>\n" ;;
      vpn|wireguard)   msg+="$I_CANDADO  VPN: <b>$(esc "$nombre")</b>\n" ;;
    esac
  done < <(nm -t -f TYPE,NAME con show --active 2>/dev/null)
  [[ -z "$msg" ]] && msg="<span foreground='$TENUE'>Sin conexión</span>"
  msg=$(printf '%b' "${msg%\\n}")

  # Wi-Fi
  if [[ -n "$wifi_dev" ]]; then
    if [[ "$radio" == "enabled" ]]; then
      filas+=("$I_POWER   Apagar Wi-Fi"); acciones+=("radio-off")

      local i=0 vistos="|" uso sen seg ssid
      while IFS= read -r l; do
        uso=${l%%:*}; l=${l#*:}
        sen=${l%%:*}; l=${l#*:}
        seg=${l%%:*}; ssid=$(desescapar "${l#*:}")
        # red oculta: no trae nombre; si es la que estás usando, le ponemos el de tu conexión
        if [[ -z "$ssid" && "$uso" == "*" && -n "$activa_wifi" ]]; then ssid=$activa_wifi; fi
        [[ -z "$ssid" || "$vistos" == *"|$ssid|"* ]] && continue   # sin nombre o repetida
        vistos+="$ssid|"
        [[ "$seg" == "--" ]] && seg=""
        SSID[i]=$ssid; SEG[i]=$seg; USO[i]=$uso
        local extra=""
        [[ -n "$seg" ]] && extra+="  <span foreground='$TENUE'>$I_CANDADO</span>"
        [[ "$uso" == "*" ]] && extra+="  <span foreground='$ACENTO'>$I_OK conectado</span>"
        filas+=("$(barras "$sen")   <b>$(esc "$ssid")</b>$extra"); acciones+=("wifi:$i")
        i=$((i + 1))
      done < <(nm -t -f IN-USE,SIGNAL,SECURITY,SSID dev wifi list --rescan no 2>/dev/null | sort -t: -k1,1r -k2,2nr)   # la conectada primero, luego por señal

      ((i == 0)) && { filas+=("<span foreground='$TENUE'>   No veo redes… dale a buscar</span>"); acciones+=("nada"); }
      filas+=("$I_BUSCAR   Buscar redes otra vez"); acciones+=("buscar")
      filas+=("$I_CANDADO   Conectar a una red oculta…"); acciones+=("oculta")
    else
      filas+=("$I_POWER   Encender Wi-Fi"); acciones+=("radio-on")
    fi
  fi

  # Cable
  while IFS=: read -r dev tipo estado; do
    [[ "$tipo" == "ethernet" ]] || continue
    if [[ "$estado" == "connected" ]]; then
      filas+=("$I_CABLE   Cable <span foreground='$TENUE'>($dev)</span>  <span foreground='$ACENTO'>$I_OK conectado</span>  <span size='small' foreground='$TENUE'>clic para desconectar</span>")
      acciones+=("cable-off:$dev")
    else
      filas+=("$I_CABLE   Cable <span foreground='$TENUE'>($dev) — $estado</span>  <span size='small' foreground='$TENUE'>clic para conectar</span>")
      acciones+=("cable-on:$dev")
    fi
  done < <(nm -t -f DEVICE,TYPE,STATE dev 2>/dev/null)

  filas+=("$I_AJUSTES   Configuración avanzada"); acciones+=("avanzado")

  local sel
  pkill -x rofi && return 0
  sel=$(printf '%s\n' "${filas[@]}" | menu "$I_WIFI  Red" "$msg") || return 0
  [[ -z "$sel" ]] && return 0

  case "${acciones[sel]}" in
    radio-off) nm radio wifi off && notificar "Wi-Fi apagado" ;;
    radio-on)  nm radio wifi on  && notificar "Wi-Fi encendido" "Buscando redes…"; sleep 3; principal ;;
    buscar)    notificar "Buscando redes…"; nm dev wifi rescan >/dev/null 2>&1; sleep 2; principal ;;
    cable-off:*) nm dev disconnect "${acciones[sel]#*:}" >/dev/null 2>&1 && notificar "Cable desconectado" ;;
    cable-on:*)  nm dev connect "${acciones[sel]#*:}" >/dev/null 2>&1 && notificar "Cable conectado" ;;
    avanzado)  avanzado ;;
    oculta)    conectar_oculta ;;
    wifi:*)
      local k=${acciones[sel]#wifi:}
      if [[ "${USO[k]}" == "*" ]]; then submenu_conectada "${SSID[k]}"
      else conectar_wifi "${SSID[k]}" "${SEG[k]}"; fi ;;
  esac
}

command -v nmcli >/dev/null 2>&1 || { notificar "No encontré nmcli" "Instala networkmanager"; exit 1; }

case "${1:-menu}" in
  avanzado) avanzado ;;
  *)        principal ;;
esac
