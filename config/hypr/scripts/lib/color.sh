#!/usr/bin/env bash
# lib/color.sh — matemáticas de color y variables derivadas de la paleta
# shellcheck disable=SC2034  # (V y compañía se usan desde plantillas.sh y paleta.sh)
# Lo carga paleta.sh (no se ejecuta solo). Todo en bash puro, sin dependencias.

declare -gA V=()   # variables disponibles para las plantillas: {{nombre}}

hex()  { printf '%s' "${1#\#}"; }
rgb()  { local h=${1#\#}; printf '%d, %d, %d' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"; }
luma() { local h=${1#\#}; printf '%d' $(( (0x${h:0:2} * 299 + 0x${h:2:2} * 587 + 0x${h:4:2} * 114) / 1000 )); }
es_claro() { (( $(luma "$1") > 140 )); }

# mezcla A B PCT → color que es PCT% de B y el resto de A
mezcla() {
  local a=${1#\#} b=${2#\#} p=$3 i x y out=""
  for i in 0 2 4; do
    x=$((0x${a:i:2})); y=$((0x${b:i:2}))
    out+=$(printf '%02x' $(( (x * (100 - p) + y * p + 50) / 100 )))
  done
  printf '#%s' "$out"
}

# Colores genéricos para cuando una paleta no trae rojo/verde/amarillo/azul/magenta/cyan
defaults_semanticos() {   # $1 = claro|oscuro → imprime 6 colores
  if [[ "$1" == claro ]]; then echo "#c0392b #2e7d4f #a66f00 #2563a8 #8e44ad #0e7490"
  else                         echo "#f87171 #4ade80 #facc15 #60a5fa #c084fc #22d3ee"; fi
}

# Llena V[] a partir de las variables globales de la paleta elegida:
#   ID NOM F F2 TEN TEX A A2 SO INA ROJO VERDE AMAR AZUL MAG CIAN
definir_variables() {
  local claro=0 n c base bright
  es_claro "$F" && claro=1
  V=()
  V[id]=$ID;  V[nombre]=$NOM
  V[modo]=$( ((claro)) && echo claro || echo oscuro )
  V[fondo]=$F;   V[fondo2]=$F2;   V[tenue]=$TEN;   V[texto]=$TEX
  V[acento]=$A;  V[acento2]=$A2;  V[sobre]=$SO;    V[inactivo]=$INA
  V[rojo]=$ROJO; V[verde]=$VERDE; V[amarillo]=$AMAR
  V[azul]=$AZUL; V[magenta]=$MAG; V[cyan]=$CIAN
  V[medio]=$(mezcla "$A" "$A2" 50)                 # punto medio del degradado
  V[sombra]=$(mezcla "$F" "#000000" 55)

  # Modo root de la barra: siempre contrasta con el resto (blanca en tema oscuro, negra en claro)
  if ((claro)); then V[root_fondo]="#1c1c1e"; V[root_texto]="#fefefe"; V[root_borde]="#3a3a3c"
  else               V[root_fondo]="#fefefe"; V[root_texto]="#1c1c1e"; V[root_borde]="#d1d1d3"; fi

  # Terminal (16 colores ANSI). En paletas claras la terminal va invertida (oscura),
  # así que los colores se aclaran para que se lean sobre ese fondo.
  local nombres=(ROJO VERDE AMAR AZUL MAG CIAN)
  if ((claro)); then
    V[term_fondo]=$TEX; V[term_texto]=$F
    V[term_acento]=$(mezcla "$A" "#ffffff" 35); V[term_acento2]=$(mezcla "$A2" "#ffffff" 35)
    V[ansi0]=$(mezcla "$TEX" "#ffffff" 15);  V[ansi8]=$(mezcla "$TEX" "#ffffff" 40)
    V[term_tenue]=${V[ansi8]}
    V[ansi7]=$(mezcla "$F" "$TEX" 15);       V[ansi15]=$F
    for n in 0 1 2 3 4 5; do
      c=${!nombres[n]}
      V[ansi$((n + 1))]=$(mezcla "$c" "#ffffff" 40)
      V[ansi$((n + 9))]=$(mezcla "$c" "#ffffff" 60)
    done
  else
    V[term_fondo]=$F; V[term_texto]=$TEX
    V[term_acento]=$A; V[term_acento2]=$A2; V[term_tenue]=$TEN
    V[ansi0]=$F2;  V[ansi8]=$TEN
    V[ansi7]=$(mezcla "$TEX" "$F" 25);       V[ansi15]=$TEX
    for n in 0 1 2 3 4 5; do
      c=${!nombres[n]}
      base=$c; bright=$(mezcla "$c" "#ffffff" 22)
      V[ansi$((n + 1))]=$base
      V[ansi$((n + 9))]=$bright
    done
  fi
}
