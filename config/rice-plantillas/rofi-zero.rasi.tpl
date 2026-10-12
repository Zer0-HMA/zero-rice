#@ destino: ~/.config/rofi/themes/zero.rasi
/* Generado por paleta.sh — paleta: {{nombre}} */
* {
    bg: {{fondo.a94}}; bg-alt: {{fondo2}}; fg: {{texto}}; fg-dim: {{tenue}};
    acento: {{acento}}; acento2: {{acento2}}; sobre: {{sobre}};
    background-color: transparent;
    text-color: @fg;
    font: "JetBrainsMono Nerd Font 12";
}
window { width: 620px; background-color: @bg; border: 2px; border-color: @acento; border-radius: 16px; padding: 18px; }
mainbox { spacing: 14px; children: [ inputbar, listview ]; }
inputbar { children: [ prompt, entry ]; spacing: 12px; padding: 12px 16px; border-radius: 12px; background-color: @bg-alt; }
prompt { text-color: @acento; }
entry { placeholder: "Buscar..."; placeholder-color: @fg-dim; cursor: text; }
listview { lines: 8; columns: 1; spacing: 6px; fixed-height: true; scrollbar: false; }
element { padding: 9px 14px; spacing: 14px; border-radius: 10px; cursor: pointer; }
element selected.normal { background-image: linear-gradient(to right, {{acento.a25}}, {{acento2.a13}}); border: 0 0 0 3px; border-color: @acento; }
element-icon { size: 30px; cursor: inherit; }
element-text { vertical-align: 0.5; text-color: inherit; cursor: inherit; }
