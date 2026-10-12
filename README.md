# ZERO — rice para Hyprland

Configuración completa para **Arch Linux + Hyprland** (config en Lua): barra con AGS, lanzador con clima y estadísticas, 48 paletas de colores que cambian todo el escritorio con un atajo, menú de red, capturas de pantalla con vista previa y más.

![Lanzador](capturas/lanzador.png)

## Qué trae

- **Look de Hyprland:** bordes con degradado animado, esquinas redondeadas, blur, sombras y animaciones suaves.
- **Barra (AGS v3):** usuario (se pone **blanca cuando eres root**), workspaces 1–5, reloj con calendario, música, red, CPU/RAM/temperatura, volumen, batería, bandeja, paletas, notificaciones y menú de energía. Tiene un guardián que la levanta sola si se cae.
- **Lanzador (Rofi):** panel con saludo según la hora, reloj, **clima de tu ciudad** y estadísticas de tu PC; apps en cuadrícula y pestañas Apps / Comandos / Archivos.
- **48 paletas de colores:** cambian bordes, barra, lanzador, menús, notificaciones, terminal (con sus 16 colores) y fondo de pantalla al mismo tiempo. Puedes agregar las tuyas.
- **Paleta por cada imagen:** cada fondo tuyo guarda su propia paleta (pestaña "Imágenes" del menú); elegirla aplica sus colores y pone esa imagen.
- **5 estilos de fondo generado:** líneas, malla, aurora, rejilla synthwave y círculos, todos con los colores de tu paleta.
- **Motor de plantillas:** tematizar una app nueva es agregar un archivo `.tpl`, sin tocar código.
- **Bienvenida en la terminal:** logo, datos del sistema y tu paleta (o un saludo con clima) al abrir la terminal, con los colores de la paleta.
- **Clima:** detecta tu ciudad por internet, o la eliges de una lista que se filtra mientras escribes.
- **Menú de red:** Wi-Fi con barras de señal, redes ocultas, cable y configuración avanzada.
- **Capturas de pantalla:** área, pantalla o ventana; notificación con vista previa y botones Abrir / Carpeta / Editar / Borrar.
- **Notificaciones (SwayNC)** y **fondos de pantalla (awww)** con selector de miniaturas.

## Requisitos

- Arch Linux (o derivada con `pacman`).
- **Hyprland con config en Lua** (`hyprland.lua`, versión 0.55 o más nueva). Si todavía tienes `hyprland.conf`, actualiza primero con `sudo pacman -Syu hyprland`.
- Internet durante la instalación.

Todo lo demás lo instala el script: kitty, rofi, swaync, NetworkManager, pipewire, fuentes, íconos, AGS y sus librerías desde el AUR (instala `yay` si no lo tienes), etc.

## Instalación

```bash
git clone https://github.com/Zer0-HMA/zero-rice.git
cd zero-rice
./install.sh
```

El script pregunta antes de cada paso, respalda todo lo que reemplaza en `~/.config/rice-respaldo-<fecha>/` y al final te deja elegir la paleta inicial.

| Opción | Qué hace |
|---|---|
| `./install.sh --si` | Instala todo sin preguntar |
| `./install.sh --solo-configs` | No instala paquetes, solo las configuraciones |
| `./install.sh --paleta=tokyo` | Elige la paleta inicial |
| `./install.sh --actualizar` | Baja lo último del repo y actualiza (conserva tu paleta, tu fondo y tu ciudad) |
| `./install.sh --desinstalar` | Quita el rice (no borra paquetes; todo queda respaldado) |

> Puedes correrlo desde la TTY antes de entrar a Hyprland por primera vez, o desde dentro de Hyprland (se aplica en vivo).

## Atajos

| Atajo | Acción |
|---|---|
| `Super + R` | Lanzador de apps |
| `Super + Shift + P` | Cambiar paleta de colores |
| `Super + Ctrl + P` | Siguiente paleta |
| `Super + Alt + P` | Paleta aleatoria |
| `Super + Shift + C` | Elegir ciudad del clima |
| `Super + W` | Elegir fondo de pantalla (con miniaturas) |
| `Super + Shift + W` | Fondo aleatorio |
| `Super + N` | Centro de notificaciones |
| `Super + Shift + N` | Menú de red |
| `Super + B` | Reiniciar la barra |
| `Impr Pant` / `Super + Shift + S` | Captura de un área |
| `Shift + Impr Pant` | Captura de pantalla completa |
| `Super + Impr Pant` | Captura de la ventana activa |
| `Super + Shift + Impr Pant` | Captura de pantalla en 5 segundos |

## Paletas

![Las 48 paletas](capturas/paletas-todas.png)

Se cambian con `Super + Shift + P`, con el botón de paleta de la barra o desde la terminal:

```bash
~/.config/hypr/scripts/paleta.sh tokyo         # una en específico
~/.config/hypr/scripts/paleta.sh siguiente     # la que sigue (también: anterior)
~/.config/hypr/scripts/paleta.sh aleatoria     # sorpresa
~/.config/hypr/scripts/paleta.sh lista         # ver todas en la terminal
```

Las paletas claras (Nieve, Niebla, Catppuccin Latte, Rosé Pine Dawn, Tokyo Night Day, Solarized Light, Matcha, Gruvbox Light) vuelven claro todo el escritorio; la terminal se mantiene oscura y el modo root de la barra se invierte para que siempre se note.

### Paletas de tus imágenes

El menú de paletas (`Super + Shift + P`) tiene **dos pestañas**:

- **Paletas:** las 48 de siempre (y las que tú agregues).
- **Imágenes:** una paleta **por cada fondo tuyo**, con su miniatura. Al elegir una se aplican sus colores y se pone esa imagen de fondo.

Cambias de pestaña con `Alt + 1` / `Alt + 2` o con la primera fila. `Super + Alt + I` abre directo en tus imágenes.

Las imágenes salen de `~/.config/wallpapers/` y de las que agregas con `Super + Shift + I`. Los colores se calculan una sola vez por imagen (y de nuevo solo si la cambias) y se guardan en `~/.config/rice-paletas/imagenes.txt`.

```bash
paleta.sh imagenes                 # ver la lista
paleta.sh imagen playa             # esa imagen de fondo + sus colores (por nombre)
paleta.sh desde-fondo              # solo los colores del fondo que tienes puesto
paleta.sh desde-fondo foto.jpg     # o de una imagen en específico
paleta.sh auto on                  # cada fondo nuevo (Super + W) cambia también los colores
```

`siguiente`, `anterior` y `aleatoria` solo recorren las paletas, no tus imágenes. Para que las paletas de tus imágenes sean de tema claro pon `MODO_IMAGENES=claro` en `~/.config/rice-paletas/ajustes.conf`. Necesita `imagemagick` (el instalador lo pone).

### Fondos generados

Cada paleta genera su propio fondo. Hay 5 estilos: `lineas` (el original), `malla`, `aurora`, `rejilla` (synthwave) y `circulos`.

```bash
paleta.sh fondo malla        # regenera el fondo de la paleta actual en ese estilo
paleta.sh fondo aleatorio    # uno al azar
```

Para dejar uno fijo, crea `~/.config/rice-paletas/ajustes.conf` (el instalador ya lo deja listo) con `ESTILO_FONDO=aurora`. Ahí mismo puedes poner `CAMBIAR_FONDO=0` si no quieres que la paleta toque tu fondo, o `TEMA_KITTY=0` para que no cambie la terminal.

### Agregar tu propia paleta

Abre `~/.config/rice-paletas/paletas.txt`, copia una línea y cambia los colores. El formato viene explicado al principio del archivo. Además de fondo, texto y acentos, cada paleta puede traer **rojo, verde, amarillo, azul, magenta y cyan**: se usan en las alertas (batería baja, temperatura alta, confirmar apagado) y como colores de la terminal. Si los omites, se usan unos genéricos. Si el color de fondo es claro, todo el escritorio se vuelve tema claro automáticamente.

### Tematizar otra app (plantillas)

Los colores no están escritos dentro del script: viven en `~/.config/rice-plantillas/*.tpl`. Cada plantilla es el archivo de configuración de una app con `{{variables}}`, más una cabecera que dice dónde se escribe:

```
#@ destino: ~/.config/btop/themes/zero.theme
#@ requiere: cmd btop
theme[main_bg]="{{fondo}}"
theme[main_fg]="{{texto}}"
theme[hi_fg]="{{acento}}"
```

Al cambiar de paleta se rellenan todas las plantillas. Variables disponibles: `fondo fondo2 tenue texto acento acento2 sobre inactivo rojo verde amarillo azul magenta cyan` y `ansi0` … `ansi15`; formas: `{{acento.hex}}`, `{{acento.rgb}}`, `{{acento.a30}}` (30 % de opacidad), `{{acento.rgba30}}` (CSS) y `{{acento.hypr}}`. La lista completa está en `config/hypr/scripts/lib/plantillas.sh`.

## Terminal

Al abrir una terminal se muestra una bienvenida con los colores de tu paleta (cambia sola cuando cambias de paleta):

```bash
bienvenida info      # logo + datos del sistema + tu paleta + los colores de la terminal (fastfetch)
bienvenida saludo    # una línea: saludo, clima, tiempo encendida y RAM
bienvenida off       # nada al abrir
ff                   # fastfetch completo
```

Solo sale en la ventana nueva: no en subshells, ni en tmux, nvim o ventanas muy chicas. El instalador agrega una línea al **inicio** de `~/.zshrc`, antes del bloque de "instant prompt" de Powerlevel10k, que es donde debe ir:

```zsh
source "$HOME/.config/rice-terminal/bienvenida.zsh"
```

`fastfetch.jsonc` y `colores.zsh` (en `~/.config/rice-terminal/`) los genera `paleta.sh` desde las plantillas; en `colores.zsh` tienes los colores de tu paleta para tus propios scripts de zsh (`$RT_ACENTO`, `$RT_ROJO`...).

## Clima

![Elegir ciudad](capturas/elegir-ciudad.png)

- Al instalar, detecta tu ciudad por tu conexión a internet. Es aproximada, por eso dice "(aprox.)".
- Con `Super + Shift + C` eliges tu ciudad de una lista que **se filtra mientras escribes** (sin importar acentos). Las de tu país salen primero, con estado, país y población para no confundirte.
- Si tu pueblo no viene en la lista, escribe el nombre completo y presiona Enter para buscarlo en internet.
- La ciudad que elijas se queda guardada. Para volver a la detección automática: `~/.config/hypr/scripts/clima.sh auto`.
- Ver el clima en la terminal: `~/.config/hypr/scripts/clima.sh ver`.

## Personalizar

- **Tus propios ajustes de Hyprland** (monitores, teclado, más atajos…) van en `~/.config/hypr/mio.lua`. Se carga al final del rice, así que le gana a todo, y **el instalador nunca lo toca**, ni al actualizar. Ejemplo:

  ```lua
  hl.config({ input = { kb_layout = "latam" } })
  hl.bind("SUPER + T", hl.dsp.exec_cmd("thunar"))
  ```

- **Tus fondos de pantalla** van en `~/.config/wallpapers/` (jpg, png, webp, gif). Elígelos con `Super + W`. Para usar una imagen que está en otra carpeta (Descargas, Imágenes...), `Super + Shift + I` abre un navegador con miniaturas; la imagen se copia a tus fondos. También: `wall.sh /ruta/a/foto.jpg`.
- **Carpeta de capturas:** `~/Pictures/Capturas` (o la carpeta de imágenes de tu idioma). Se copian solas al portapapeles.

## Problemas comunes

**La barra no aparece.** Corre `~/.config/hypr/scripts/barra.sh log` para ver el error. Si dice que falta algo de `Astal`, instala `yay -S libastal-meta`.

**Sale una barra roja arriba de la pantalla.** Es un error en la config de Hyprland. Si acabas de editar `mio.lua`, revisa ese archivo.

**El clima dice "no disponible".** Revisa tu internet y elige tu ciudad con `Super + Shift + C`.

**El fondo de pantalla no cambia.** El proyecto `swww` se renombró a `awww`; el instalador instala `awww` desde el AUR, y los scripts usan el que tengas.

## Estructura del repo

```
zero-rice/
├── install.sh                      instalador (instalar / actualizar / desinstalar)
├── config/
│   ├── hypr/rice.lua               look, autoinicio y atajos
│   ├── hypr/scripts/               barra, paleta, clima, panel, lanzador, red, captura, wall
│   ├── hypr/scripts/lib/           motor de paletas: color, plantillas, fondos, desde imagen
│   ├── ags/                        barra (app.tsx + style.css)
│   ├── rofi/                       lanzador
│   ├── swaync/                     notificaciones
│   ├── rice-plantillas/            una plantilla .tpl por app (barra, rofi, swaync, kitty, hyprland)
│   └── rice-paletas/paletas.txt    las 48 paletas
└── capturas/                       imágenes de este README
```

Los colores de la barra, Rofi, SwayNC, kitty y Hyprland no están escritos en el repo: `paleta.sh` los genera a partir de las plantillas y de la paleta que elijas.

## Créditos

- [Hyprland](https://hypr.land), [AGS / Astal](https://github.com/Aylur/ags), [Rofi](https://github.com/davatorium/rofi), [SwayNotificationCenter](https://github.com/ErikReider/SwayNotificationCenter), [awww](https://github.com/LGFae/swww)
- Clima: [Open-Meteo](https://open-meteo.com) (gratis, sin cuenta)
- Lista de ciudades: [GeoNames](https://www.geonames.org) (licencia CC BY 4.0)
- Ubicación aproximada: [ip-api.com](https://ip-api.com) e [ipinfo.io](https://ipinfo.io)
- Íconos: [Nerd Fonts](https://www.nerdfonts.com) y [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme)
- Paletas inspiradas en Catppuccin, Tokyo Night, Nord, Gruvbox, Rosé Pine, Dracula, Kanagawa, Everforest, Solarized, One Dark, Ayu, Oxocarbon, Synthwave '84, GitHub, Poimandres, Material, Monokai Pro y Horizon, de sus respectivos proyectos
