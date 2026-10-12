# Cambios

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y las versiones siguen [SemVer](https://semver.org/lang/es/).

## [0.5.2] — 2026-10-12

### Corregido
- `zero-lock diagnostico` decía que Hyprland "no tenía ningún atajo de bloqueo" aunque sí lo tuviera: con la config en Lua, `hyprctl binds` no muestra el comando del atajo, solo una función. Los atajos de bloqueo de `rice.lua` ahora llevan descripción (`zero-lock: bloquear`) y el diagnóstico la reconoce.
- Bloquear tardaba ~2 s de más cuando `awww query` no respondía: el fondo actual se toma primero de `~/.config/wallpapers/.actual` (instantáneo) y solo si no existe se le pregunta a awww/swww, con 1 s de límite.
- Si tu `hypridle.conf` es propio y lanza hyprlock directo (`pidof hyprlock || hyprlock`), el instalador ofrece cambiarlo por zero-lock, que sí sabe qué hacer con un hyprlock colgado.

### Agregado
- `zero-lock diagnostico` ahora dice qué proceso lanzó cada hyprlock abierto, a qué está atado `Super + L` (y si está atado varias veces), si zero-lock ha bloqueado alguna vez en tu compu, con qué bloquea hypridle y, si generar la config tarda, qué paso es el lento.

## [0.5.1] — 2026-10-12

### Corregido
- **`Super + L` dejaba de bloquear** después del primer desbloqueo. hyprlock 0.9.6 a veces se congela al desbloquear ([hyprlock#1055](https://github.com/hyprwm/hyprlock/issues/1055)): el proceso quedaba vivo sin bloquear nada, y `zero-lock` (y `hypridle`, con su `pidof hyprlock ||`) creían que la pantalla ya estaba bloqueada. Ahora `zero-lock` le pregunta a Hyprland (`hyprctl locked`) y, si el hyprlock está colgado, lo cierra y bloquea de nuevo. Esto también arregla que hypridle no bloqueara antes de suspender.
- **Te volvía a bloquear justo después de escribir tu contraseña** si hyprlock se caía al desbloquear: lo tomaba como una caída y abría la pantalla de emergencia. Ahora solo reintenta si la sesión sigue bloqueada.
- La descarga de la portada de la música heredaba el candado de "ya estoy bloqueando": mientras se descargaba, `Super + L` se ignoraba.
- `hypridle.conf` usa `zero-lock.sh lock --auto` (sin `pidof hyprlock ||`); el instalador migra el tuyo si tenía la línea vieja de zero-lock.
- `misc:allow_session_lock_restore` encendido: si hyprlock se cae con la pantalla bloqueada, se puede volver a abrir.

### Agregado
- `zero-lock diagnostico` dice si Hyprland ve la sesión bloqueada, si hay un hyprlock colgado y avisa del bug de hyprlock 0.9.6.
- CI: prueba de regresión con un hyprlock simulado que se congela y se cae (`.github/pruebas/zero-lock-bloqueo.sh`).

## [0.5.0] — 2026-10-12

### Agregado
- **Panel de control** (`Super + A`, botón de ajustes de la barra o `ags request panel`): botones rápidos de Wi-Fi, bluetooth, No molestar, micrófono, luz nocturna y Tailscale; volumen y brillo; música con portada y barra de avance; calendario plegable; accesos a paleta, estilo de barra, fondo, animaciones, captura y portapapeles. Se cierra con `Esc` o con un clic fuera, aparece en el monitor enfocado y se desplaza si no cabe.
- `red.sh tailscale`: conecta o desconecta Tailscale según su estado.
- `hyprsunset` en los paquetes, para la luz nocturna.

### Cambiado
- El título de la ventana en la barra lleva una sombra suave para leerse sobre cualquier fondo.

## [0.4.0] — 2026-10-12

### Agregado
- **6 estilos de barra** (`Super + Shift + B` o clic derecho en el botón de paletas): islas, flotante, bloque, neón, vidrio y minimal. Son independientes de la paleta y se aplican en vivo (`barra-estilo.sh`, `~/.config/ags/estilos/`).
- **Módulos que se expanden** al pasar el mouse: reloj (fecha), red (nombre y señal) y sistema (RAM, temperatura y disco). La temperatura alta nunca se esconde.
- **Espectro de audio** en la isla de música (AstalCava), solo mientras algo suena. Si tu libastal no trae cava, la barra sigue igual.
- Microanimaciones: la pastilla del workspace activo se estira con rebote, y las alertas (notificaciones, batería baja, temperatura alta) laten.
- **Neovim con LazyVim** que sigue la paleta: plantilla `nvim-colores.lua.tpl`, tema base16 generado y repintado en vivo en todos los Neovim abiertos. Logo de ZERO al iniciar, lualine redondeada, atajos `Espacio + z`, bashls/cssls/shellcheck/shfmt para editar el rice.
- `install.sh`: paso de Neovim (paquetes, respaldo de tu config anterior y descarga de plugins), `--sin-nvim`, revisión de versión de Neovim y de AstalCava.
- CI: sintaxis de la config de Neovim y que cada estilo de barra tenga su CSS.

### Corregido
- Si `colores.css` no existía todavía, la barra usaba colores por defecto sin `@rojo` ni los del modo root.

## [0.3.0] — 2026-10-11

### Agregado
- **48 paletas** y **paleta propia por cada imagen** (pestañas Paletas / Imágenes en `Super + Shift + P`, `Super + Alt + I`), selector de imágenes de cualquier carpeta (`Super + Shift + I`), siguiente/aleatoria (`Super + Ctrl/Alt + P`).
- **Motor de plantillas** (`~/.config/rice-plantillas/*.tpl`): tematizar una app nueva sin tocar código.
- **5 estilos de fondo generado**: líneas, malla, aurora, rejilla y círculos.
- **Bienvenida en la terminal** con fastfetch y tu paleta (`bienvenida info | saludo | off`).
- **zero-lock**: pantalla de bloqueo personalizable (hyprlock) con 5 estilos (`tarjetas`, `minimal`, `centrado`, `terminal`, `panel`).
  Menú en rofi (`Super + Shift + L`): estilo, fondo (automático, captura, explorador de archivos con vista previa, galería o color), desenfoque, brillo, tamaño, reloj 12/24 h, colores, foto y elementos.
  Los textos se recortan para no salirse de los recuadros y todo se escala a la resolución de tu pantalla.
  Usa la paleta activa mediante la plantilla `hyprlock-colores.conf.tpl`. `Super + L` bloquea y `hypridle` usa el mismo comando.
- `zero-lock diagnostico`: revisa hyprlock, hypridle, los atajos registrados en Hyprland, procesos atorados y el log del bloqueo.
- Config de emergencia: si la pantalla bonita no se puede generar o hyprlock falla con ella, se bloquea igual con una mínima.
- Plantillas `gtk3-colores.css.tpl` y `gtk4-colores.css.tpl`: las apps GTK vuelven a seguir tu paleta (con `TEMA_GTK=0` se desactiva).
- Captura del escritorio en el README.

### Corregido
- **`Super + L` no bloqueaba**: `zero-lock` le preguntaba a `bluetoothctl` por el estado del bluetooth, y con el servicio apagado `bluetoothctl` se queda esperando para siempre; hyprlock nunca llegaba a abrirse (y el botón de la barra y hypridle se trababan igual). Ahora todo lo que se consulta tiene tiempo límite, el bluetooth solo se revisa si hay adaptador y servicio, y la portada de la música ya no se descarga antes de bloquear.
- Un solo bloqueo a la vez: varios `Super + L` seguidos ya no dejan procesos colgados.
- `zero-lock` ya no usa `general:grace` (hyprlock nuevo lo quitó); la vista previa usa `--grace` si tu hyprlock lo tiene.
- `~/.local/bin/zero-lock` ahora es un enlace al script del rice (antes era una copia que se quedaba vieja al actualizar).
- `zero-lock estado` mostraba los valores corridos (faltaba el tamaño) y el estilo minimal no mostraba el nombre del equipo en Arch (sin el comando `hostname`).
- **Se recuperó lo que la versión de "paleta por cada imagen" borró sin querer de la 0.2.0**: arranque de hypridle, polkit y cliphist; atajos `Super + Shift + V/F/A/E` y workspaces 3D; menú de animaciones; blur del OSD; instalación de `ws3d.tsx`, `efectos3d.ts`, `perfil.sh`, `animaciones.sh`, `ws3d.sh`, `portapapeles.sh` y `temp.sh` (sin ellos la barra no arrancaba en una instalación nueva); paquetes `hyprlock hypridle hyprpolkitagent xdg-desktop-portal-hyprland cliphist kernel-modules-hook`; `hypridle.conf`; `--version`, `--enlazar` y `--copiar`; desinstalación completa.
- `install.sh` había perdido el permiso de ejecución (`./install.sh` daba "Permiso denegado").
- El instalador buscaba tu ciudad en la ruta vieja y la volvía a detectar en cada actualización.
- Si venías de la 0.2.0, tu paleta actual (guardada en `~/.local/state/zero-rice/paleta`) se vuelve a encontrar.
- La revisión automática ahora también revisa `lib/`, los permisos de ejecución y que zero-lock genere sus 5 estilos sin colgarse.

## [0.2.0] — 2026-10-09

### Agregado
- **Foto de perfil** (`Super + Shift + F` o clic en tu nombre): en la barra, el lanzador y la pantalla de bloqueo.
- **Workspaces en 3D** (`Super + Shift + E`): 12 efectos dibujados por la barra, sin plugins.
- **14 estilos de animaciones** (`Super + Shift + A`) con velocidad y borde girando ajustables.
- **OSD de volumen y brillo** y **contador de notificaciones** con No molestar (clic derecho) en la barra.
- **Modo enlazado** (`./install.sh --enlazar`): `~/.config` apunta al repo para desarrollar el rice sin copias desincronizadas.
- El instalador detecta si tu `hyprland.lua` arranca la barra, las notificaciones o el fondo por su cuenta y ofrece desactivarlo.
- `kernel-modules-hook`: actualizar el kernel ya no rompe nada (Wi-Fi, VPN, USB…) hasta que reinicias.

### Corregido
- El OSD de volumen sigue a la salida activa (audífonos, Bluetooth).
- Al actualizar, un guardián de la barra de la versión anterior se retira solo en vez de pelearse con el nuevo.

## [0.1.0] — 2026-10-09

### Agregado
- Pantalla de bloqueo con **hyprlock** que usa los colores de tu paleta (`Super + L`) y bloqueo automático a los 10 minutos con **hypridle**.
- **Historial del portapapeles** con cliphist (`Super + Shift + V`).
- **Agente de polkit** (las apps que piden contraseña de administrador ya funcionan) y **xdg-desktop-portal-hyprland** (compartir pantalla en Discord, Meet, OBS…).
- Las **apps GTK** (Thunar, etc.) toman los colores de la paleta y el modo claro/oscuro.
- **Tailscale** en el menú de red (conectar/desconectar) y en la barra.
- `install.sh --version`, archivo `VERSION`, licencia MIT y revisión automática de los scripts en GitHub.

### Cambiado
- Los colores de Hyprland viven en `colores.lua`: `rice.lua` ya no se modifica, así que `--actualizar` no crea respaldos de más.
- Al cambiar de paleta la barra se repinta sola, **sin reiniciarse** (adiós parpadeo).
- La paleta ya **no reemplaza el fondo que tú elegiste**; solo cambia los fondos generados por paletas (`CAMBIAR_FONDO=2` para el comportamiento anterior).
- El lanzador abre más rápido: ya no espera un tiempo fijo para medir la CPU y reusa el panel si lo acabas de abrir.
- El estado (paleta actual, ciudad) va a `~/.local/state/zero-rice`, la caché a `~/.cache/zero-rice` y los logs a `$XDG_RUNTIME_DIR/zero-rice`. Se mueven solos desde las versiones anteriores.
- Los scripts respetan `XDG_CONFIG_HOME`.

### Corregido
- El volumen de la barra ahora sigue a la salida de audio activa (audífonos, Bluetooth).
- La música muestra el reproductor que está sonando, no siempre el primero.
- La temperatura se lee del sensor de la CPU (coretemp/k10temp) en vez del más caliente de todos.
- Con dos monitores, la CPU y la red se leen una sola vez (antes los porcentajes salían mal).
- La detección de root ya no lanza procesos cada 1.5 s: solo revisa terminales, al cambiar de ventana y cada 3 s.
- La red se actualiza cuando algo cambia (`nmcli monitor`) en vez de preguntar cada 4 s.
- El fondo generado por la paleta usa la resolución del monitor más grande.
- Mensajes de error que apuntaban a archivos que no existen.

## [0.0.1]
- Primera versión.
