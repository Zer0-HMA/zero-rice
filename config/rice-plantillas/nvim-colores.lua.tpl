#@ destino: ~/.config/rice-nvim/paleta.lua
#@ requiere: dir ~/.config/nvim
-- Generado por paleta.sh — paleta: {{nombre}}
-- Lo lee ~/.config/nvim/lua/zero/init.lua; Neovim se repinta solo cuando este archivo cambia.
return {
  nombre  = [[{{nombre}}]],
  modo    = "{{modo}}",
  -- legibles sobre el fondo de la terminal (que siempre es oscuro)
  fondo   = "{{term_fondo}}",
  texto   = "{{term_texto}}",
  tenue   = "{{term_tenue}}",
  acento  = "{{term_acento}}",
  acento2 = "{{term_acento2}}",
  ansi = {
    "{{ansi0}}", "{{ansi1}}", "{{ansi2}}", "{{ansi3}}", "{{ansi4}}", "{{ansi5}}", "{{ansi6}}", "{{ansi7}}",
    "{{ansi8}}", "{{ansi9}}", "{{ansi10}}", "{{ansi11}}", "{{ansi12}}", "{{ansi13}}", "{{ansi14}}", "{{ansi15}}",
  },
}
