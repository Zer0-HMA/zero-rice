// Barra v2 para AGS v3 (GTK4) — zr0_humber_
// Los colores salen de colores.css (paleta.sh lo reescribe y la barra se repinta sola, sin reiniciarse)
import app from "ags/gtk4/app"
import GLib from "gi://GLib"
import Gio from "gi://Gio"
import Pango from "gi://Pango"
import Astal from "gi://Astal?version=4.0"
import Gtk from "gi://Gtk?version=4.0"
import Gdk from "gi://Gdk?version=4.0"
import AstalHyprland from "gi://AstalHyprland"
import AstalWp from "gi://AstalWp"
import AstalBattery from "gi://AstalBattery"
import AstalTray from "gi://AstalTray"
import AstalMpris from "gi://AstalMpris"
import { For, With, This, createBinding, createComputed, createState, onCleanup } from "ags"
import { createPoll } from "ags/time"
import { execAsync, subprocess } from "ags/process"
import { readFile, monitorFile } from "ags/file"
import { CapaWs3D, cambiarWorkspace, atenderPedido } from "./ws3d"
import estilo from "./style.css"

// ── Iconos (JetBrainsMono Nerd Font) ──
const ICO = {
  arch: "\uF303",
  usuario: "\uF007",
  root: "\uF21B",
  cpu: "\uF2DB",
  ram: "\u{F035B}",
  temp: "\uF2C9",
  reloj: "\uF017",
  musica: "\uF001",
  ant: "\uF048",
  play: "\uF04B",
  pausa: "\uF04C",
  sig: "\uF051",
  paleta: "\u{F03D8}",
  campana: "\uF0F3",
  campanaOff: "\uF1F6",
  power: "\uF011",
  candado: "\uF023",
  luna: "\uF186",
  salir: "\uF08B",
  reiniciar: "\uF01E",
}

const HOME = GLib.get_home_dir()
const CFG = GLib.get_user_config_dir()
const SCRIPTS = `${CFG}/hypr/scripts`
const USUARIO = GLib.get_user_name()
const HOST = GLib.get_host_name()

const run = (cmd: string[]) => execAsync(cmd).catch(() => {})
const hypr = AstalHyprland.get_default()

// ── Colores ──
// Se leen al arrancar y cada vez que paleta.sh reescribe colores.css: la barra se repinta
// sin reiniciarse. Si el archivo no existe todavía, usa la paleta neón.
const RUTA_COLORES = `${CFG}/ags/colores.css`
const COLORES_DEFECTO = `
@define-color fondo #0b0b12; @define-color fondo2 #1a1a28; @define-color tenue #8a8aa3;
@define-color texto #e6e6f0; @define-color acento #22d3ee; @define-color acento2 #ec4899;
@define-color sobre #0b0b12; @define-color inactivo #2a2a3a;
@define-color medio #878fc3; @define-color sombra #050508; @define-color rojo #f87171;
@define-color verde #4ade80; @define-color amarillo #facc15; @define-color azul #60a5fa;
@define-color magenta #c084fc; @define-color cyan #22d3ee; @define-color root_fondo #fefefe;
@define-color root_texto #1c1c1e; @define-color root_borde #d1d1d3;`

function leerColores(): string {
  try {
    const c = readFile(RUTA_COLORES)
    return c.includes("@define-color") ? c : COLORES_DEFECTO
  } catch {
    return COLORES_DEFECTO
  }
}

// ── Estilo de la barra (Super + Shift + B) ──
// La forma se elige aparte de la paleta: barra-estilo.sh escribe el nombre en
// ~/.config/rice-barra/estilo y aquí se carga ~/.config/ags/estilos/<nombre>.css encima de style.css.
// 48 paletas × cada estilo, combinables; se aplica en vivo, sin reiniciar la barra.
const RUTA_ESTILO = `${CFG}/rice-barra/estilo`
const DIR_ESTILOS = `${CFG}/ags/estilos`

function leerEstiloBarra(): string {
  try {
    const nombre = readFile(RUTA_ESTILO).trim()
    if (!/^[a-z0-9_-]+$/.test(nombre)) return ""
    return readFile(`${DIR_ESTILOS}/${nombre}.css`)
  } catch {
    return "" // sin estilo elegido: style.css tal cual (islas)
  }
}

const cssCompleto = () => `${leerColores()}\n${estilo}\n${leerEstiloBarra()}`

const monitores: unknown[] = []
function vigilarColores() {
  let espera: ReturnType<typeof setTimeout> | null = null
  const repintar = () => {
    // paleta.sh y barra-estilo.sh escriben en varios pasos: esperamos a que terminen
    if (espera) clearTimeout(espera)
    espera = setTimeout(() => {
      espera = null
      app.apply_css(cssCompleto(), true)
    }, 250)
  }
  monitores.push(monitorFile(RUTA_COLORES, repintar))
  monitores.push(monitorFile(RUTA_ESTILO, repintar))
}


// Pasa por ws3d.tsx: si elegiste un efecto 3D (Super + Shift + E) lo dibuja; si no, cambia normal
const irAWorkspace = (id: number) => cambiarWorkspace(`${id}`)

// ── Módulo que se expande al pasar el mouse ──
// Muestra lo esencial y, al pasar el mouse, desliza el resto. Al salir espera un poco
// antes de cerrarse para que no tiemble si el mouse roza el borde.
function Expandible({ clase, base, extra }: { clase: string; base: JSX.Element; extra: JSX.Element }) {
  const [abierto, setAbierto] = createState(false)
  let cierre: ReturnType<typeof setTimeout> | null = null
  const abrir = () => {
    if (cierre) clearTimeout(cierre)
    cierre = null
    setAbierto(true)
  }
  const cerrar = () => {
    if (cierre) clearTimeout(cierre)
    cierre = setTimeout(() => {
      cierre = null
      setAbierto(false)
    }, 350)
  }
  return (
    <box class={abierto.as((a) => (a ? `${clase} expandible abierto` : `${clase} expandible`))}>
      <Gtk.EventControllerMotion onEnter={abrir} onLeave={cerrar} />
      {base}
      <revealer
        revealChild={abierto}
        transitionType={Gtk.RevealerTransitionType.SLIDE_RIGHT}
        transitionDuration={280}
      >
        {extra}
      </revealer>
    </box>
  )
}

// ── ¿Hay un shell de root en la ventana enfocada? ──
// Busca procesos bash/zsh/fish/sh de root que cuelguen de la ventana activa (ej: después de "su" o "sudo -i")
const SCRIPT_ROOT = `
pid="$1"
ps -eo pid=,ppid=,user=,comm= | awk -v r="$pid" '
{ par[$1]=$2; usr[$1]=$3; cmd[$1]=$4 }
END {
  if (usr[r] == "root") { print 1; exit }
  for (p in par) {
    if (usr[p] == "root" && cmd[p] ~ /^(bash|zsh|fish|sh|dash|nu|ksh|su)$/) {
      q = p; n = 0
      while (q != "" && q != "0" && q != "1" && n < 64) { if (q == r) { print 1; exit } q = par[q]; n++ }
    }
  }
  print 0
}'`

// Antes se lanzaba bash+ps cada 1.5 s pasara lo que pasara. Ahora: al cambiar de ventana y cada 3 s,
// y el escaneo de procesos solo se hace si la ventana enfocada es una terminal.
const TERMINALES =
  /^(kitty|alacritty|foot|footclient|wezterm|org\.wezfurlong\.wezterm|ghostty|com\.mitchellh\.ghostty|konsole|org\.kde\.konsole|xterm|uxterm|urxvt|st|xfce4-terminal|tilix|terminator|gnome-terminal-server|org\.gnome\.terminal|org\.gnome\.console|kgx)$/i

function uidDe(pid: number): number {
  try {
    const m = readFile(`/proc/${pid}/status`).match(/^Uid:\s+(\d+)/m)
    return m ? Number(m[1]) : -1
  } catch {
    return -1
  }
}

const [esRoot, setEsRoot] = createState(USUARIO === "root")
const marcarRoot = (v: boolean) => {
  if (esRoot.get() !== v) setEsRoot(v)
}
let revisandoRoot = false

async function revisarRoot() {
  if (USUARIO === "root" || revisandoRoot) return
  const cliente = hypr.focusedClient
  if (!cliente || !cliente.pid) return marcarRoot(false)
  const pid = cliente.pid
  if (uidDe(pid) === 0) return marcarRoot(true)                      // la ventana misma es de root
  if (!TERMINALES.test(cliente.class ?? "")) return marcarRoot(false) // no es terminal: no hay shell
  revisandoRoot = true
  try {
    const out = await execAsync(["bash", "-c", SCRIPT_ROOT, "root-check", String(pid)])
    marcarRoot(out.trim() === "1")
  } catch {
    marcarRoot(false)
  } finally {
    revisandoRoot = false
  }
}

if (USUARIO !== "root") {
  hypr.connect("notify::focused-client", () => revisarRoot())
  setInterval(() => revisarRoot(), 3000)
}

// ── Lanzador ──
function Lanzador() {
  return (
    <button class="modulo lanzador" tooltipText="Aplicaciones" onClicked={() => run([`${SCRIPTS}/lanzador.sh`])}>
      <label label={ICO.arch} />
    </button>
  )
}

// ── Usuario: foto de perfil y nombre (se pone blanco cuando eres root) ──
// La foto y el nombre los cambia perfil.sh (Super + Shift + F o clic aquí); la barra se entera sola.
const PERFIL = `${HOME}/.config/rice-perfil`
const AVATAR = `${PERFIL}/avatar.png`

function leerAvatar(): Gdk.Texture | null {
  try {
    return GLib.file_test(AVATAR, GLib.FileTest.EXISTS) ? Gdk.Texture.new_from_filename(AVATAR) : null
  } catch {
    return null
  }
}
function leerNombre(): string {
  try {
    return readFile(`${PERFIL}/nombre`).split("\n")[0].trim() || USUARIO
  } catch {
    return USUARIO
  }
}

const [avatar, setAvatar] = createState<Gdk.Texture | null>(leerAvatar())
const [nombre, setNombre] = createState(leerNombre())
let monitorPerfil: Gio.FileMonitor | null = null
let perfilTimer: ReturnType<typeof setTimeout> | null = null

function vigilarPerfil() {
  GLib.mkdir_with_parents(PERFIL, 0o755)
  monitorPerfil = monitorFile(PERFIL, () => {
    // llegan varios avisos por cambio; se espera a que terminen
    if (perfilTimer) clearTimeout(perfilTimer)
    perfilTimer = setTimeout(() => {
      perfilTimer = null
      setAvatar(leerAvatar())
      setNombre(leerNombre())
    }, 250)
  })
}

function leerUptime(): string {
  const seg = Math.floor(Number(readFile("/proc/uptime").split(" ")[0]))
  const h = Math.floor(seg / 3600)
  const m = Math.floor((seg % 3600) / 60)
  return h > 0 ? `${h} h ${m} min` : `${m} min`
}

function Usuario() {
  const uptime = createPoll("", 60000, leerUptime)
  const conFoto = createComputed(() => !esRoot() && avatar() !== null)
  const clases = createComputed(() => {
    const c = ["modulo", "usuario"]
    if (esRoot()) c.push("es-root")
    if (conFoto()) c.push("con-foto")
    return c.join(" ")
  })

  return (
    <box
      class={clases}
      spacing={8}
      tooltipText={uptime.as((u) => `${USUARIO}@${HOST}\nEncendida hace ${u}\nClic: foto de perfil y nombre`)}
    >
      <Gtk.GestureClick onPressed={() => run([`${SCRIPTS}/perfil.sh`, "menu"])} />
      <image class="avatar" visible={conFoto} paintable={avatar} pixelSize={22} />
      <label class="icono" visible={conFoto.as((c) => !c)} label={esRoot.as((r) => (r ? ICO.root : ICO.usuario))} />
      <label
        maxWidthChars={16}
        ellipsize={Pango.EllipsizeMode.END}
        label={createComputed(() => (esRoot() ? "root" : nombre()))}
      />
    </box>
  )
}

// ── Workspaces: siempre del 1 al 5, con puntito si tienen ventanas ──
function Workspaces() {
  const lista = createBinding(hypr, "workspaces")
  const foco = createBinding(hypr, "focusedWorkspace")
  const ids = lista.as((ws) => {
    const s = new Set([1, 2, 3, 4, 5])
    ws.forEach((w) => w.id > 0 && s.add(w.id))
    return [...s].sort((a, b) => a - b)
  })

  return (
    <box class="modulo workspaces" spacing={4}>
      <Gtk.EventControllerScroll
        flags={Gtk.EventControllerScrollFlags.VERTICAL}
        onScroll={(_c, _dx, dy) => {
          cambiarWorkspace(dy > 0 ? "e+1" : "e-1")
          return true
        }}
      />
      <For each={ids}>
        {(id) => (
          <button
            onClicked={() => irAWorkspace(id)}
            class={createComputed(() => {
              if (foco()?.id === id) return "activo"
              return lista().some((w) => w.id === id) ? "ocupado" : ""
            })}
          >
            <label label={`${id}`} />
          </button>
        )}
      </For>
    </box>
  )
}

// ── Título de la ventana activa ──
function Titulo() {
  const titulo = createBinding(hypr, "focusedClient", "title").as((t) => t || "Escritorio")
  return <label class="titulo" maxWidthChars={32} ellipsize={Pango.EllipsizeMode.END} label={titulo} />
}

// ── Reloj con calendario ──
// Una sola lectura para todos los monitores
const hora = createPoll("", 1000, () => GLib.DateTime.new_now_local().format("%H:%M")!)
const fecha = createPoll("", 60000, () => GLib.DateTime.new_now_local().format("%A %d %B")!)

function Reloj() {
  return (
    <menubutton class="modulo reloj" tooltipText="Clic: calendario">
      <Expandible
        clase="reloj-interior"
        base={
          <box spacing={8}>
            <label class="icono" label={ICO.reloj} />
            <label class="hora" label={hora} />
          </box>
        }
        extra={<label class="fecha" label={fecha} />}
      />
      <popover>
        <Gtk.Calendar />
      </popover>
    </menubutton>
  )
}

// ── Música (aparece solo si algo está sonando: Spotify, YouTube en el navegador, etc.) ──
// Se muestra el reproductor que está sonando; si ninguno suena, el primero.
const mpris = AstalMpris.get_default()
const [reproductor, setReproductor] = createState<AstalMpris.Player | null>(null)
const conectados = new WeakSet<AstalMpris.Player>()

function elegirReproductor() {
  const lista = mpris.players
  for (const p of lista) {
    if (conectados.has(p)) continue
    conectados.add(p)
    p.connect("notify::playback-status", () => {
      elegirReproductor()
      activarCava()
    })
  }
  const nuevo = lista.find((p) => p.playbackStatus === AstalMpris.PlaybackStatus.PLAYING) ?? lista[0] ?? null
  if (nuevo !== reproductor.get()) setReproductor(nuevo)
}

// ── Visualizador de audio (AstalCava) ──
// Se carga con import() dinámico: si tu libastal no trae cava, la barra sigue igual, sin espectro.
// Solo escucha el audio mientras algo suena, para no gastar CPU de más.
const BARRAS_CAVA = 10
const [hayCava, setHayCava] = createState(false)
let cava: any = null
let valoresCava: number[] = []
const areasCava = new Set<Gtk.DrawingArea>()

function sonando(): boolean {
  return mpris.players.some((p) => p.playbackStatus === AstalMpris.PlaybackStatus.PLAYING)
}

function activarCava() {
  if (!cava) return
  const on = sonando()
  try {
    if (cava.active !== on) cava.active = on
  } catch {
    // versiones viejas sin la propiedad "active": siempre activo
  }
  if (!on) {
    valoresCava = []
    areasCava.forEach((a) => a.queue_draw())
  }
}

async function iniciarCava() {
  try {
    // @ts-ignore: los tipos de AstalCava pueden no estar generados
    const modulo = await import("gi://AstalCava")
    const AstalCava = modulo.default ?? modulo
    const c = AstalCava.get_default()
    if (!c) return
    c.bars = BARRAS_CAVA
    try {
      c.framerate = 30
    } catch {}
    c.connect("notify::values", () => {
      valoresCava = c.values ?? c.get_values?.() ?? []
      areasCava.forEach((a) => a.queue_draw())
    })
    cava = c
    activarCava()
    setHayCava(true)
  } catch (e) {
    console.log(`Sin visualizador de audio (AstalCava no disponible): ${e}`)
  }
}

function Espectro() {
  return (
    <Gtk.DrawingArea
      class="cava"
      visible={hayCava}
      widthRequest={BARRAS_CAVA * 4 + (BARRAS_CAVA - 1) * 2}
      heightRequest={14}
      valign={Gtk.Align.CENTER}
      $={(area: Gtk.DrawingArea) => {
        areasCava.add(area)
        area.connect("destroy", () => areasCava.delete(area))
        area.set_draw_func((a: Gtk.DrawingArea, cr: any, w: number, h: number) => {
          // el color sale del CSS (.cava { color: ... }), así sigue a la paleta
          const c = (a as any).get_color?.() ?? { red: 1, green: 1, blue: 1, alpha: 1 }
          const gap = 2
          const ancho = (w - gap * (BARRAS_CAVA - 1)) / BARRAS_CAVA
          cr.setSourceRGBA(c.red, c.green, c.blue, c.alpha)
          for (let i = 0; i < BARRAS_CAVA; i++) {
            const v = Math.min(1, Math.max(0, valoresCava[i] ?? 0))
            const alto = Math.max(2, v * h)
            cr.rectangle(i * (ancho + gap), h - alto, ancho, alto)
          }
          cr.fill()
          cr.$dispose?.()
        })
      }}
    />
  )
}

mpris.connect("notify::players", () => {
  elegirReproductor()
  activarCava()
})
elegirReproductor()

function Musica() {
  return (
    <box class="modulo musica" visible={reproductor.as((p) => p !== null)}>
      <With value={reproductor}>
        {(p: AstalMpris.Player | null) => {
          if (!p) return <box />
          const titulo = createBinding(p, "title")
          const artista = createBinding(p, "artist")
          const texto = createComputed(() => {
            const t = titulo()
            const a = artista()
            return a ? `${t} — ${a}` : t || p.identity
          })
          return (
            <box spacing={10}>
              <label class="icono" label={ICO.musica} />
              <Espectro />
              <label class="cancion" maxWidthChars={26} ellipsize={Pango.EllipsizeMode.END} label={texto} />
              <button class="control" onClicked={() => p.previous()}>
                <label label={ICO.ant} />
              </button>
              <button class="control" onClicked={() => p.play_pause()}>
                <label
                  label={createBinding(p, "playbackStatus").as((s) =>
                    s === AstalMpris.PlaybackStatus.PLAYING ? ICO.pausa : ICO.play,
                  )}
                />
              </button>
              <button class="control" onClicked={() => p.next()}>
                <label label={ICO.sig} />
              </button>
            </box>
          )
        }}
      </With>
    </box>
  )
}

// ── Red ──
// Se lee con nmcli: la librería de red de Astal tronaba la barra al conectarse a redes ocultas.
// En vez de preguntar cada 4 s, se escucha "nmcli monitor" y se actualiza solo cuando algo cambia
// (más una revisión cada 20 s para la intensidad de la señal y Tailscale).
type EstadoRed = { cable: boolean; wifi: string; senal: number; tailscale: string }
const SIN_RED: EstadoRed = { cable: false, wifi: "", senal: 0, tailscale: "" }
const nm = (...args: string[]) => execAsync(["env", "LC_ALL=", "LANGUAGE=", "LC_MESSAGES=C", "nmcli", ...args])
const HAY_TAILSCALE = GLib.find_program_in_path("tailscale") !== null

async function leerRed(): Promise<EstadoRed> {
  const r: EstadoRed = { ...SIN_RED }
  try {
    const activas = await nm("-t", "-f", "TYPE,NAME", "con", "show", "--active")
    for (const linea of activas.split("\n")) {
      const i = linea.indexOf(":")
      if (i < 0) continue
      const tipo = linea.slice(0, i)
      const nombre = linea.slice(i + 1).replace(/\\:/g, ":")
      if (tipo === "802-3-ethernet") r.cable = true
      if (tipo === "802-11-wireless") r.wifi = nombre
    }
    if (r.wifi) {
      const lista = await nm("-t", "-f", "IN-USE,SIGNAL", "dev", "wifi", "list", "--rescan", "no")
      const enUso = lista.split("\n").find((l) => l.startsWith("*:"))
      r.senal = enUso ? Number(enUso.split(":")[1]) || 0 : 0
    }
  } catch {
    // nmcli no disponible o NetworkManager apagado: se queda "sin red"
  }
  if (HAY_TAILSCALE) {
    try {
      const ip = (await execAsync(["tailscale", "ip", "-4"])).trim()
      if (ip) r.tailscale = ip
    } catch {
      // tailscale apagado o desconectado
    }
  }
  return r
}

const [red, setRed] = createState<EstadoRed>(SIN_RED)
let leyendoRed = false
let otraVez = false

async function refrescarRed() {
  if (leyendoRed) {
    otraVez = true
    return
  }
  leyendoRed = true
  try {
    const nuevo = await leerRed()
    if (JSON.stringify(nuevo) !== JSON.stringify(red.get())) setRed(nuevo)
  } finally {
    leyendoRed = false
    if (otraVez) {
      otraVez = false
      refrescarRed()
    }
  }
}

let monitorRed: unknown = null
function vigilarRed() {
  refrescarRed()
  setInterval(() => refrescarRed(), 20000)
  let espera: ReturnType<typeof setTimeout> | null = null
  try {
    monitorRed = subprocess(["env", "LC_ALL=", "LANGUAGE=", "LC_MESSAGES=C", "nmcli", "monitor"], () => {
      if (espera) clearTimeout(espera)
      espera = setTimeout(() => {
        espera = null
        refrescarRed()
      }, 600)
    })
  } catch {
    // sin nmcli: solo la revisión cada 20 s
  }
}

function iconoWifi(s: number): string {
  if (s >= 80) return "network-wireless-signal-excellent-symbolic"
  if (s >= 60) return "network-wireless-signal-good-symbolic"
  if (s >= 40) return "network-wireless-signal-ok-symbolic"
  if (s >= 20) return "network-wireless-signal-weak-symbolic"
  return "network-wireless-signal-none-symbolic"
}

function Red() {
  return (
    <button
      class="modulo red"
      onClicked={() => run([`${SCRIPTS}/red.sh`])}
      tooltipText={red.as((r) =>
        [
          r.cable ? "Cable: conectado" : "",
          r.wifi ? `Wi-Fi: ${r.wifi} (${r.senal}%)` : "",
          !r.cable && !r.wifi ? "Sin conexión" : "",
          r.tailscale ? `Tailscale: ${r.tailscale}` : "",
          "Clic: menú de red",
        ]
          .filter(Boolean)
          .join("\n"),
      )}
    >
      <Expandible
        clase="red-interior"
        base={
          <box spacing={8}>
            <image iconName="network-wired-symbolic" visible={red.as((r) => r.cable)} />
            <image iconName={red.as((r) => iconoWifi(r.senal))} visible={red.as((r) => !!r.wifi)} />
            <image iconName="network-offline-symbolic" visible={red.as((r) => !r.cable && !r.wifi)} />
            <image class="tailscale" iconName="network-vpn-symbolic" visible={red.as((r) => !!r.tailscale)} />
          </box>
        }
        extra={
          <label
            class="detalle"
            maxWidthChars={16}
            ellipsize={Pango.EllipsizeMode.END}
            label={red.as((r) => (r.wifi ? `${r.wifi}  ${r.senal}%` : r.cable ? "Cable" : "Sin red"))}
          />
        }
      />
    </button>
  )
}

// ── Sistema: CPU, RAM y temperatura (disco en el tooltip) ──
let cpuPrev: { total: number; idle: number } | null = null

function leerCpu(): number {
  const f = readFile("/proc/stat").split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
  const idle = f[3] + f[4]
  const total = f.reduce((a, b) => a + b, 0)
  let uso = 0
  if (cpuPrev) {
    const dt = total - cpuPrev.total
    uso = dt ? Math.round((1 - (idle - cpuPrev.idle) / dt) * 100) : 0
  }
  cpuPrev = { total, idle }
  return uso
}

function leerRam(): number {
  const m = readFile("/proc/meminfo")
  const total = Number(m.match(/MemTotal:\s+(\d+)/)?.[1] ?? 1)
  const libre = Number(m.match(/MemAvailable:\s+(\d+)/)?.[1] ?? 0)
  return Math.round(((total - libre) / total) * 100)
}

async function leerTemp(): Promise<number> {
  try {
    // temp.sh busca el sensor de la CPU (coretemp / k10temp) en vez del más caliente de todos
    const out = await execAsync([`${SCRIPTS}/temp.sh`])
    return Number(out.trim()) || 0
  } catch {
    return 0
  }
}

async function leerDisco(): Promise<string> {
  try {
    const out = await execAsync(["df", "-h", "--output=used,size,pcent", "/"])
    const [usado, total, pct] = out.trim().split("\n")[1].trim().split(/\s+/)
    return `Disco /: ${usado} de ${total} (${pct})`
  } catch {
    return "Disco: ?"
  }
}

// Una sola lectura para todos los monitores (antes cada barra medía la CPU por su cuenta
// y con dos monitores los porcentajes salían mal)
const cpu = createPoll(0, 2000, leerCpu)
const ram = createPoll(0, 2000, leerRam)
const temp = createPoll(0, 5000, leerTemp)
const disco = createPoll("", 60000, leerDisco)

const ICO_DISCO = "\uF0A0"
const discoCorto = disco.as((d) => d.match(/\((\d+%)\)/)?.[1] ?? "")

function Sistema() {
  return (
    <Expandible
      clase="modulo sistema"
      base={
        <box spacing={14} tooltipText={disco}>
          <label label={cpu.as((v) => `${ICO.cpu}  ${v}%`)} />
          {/* la temperatura alta nunca se esconde */}
          <label
            visible={temp.as((t) => t >= 80)}
            class="caliente"
            label={temp.as((t) => `${ICO.temp} ${t}°`)}
          />
        </box>
      }
      extra={
        <box spacing={14} class="detalle">
          <label label={ram.as((v) => `${ICO.ram}  ${v}%`)} />
          <label visible={temp.as((t) => t > 0 && t < 80)} label={temp.as((t) => `${ICO.temp} ${t}°`)} />
          <label visible={discoCorto.as((d) => d !== "")} label={discoCorto.as((d) => `${ICO_DISCO}  ${d}`)} />
        </box>
      }
    />
  )
}

// ── Volumen (rueda: subir/bajar · clic: slider) ──
// Sigue a la salida predeterminada: si conectas audífonos o Bluetooth, la barra cambia con ella.
function ControlVolumen({ bocina }: { bocina: AstalWp.Endpoint }) {
  const icono = createBinding(bocina, "volumeIcon")
  const nivel = createBinding(bocina, "volume")

  return (
    <menubutton class="modulo volumen" tooltipText="Rueda: subir/bajar · Clic: más opciones">
      <Gtk.EventControllerScroll
        flags={Gtk.EventControllerScrollFlags.VERTICAL}
        onScroll={(_c, _dx, dy) => {
          bocina.set_volume(Math.max(0, Math.min(1, bocina.volume - dy * 0.05)))
          return true
        }}
      />
      <box spacing={8}>
        <image iconName={icono} />
        <label label={nivel.as((v) => `${Math.round(v * 100)}%`)} />
      </box>
      <popover>
        <box class="pop-volumen" spacing={8}>
          <button onClicked={() => bocina.set_mute(!bocina.mute)} tooltipText="Silenciar">
            <image iconName={icono} />
          </button>
          <slider widthRequest={220} value={nivel} onChangeValue={({ value }) => bocina.set_volume(value)} />
        </box>
      </popover>
    </menubutton>
  )
}

function Volumen() {
  const wp = AstalWp.get_default()
  if (!wp) return <box />
  return (
    <With value={createBinding(wp, "defaultSpeaker")}>
      {(bocina: AstalWp.Endpoint | null) => (bocina ? <ControlVolumen bocina={bocina} /> : <box />)}
    </With>
  )
}

// ── Batería ──
function Bateria() {
  const bat = AstalBattery.get_default()
  const pct = createBinding(bat, "percentage")
  return (
    <box
      class={pct.as((p) => (p < 0.2 ? "modulo bateria baja" : "modulo bateria"))}
      visible={createBinding(bat, "isPresent")}
      spacing={8}
    >
      <image iconName={createBinding(bat, "batteryIconName")} />
      <label label={pct.as((p) => `${Math.round(p * 100)}%`)} />
    </box>
  )
}

// ── Bandeja del sistema ──
function Bandeja() {
  const tray = AstalTray.get_default()
  const items = createBinding(tray, "items")

  const init = (btn: Gtk.MenuButton, item: AstalTray.TrayItem) => {
    btn.menuModel = item.menuModel
    btn.insert_action_group("dbusmenu", item.actionGroup)
    item.connect("notify::action-group", () => {
      btn.insert_action_group("dbusmenu", item.actionGroup)
    })
  }

  return (
    <box class="modulo bandeja" spacing={6} visible={items.as((i) => i.length > 0)}>
      <For each={items}>
        {(item) => (
          <menubutton $={(self) => init(self, item)}>
            <image gicon={createBinding(item, "gicon")} />
          </menubutton>
        )}
      </For>
    </box>
  )
}

// ── Botones de paletas y notificaciones ──
function Paletas() {
  return (
    <button
      class="modulo boton"
      tooltipText="Clic: paleta de colores · Clic derecho: estilo de la barra"
      onClicked={() => run([`${SCRIPTS}/paleta.sh`, "menu"])}
    >
      <Gtk.GestureClick button={3} onPressed={() => run([`${SCRIPTS}/barra-estilo.sh`, "menu"])} />
      <label label={ICO.paleta} />
    </button>
  )
}

// ── Notificaciones: contador en vivo y No molestar ──
// Escucha a swaync (swaync-client -swb avisa cada cambio), así que no hace polling.
type EstadoNotis = { cuantas: number; dnd: boolean }
const [notis, setNotis] = createState<EstadoNotis>({ cuantas: 0, dnd: false })

function escucharNotis(): () => void {
  if (!GLib.find_program_in_path("swaync-client")) return () => {}
  let proc: ReturnType<typeof subprocess> | null = null
  let vivo = true

  const arrancar = () => {
    if (!vivo) return
    try {
      proc = subprocess(
        ["swaync-client", "-swb"],
        (linea) => {
          try {
            const j = JSON.parse(linea)
            setNotis({ cuantas: Number(j.text) || 0, dnd: String(j.alt ?? "").includes("dnd") })
          } catch {
            // línea que no es JSON: se ignora
          }
        },
        () => {},
      )
      // si swaync se reinicia o todavía no arrancaba, se vuelve a conectar solo
      proc.connect("exit", () => {
        proc = null
        if (vivo) setTimeout(arrancar, 3000)
      })
    } catch {
      if (vivo) setTimeout(arrancar, 10000)
    }
  }

  arrancar()
  return () => {
    vivo = false
    proc?.kill()
  }
}

function Notis() {
  const clases = notis.as((n) => {
    const c = ["modulo", "boton", "notis"]
    if (n.cuantas > 0) c.push("hay")
    if (n.dnd) c.push("dnd")
    return c.join(" ")
  })
  const tooltip = notis.as((n) => {
    const cuantas = n.cuantas === 0 ? "Sin notificaciones" : n.cuantas === 1 ? "1 notificación" : `${n.cuantas} notificaciones`
    return [cuantas, n.dnd ? "No molestar: activado" : "", "Clic: abrir el centro", "Clic derecho: No molestar"]
      .filter(Boolean)
      .join("\n")
  })

  return (
    <button class={clases} tooltipText={tooltip} onClicked={() => run(["swaync-client", "-t", "-sw"])}>
      <Gtk.GestureClick button={3} onPressed={() => run(["swaync-client", "-d", "-sw"])} />
      <box spacing={7}>
        <label label={notis.as((n) => (n.dnd ? ICO.campanaOff : ICO.campana))} />
        <label
          class="contador"
          visible={notis.as((n) => n.cuantas > 0)}
          label={notis.as((n) => (n.cuantas > 99 ? "99+" : `${n.cuantas}`))}
        />
      </box>
    </button>
  )
}

// ── Menú de energía (apagar/reiniciar/salir piden doble clic para no hacerlo sin querer) ──
function Energia() {
  let boton: Gtk.MenuButton
  const [confirmar, setConfirmar] = createState("")

  const opcion = (id: string, icono: string, texto: string, cmd: string[], peligrosa: boolean) => (
    <button
      class={confirmar.as((c) => (c === id ? "opcion confirmar" : "opcion"))}
      onClicked={() => {
        if (peligrosa && confirmar.get() !== id) {
          setConfirmar(id)
          setTimeout(() => confirmar.get() === id && setConfirmar(""), 3000)
          return
        }
        setConfirmar("")
        boton.popdown()
        run(cmd)
      }}
    >
      <box spacing={12}>
        <label class="icono" label={icono} />
        <label label={confirmar.as((c) => (c === id ? "¿Seguro? Clic otra vez" : texto))} />
      </box>
    </button>
  )

  return (
    <menubutton $={(self) => (boton = self)} class="modulo energia" tooltipText="Energía">
      <label label={ICO.power} />
      <popover>
        <box class="pop-energia" orientation={Gtk.Orientation.VERTICAL} spacing={4}>
          {opcion("bloquear", ICO.candado, "Bloquear", ["bash", "-c", "if command -v hyprlock >/dev/null; then ~/.config/hypr/scripts/zero-lock.sh lock; else loginctl lock-session; fi"], false)}
          {opcion("suspender", ICO.luna, "Suspender", ["systemctl", "suspend"], false)}
          {opcion("salir", ICO.salir, "Cerrar sesión", ["hyprctl", "dispatch", "hl.dsp.exit()"], true)}
          {opcion("reiniciar", ICO.reiniciar, "Reiniciar", ["systemctl", "reboot"], true)}
          {opcion("apagar", ICO.power, "Apagar", ["systemctl", "poweroff"], true)}
        </box>
      </popover>
    </menubutton>
  )
}

// ── OSD de volumen y brillo ──
// No necesita atajos propios: reacciona a cualquier cambio (teclas, rueda en la barra, pavucontrol...).
type DatoOSD = { icono: string; valor: number; texto: string; apagado: boolean }
const [osd, setOsd] = createState<DatoOSD>({ icono: "audio-volume-high-symbolic", valor: 0, texto: "", apagado: false })
const [osdVisible, setOsdVisible] = createState(false)
let osdTimer: ReturnType<typeof setTimeout> | null = null
let osdListo = false // mientras la barra arranca no se muestra nada

function mostrarOSD(d: DatoOSD) {
  if (!osdListo) return
  setOsd(d)
  setOsdVisible(true)
  if (osdTimer) clearTimeout(osdTimer)
  osdTimer = setTimeout(() => {
    osdTimer = null
    setOsdVisible(false)
  }, 1500)
}

function vigilarVolumen() {
  const wp = AstalWp.get_default()
  if (!wp) return
  // se reconecta cuando cambias de salida (audífonos, Bluetooth), igual que el módulo de volumen
  let actual: AstalWp.Endpoint | null = null
  let ids: number[] = []
  const conectarBocina = () => {
    const anterior = actual
    if (anterior) ids.forEach((id) => anterior.disconnect(id))
    ids = []
    actual = wp.defaultSpeaker
    const bocina = actual
    if (!bocina) return
    const verBocina = () =>
      mostrarOSD({
        icono: bocina.volumeIcon,
        valor: bocina.mute ? 0 : Math.min(1, bocina.volume),
        texto: bocina.mute ? "Silencio" : `${Math.round(bocina.volume * 100)}%`,
        apagado: bocina.mute,
      })
    ids = [bocina.connect("notify::volume", verBocina), bocina.connect("notify::mute", verBocina)]
  }
  conectarBocina()
  wp.connect("notify::default-speaker", conectarBocina)

  const mic = wp.defaultMicrophone
  if (mic) {
    mic.connect("notify::mute", () =>
      mostrarOSD({
        icono: mic.mute ? "microphone-sensitivity-muted-symbolic" : "audio-input-microphone-symbolic",
        valor: mic.mute ? 0 : Math.min(1, mic.volume),
        texto: mic.mute ? "Mic apagado" : "Mic activo",
        apagado: mic.mute,
      }),
    )
  }
}

const monitoresBrillo: Gio.FileMonitor[] = [] // se guardan para que no se los lleve el recolector de basura

function vigilarBrillo() {
  const base = "/sys/class/backlight"
  const pantallas: string[] = []
  try {
    const lista = Gio.File.new_for_path(base).enumerate_children("standard::name", Gio.FileQueryInfoFlags.NONE, null)
    let info: Gio.FileInfo | null
    while ((info = lista.next_file(null))) pantallas.push(info.get_name())
  } catch {
    return // PC de escritorio: no hay brillo que mostrar
  }

  for (const nombre of pantallas) {
    const dir = `${base}/${nombre}`
    const leer = () => {
      try {
        const max = Number(readFile(`${dir}/max_brightness`)) || 1
        return Math.round((Number(readFile(`${dir}/brightness`)) / max) * 100)
      } catch {
        return -1
      }
    }
    let ultimo = leer()
    monitoresBrillo.push(
      monitorFile(`${dir}/brightness`, () => {
        const v = leer()
        if (v < 0 || v === ultimo) return
        ultimo = v
        mostrarOSD({ icono: "display-brightness-symbolic", valor: v / 100, texto: `${v}%`, apagado: false })
      }),
    )
  }
}

function OSD({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  let win: Astal.Window
  onCleanup(() => win.destroy())

  // solo aparece en el monitor donde estás trabajando
  const aqui = createBinding(hypr, "focusedMonitor").as((m) => !m || m.name === gdkmonitor.connector)
  const visible = createComputed(() => osdVisible() && aqui())

  return (
    <window
      $={(self) => (win = self)}
      visible={visible}
      namespace="osd-zero"
      name={`osd-${gdkmonitor.connector}`}
      class="osd"
      gdkmonitor={gdkmonitor}
      layer={Astal.Layer.OVERLAY}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.NONE}
      anchor={Astal.WindowAnchor.BOTTOM}
      marginBottom={110}
      application={app}
    >
      <box class={osd.as((d) => (d.apagado ? "osd-caja apagado" : "osd-caja"))} spacing={14}>
        <image iconName={osd.as((d) => d.icono)} pixelSize={20} />
        <levelbar
          $={(self) => ["low", "high", "full"].forEach((o) => self.remove_offset_value(o))}
          valign={Gtk.Align.CENTER}
          widthRequest={200}
          minValue={0}
          maxValue={1}
          value={osd.as((d) => d.valor)}
        />
        <label class="osd-texto" widthChars={4} xalign={1} label={osd.as((d) => d.texto)} />
      </box>
    </window>
  )
}

// ── La barra ──
function Barra({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  let win: Astal.Window
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor

  onCleanup(() => win.destroy())

  return (
    <window
      $={(self) => (win = self)}
      visible
      namespace="barra-zero"
      name={`barra-${gdkmonitor.connector}`}
      class={esRoot.as((r) => (r ? "barra modo-root" : "barra"))}
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={TOP | LEFT | RIGHT}
      application={app}
    >
      <centerbox class="contenedor">
        <box $type="start" spacing={8}>
          <Lanzador />
          <Usuario />
          <Workspaces />
          <Titulo />
        </box>
        <box $type="center" spacing={8}>
          <Reloj />
          <Musica />
        </box>
        <box $type="end" spacing={8}>
          <Bandeja />
          <Red />
          <Sistema />
          <Volumen />
          <Bateria />
          <Paletas />
          <Notis />
          <Energia />
        </box>
      </centerbox>
    </window>
  )
}

app.start({
  css: cssCompleto(),
  requestHandler: atenderPedido, // ws3d.sh → "ags request ws 3"
  gtkTheme: "Adwaita",
  main() {
    vigilarColores()
    vigilarRed()
    revisarRoot()
    vigilarPerfil()
    const pararNotis = escucharNotis()
    app.connect("shutdown", pararNotis)
    vigilarVolumen()
    vigilarBrillo()
    iniciarCava()
    setTimeout(() => (osdListo = true), 2000)

    const monitores = createBinding(app, "monitors")
    return (
      <For each={monitores}>
        {(monitor) => (
          <This this={app}>
            <Barra gdkmonitor={monitor} />
            <OSD gdkmonitor={monitor} />
            <CapaWs3D gdkmonitor={monitor} />
          </This>
        )}
      </For>
    )
  },
})
