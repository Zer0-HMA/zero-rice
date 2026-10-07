// Barra v2 para AGS v3 (GTK4) — zr0_humber_
// Los colores salen de colores.css (lo genera paleta.sh); la forma, de style.css
import app from "ags/gtk4/app"
import GLib from "gi://GLib"
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
import { execAsync } from "ags/process"
import { readFile } from "ags/file"
import colores from "./colores.css"
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
  power: "\uF011",
  candado: "\uF023",
  luna: "\uF186",
  salir: "\uF08B",
  reiniciar: "\uF01E",
}

const HOME = GLib.get_home_dir()
const USUARIO = GLib.get_user_name()
const HOST = GLib.get_host_name()

const run = (cmd: string[]) => execAsync(cmd).catch(() => {})
const hypr = AstalHyprland.get_default()

// Hyprland con config en Lua usa dispatchers de Lua (el "dispatch workspace 3" viejo ya no jala)
const irAWorkspace = (id: number) => run(["hyprctl", "dispatch", `hl.dsp.focus({ workspace = ${id} })`])

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

const esRoot =
  USUARIO === "root"
    ? createPoll(true, 60000, () => true)
    : createPoll(false, 1500, async () => {
        const pid = hypr.focusedClient?.pid
        if (!pid) return false
        try {
          const out = await execAsync(["bash", "-c", SCRIPT_ROOT, "root-check", String(pid)])
          return out.trim() === "1"
        } catch {
          return false
        }
      })

// ── Lanzador ──
function Lanzador() {
  return (
    <button class="modulo lanzador" tooltipText="Aplicaciones" onClicked={() => run([`${HOME}/.config/hypr/scripts/lanzador.sh`])}>
      <label label={ICO.arch} />
    </button>
  )
}

// ── Usuario (se pone blanco cuando eres root) ──
function leerUptime(): string {
  const seg = Math.floor(Number(readFile("/proc/uptime").split(" ")[0]))
  const h = Math.floor(seg / 3600)
  const m = Math.floor((seg % 3600) / 60)
  return h > 0 ? `${h} h ${m} min` : `${m} min`
}

function Usuario() {
  const uptime = createPoll("", 60000, leerUptime)
  return (
    <box
      class={esRoot.as((r) => (r ? "modulo usuario es-root" : "modulo usuario"))}
      spacing={8}
      tooltipText={uptime.as((u) => `${USUARIO}@${HOST}\nEncendida hace ${u}`)}
    >
      <label class="icono" label={esRoot.as((r) => (r ? ICO.root : ICO.usuario))} />
      <label label={esRoot.as((r) => (r ? "root" : USUARIO))} />
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
          run(["hyprctl", "dispatch", `hl.dsp.focus({ workspace = "${dy > 0 ? "e+1" : "e-1"}" })`])
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
function Reloj() {
  const hora = createPoll("", 1000, () => GLib.DateTime.new_now_local().format("%a %d %b   %H:%M")!)
  return (
    <menubutton class="modulo reloj">
      <box spacing={8}>
        <label class="icono" label={ICO.reloj} />
        <label label={hora} />
      </box>
      <popover>
        <Gtk.Calendar />
      </popover>
    </menubutton>
  )
}

// ── Música (aparece solo si algo está sonando: Spotify, YouTube en el navegador, etc.) ──
function Musica() {
  const mpris = AstalMpris.get_default()
  const players = createBinding(mpris, "players")

  return (
    <box class="modulo musica" visible={players.as((p) => p.length > 0)}>
      <With value={players.as((p) => p[0])}>
        {(p: AstalMpris.Player | undefined) => {
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
// Se lee con nmcli: la librería de red de Astal tronaba la barra al conectarse a redes ocultas
type EstadoRed = { cable: boolean; wifi: string; senal: number }
const SIN_RED: EstadoRed = { cable: false, wifi: "", senal: 0 }
const nm = (...args: string[]) => execAsync(["env", "LC_ALL=", "LANGUAGE=", "LC_MESSAGES=C", "nmcli", ...args])

async function leerRed(): Promise<string> {
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
  return JSON.stringify(r)
}

function iconoWifi(s: number): string {
  if (s >= 80) return "network-wireless-signal-excellent-symbolic"
  if (s >= 60) return "network-wireless-signal-good-symbolic"
  if (s >= 40) return "network-wireless-signal-ok-symbolic"
  if (s >= 20) return "network-wireless-signal-weak-symbolic"
  return "network-wireless-signal-none-symbolic"
}

function Red() {
  const red = createPoll(JSON.stringify(SIN_RED), 4000, leerRed).as((j) => JSON.parse(j) as EstadoRed)

  return (
    <button
      class="modulo red"
      onClicked={() => run([`${HOME}/.config/hypr/scripts/red.sh`])}
      tooltipText={red.as((r) =>
        [
          r.cable ? "Cable: conectado" : "",
          r.wifi ? `Wi-Fi: ${r.wifi} (${r.senal}%)` : "",
          !r.cable && !r.wifi ? "Sin conexión" : "",
          "Clic: menú de red",
        ]
          .filter(Boolean)
          .join("\n"),
      )}
    >
      <box spacing={8}>
        <image iconName="network-wired-symbolic" visible={red.as((r) => r.cable)} />
        <image iconName={red.as((r) => iconoWifi(r.senal))} visible={red.as((r) => !!r.wifi)} />
        <image iconName="network-offline-symbolic" visible={red.as((r) => !r.cable && !r.wifi)} />
        <label
          maxWidthChars={14}
          ellipsize={Pango.EllipsizeMode.END}
          label={red.as((r) => r.wifi || (r.cable ? "Cable" : "Sin red"))}
        />
      </box>
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
    const out = await execAsync(["bash", "-c", "cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1"])
    return Math.round(Number(out.trim()) / 1000) || 0
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

function Sistema() {
  const cpu = createPoll(0, 2000, leerCpu)
  const ram = createPoll(0, 2000, leerRam)
  const temp = createPoll(0, 5000, leerTemp)
  const disco = createPoll("", 60000, leerDisco)

  return (
    <box class="modulo sistema" spacing={14} tooltipText={disco}>
      <label label={cpu.as((v) => `${ICO.cpu}  ${v}%`)} />
      <label label={ram.as((v) => `${ICO.ram}  ${v}%`)} />
      <label
        visible={temp.as((t) => t > 0)}
        class={temp.as((t) => (t >= 80 ? "caliente" : ""))}
        label={temp.as((t) => `${ICO.temp} ${t}°`)}
      />
    </box>
  )
}

// ── Volumen (rueda: subir/bajar · clic: slider) ──
function Volumen() {
  const wp = AstalWp.get_default()
  if (!wp) return <box />
  const bocina = wp.defaultSpeaker
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
      tooltipText="Cambiar paleta de colores"
      onClicked={() => run([`${HOME}/.config/hypr/scripts/paleta.sh`, "menu"])}
    >
      <label label={ICO.paleta} />
    </button>
  )
}

function Notis() {
  return (
    <button class="modulo boton" tooltipText="Notificaciones" onClicked={() => run(["swaync-client", "-t", "-sw"])}>
      <label label={ICO.campana} />
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
          {opcion("bloquear", ICO.candado, "Bloquear", ["bash", "-c", "command -v hyprlock >/dev/null && hyprlock || loginctl lock-session"], false)}
          {opcion("suspender", ICO.luna, "Suspender", ["systemctl", "suspend"], false)}
          {opcion("salir", ICO.salir, "Cerrar sesión", ["hyprctl", "dispatch", "hl.dsp.exit()"], true)}
          {opcion("reiniciar", ICO.reiniciar, "Reiniciar", ["systemctl", "reboot"], true)}
          {opcion("apagar", ICO.power, "Apagar", ["systemctl", "poweroff"], true)}
        </box>
      </popover>
    </menubutton>
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
  css: colores + estilo,
  gtkTheme: "Adwaita",
  main() {
    const monitores = createBinding(app, "monitors")
    return (
      <For each={monitores}>
        {(monitor) => (
          <This this={app}>
            <Barra gdkmonitor={monitor} />
          </This>
        )}
      </For>
    )
  },
})
