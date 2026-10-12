#@ destino: ~/.config/gtk-4.0/zero-paleta.css
#@ opcion: TEMA_GTK
#@ despues: for v in 3.0 4.0; do c="$HOME/.config/gtk-$v/gtk.css"; grep -qF '@import url("zero-paleta.css");' "$c" 2>/dev/null || { mkdir -p "${c%/*}"; { echo '@import url("zero-paleta.css");'; cat "$c" 2>/dev/null; true; } > "$c.tmp" && mv -f "$c.tmp" "$c"; }; done
#@ despues: command -v gsettings >/dev/null && if grep -q 'modo: claro' "$HOME/.config/gtk-4.0/zero-paleta.css"; then gsettings set org.gnome.desktop.interface color-scheme prefer-light; gsettings set org.gnome.desktop.interface gtk-theme Adwaita; else gsettings set org.gnome.desktop.interface color-scheme prefer-dark; gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark; fi
/* Generado por paleta.sh — paleta: {{nombre}} · modo: {{modo}} (GTK 4 / libadwaita) */
@define-color accent_color {{acento}};
@define-color accent_bg_color {{acento}};
@define-color accent_fg_color {{sobre}};
@define-color window_bg_color {{fondo}};
@define-color window_fg_color {{texto}};
@define-color view_bg_color {{fondo}};
@define-color view_fg_color {{texto}};
@define-color headerbar_bg_color {{fondo2}};
@define-color headerbar_fg_color {{texto}};
@define-color sidebar_bg_color {{fondo2}};
@define-color sidebar_fg_color {{texto}};
@define-color card_bg_color {{fondo2}};
@define-color card_fg_color {{texto}};
@define-color popover_bg_color {{fondo2}};
@define-color popover_fg_color {{texto}};
@define-color dialog_bg_color {{fondo2}};
@define-color dialog_fg_color {{texto}};
:root {
  --accent-color: {{acento}}; --accent-bg-color: {{acento}}; --accent-fg-color: {{sobre}};
  --window-bg-color: {{fondo}}; --window-fg-color: {{texto}};
  --view-bg-color: {{fondo}}; --view-fg-color: {{texto}};
  --headerbar-bg-color: {{fondo2}}; --headerbar-fg-color: {{texto}};
  --sidebar-bg-color: {{fondo2}}; --sidebar-fg-color: {{texto}};
  --card-bg-color: {{fondo2}}; --card-fg-color: {{texto}};
  --popover-bg-color: {{fondo2}}; --popover-fg-color: {{texto}};
  --dialog-bg-color: {{fondo2}}; --dialog-fg-color: {{texto}};
}
