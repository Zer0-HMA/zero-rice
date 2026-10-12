#!/usr/bin/env bash
# lib/dinamica.sh — una paleta guardada por cada una de tus imágenes (necesita ImageMagick)
#
#   colores_de_imagen IMG [oscuro|claro]  → imprime los 14 colores de la paleta de esa imagen
#   indexar_imagenes [IMG...]             → calcula y guarda la paleta de cada imagen
#
# Guarda:  ~/.config/rice-paletas/imagenes.txt   mismo formato que paletas.txt + la ruta de la imagen
#          ~/.config/rice-paletas/imagenes.idx   qué ya se calculó (ruta|fecha|tamaño|modo|id)
#          ~/.cache/rice-paletas/miniaturas/     miniaturas para el menú
# Solo se recalcula lo que cambió; borrar una imagen quita su paleta.

IMG_LISTA="$DIR/imagenes.txt"
IMG_INDICE="$DIR/imagenes.idx"
MINIS="${XDG_CACHE_HOME:-$HOME/.cache}/rice-paletas/miniaturas"
IMG_REGEX='.*\.(jpe?g|png|webp|gif|bmp)$'

_im() { if command -v magick >/dev/null 2>&1; then echo magick; elif command -v convert >/dev/null 2>&1; then echo convert; else return 1; fi; }

# colores_de_imagen IMAGEN [oscuro|claro] → "F F2 TEN TEX A A2 SO INA rojo verde amarillo azul magenta cyan"
colores_de_imagen() {
  local img=$1 modo=${2:-oscuro} IM hist
  IM=$(_im) || return 1
  hist=$("$IM" "${img}[0]" -alpha off -resize 200x200 -colors 16 -depth 8 -format '%c' histogram:info:- 2>/dev/null \
         | sed -nE 's/^ *([0-9]+): *\([^)]*\) *(#[0-9A-Fa-f]{6}).*/\1 \2/p')
  [[ -n "$hist" ]] || return 1
  awk -v modo="$modo" '
    function max(a,b){return a>b?a:b} function min(a,b){return a<b?a:b}
    function clamp(x,lo,hi){return min(hi,max(lo,x))}
    function h2d(s,  i,v,c){v=0;s=tolower(s);for(i=1;i<=length(s);i++){c=index("0123456789abcdef",substr(s,i,1))-1;v=v*16+c}return v}
    function dh(a,b,  d){d=a-b;if(d<0)d=-d;return d>180?360-d:d}
    function hsl2hex(h,s,l,  c,x,m,r,g,b,hp){
      h=(h%360+360)%360; c=(1-((2*l-1)<0?-(2*l-1):(2*l-1)))*s; hp=h/60
      x=c*(1-((hp%2-1)<0?-(hp%2-1):(hp%2-1))); m=l-c/2
      if(hp<1){r=c;g=x;b=0}else if(hp<2){r=x;g=c;b=0}else if(hp<3){r=0;g=c;b=x}
      else if(hp<4){r=0;g=x;b=c}else if(hp<5){r=x;g=0;b=c}else{r=c;g=0;b=x}
      return sprintf("#%02x%02x%02x",(r+m)*255+0.5,(g+m)*255+0.5,(b+m)*255+0.5)}
    {
      n++; cnt[n]=$1; total+=$1
      R=h2d(substr($2,2,2))/255; G=h2d(substr($2,4,2))/255; B=h2d(substr($2,6,2))/255
      mx=max(R,max(G,B)); mn=min(R,min(G,B)); L=(mx+mn)/2; d=mx-mn
      if(d==0){S=0;Hh=0}else{
        S=d/(1-((2*L-1)<0?-(2*L-1):(2*L-1)))
        if(mx==R)Hh=60*(((G-B)/d)%6); else if(mx==G)Hh=60*((B-R)/d+2); else Hh=60*((R-G)/d+4)
        if(Hh<0)Hh+=360}
      hh[n]=Hh; ss[n]=S; ll[n]=L; if(S>maxs)maxs=S
    }
    END{
      ia=0;best=0
      for(i=1;i<=n;i++) if(ss[i]>=0.22 && ll[i]>=0.22 && ll[i]<=0.88){sc=ss[i]*(0.35+sqrt(cnt[i]/total)); if(sc>best){best=sc;ia=i}}
      gris=(maxs<0.12 || ia==0)
      if(gris){ha=210;sa=0.28}else{ha=hh[ia];sa=ss[ia]}
      h2=(ha+40)%360;s2=sa;best=0
      for(i=1;i<=n;i++) if(!gris && ss[i]>=0.2 && ll[i]>=0.22 && ll[i]<=0.88 && dh(hh[i],ha)>=35){sc=ss[i]*(0.3+sqrt(cnt[i]/total)); if(sc>best){best=sc;h2=hh[i];s2=ss[i]}}
      sb=gris?0.08:min(0.32,sa*0.5)
      if(modo=="claro"){
        A=hsl2hex(ha,clamp(sa,0.5,0.85),0.38); A2=hsl2hex(h2,clamp(s2,0.45,0.8),0.42)
        F=hsl2hex(ha,sb,0.95); F2=hsl2hex(ha,sb,0.88); INA=hsl2hex(ha,sb,0.84)
        TEX=hsl2hex(ha,0.28,0.17); TEN=hsl2hex(ha,0.12,0.42); SO=F
        sl=0.38; sv=0.34
        ro=hsl2hex(355,0.70,sl); ve=hsl2hex(140,0.55,sv); am=hsl2hex(42,0.85,0.36)
        az=hsl2hex(215,0.70,sl); mg=hsl2hex(295,0.55,sl); ci=hsl2hex(185,0.75,0.30)
      } else {
        A=hsl2hex(ha,clamp(sa,0.5,0.9),0.66); A2=hsl2hex(h2,clamp(s2,0.45,0.85),0.70)
        F=hsl2hex(ha,sb,0.07); F2=hsl2hex(ha,sb,0.13); INA=hsl2hex(ha,sb,0.17)
        TEX=hsl2hex(ha,0.25,0.93); TEN=hsl2hex(ha,0.14,0.62); SO=F
        ro=hsl2hex(355,0.75,0.68); ve=hsl2hex(140,0.50,0.62); am=hsl2hex(45,0.85,0.65)
        az=hsl2hex(215,0.80,0.68); mg=hsl2hex(295,0.60,0.72); ci=hsl2hex(185,0.70,0.62)
      }
      print F,F2,TEN,TEX,A,A2,SO,INA,ro,ve,am,az,mg,ci
    }' <<<"$hist"
}

# id estable para una imagen: img-nombre-xxxx
imagen_id() {
  local base=${1##*/} slug h
  base=${base%.*}
  slug=$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-24)
  h=$(printf '%s' "$1" | cksum | cut -d' ' -f1)
  printf 'img-%s-%s' "${slug:-imagen}" "$(printf '%x' "$h" | cut -c1-4)"
}

imagen_nombre() {   # nombre bonito (sin extensión, sin "|")
  local b=${1##*/}; b=${b%.*}; b=${b//|//}
  printf '%.32s' "$b"
}

# linea_imagen ID NOMBRE DESC RUTA  <14 colores>  → una línea de imagenes.txt
linea_imagen() {
  local id=$1 nom=$2 desc=$3 ruta=$4; shift 4
  local f f2 ten tex a a2 so ina ro ve am az mg ci
  read -r f f2 ten tex a a2 so ina ro ve am az mg ci <<<"$*"
  printf '%s|%s|%s|%s,%s,%s,%s,%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
    "$id" "$nom" "$desc" "$f" "$f2" "$a" "$a2" "$tex" \
    "$f" "$f2" "$ten" "$tex" "$a" "$a2" "$so" "$ina" "$ro" "$ve" "$am" "$az" "$mg" "$ci" "$ruta"
}

# indexar_imagenes [IMAGEN...]
#   sin argumentos: revisa ~/.config/wallpapers (+ lo que ya estaba indexado)
#   con argumentos: agrega/actualiza solo esas imágenes
indexar_imagenes() {
  local IM modo=${MODO_IMAGENES:-oscuro} ruta clave k linea mt sz md id r
  IM=$(_im) || { echo "Falta ImageMagick:  sudo pacman -S imagemagick" >&2; return 1; }
  local -A viejo_clave=() viejo_id=() viejo_linea=() visto=()
  local -a rutas=() pend=()
  mkdir -p "$MINIS" "$DIR"

  if [[ -f "$IMG_INDICE" ]]; then
    while IFS='|' read -r ruta mt sz md id; do
      [[ -n "$ruta" ]] && { viejo_clave[$ruta]="$mt|$sz|$md"; viejo_id[$ruta]=$id; }
    done < "$IMG_INDICE"
  fi
  if [[ -f "$IMG_LISTA" ]]; then
    while IFS= read -r linea; do [[ -n "$linea" ]] && viejo_linea[${linea##*|}]=$linea; done < "$IMG_LISTA"
  fi

  # qué imágenes revisar
  if (($#)); then
    for ruta in "$@"; do [[ -z "${visto[$ruta]:-}" ]] && { visto[$ruta]=1; rutas+=("$ruta"); }; done
  else
    while IFS= read -r -d '' ruta; do
      [[ -z "${visto[$ruta]:-}" ]] && { visto[$ruta]=1; rutas+=("$ruta"); }
    done < <(find -L "$HOME/.config/wallpapers" -maxdepth 2 -type f -regextype posix-extended -iregex "$IMG_REGEX" \
               ! -name 'paleta-*' -print0 2>/dev/null | sort -z)
  fi
  for ruta in "${!viejo_clave[@]}"; do     # lo que ya estaba (de otras carpetas) se conserva si el archivo sigue ahí
    [[ -z "${visto[$ruta]:-}" ]] && { visto[$ruta]=1; rutas+=("$ruta"); }
  done

  # qué hay que calcular
  local -a validas=()
  for ruta in "${rutas[@]}"; do
    [[ -f "$ruta" && "$ruta" != *"|"* ]] || continue
    clave="$(stat -c '%Y|%s' "$ruta")|$modo"
    validas+=("$ruta")
    if [[ "${viejo_clave[$ruta]:-}" == "$clave" ]] && { [[ "${viejo_id[$ruta]}" == "-" ]] || [[ -f "$MINIS/${viejo_id[$ruta]}.png" ]]; }; then
      continue
    fi
    pend+=("$ruta")
  done

  local tmp; tmp=$(mktemp -d)
  if ((${#pend[@]} >= 4)) && command -v notify-send >/dev/null 2>&1; then
    notify-send -a "Paletas" -h string:x-canonical-private-synchronous:paleta-indexar \
      "Leyendo los colores de ${#pend[@]} imágenes…" "Solo pasa la primera vez" 2>/dev/null
  fi

  k=0
  for ruta in "${pend[@]}"; do
    while (( $(jobs -rp | wc -l) >= 4 )); do wait -n; done
    (
      local cols id
      id=$(imagen_id "$ruta")
      if cols=$(colores_de_imagen "$ruta" "$modo") && [[ -n "$cols" ]]; then
        # shellcheck disable=SC2086  # (cols son 14 palabras a propósito)
        "$IM" "${ruta}[0]" -alpha off -thumbnail 192x108^ -gravity center -extent 192x108 "$MINIS/$id.png" 2>/dev/null
        # shellcheck disable=SC2086
        linea_imagen "$id" "$(imagen_nombre "$ruta")" "imagen · $(basename "$(dirname "$ruta")")" "$ruta" $cols > "$tmp/$k.ok"
      fi
    ) &
    k=$((k + 1))
  done
  wait

  # armar los archivos finales
  local -a lineas=() indice=()
  k=0
  for ruta in "${validas[@]}"; do
    clave="$(stat -c '%Y|%s' "$ruta")|$modo"
    r=""
    for p in "${pend[@]}"; do [[ "$p" == "$ruta" ]] && r=1; done
    if [[ -n "$r" ]]; then
      # recién calculada (el índice k sigue el orden de pend)
      local j=0 idx=-1
      for p in "${pend[@]}"; do [[ "$p" == "$ruta" ]] && idx=$j; j=$((j + 1)); done
      if [[ -f "$tmp/$idx.ok" ]]; then
        linea=$(cat "$tmp/$idx.ok"); lineas+=("$linea"); indice+=("$ruta|$clave|${linea%%|*}")
      else
        indice+=("$ruta|$clave|-")          # no se pudo leer: no se reintenta hasta que cambie
      fi
    else
      [[ "${viejo_id[$ruta]:-}" == "-" ]] && { indice+=("$ruta|$clave|-"); continue; }
      [[ -n "${viejo_linea[$ruta]:-}" ]] && { lineas+=("${viejo_linea[$ruta]}"); indice+=("$ruta|$clave|${viejo_id[$ruta]}"); }
    fi
  done
  rm -rf "$tmp"

  { printf '%s\n' "${lineas[@]}" | sed '/^$/d' | sort -t'|' -k2,2 -f; } > "$IMG_LISTA.tmp" && mv -f "$IMG_LISTA.tmp" "$IMG_LISTA"
  { printf '%s\n' "${indice[@]}" | sed '/^$/d'; } > "$IMG_INDICE.tmp" && mv -f "$IMG_INDICE.tmp" "$IMG_INDICE"
  return 0
}
