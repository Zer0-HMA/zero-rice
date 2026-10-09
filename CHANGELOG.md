# Cambios

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y las versiones siguen [SemVer](https://semver.org/lang/es/).

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
