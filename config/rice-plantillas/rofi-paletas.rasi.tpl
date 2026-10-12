#@ destino: ~/.config/rofi/themes/paletas.rasi
/* Menú de paletas — generado por paleta.sh */
* {
    bg: {{fondo.a94}}; bg-alt: {{fondo2}}; fg: {{texto}}; fg-dim: {{tenue}};
    acento: {{acento}}; acento2: {{acento2}}; sobre: {{sobre}};
    background-color: transparent;
    text-color: @fg;
    font: "JetBrainsMono Nerd Font 12";
}
window { width: 820px; background-color: @bg; border: 2px; border-color: @acento; border-radius: 18px; padding: 20px; }
mainbox { spacing: 16px; children: [ inputbar, listview ]; }
inputbar { children: [ prompt, entry ]; spacing: 12px; padding: 12px 16px; border-radius: 12px; background-color: @bg-alt; }
prompt { text-color: @acento; }
entry { placeholder: "Busca una paleta... (Enter para aplicar)"; placeholder-color: @fg-dim; }
listview { lines: 9; columns: 1; spacing: 6px; fixed-height: true; scrollbar: false; }
element { padding: 10px 16px; border-radius: 12px; cursor: pointer; }
element selected.normal { background-color: @bg-alt; border: 0 0 0 4px; border-color: @acento; }
element-text { font: "JetBrainsMono Nerd Font 14"; vertical-align: 0.5; text-color: @fg; cursor: inherit; }
