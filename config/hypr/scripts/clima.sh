#!/usr/bin/env bash
# shellcheck disable=SC2154  # (ciudad, temp, codigo...) se crean al leer el clima guardado con printf -v
# clima.sh — clima con Open-Meteo (gratis, sin cuenta ni API key)
#   clima.sh              → actualiza en segundo plano si el dato tiene más de 30 min (lo usa el lanzador)
#   clima.sh actualizar   → actualiza ya
#   clima.sh ciudad       → elegir tu ciudad de una lista que se filtra mientras escribes
#   clima.sh auto         → detectar la ubicación otra vez por internet
#   clima.sh ver          → muestra el clima en la terminal

shopt -u patsub_replacement 2>/dev/null

DIR="$HOME/.config/rice-clima"
UBI="$DIR/ubicacion"      # nombre|lat|lon|modo(auto/manual)
ACTUAL="$DIR/actual"      # datos listos para el lanzador (clave=valor)
AVISO="$DIR/.aviso"
CIUDADES="$DIR/ciudades.tsv"   # lista offline de ciudades (GeoNames, se descarga una vez)
PAIS="$DIR/pais"               # código de país detectado (para mostrar primero las de tu país)       # para no avisar cada 5 minutos que no hay ubicación
LOCK="$DIR/.lock"
TEMA="$HOME/.config/rofi/themes/zero.rasi"
I_PIN=$'\U000f034e'; I_RADAR=$'\U000f01a4'
CUADRO_TEXTO='window { width: 520px; } mainbox { children: [ message, inputbar ]; } message { padding: 10px 16px; border-radius: 12px; background-color: @bg-alt; } textbox { text-color: @fg; }'
CUADRO='window { width: 560px; } mainbox { children: [ message, inputbar, listview ]; } message { padding: 10px 16px; border-radius: 12px; background-color: @bg-alt; } textbox { text-color: @fg; } listview { lines: 8; }'
mkdir -p "$DIR"

leer_actual() {   # carga clima guardado sin ejecutar nada (nombres con espacios, acentos, etc.)
  local k v
  while IFS='=' read -r k v; do [[ "$k" =~ ^[a-z]+$ ]] && printf -v "$k" '%s' "$v"; done < "$ACTUAL"
}
notificar() { command -v notify-send >/dev/null 2>&1 && notify-send -a "Clima" "$@"; return 0; }
falta() { command -v "$1" >/dev/null 2>&1 || { echo "Falta '$1' (sudo pacman -S $1)" >&2; exit 1; }; }
falta curl; falta jq

# ─────────── ubicación ───────────
detectar() {   # por la IP de tu internet (aproximado, como lo hacen las apps del clima)
  local j
  if j=$(curl -fsS --max-time 5 'http://ip-api.com/json/?lang=es&fields=status,city,regionName,country,countryCode,lat,lon') \
     && [[ $(jq -r .status <<<"$j") == success ]]; then
    jq -r '.countryCode // empty' <<<"$j" > "$PAIS"
    printf '%s|%s|%s|auto\n' "$(jq -r 'if (.regionName // "") == "" or .regionName == .city then .city else "\(.city), \(.regionName)" end' <<<"$j")" \
      "$(jq -r .lat <<<"$j")" "$(jq -r .lon <<<"$j")" > "$UBI"
    return 0
  fi
  if j=$(curl -fsS --max-time 5 'https://ipinfo.io/json') && [[ $(jq -r '.loc // empty' <<<"$j") == *,* ]]; then
    jq -r '.country // empty' <<<"$j" > "$PAIS"
    local loc; loc=$(jq -r .loc <<<"$j")
    printf '%s|%s|%s|auto\n' "$(jq -r 'if (.region // "") == "" or .region == .city then .city else "\(.city), \(.region)" end' <<<"$j")" \
      "${loc%,*}" "${loc#*,}" > "$UBI"
    return 0
  fi
  return 1
}

preparar_ciudades() {   # descarga y arma la lista de ciudades (solo la primera vez)
  [[ -s "$CIUDADES" ]] && return 0
  local tmp; tmp=$(mktemp -d)
  notificar "Preparando la lista de ciudades" "Se descarga una sola vez (unos 5 MB)…"
  local base="https://download.geonames.org/export/dump"
  if ! curl -fsSL --max-time 120 -o "$tmp/ciudades.zip" "$base/cities5000.zip" \
     || ! curl -fsSL --max-time 60 -o "$tmp/estados.txt" "$base/admin1CodesASCII.txt" \
     || ! curl -fsSL --max-time 60 -o "$tmp/paises.txt" "$base/countryInfo.txt"; then
    rm -rf "$tmp"; return 1
  fi
  if command -v bsdtar >/dev/null 2>&1; then bsdtar -xOf "$tmp/ciudades.zip" > "$tmp/ciudades.txt"
  elif command -v unzip >/dev/null 2>&1; then unzip -p "$tmp/ciudades.zip" > "$tmp/ciudades.txt"
  else rm -rf "$tmp"; return 1; fi

  # Columnas de salida: país | texto que se muestra | nombre sin acentos | lat | lon
  awk -F'\t' -v OFS='\t' '
    BEGIN {
      # nombres de países en español (los demás quedan en inglés)
      split("MX:México,ES:España,US:Estados Unidos,CO:Colombia,AR:Argentina,CL:Chile,PE:Perú,VE:Venezuela,EC:Ecuador,GT:Guatemala,CU:Cuba,BO:Bolivia,DO:República Dominicana,HN:Honduras,PY:Paraguay,SV:El Salvador,NI:Nicaragua,CR:Costa Rica,PA:Panamá,UY:Uruguay,PR:Puerto Rico,BR:Brasil,CA:Canadá,FR:Francia,DE:Alemania,IT:Italia,PT:Portugal,GB:Reino Unido,JP:Japón,CN:China,KR:Corea del Sur,RU:Rusia,NL:Países Bajos,BE:Bélgica,CH:Suiza,SE:Suecia,NO:Noruega,DK:Dinamarca,PL:Polonia,IE:Irlanda,AU:Australia,IN:India,TR:Turquía,GR:Grecia,MA:Marruecos,EG:Egipto,ZA:Sudáfrica", a, ",")
      for (k in a) { split(a[k], b, ":"); es[b[1]] = b[2] }
      es_estado["MX.09"] = "Ciudad de México"; es_estado["MX.15"] = "Estado de México"
    }
    FILENAME ~ /paises/  { if ($0 !~ /^#/ && $1 != "") pais[$1] = ($1 in es) ? es[$1] : $5; next }
    FILENAME ~ /estados/ { estado[$1] = ($1 in es_estado) ? es_estado[$1] : $2; next }
    {
      nombre = ($2 == "Mexico City") ? "Ciudad de México" : $2
      e = estado[$9 "." $11]; p = pais[$9]
      lugar = nombre
      if (e != "" && e != nombre) lugar = lugar ", " e
      if (p != "") lugar = lugar ", " p
      pob = $15 + 0
      if (pob >= 1000000)   h = sprintf("%.1f M hab.", pob / 1000000)
      else if (pob >= 1000) h = sprintf("%d mil hab.", pob / 1000)
      else                  h = ""
      if (h != "") lugar = lugar "   ·  " h
      print pob, $9, lugar, $3, $5, $6
    }' "$tmp/paises.txt" "$tmp/estados.txt" "$tmp/ciudades.txt" \
  | sort -t$'\t' -k1,1nr | cut -f2- > "$CIUDADES.tmp" && mv "$CIUDADES.tmp" "$CIUDADES"
  rm -rf "$tmp"
  [[ -s "$CIUDADES" ]]
}

buscar_en_internet() {  # $1 = texto; para pueblos que no vienen en la lista
  local q=$1 res n filas sel
  res=$(curl -fsS --max-time 8 -G 'https://geocoding-api.open-meteo.com/v1/search' \
          --data-urlencode "name=$q" -d count=15 -d language=es -d format=json 2>/dev/null) \
    || { notificar -u critical "Sin conexión" "No pude buscar la ciudad"; return 1; }
  n=$(jq '.results // [] | length' <<<"$res")
  if ((n == 0)); then notificar "No encontré «$q»" "Prueba con otro nombre (sin abreviaturas)"; return 2; fi
  filas=$(jq -r '.results[] | [.name, (.admin1 // empty), (.country // empty)] | join(", ")' <<<"$res")
  sel=$(printf '%s\n' "$filas" | rofi -dmenu -i -format i -p "$I_PIN  Elige" \
          -mesg "Encontré $n lugares con «$q» en internet:" -theme "$TEMA" -theme-str "$CUADRO") || return 1
  [[ "$sel" =~ ^[0-9]+$ ]] || return 1
  jq -r --argjson i "$sel" '.results[$i] | "\(.name)\(if (.admin1 // "") != "" and .admin1 != .name then ", " + .admin1 else "" end)|\(.latitude)|\(.longitude)|manual"' <<<"$res" > "$UBI"
}

elegir_ciudad() {
  local tmp sel idx texto pais r=0
  if ! preparar_ciudades; then
    # sin la lista: pedir el nombre y buscar en internet
    while :; do
      texto=$(rofi -dmenu -p "$I_PIN  Ciudad" -mesg "¿De qué ciudad quieres el clima? Escribe el nombre y Enter" \
                -theme "$TEMA" -theme-str "$CUADRO_TEXTO" < /dev/null) || return 1
      [[ -z "$texto" ]] && return 1
      buscar_en_internet "$texto"; r=$?
      ((r == 2)) && continue
      ((r == 0)) && { rm -f "$AVISO"; return 0; }
      return 1
    done
  fi

  # tu país primero, luego el resto (cada grupo de mayor a menor población)
  pais=$(cat "$PAIS" 2>/dev/null)
  tmp=$(mktemp)
  { awk -F'\t' -v p="$pais" 'p != "" && $1 == p' "$CIUDADES"
    awk -F'\t' -v p="$pais" 'p == "" || $1 != p' "$CIUDADES"; } > "$tmp"

  sel=$(
    { printf '%s\0meta\x1f%s\n' "$I_RADAR  Detectar automáticamente (por internet)" "auto detectar"
      awk -F'\t' '{ printf "%s\001meta\037%s\n", $2, $3 }' "$tmp" | tr '\001' '\000'; } \
    | rofi -dmenu -i -normalize-match -format 'i|f' -p "$I_PIN  Ciudad" \
           -mesg "Escribe para filtrar (no importan los acentos). Si no aparece tu pueblo, escribe el nombre y Enter para buscarlo en internet." \
           -theme "$TEMA" -theme-str "$CUADRO window { width: 720px; } listview { lines: 10; fixed-height: false; } element { padding: 8px 14px; } element-icon { enabled: false; size: 0px; }"
  ) || { rm -f "$tmp"; return 1; }

  idx=${sel%%|*}; texto=${sel#*|}
  if [[ "$idx" == 0 ]]; then
    rm -f "$tmp" "$UBI"; detectar; r=$?; rm -f "$AVISO"; return $r
  elif [[ "$idx" =~ ^[0-9]+$ ]] && ((idx > 0)); then
    awk -F'\t' -v n="$idx" 'NR == n { split($2, a, "   ·  "); printf "%s|%s|%s|manual\n", a[1], $4, $5 }' "$tmp" > "$UBI"
    rm -f "$tmp" "$AVISO"; return 0
  fi
  rm -f "$tmp"
  # texto que no está en la lista → buscar en internet
  [[ -n "$texto" ]] || return 1
  buscar_en_internet "$texto" && { rm -f "$AVISO"; return 0; }
  return 1
}

avisar_sin_ubicacion() {
  # una vez cada 6 horas como mucho
  if [[ -f "$AVISO" ]] && (( $(date +%s) - $(stat -c %Y "$AVISO") < 21600 )); then return 0; fi
  touch "$AVISO"
  (
    accion=$(notify-send -a "Clima" -A ciudad="Elegir ciudad" -t 15000 \
      "No sé en qué ciudad estás" "No pude detectar tu ubicación. Elige tu ciudad para ver el clima en el lanzador.")
    [[ "$accion" == ciudad ]] && "$0" ciudad
  ) >/dev/null 2>&1 &
  disown
}

# ─────────── clima ───────────
actualizar() {
  exec 9>"$LOCK"; flock -n 9 || return 0
  if [[ ! -s "$UBI" ]]; then
    detectar || { avisar_sin_ubicacion; return 1; }
  fi
  local nombre lat lon modo j
  IFS='|' read -r nombre lat lon modo < "$UBI"
  j=$(curl -fsS --max-time 8 -G 'https://api.open-meteo.com/v1/forecast' \
        -d "latitude=$lat" -d "longitude=$lon" \
        -d 'current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day' \
        -d 'daily=temperature_2m_max,temperature_2m_min' -d 'timezone=auto' -d 'forecast_days=1' 2>/dev/null) || return 1
  jq -e '.current.temperature_2m' >/dev/null 2>&1 <<<"$j" || return 1
  {
    echo "ciudad=$nombre"
    echo "modo=$modo"
    jq -r '"temp=\(.current.temperature_2m | round)",
           "sensacion=\(.current.apparent_temperature | round)",
           "humedad=\(.current.relative_humidity_2m)",
           "viento=\(.current.wind_speed_10m | round)",
           "codigo=\(.current.weather_code)",
           "dia=\(.current.is_day)",
           "max=\(.daily.temperature_2m_max[0] | round)",
           "min=\(.daily.temperature_2m_min[0] | round)"' <<<"$j"
    echo "hora=$(date +%s)"
  } > "$ACTUAL.tmp" && mv "$ACTUAL.tmp" "$ACTUAL"
}

describir() {   # código WMO → "icono|descripción"   ($1 = código, $2 = 1 si es de día)
  local d=${2:-1}
  case "$1" in
    0)        ((d)) && echo $'\ue30d|Despejado' || echo $'\ue32b|Despejado' ;;
    1)        ((d)) && echo $'\ue30c|Casi despejado' || echo $'\ue379|Casi despejado' ;;
    2)        ((d)) && echo $'\ue302|Parcialmente nublado' || echo $'\ue37e|Parcialmente nublado' ;;
    3)        echo $'\ue312|Nublado' ;;
    45|48)    echo $'\ue313|Niebla' ;;
    51|53|55) echo $'\ue31b|Llovizna' ;;
    56|57)    echo $'\ue3ad|Llovizna helada' ;;
    61)       echo $'\ue318|Lluvia ligera' ;;
    63)       echo $'\ue318|Lluvia' ;;
    65)       echo $'\ue318|Lluvia fuerte' ;;
    66|67)    echo $'\ue3ad|Lluvia helada' ;;
    71|73|75|77) echo $'\ue31a|Nieve' ;;
    80|81|82) echo $'\ue319|Chubascos' ;;
    85|86)    echo $'\ue31a|Chubascos de nieve' ;;
    95)       echo $'\ue31d|Tormenta' ;;
    96|99)    echo $'\ue31d|Tormenta con granizo' ;;
    *)        echo $'\ue312|—' ;;
  esac
}

case "${1:-}" in
  "")
    # si el dato es viejo (o no hay), actualizar en segundo plano sin hacer esperar al lanzador
    if [[ ! -f "$ACTUAL" ]] || (( $(date +%s) - $(stat -c %Y "$ACTUAL") > 1800 )); then
      setsid -f "$0" actualizar >/dev/null 2>&1
    fi ;;
  actualizar) actualizar ;;
  ciudad)
    if elegir_ciudad; then
      actualizar && { leer_actual; notificar "Clima de $ciudad" "${temp}° · $(describir "$codigo" "$dia" | cut -d'|' -f2)"; }
    fi ;;
  auto)
    rm -f "$UBI"
    if detectar; then actualizar; notificar "Ubicación detectada" "$(cut -d'|' -f1 "$UBI")"
    else notificar -u critical "No pude detectar tu ubicación" "Elige tu ciudad con Super + Shift + C"; fi ;;
  ver)
    [[ -f "$ACTUAL" ]] || actualizar
    if [[ -f "$ACTUAL" ]]; then
      leer_actual; IFS='|' read -r ico desc <<<"$(describir "$codigo" "$dia")"
      echo "$ico  ${temp}°C  $desc — $ciudad (máx ${max}° / mín ${min}°, humedad ${humedad}%, viento ${viento} km/h)"
    else
      echo "Sin datos del clima. Usa: clima.sh ciudad"
    fi ;;
  describir) describir "$2" "${3:-1}" ;;
  preparar)  preparar_ciudades && echo "Lista de ciudades lista: $(wc -l < "$CIUDADES") ciudades" ;;
  *) sed -n '2,7p' "$0" ;;
esac
