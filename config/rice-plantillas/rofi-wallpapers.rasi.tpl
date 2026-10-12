#@ destino: ~/.config/rofi/themes/wallpapers.rasi
/* Generado por paleta.sh — paleta: {{nombre}} */
* {
    bg: {{fondo.a94}}; bg-alt: {{fondo2}}; fg: {{texto}}; fg-dim: {{tenue}};
    acento: {{acento}}; acento2: {{acento2}}; sobre: {{sobre}};
    background-color: transparent;
    text-color: @fg;
    font: "JetBrainsMono Nerd Font 11";
}
window { width: 1040px; background-color: @bg; border: 2px; border-color: @acento2; border-radius: 18px; padding: 20px; }
mainbox { spacing: 16px; children: [ inputbar, listview ]; }
inputbar { children: [ prompt, entry ]; spacing: 12px; padding: 12px 16px; border-radius: 12px; background-color: @bg-alt; }
prompt { text-color: @acento; }
entry { placeholder: "Buscar fondo..."; placeholder-color: @fg-dim; }
listview { columns: 4; lines: 2; spacing: 14px; fixed-columns: true; scrollbar: false; }
element { orientation: vertical; children: [ element-icon, element-text ]; padding: 10px; spacing: 8px; border-radius: 14px; cursor: pointer; }
element selected.normal { background-color: @bg-alt; border: 2px; border-color: @acento; }
element-icon { size: 210px; horizontal-align: 0.5; cursor: inherit; }
element-text { horizontal-align: 0.5; text-color: inherit; cursor: inherit; }
