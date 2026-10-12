# ZERO — a Hyprland rice

[![Revisar](https://github.com/Zer0-HMA/zero-rice/actions/workflows/revisar.yml/badge.svg)](https://github.com/Zer0-HMA/zero-rice/actions/workflows/revisar.yml)
![Version](https://img.shields.io/badge/version-0.3.0-blue)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

*[Versión en español](README.md)*

![Desktop](capturas/escritorio.jpg)

A complete setup for **Arch Linux + Hyprland** (Lua config): an AGS bar, a Rofi launcher with weather and system stats, and 48 color palettes that recolor the whole desktop with one shortcut — borders, bar, launcher, menus, notifications, terminal, GTK apps, lock screen and wallpaper.

![Launcher](capturas/lanzador.png)

## Features

- **Hyprland look:** animated gradient borders, rounded corners, blur, shadows and smooth animations.
- **Bar (AGS v3):** user (turns white when you're root), workspaces, clock with calendar, media, network (with Tailscale), CPU/RAM/temperature, volume, battery, tray, palettes, notifications and power menu. A watchdog restarts it if it crashes, and it repaints itself live when you switch palettes.
- **Launcher (Rofi):** greeting panel with clock, **local weather** and PC stats; app grid with Apps / Commands / Files tabs.
- **48 palettes:** Catppuccin, Tokyo Night, Nord, Gruvbox, Rosé Pine, Dracula, Kanagawa and more — plus **one palette per wallpaper image** you own. Add your own in one line, or theme a new app by dropping in a `.tpl` template.
- **Network menu:** Wi-Fi with signal bars, hidden networks, wired, Tailscale and advanced settings.
- **Screenshots:** area, screen or window, with a preview notification and Open / Folder / Edit / Delete buttons.
- **Profile picture** in the bar, launcher and lock screen; **volume/brightness OSD**; live **notification counter**.
- **3D workspace transitions** (cube, carousel, door, tunnel, blinds…) and **14 animation styles**, each picked from a menu.
- **Lock screen (`zero-lock`, hyprlock):** 5 styles, a menu for background, blur, size, clock and widgets, follows your palette, with a fail-safe fallback so it always locks. Auto-lock with hypridle, **clipboard history** (cliphist), polkit agent and desktop portal.
- **Terminal greeting** with fastfetch in your palette colors.

## Install

```bash
git clone https://github.com/Zer0-HMA/zero-rice.git
cd zero-rice
./install.sh
```

Requires Arch Linux (or a `pacman`-based distro) and **Hyprland 0.55+ with Lua config** (`hyprland.lua`). The script asks before each step, backs up everything it replaces to `~/.config/rice-respaldo-<date>/`, and installs the rest (including `yay` and AGS from the AUR if needed). Options: `--si` (yes to all), `--solo-configs`, `--paleta=tokyo`, `--actualizar` (update), `--desinstalar` (uninstall), `--version`, `--enlazar` / `--copiar`.

## Shortcuts

| Shortcut | Action |
|---|---|
| `Super + R` | App launcher |
| `Super + Shift + P` | Switch palette |
| `Super + Shift + C` | Pick weather city |
| `Super + W` / `Super + Shift + W` | Pick / random wallpaper |
| `Super + N` | Notification center |
| `Super + Shift + N` | Network menu |
| `Super + L` / `Super + Shift + L` | Lock screen / customize it |
| `Super + Ctrl + P` / `Super + Alt + P` | Next / random palette |
| `Super + Shift + V` | Clipboard history |
| `Super + Shift + A` / `Super + Shift + E` | Animation style / 3D workspace effect |
| `Super + Shift + F` | Profile picture and name |
| `Super + B` | Restart the bar |
| `Print` / `Super + Shift + S` | Area screenshot |

Hacking on the rice? `./install.sh --enlazar` symlinks `~/.config` to the repo so your edits land straight in git.

Lock screen not working? Run `zero-lock diagnostico`.

Your own Hyprland settings go in `~/.config/hypr/mio.lua`, which is loaded last and never touched by the installer.

## Privacy

For the weather, your approximate location is looked up by IP via ip-api.com (plain HTTP) or ipinfo.io. Pick your city manually with `Super + Shift + C` to stop that. Weather data comes from Open-Meteo.

## License

[MIT](LICENSE) © Zer0-HMA. The UI and docs are in Spanish.
