// ws3d.tsx — workspaces con transiciones 3D (lo carga la barra, app.tsx)
// Cómo funciona: toma una captura de la pantalla actual, pone encima una capa a pantalla completa,
// cambia de workspace por debajo y anima en 3D la captura actual hacia la del destino.
// La captura del destino es la última vez que lo viste (se guarda sola en /run/user, que vive en RAM).
import app from "ags/gtk4/app"
import GLib from "gi://GLib"
import Gio from "gi://Gio"
import GObject from "gi://GObject"
import Gtk from "gi://Gtk?version=4.0"
import Gdk from "gi://Gdk?version=4.0"
import Astal from "gi://Astal?version=4.0"
import AstalHyprland from "gi://AstalHyprland"
import { onCleanup } from "ags"
import { execAsync } from "ags/process"
import { readFile } from "ags/file"
import { EFECTOS, type Ctx } from "./efectos3d"

const HOME = GLib.get_home_dir()
const ESTADO = `${HOME}/.config/rice-ws3d/estado`
const CACHE = `${GLib.get_user_runtime_dir()}/zero-ws3d`
const hypr = AstalHyprland.get_default()

// ─────────── configuración (la escribe ws3d.sh) ───────────
const DURACION: Record<string, number> = { rapida: 450, normal: 700, lenta: 1100 }
function leerConfig() {
  const cfg = { efecto: "cubo", velocidad: "normal" }
  try {
    for (const linea of readFile(ESTADO).split("\n")) {
      const i = linea.indexOf("=")
      if (i > 0) (cfg as Record<string, string>)[linea.slice(0, i).trim()] = linea.slice(i + 1).trim()
    }
  } catch {
    // sin archivo: valores por defecto
  }
  return cfg
}

function leerFondo(): Gdk.RGBA {
  const c = new Gdk.RGBA()
  try {
    const m = readFile(`${HOME}/.config/ags/colores.css`).match(/@define-color\s+fondo\s+(#[0-9a-fA-F]{6})/)
    if (m && c.parse(m[1])) {
      // un poco más oscuro que la barra, para que las caras resalten
      c.red *= 0.6; c.green *= 0.6; c.blue *= 0.6
      return c
    }
  } catch {
    // se usa el de abajo
  }
  c.parse("#07070b")
  return c
}

// ─────────── la escena que dibuja el efecto ───────────
const Escena = GObject.registerClass(
  class Escena extends Gtk.Widget {
    _init(params?: Partial<Gtk.Widget.ConstructorProps>) {
      super._init(params)
      ;(this as any).datos = null
      ;(this as any).avance = 0
    }
    vfunc_snapshot(s: Gtk.Snapshot) {
      const self = this as any
      const d = self.datos as (Omit<Ctx, "W" | "H" | "t"> & { efecto: string }) | null
      if (!d) return
      const ef = EFECTOS[d.efecto] ?? EFECTOS.cubo
      ef.dibujar(s, { ...d, W: this.get_width(), H: this.get_height(), t: self.avance })
    }
  },
)
type TEscena = InstanceType<typeof Escena> & { datos: any; avance: number }

type Capa = { win: Astal.Window; escena: TEscena }
const capas = new Map<string, Capa>()

export function CapaWs3D({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const escena = new Escena() as TEscena
  escena.hexpand = true
  escena.vexpand = true
  const conector = gdkmonitor.connector
  let win: Astal.Window
  onCleanup(() => {
    capas.delete(conector)
    win?.destroy()
  })
  const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor
  return (
    <window
      $={(self) => {
        win = self
        self.set_child(escena)
        capas.set(conector, { win: self, escena })
      }}
      visible={false}
      namespace="zero-ws3d"
      name={`ws3d-${conector}`}
      class="ws3d"
      gdkmonitor={gdkmonitor}
      layer={Astal.Layer.OVERLAY}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.NONE}
      anchor={TOP | BOTTOM | LEFT | RIGHT}
      application={app}
    />
  )
}

// ─────────── utilidades ───────────
const existe = (p: string) => GLib.file_test(p, GLib.FileTest.EXISTS)
const irDirecto = (destino: number | string) => {
  const ws = typeof destino === "number" ? `${destino}` : `"${destino}"`
  return execAsync(["hyprctl", "dispatch", `hl.dsp.focus({ workspace = ${ws} })`]).catch(() => "")
}

function textura(ruta: string): Gdk.Texture | null {
  try {
    return existe(ruta) ? Gdk.Texture.new_from_filename(ruta) : null
  } catch {
    return null
  }
}

async function capturar(monitor: string, ruta: string): Promise<boolean> {
  try {
    await execAsync(["grim", "-o", monitor, "-t", "jpeg", "-q", "88", `${ruta}.tmp`])
    GLib.rename(`${ruta}.tmp`, ruta)
    return true
  } catch {
    return false
  }
}

// espera a que la capa ya esté en pantalla (dos cuadros), con límite por si acaso
function esperarCuadros(w: Gtk.Widget, n = 2): Promise<void> {
  return new Promise((listo) => {
    let hecho = false
    const fin = () => { if (!hecho) { hecho = true; listo() } }
    let k = 0
    w.add_tick_callback(() => {
      if (++k >= n) { fin(); return GLib.SOURCE_REMOVE }
      return GLib.SOURCE_CONTINUE
    })
    setTimeout(fin, 250)
  })
}

function correr(escena: TEscena, ms: number): Promise<void> {
  return new Promise((listo) => {
    let ini = -1
    escena.add_tick_callback((_w, reloj) => {
      const ahora = reloj.get_frame_time()
      if (ini < 0) ini = ahora
      escena.avance = Math.min(1, (ahora - ini) / (ms * 1000))
      escena.queue_draw()
      if (escena.avance >= 1) { listo(); return GLib.SOURCE_REMOVE }
      return GLib.SOURCE_CONTINUE
    })
  })
}

// "3", "e+1", "e-1" → número de workspace (e±1 = siguiente/anterior que exista en este monitor)
function resolver(destino: string, monitor: string, actual: number): number | null {
  if (/^-?\d+$/.test(destino)) return Number(destino)
  const m = destino.match(/^e([+-])1$/)
  if (!m) return null
  const ids = hypr.workspaces
    .filter((w) => w.id > 0 && w.monitor?.name === monitor)
    .map((w) => w.id)
    .sort((a, b) => a - b)
  if (ids.length < 2) return null
  const i = ids.indexOf(actual)
  const n = ids.length
  return ids[(((i < 0 ? 0 : i) + (m[1] === "+" ? 1 : -1)) % n + n) % n]
}

// ─────────── el cambio ───────────
let ocupado = false
let pendiente: string | null = null

export async function cambiarWorkspace(destino: string): Promise<string> {
  const foco = hypr.focusedWorkspace
  const mon = hypr.focusedMonitor
  if (!foco || !mon) { await irDirecto(destino); return "ok directo" }

  const hacia = resolver(destino, mon.name, foco.id)
  if (hacia === null) { await irDirecto(destino); return "ok directo" }
  if (hacia === foco.id) return "ok igual"

  if (ocupado) { pendiente = `${hacia}`; return "ok en cola" }

  const cfg = leerConfig()
  const capa = capas.get(mon.name)
  const wsDestino = hypr.get_workspace(hacia)
  const enOtroMonitor = wsDestino && wsDestino.monitor && wsDestino.monitor.name !== mon.name
  if (cfg.efecto === "ninguno" || !capa || enOtroMonitor || foco.id < 0) {
    await irDirecto(hacia)
    return "ok directo"
  }

  ocupado = true
  try {
    await animar(capa, mon.name, foco, hacia, cfg)
  } catch (e) {
    capa.win.visible = false
    await irDirecto(hacia)
    printerr(`ws3d: ${e}`)
  } finally {
    ocupado = false
    if (pendiente !== null) {
      const sig = pendiente
      pendiente = null
      cambiarWorkspace(sig)
    }
  }
  return "ok"
}

async function animar(capa: Capa, monitor: string, foco: AstalHyprland.Workspace, hacia: number, cfg: { efecto: string; velocidad: string }) {
  GLib.mkdir_with_parents(CACHE, 0o700)
  const rutaA = `${CACHE}/${monitor}-ws${foco.id}.jpg`
  if (!(await capturar(monitor, rutaA))) throw new Error("grim falló")
  const A = textura(rutaA)
  if (!A) throw new Error("no pude leer la captura")
  // un workspace vacío se ve igual que cualquier otro vacío (fondo + barra)
  if (foco.clients.length === 0) GLib.spawn_command_line_async(`cp -f '${rutaA}' '${CACHE}/${monitor}-vacio.jpg'`)

  const ws = hypr.get_workspace(hacia)
  const vacio = !ws || ws.clients.length === 0
  let fondoPantalla = ""
  try { fondoPantalla = readFile(`${HOME}/.config/wallpapers/.actual`).trim() } catch { /* sin fondo */ }
  const B =
    textura(vacio ? `${CACHE}/${monitor}-vacio.jpg` : `${CACHE}/${monitor}-ws${hacia}.jpg`) ??
    (vacio ? null : textura(`${CACHE}/${monitor}-vacio.jpg`)) ??
    textura(fondoPantalla) ??
    A

  const ids = Object.keys(EFECTOS)
  const efecto = cfg.efecto === "aleatorio" ? ids[Math.floor(Math.random() * ids.length)] : cfg.efecto
  const ms = (DURACION[cfg.velocidad] ?? 700) * (EFECTOS[efecto]?.duracion ?? 1)

  capa.escena.datos = { A, B, d: hacia > foco.id ? 1 : -1, fondo: leerFondo(), efecto }
  capa.escena.avance = 0
  capa.win.visible = true
  await esperarCuadros(capa.escena)
  await irDirecto(hacia) // el cambio real pasa por debajo de la capa
  await correr(capa.escena, ms)
  capa.win.visible = false
  capa.escena.datos = null

  refrescarDespues(monitor, hacia)
}

// medio segundo después de llegar se guarda cómo se ve el destino, para la próxima vez
function refrescarDespues(monitor: string, ws: number) {
  setTimeout(async () => {
    if (ocupado || hypr.focusedWorkspace?.id !== ws) return
    const ruta = `${CACHE}/${monitor}-ws${ws}.jpg`
    if ((await capturar(monitor, ruta)) && hypr.get_workspace(ws)?.clients.length === 0)
      GLib.spawn_command_line_async(`cp -f '${ruta}' '${CACHE}/${monitor}-vacio.jpg'`)
  }, 500)
}

// ─────────── pedidos desde ws3d.sh (ags request ws 3) ───────────
export function atenderPedido(argv: string[], responder: (r: string) => void) {
  if (argv[0] === "ws" && argv[1]) {
    // se responde luego luego para que el atajo no espere a la animación
    responder("ok")
    cambiarWorkspace(argv[1])
    return
  }
  if (argv[0] === "ws3d-ping") return responder("ok")
  responder("desconocido")
}
