// Panel de control — se despliega desde la barra (botón de ajustes, Super + A o "ags request panel")
// Botones rápidos, volumen y brillo, música, calendario y accesos a los menús del rice.
// Vive en su propio archivo: lo que necesita de la barra (perfil, red, notificaciones, música)
// se lo pasa app.tsx con configurarPanel(), así no hay imports circulares.
import app from "ags/gtk4/app"
import GLib from "gi://GLib"
import Gio from "gi://Gio"
import Pango from "gi://Pango"
import Astal from "gi://Astal?version=4.0"
import Gtk from "gi://Gtk?version=4.0"
import Gdk from "gi://Gdk?version=4.0"
import AstalHyprland from "gi://AstalHyprland"
import AstalWp from "gi://AstalWp"
import AstalMpris from "gi://AstalMpris"
import { With, createBinding, createComputed, createState, onCleanup } from "ags"
import { execAsync } from "ags/process"
import { readFile } from "ags/file"

// ── Lo que el panel toma de la barra ──
type Contexto = {
  avatar: any // Accessor<Gdk.Texture | null>
  nombre: any // Accessor<string>
  notis: any // Accessor<{ cuantas: number; dnd: boolean }>
  red: any // Accessor<{ cable: boolean; wifi: string; senal: number; tailscale: string }>
  refrescarRed: () => void
  reproductor: any // Accessor<AstalMpris.Player | null>
  scripts: string
}
let ctx: Contexto
export function configurarPanel(c: Contexto) {
  ctx = c
}

const ICO = {
  wifi: "\uF1EB",
  bt: "\uF293",
  dnd: "\uF1F6",
  luna: "\uF186",
  mic: "\uF130",
  micOff: "\uF131",
  escudo: "\uF132",
  vol: "\uF028",
  sol: "\uF185",
  candado: "\uF023",
  paleta: "\u{F03D8}",
  barra: "\uF0C9",
  fondo: "\uF03E",
  magia: "\uF0D0",
  camara: "\uF030",
  clip: "\uF0EA",
  ant: "\uF048",
  play: "\uF04B",
  pausa: "\uF04C",
  sig: "\uF051",
  musica: "\uF001",
  calendario: "\uF073",
  abajo: "\uF078",
  arriba: "\uF077",
}

const run = (cmd: string[]) => execAsync(cmd).catch(() => "")
const hay = (prog: string) => GLib.find_program_in_path(prog) !== null
const hypr = AstalHyprland.get_default()

// ── Abrir y cerrar ──
// Una ventana por monitor; se muestra solo la del monitor donde está tu mouse/foco.
const [panelEn, setPanelEn] = createState("") // conector del monitor ("" = cerrado)
const [desplegado, setDesplegado] = createState(false)
const conectores: string[] = []
const DURACION = 260

export function abrirPanel() {
  let m = hypr.focusedMonitor?.name ?? ""
  if (!conectores.includes(m)) m = conectores[0] ?? ""
  if (!m) return
  setPanelEn(m)
  refrescarEstados()
  setTimeout(() => setDesplegado(true), 16)
}

export function cerrarPanel() {
  setDesplegado(false)
  setTimeout(() => {
    if (!desplegado.get()) setPanelEn("")
  }, DURACION + 20)
}

export function alternarPanel() {
  if (panelEn.get() && desplegado.get()) cerrarPanel()
  else abrirPanel()
}

// Cierra el panel y luego corre algo (para que el panel no salga en una captura, ni tape un menú)
function yLuego(cmd: string[], espera = 0) {
  cerrarPanel()
  setTimeout(() => run(cmd), espera || DURACION)
}

// ── Estados de los botones rápidos (se leen al abrir y después de cada clic) ──
const [wifiOn, setWifiOn] = createState(false)
const [hayWifi, setHayWifi] = createState(false)
const [nocturna, setNocturna] = createState(false)
const [micMudo, setMicMudo] = createState(false)
const [btOn, setBtOn] = createState(false)
const [btTexto, setBtTexto] = createState("")
const [hayBt, setHayBt] = createState(false)
const [brillo, setBrillo] = createState(-1) // -1 = sin pantalla con brillo (PC de escritorio)

const HAY_NMCLI = hay("nmcli")
const HAY_SUNSET = hay("hyprsunset")
const HAY_TAILSCALE = hay("tailscale")
const nm = (...a: string[]) => execAsync(["env", "LC_ALL=C", "nmcli", ...a])

async function leerWifi() {
  if (!HAY_NMCLI) return
  try {
    const tipos = await nm("-t", "-f", "TYPE", "device")
    setHayWifi(tipos.split("\n").includes("wifi"))
    setWifiOn((await nm("radio", "wifi")).trim() === "enabled")
  } catch {
    setHayWifi(false)
  }
}

async function leerNocturna() {
  if (!HAY_SUNSET) return
  try {
    await execAsync(["pgrep", "-x", "hyprsunset"])
    setNocturna(true)
  } catch {
    setNocturna(false)
  }
}

function microfono(): AstalWp.Endpoint | null {
  return AstalWp.get_default()?.defaultMicrophone ?? null
}
function leerMic() {
  setMicMudo(microfono()?.mute ?? false)
}

// Bluetooth con AstalBluetooth, cargado la primera vez que abres el panel (import dinámico):
// la barra nunca espera al bluetooth al arrancar, y si no está la librería, el botón no aparece.
let bt: any = null
let btIntentado = false
async function iniciarBt() {
  if (btIntentado) return
  btIntentado = true
  try {
    // @ts-ignore: los tipos de AstalBluetooth pueden no estar generados
    const modulo = await import("gi://AstalBluetooth")
    const AstalBluetooth = modulo.default ?? modulo
    bt = AstalBluetooth.get_default()
    if (!bt) return
    for (const p of ["notify::is-powered", "notify::is-connected", "notify::adapter"]) bt.connect(p, leerBt)
  } catch (e) {
    console.log(`Panel sin bluetooth (AstalBluetooth no disponible): ${e}`)
  }
}
function leerBt() {
  if (!bt || !bt.adapter) {
    setHayBt(false)
    return
  }
  setHayBt(true)
  setBtOn(!!bt.isPowered)
  const conectado = (bt.devices ?? []).find((d: any) => d.connected)
  setBtTexto(conectado ? conectado.alias || conectado.name : bt.isPowered ? "Encendido" : "Apagado")
}

const BACKLIGHT = "/sys/class/backlight"
function pantallaBrillo(): string | null {
  try {
    const lista = Gio.File.new_for_path(BACKLIGHT).enumerate_children("standard::name", Gio.FileQueryInfoFlags.NONE, null)
    const info = lista.next_file(null)
    return info ? `${BACKLIGHT}/${info.get_name()}` : null
  } catch {
    return null
  }
}
function leerBrillo() {
  const dir = pantallaBrillo()
  if (!dir || !hay("brightnessctl")) return setBrillo(-1)
  try {
    const max = Number(readFile(`${dir}/max_brightness`)) || 1
    setBrillo(Number(readFile(`${dir}/brightness`)) / max)
  } catch {
    setBrillo(-1)
  }
}

async function refrescarEstados() {
  setUptime(leerUptime())
  setFecha(leerFecha())
  leerMic()
  leerBrillo()
  leerWifi()
  leerNocturna()
  await iniciarBt()
  leerBt()
  ctx?.refrescarRed()
}

// el brillo se manda con un respiro, para no lanzar cien brightnessctl al arrastrar
let esperaBrillo: ReturnType<typeof setTimeout> | null = null
function ponerBrillo(v: number) {
  setBrillo(v)
  if (esperaBrillo) clearTimeout(esperaBrillo)
  esperaBrillo = setTimeout(() => {
    esperaBrillo = null
    run(["brightnessctl", "-q", "set", `${Math.max(1, Math.round(v * 100))}%`])
  }, 60)
}

function leerUptime(): string {
  try {
    const seg = Math.floor(Number(readFile("/proc/uptime").split(" ")[0]))
    const h = Math.floor(seg / 3600)
    const m = Math.floor((seg % 3600) / 60)
    return h > 0 ? `Encendida hace ${h} h ${m} min` : `Encendida hace ${m} min`
  } catch {
    return ""
  }
}
const [uptime, setUptime] = createState(leerUptime())
const leerFecha = () => GLib.DateTime.new_now_local().format("%A %d %B")!
const [fecha, setFecha] = createState(leerFecha())
const [verCalendario, setVerCalendario] = createState(false)

// ── Piezas ──
function Rapido(p: {
  icono: any
  titulo: string
  sub: any
  activo: any
  visible?: any
  onClicked: () => void
}) {
  return (
    <button
      class={p.activo.as((a: boolean) => (a ? "rapido activo" : "rapido"))}
      visible={p.visible ?? true}
      hexpand
      onClicked={p.onClicked}
    >
      <box spacing={10}>
        <label class="rapido-icono" label={p.icono} />
        <box orientation={Gtk.Orientation.VERTICAL} valign={Gtk.Align.CENTER}>
          <label class="rapido-titulo" xalign={0} label={p.titulo} />
          <label class="rapido-sub" xalign={0} maxWidthChars={13} ellipsize={Pango.EllipsizeMode.END} label={p.sub} />
        </box>
      </box>
    </button>
  )
}

function Cabecera() {
  return (
    <box class="panel-cabecera" spacing={12}>
      <image class="panel-avatar" paintable={ctx.avatar} pixelSize={44} visible={ctx.avatar.as((a: any) => a !== null)} />
      <box orientation={Gtk.Orientation.VERTICAL} valign={Gtk.Align.CENTER} hexpand>
        <label class="panel-nombre" xalign={0} label={ctx.nombre} />
        <label class="panel-uptime" xalign={0} label={uptime} />
      </box>
      <button
        class="panel-circulo"
        tooltipText="Bloquear"
        onClicked={() => yLuego([`${ctx.scripts}/zero-lock.sh`, "lock"])}
      >
        <label label={ICO.candado} />
      </button>
    </box>
  )
}

function Rapidos() {
  const red = ctx.red
  const subWifi = createComputed(() => {
    const r = red()
    return r.wifi ? r.wifi : wifiOn() ? "Sin conectar" : "Apagado"
  })
  return (
    <box class="panel-rapidos" orientation={Gtk.Orientation.VERTICAL} spacing={8}>
      <box spacing={8} homogeneous>
        <Rapido
          icono={ICO.wifi}
          titulo="Wi-Fi"
          visible={hayWifi}
          activo={wifiOn}
          sub={subWifi}
          onClicked={async () => {
            await run(["nmcli", "radio", "wifi", wifiOn.get() ? "off" : "on"])
            leerWifi()
            setTimeout(() => ctx.refrescarRed(), 1500)
          }}
        />
        <Rapido
          icono={ICO.bt}
          titulo="Bluetooth"
          visible={hayBt}
          activo={btOn}
          sub={btTexto}
          onClicked={() => {
            try {
              bt?.toggle()
            } catch {}
            setTimeout(leerBt, 400)
          }}
        />
      </box>
      <box spacing={8} homogeneous>
        <Rapido
          icono={ICO.dnd}
          titulo="No molestar"
          activo={ctx.notis.as((n: any) => n.dnd)}
          sub={ctx.notis.as((n: any) => (n.dnd ? "Activado" : n.cuantas ? `${n.cuantas} pendientes` : "Desactivado"))}
          onClicked={() => run(["swaync-client", "-d", "-sw"])}
        />
        <Rapido
          icono={micMudo.as((m: boolean) => (m ? ICO.micOff : ICO.mic))}
          titulo="Micrófono"
          activo={micMudo.as((m: boolean) => !m)}
          sub={micMudo.as((m: boolean) => (m ? "Silenciado" : "Activo"))}
          onClicked={() => {
            const mic = microfono()
            if (mic) mic.set_mute(!mic.mute)
            setTimeout(leerMic, 100)
          }}
        />
      </box>
      <box spacing={8} homogeneous>
        <Rapido
          icono={ICO.luna}
          titulo="Luz nocturna"
          visible={HAY_SUNSET}
          activo={nocturna}
          sub={nocturna.as((n: boolean) => (n ? "Cálida (4500 K)" : "Apagada"))}
          onClicked={async () => {
            if (nocturna.get()) await run(["pkill", "-x", "hyprsunset"])
            else await run(["bash", "-c", "setsid -f hyprsunset -t 4500 >/dev/null 2>&1"])
            setTimeout(leerNocturna, 300)
          }}
        />
        <Rapido
          icono={ICO.escudo}
          titulo="Tailscale"
          visible={HAY_TAILSCALE}
          activo={red.as((r: any) => !!r.tailscale)}
          sub={red.as((r: any) => r.tailscale || "Desconectado")}
          onClicked={() => {
            run([`${ctx.scripts}/red.sh`, "tailscale"]).then(() => ctx.refrescarRed())
          }}
        />
      </box>
    </box>
  )
}

function Deslizadores() {
  const wp = AstalWp.get_default()
  return (
    <box class="panel-tarjeta panel-deslizadores" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
      {wp ? (
        <With value={createBinding(wp, "defaultSpeaker")}>
          {(bocina: AstalWp.Endpoint | null) =>
            bocina ? (
              <box spacing={12}>
                <button class="panel-mini" tooltipText="Silenciar" onClicked={() => bocina.set_mute(!bocina.mute)}>
                  <image iconName={createBinding(bocina, "volumeIcon")} />
                </button>
                <slider hexpand value={createBinding(bocina, "volume")} onChangeValue={({ value }) => bocina.set_volume(value)} />
                <label
                  class="panel-valor"
                  widthChars={4}
                  xalign={1}
                  label={createBinding(bocina, "volume").as((v: number) => `${Math.round(v * 100)}%`)}
                />
              </box>
            ) : (
              <box />
            )
          }
        </With>
      ) : (
        <box />
      )}
      <box spacing={12} visible={brillo.as((b: number) => b >= 0)}>
        <label class="panel-mini icono-brillo" label={ICO.sol} />
        <slider hexpand value={brillo.as((b: number) => Math.max(0, b))} onChangeValue={({ value }) => ponerBrillo(value)} />
        <label class="panel-valor" widthChars={4} xalign={1} label={brillo.as((b: number) => `${Math.round(Math.max(0, b) * 100)}%`)} />
      </box>
    </box>
  )
}

function fmtTiempo(s: number): string {
  if (!(s > 0)) return "0:00"
  const m = Math.floor(s / 60)
  return `${m}:${String(Math.floor(s % 60)).padStart(2, "0")}`
}

function Musica() {
  return (
    <box class="panel-tarjeta panel-musica" visible={ctx.reproductor.as((p: any) => p !== null)}>
      <With value={ctx.reproductor}>
        {(p: AstalMpris.Player | null) => {
          if (!p) return <box />
          const portada = createBinding(p, "coverArt")
          const estado = createBinding(p, "playbackStatus")
          const posicion = createBinding(p, "position")
          const largo = createBinding(p, "length")
          return (
            <box spacing={14} hexpand>
              <box class="panel-portada" overflow={Gtk.Overflow.HIDDEN} valign={Gtk.Align.CENTER}>
                <image
                  pixelSize={64}
                  visible={portada.as((c: string) => !!c)}
                  file={portada.as((c: string) => c || "")}
                />
                <label class="panel-sin-portada" label={ICO.musica} visible={portada.as((c: string) => !c)} />
              </box>
              <box orientation={Gtk.Orientation.VERTICAL} spacing={4} hexpand valign={Gtk.Align.CENTER}>
                <label class="panel-cancion" xalign={0} maxWidthChars={24} ellipsize={Pango.EllipsizeMode.END} label={createBinding(p, "title").as((t: string) => t || p.identity)} />
                <label class="panel-artista" xalign={0} maxWidthChars={26} ellipsize={Pango.EllipsizeMode.END} label={createBinding(p, "artist").as((a: string) => a || "")} />
                <box spacing={6}>
                  <button class="panel-mini" onClicked={() => p.previous()}>
                    <label label={ICO.ant} />
                  </button>
                  <button class="panel-mini panel-play" onClicked={() => p.play_pause()}>
                    <label label={estado.as((s: any) => (s === AstalMpris.PlaybackStatus.PLAYING ? ICO.pausa : ICO.play))} />
                  </button>
                  <button class="panel-mini" onClicked={() => p.next()}>
                    <label label={ICO.sig} />
                  </button>
                  <label class="panel-tiempo" hexpand xalign={1} label={posicion.as((s: number) => `${fmtTiempo(s)} / ${fmtTiempo(p.length)}`)} />
                </box>
                <slider
                  class="panel-progreso"
                  visible={largo.as((l: number) => l > 0)}
                  value={posicion.as((s: number) => (p.length > 0 ? Math.min(1, s / p.length) : 0))}
                  onChangeValue={({ value }) => {
                    if (p.length > 0) p.set_position(value * p.length)
                  }}
                />
              </box>
            </box>
          )
        }}
      </With>
    </box>
  )
}

function Accesos() {
  const acceso = (icono: string, texto: string, cmd: string[], espera = 0) => (
    <button class="panel-acceso" hexpand tooltipText={texto} onClicked={() => yLuego(cmd, espera)}>
      <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
        <label class="panel-acceso-icono" label={icono} />
        <label class="panel-acceso-texto" label={texto} />
      </box>
    </button>
  )
  const s = ctx.scripts
  return (
    <box class="panel-accesos" spacing={6} homogeneous>
      {acceso(ICO.paleta, "Paleta", [`${s}/paleta.sh`, "menu"])}
      {acceso(ICO.barra, "Barra", [`${s}/barra-estilo.sh`, "menu"])}
      {acceso(ICO.fondo, "Fondo", [`${s}/wall.sh`, "menu"])}
      {acceso(ICO.magia, "Animación", [`${s}/animaciones.sh`, "menu"])}
      {acceso(ICO.camara, "Captura", [`${s}/captura.sh`, "area"], 450)}
      {acceso(ICO.clip, "Copiado", [`${s}/portapapeles.sh`])}
    </box>
  )
}

// Calendario plegable: una fila con la fecha; al tocarla se despliega (así el panel cabe en pantallas bajas)
function Calendario() {
  return (
    <box class="panel-tarjeta panel-calendario" orientation={Gtk.Orientation.VERTICAL}>
      <button class="panel-fecha" onClicked={() => setVerCalendario(!verCalendario.get())}>
        <box spacing={10}>
          <label class="panel-mini" label={ICO.calendario} />
          <label hexpand xalign={0} label={fecha} />
          <label class="panel-flecha" label={verCalendario.as((v: boolean) => (v ? ICO.arriba : ICO.abajo))} />
        </box>
      </button>
      <revealer
        revealChild={verCalendario}
        transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
        transitionDuration={220}
      >
        <Gtk.Calendar hexpand />
      </revealer>
    </box>
  )
}

// ── La ventana ──
export function PanelControl({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  let win: Astal.Window
  const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor
  const conector = gdkmonitor.connector
  if (!conectores.includes(conector)) conectores.push(conector)
  const reloj = setInterval(() => panelEn.get() && setUptime(leerUptime()), 60000)

  onCleanup(() => {
    clearInterval(reloj)
    const i = conectores.indexOf(conector)
    if (i >= 0) conectores.splice(i, 1)
    win.destroy()
  })

  return (
    <window
      $={(self) => (win = self)}
      visible={panelEn.as((m) => m === conector)}
      namespace="zero-panel"
      name={`panel-${conector}`}
      class="panel-ventana"
      gdkmonitor={gdkmonitor}
      layer={Astal.Layer.TOP}
      keymode={Astal.Keymode.ON_DEMAND}
      anchor={TOP | BOTTOM | LEFT | RIGHT}
      application={app}
    >
      <Gtk.EventControllerKey
        onKeyPressed={(_c, tecla) => {
          if (tecla === Gdk.KEY_Escape) {
            cerrarPanel()
            return true
          }
          return false
        }}
      />
      <overlay>
        {/* clic fuera del panel = cerrarlo */}
        <box class={desplegado.as((d) => (d ? "panel-fondo visible" : "panel-fondo"))} hexpand vexpand>
          <Gtk.GestureClick onPressed={() => cerrarPanel()} />
        </box>
        <revealer
          $type="overlay"
          halign={Gtk.Align.END}
          valign={Gtk.Align.START}
          revealChild={desplegado}
          transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
          transitionDuration={DURACION}
        >
          <box class="panel" widthRequest={380}>
            <Gtk.ScrolledWindow
              hscrollbarPolicy={Gtk.PolicyType.NEVER}
              propagateNaturalHeight
              maxContentHeight={Math.max(300, gdkmonitor.get_geometry().height - 110)}
              hexpand
            >
              <box orientation={Gtk.Orientation.VERTICAL} spacing={12}>
            <Cabecera />
            <Rapidos />
            <Deslizadores />
            <Musica />
            <Calendario />
            <Accesos />
              </box>
            </Gtk.ScrolledWindow>
          </box>
        </revealer>
      </overlay>
    </window>
  )
}

// "ags request panel [abrir|cerrar]"  (lo usa Super + A)
export function atenderPanel(argv: string[], responder: (r: string) => void): boolean {
  if (argv[0] !== "panel") return false
  responder("ok")
  if (argv[1] === "abrir") abrirPanel()
  else if (argv[1] === "cerrar") cerrarPanel()
  else alternarPanel()
  return true
}
