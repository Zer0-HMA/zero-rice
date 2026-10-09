#!/usr/bin/env bash
# temp.sh — temperatura de la CPU en °C (número entero). Imprime 0 si no la encuentra.
# Lo usan la barra y el lanzador. Busca el sensor de la CPU en vez de tomar el máximo de
# todos (el de la tarjeta Wi-Fi o "acpitz" daban lecturas raras).
shopt -s nullglob

leer() {   # $1 = archivo *_input en miligrados
  local v
  { read -r v < "$1"; } 2>/dev/null || return 1
  [[ "$v" =~ ^[0-9]+$ ]] && ((v > 0)) || return 1
  echo $((v / 1000))
}

# 1) hwmon: coretemp (Intel), k10temp/zenpower (AMD), cpu_thermal (ARM)
for h in /sys/class/hwmon/hwmon*; do
  { read -r nombre < "$h/name"; } 2>/dev/null || continue
  case "$nombre" in
    coretemp|k10temp|zenpower|cpu_thermal|cpu-thermal|soc_thermal) ;;
    *) continue ;;
  esac
  for l in "$h"/temp*_label; do
    [[ -r "$l" ]] || continue
    read -r etiqueta < "$l"
    case "$etiqueta" in
      "Package id 0"|Tdie|Tctl) leer "${l%_label}_input" && exit 0 ;;
    esac
  done
  leer "$h/temp1_input" && exit 0
done

# 2) zona térmica del paquete de la CPU (Intel)
for z in /sys/class/thermal/thermal_zone*; do
  { read -r tipo < "$z/type"; } 2>/dev/null || continue
  [[ "$tipo" == x86_pkg_temp ]] && leer "$z/temp" && exit 0
done

echo 0
