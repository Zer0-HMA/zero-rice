#@ destino: ~/.config/kitty/paleta.conf
#@ requiere: dir ~/.config/kitty
#@ opcion: TEMA_KITTY
#@ despues: pkill -USR1 -x kitty
# Generado por paleta.sh — paleta: {{nombre}}
background            {{term_fondo}}
foreground            {{term_texto}}
cursor                {{acento}}
cursor_text_color     {{sobre}}
selection_background  {{acento}}
selection_foreground  {{sobre}}
url_color             {{acento}}
active_border_color   {{acento}}
inactive_border_color {{inactivo}}

active_tab_foreground   {{sobre}}
active_tab_background   {{acento}}
inactive_tab_foreground {{term_texto}}
inactive_tab_background {{ansi0}}
tab_bar_background      {{term_fondo}}

# Los 16 colores de la terminal (ls, git, btop, nvim...)
color0  {{ansi0}}
color1  {{ansi1}}
color2  {{ansi2}}
color3  {{ansi3}}
color4  {{ansi4}}
color5  {{ansi5}}
color6  {{ansi6}}
color7  {{ansi7}}
color8  {{ansi8}}
color9  {{ansi9}}
color10 {{ansi10}}
color11 {{ansi11}}
color12 {{ansi12}}
color13 {{ansi13}}
color14 {{ansi14}}
color15 {{ansi15}}
