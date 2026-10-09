// efectos3d.ts — transiciones 3D entre workspaces para la barra ZERO
// Solo dibuja: recibe dos capturas (A = workspace actual, B = el destino) y el avance t (0→1),
// y las pinta con transformaciones 3D de GTK (perspectiva + rotaciones). Lo usa ws3d.tsx.
import Gdk from "gi://Gdk?version=4.0"
import Gtk from "gi://Gtk?version=4.0"
import Graphene from "gi://Graphene"

export type Ctx = {
  W: number // tamaño de la pantalla (lógico)
  H: number
  t: number // avance 0 → 1 (lineal; cada efecto elige su curva)
  d: 1 | -1 // 1 = hacia un workspace mayor, -1 = hacia uno menor
  A: Gdk.Texture
  B: Gdk.Texture
  fondo: Gdk.RGBA // lo que se ve detrás de las caras
}
type Efecto = { nombre: string; desc: string; duracion: number; dibujar: (s: Gtk.Snapshot, c: Ctx) => void }

// ─────────── utilidades ───────────
const P = (x: number, y: number) => new Graphene.Point().init(x, y)
const P3 = (x: number, y: number, z: number) => new Graphene.Point3D().init(x, y, z)
const R = (x: number, y: number, w: number, h: number) => new Graphene.Rect().init(x, y, w, h)
const EJE_X = new Graphene.Vec3().init(1, 0, 0)
const EJE_Y = new Graphene.Vec3().init(0, 1, 0)
const EJE_Z = new Graphene.Vec3().init(0, 0, 1)
const rad = (g: number) => (g * Math.PI) / 180
const lim = (x: number) => Math.max(0, Math.min(1, x))
const mezcla = (a: number, b: number, t: number) => a + (b - a) * t

export const curvas = {
  entradaSalida: (t: number) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2),
  salida: (t: number) => 1 - Math.pow(1 - t, 3),
  salidaExpo: (t: number) => (t >= 1 ? 1 : 1 - Math.pow(2, -10 * t)),
  rebote: (t: number) => {
    const c1 = 1.4, c3 = c1 + 1
    return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2)
  },
}

const negro = (a: number) => {
  const c = new Gdk.RGBA()
  c.red = 0; c.green = 0; c.blue = 0; c.alpha = a
  return c
}

// Pinta una captura centrada en el origen, oscurecida según qué tan de lado esté (da sensación de volumen)
function cara(s: Gtk.Snapshot, tex: Gdk.Texture, w: number, h: number, sombra = 0) {
  const r = R(-w / 2, -h / 2, w, h)
  s.append_texture(tex, r)
  if (sombra > 0.005) s.append_color(negro(Math.min(0.85, sombra)), r)
}
// Un pedazo de la captura: la franja/cuadro [x0,y0,w,h] de la pantalla, centrado en el origen
function pedazo(s: Gtk.Snapshot, tex: Gdk.Texture, W: number, H: number, x0: number, y0: number, w: number, h: number, sombra = 0) {
  // se encima 0.75 px con sus vecinos para que no se vean rayitas entre pedazos
  const clip = R(-w / 2 - 0.75, -h / 2 - 0.75, w + 1.5, h + 1.5)
  s.push_clip(clip)
  s.append_texture(tex, R(-w / 2 - x0, -h / 2 - y0, W, H))
  if (sombra > 0.005) s.append_color(negro(Math.min(0.85, sombra)), clip)
  s.pop()
}
const sombraPorAngulo = (g: number) => 0.6 * (1 - Math.cos(rad(g)))

function fondo(s: Gtk.Snapshot, c: Ctx) {
  s.append_color(c.fondo, R(0, 0, c.W, c.H))
}
function centro(s: Gtk.Snapshot, c: Ctx, profundidad: number) {
  s.translate(P(c.W / 2, c.H / 2))
  s.perspective(profundidad)
}

// ─────────── cubo (horizontal o vertical) ───────────
function cubo(s: Gtk.Snapshot, c: Ctx, vertical: boolean) {
  const e = curvas.entradaSalida(c.t)
  const lado = vertical ? c.H : c.W
  const eje = vertical ? EJE_X : EJE_Y
  // horizontal: el destino entra por la derecha (d=1); vertical: por abajo (d=1)
  const giro = vertical ? c.d * 90 * e : -c.d * 90 * e
  const caraB = vertical ? -c.d * 90 : c.d * 90
  const alejar = lado * 0.32 * Math.sin(Math.PI * c.t) // se aleja un poco a medio giro para ver el cubo

  fondo(s, c)
  s.save()
  centro(s, c, c.W * 1.4)
  s.translate_3d(P3(0, 0, -lado / 2 - alejar))
  s.rotate_3d(giro, eje)
  const caras = [
    { tex: c.A, g: 0 },
    { tex: c.B, g: caraB },
  ].map((f) => ({ ...f, total: f.g + giro }))
  caras.sort((a, b) => Math.cos(rad(a.total)) - Math.cos(rad(b.total))) // lo de atrás primero
  for (const f of caras) {
    if (Math.cos(rad(f.total)) <= 0) continue // cara de espaldas
    s.save()
    s.rotate_3d(f.g, eje)
    s.translate_3d(P3(0, 0, lado / 2))
    cara(s, f.tex, c.W, c.H, sombraPorAngulo(f.total))
    s.restore()
  }
  s.restore()
}

// ─────────── voltear como carta ───────────
function voltear(s: Gtk.Snapshot, c: Ctx) {
  const e = curvas.entradaSalida(c.t)
  const g = -c.d * 180 * e
  fondo(s, c)
  s.save()
  centro(s, c, c.W * 1.6)
  s.translate_3d(P3(0, 0, -c.W * 0.45 * Math.sin(Math.PI * c.t)))
  s.rotate_3d(g, EJE_Y)
  if (Math.abs(g) < 90) cara(s, c.A, c.W, c.H, sombraPorAngulo(g))
  else {
    s.rotate_3d(180, EJE_Y) // el reverso, al derecho
    cara(s, c.B, c.W, c.H, sombraPorAngulo(g + 180))
  }
  s.restore()
}

// ─────────── carrusel (como portadas de discos) ───────────
function carrusel(s: Gtk.Snapshot, c: Ctx) {
  const e = curvas.entradaSalida(c.t)
  const atras = -c.W * 0.55 * Math.sin(Math.PI * c.t)
  const paso = c.W * 0.75
  const pantallas = [
    { tex: c.A, x: -c.d * paso * e, g: c.d * 55 * e },
    { tex: c.B, x: c.d * paso * (1 - e), g: -c.d * 55 * (1 - e) },
  ]
  pantallas.sort((a, b) => Math.abs(b.x) - Math.abs(a.x)) // la del centro va encima
  fondo(s, c)
  s.save()
  centro(s, c, c.W * 1.3)
  for (const p of pantallas) {
    s.save()
    s.translate_3d(P3(p.x, 0, atras))
    s.rotate_3d(p.g, EJE_Y)
    cara(s, p.tex, c.W, c.H, sombraPorAngulo(p.g) + Math.abs(p.x) / c.W * 0.4)
    s.restore()
  }
  s.restore()
}

// ─────────── puerta que se abre ───────────
// La actual se abre hacia adentro sobre su bisagra; el destino espera al fondo y se acerca cuando ya pasó la puerta
function puerta(s: Gtk.Snapshot, c: Ctx) {
  const eP = curvas.entradaSalida(lim(c.t / 0.62))
  const eB = curvas.salida(lim((c.t - 0.5) / 0.5))
  const g = c.d * 92 * eP
  fondo(s, c)
  s.save()
  centro(s, c, c.W * 1.1)
  s.save()
  s.translate_3d(P3(0, 0, -c.W * 1.1 * (1 - eB)))
  cara(s, c.B, c.W, c.H, 0.55 * (1 - eB))
  s.restore()
  if (Math.abs(g) < 90) {
    const bisagra = -c.d * c.W / 2 // izquierda si vas a la derecha
    s.save()
    s.translate_3d(P3(bisagra, 0, 0))
    s.rotate_3d(g, EJE_Y)
    s.translate_3d(P3(-bisagra, 0, 0))
    cara(s, c.A, c.W, c.H, sombraPorAngulo(g))
    s.restore()
  }
  s.restore()
}

// ─────────── caída hacia atrás ───────────
function caida(s: Gtk.Snapshot, c: Ctx) {
  const eA = curvas.entradaSalida(lim(c.t / 0.75))
  const eB = curvas.salida(lim((c.t - 0.2) / 0.8))
  fondo(s, c)
  s.save()
  centro(s, c, c.W * 1.1)
  // el destino sube desde el fondo
  s.save()
  s.translate_3d(P3(0, 0, -c.W * 0.5 * (1 - eB)))
  cara(s, c.B, c.W, c.H, 0.6 * (1 - eB))
  s.restore()
  // la actual se cae hacia atrás sobre su borde de abajo (o de arriba si vas hacia atrás)
  const g = 92 * eA
  if (g < 90) {
    const borde = c.d * c.H / 2
    s.save()
    s.translate_3d(P3(0, borde, 0))
    s.rotate_3d(c.d * g, EJE_X)
    s.translate_3d(P3(0, -borde, 0))
    cara(s, c.A, c.W, c.H, sombraPorAngulo(g))
    s.restore()
  }
  s.restore()
}

// ─────────── túnel (atraviesas la pantalla) ───────────
function tunel(s: Gtk.Snapshot, c: Ctx) {
  const e = curvas.entradaSalida(c.t)
  // d=1: la actual viene hacia ti y desaparece; d=-1: se va al fondo
  const lejos = -c.W * 1.6, cerca = c.W * 0.55
  const zA = c.d > 0 ? mezcla(0, cerca, e) : mezcla(0, lejos, e)
  const zB = c.d > 0 ? mezcla(lejos, 0, e) : mezcla(cerca, 0, e)
  const capas = [
    { tex: c.A, z: zA, op: 1 - e },
    { tex: c.B, z: zB, op: e },
  ].sort((a, b) => a.z - b.z)
  fondo(s, c)
  s.save()
  centro(s, c, c.W * 1.2)
  for (const k of capas) {
    if (k.op <= 0.01) continue
    s.save()
    s.translate_3d(P3(0, 0, k.z))
    s.push_opacity(Math.min(1, k.op * 1.3))
    cara(s, k.tex, c.W, c.H)
    s.pop()
    s.restore()
  }
  s.restore()
}

// ─────────── inclinado (deslizar con perspectiva) ───────────
function inclinado(s: Gtk.Snapshot, c: Ctx) {
  const e = curvas.entradaSalida(c.t)
  const arco = Math.sin(Math.PI * c.t)
  const sep = c.W * 1.08
  fondo(s, c)
  s.save()
  centro(s, c, c.W * 1.5)
  s.translate_3d(P3(0, 0, -c.W * 0.5 * arco))
  s.rotate_3d(c.d * 28 * arco, EJE_Y)
  for (const [tex, x] of [[c.A, -c.d * sep * e], [c.B, c.d * sep * (1 - e)]] as [Gdk.Texture, number][]) {
    s.save()
    s.translate_3d(P3(x, 0, 0))
    cara(s, tex, c.W, c.H, 0.25 * arco)
    s.restore()
  }
  s.restore()
}

// ─────────── remolino ───────────
function remolino(s: Gtk.Snapshot, c: Ctx) {
  const e = curvas.entradaSalida(c.t)
  fondo(s, c)
  s.save()
  centro(s, c, c.W * 1.2)
  const capas = [
    { tex: c.A, z: -c.W * 1.4 * e, g: c.d * 200 * e, op: 1 - lim((c.t - 0.35) / 0.4) },
    { tex: c.B, z: -c.W * 1.4 * (1 - e), g: -c.d * 200 * (1 - e), op: lim((c.t - 0.25) / 0.4) },
  ].sort((a, b) => a.z - b.z)
  for (const k of capas) {
    if (k.op <= 0.01) continue
    s.save()
    s.translate_3d(P3(0, 0, k.z))
    s.rotate_3d(k.g, EJE_Z)
    s.rotate_3d(k.g * 0.12, EJE_X)
    s.push_opacity(k.op)
    cara(s, k.tex, c.W, c.H)
    s.pop()
    s.restore()
  }
  s.restore()
}

// ─────────── persianas y mosaico (pedazos que se voltean) ───────────
function piezas(s: Gtk.Snapshot, c: Ctx, cols: number, filas: number, eje: Graphene.Vec3, retraso: number) {
  const w = c.W / cols, h = c.H / filas
  const maxOrden = cols - 1 + (filas - 1)
  fondo(s, c)
  s.save()
  centro(s, c, c.W * 1.3)
  for (let i = 0; i < cols; i++) {
    for (let j = 0; j < filas; j++) {
      // el barrido va en la dirección del cambio
      const orden = (c.d > 0 ? i : cols - 1 - i) + j
      const ini = maxOrden ? (orden / maxOrden) * retraso : 0
      const tl = curvas.entradaSalida(lim((c.t - ini) / (1 - retraso)))
      const g = 180 * tl
      const x0 = i * w, y0 = j * h
      s.save()
      s.translate_3d(P3(x0 + w / 2 - c.W / 2, y0 + h / 2 - c.H / 2, -Math.sin(Math.PI * tl) * w * 0.6))
      s.rotate_3d(c.d * g, eje)
      if (g < 90) pedazo(s, c.A, c.W, c.H, x0, y0, w, h, sombraPorAngulo(g))
      else {
        s.rotate_3d(180, eje)
        pedazo(s, c.B, c.W, c.H, x0, y0, w, h, sombraPorAngulo(g + 180))
      }
      s.restore()
    }
  }
  s.restore()
}

// ─────────── el catálogo ───────────
// duracion: multiplica la duración elegida (rápida/normal/lenta)
export const EFECTOS: Record<string, Efecto> = {
  cubo:          { nombre: "Cubo",          desc: "el clásico: los workspaces son caras de un cubo que gira",   duracion: 1,    dibujar: (s, c) => cubo(s, c, false) },
  cubovertical:  { nombre: "Cubo vertical", desc: "el cubo gira hacia arriba y hacia abajo",                    duracion: 1,    dibujar: (s, c) => cubo(s, c, true) },
  voltear:       { nombre: "Voltear",       desc: "la pantalla se voltea como carta y atrás está la otra",      duracion: 1.05, dibujar: voltear },
  carrusel:      { nombre: "Carrusel",      desc: "se alejan y giran como portadas de discos",                  duracion: 1.1,  dibujar: carrusel },
  puerta:        { nombre: "Puerta",        desc: "la pantalla se abre como puerta y la otra te espera atrás",  duracion: 1.1,  dibujar: puerta },
  caida:         { nombre: "Caída",         desc: "la pantalla se cae hacia atrás y la otra sube del fondo",    duracion: 1.15, dibujar: caida },
  tunel:         { nombre: "Túnel",         desc: "atraviesas la pantalla y llegas a la otra",                  duracion: 1,    dibujar: tunel },
  inclinado:     { nombre: "Inclinado",     desc: "se desliza de lado, inclinándose en 3D",                     duracion: 1,    dibujar: inclinado },
  remolino:      { nombre: "Remolino",      desc: "la pantalla se va girando al fondo y la otra regresa girando", duracion: 1.15, dibujar: remolino },
  persianas:     { nombre: "Persianas",     desc: "franjas que se voltean una tras otra",                       duracion: 1.35, dibujar: (s, c) => piezas(s, c, 12, 1, EJE_Y, 0.45) },
  mosaico:       { nombre: "Mosaico",       desc: "cuadritos que se voltean en ola diagonal",                   duracion: 1.45, dibujar: (s, c) => piezas(s, c, 10, 6, EJE_Y, 0.5) },
  domino:        { nombre: "Dominó",        desc: "franjas horizontales que caen en cascada",                   duracion: 1.35, dibujar: (s, c) => piezas(s, c, 1, 8, EJE_X, 0.45) },
}
