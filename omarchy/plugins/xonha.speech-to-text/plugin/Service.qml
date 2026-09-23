import QtQuick
import Quickshell
import Quickshell.Io

// Headless service: runs the speech-to-text daemon (daemon/sttd.py), restarts
// it if it dies, and keeps one control connection to it. The bar widget reads
// everything from here and sends every action through here.
Item {
  id: root

  property var shell: null
  property var manifest: null

  // ---- daemon state (mirrors the JSON the daemon pushes) ----
  property var state: ({})
  readonly property bool connected: sockConnected
  readonly property string status: state.state || "idle"       // idle | recording | transcribing
  readonly property bool recording: status === "recording"
  readonly property bool listening: recording && !!state.listening   // audio is flowing; before that the mic is still connecting
  readonly property bool transcribing: status === "transcribing"
  readonly property bool busy: recording || transcribing
  readonly property string lang: state.lang || ""
  readonly property string langLabel: state.langLabel || ""
  readonly property real elapsed: state.elapsed || 0
  readonly property var levels: state.levels || []
  readonly property string partial: state.partial || ""
  readonly property var last: state.last || null
  readonly property string error: state.error || ""
  readonly property int playing: state.playing || 0
  readonly property var config: state.config || ({})
  readonly property var engines: state.engines || []
  readonly property var binds: state.binds || []           // keys actually applied
  readonly property var conflicts: state.conflicts || []   // keys refused because something else owns them
  readonly property var languages: config.languages || []
  // code -> name (whisper's list). Static, so the daemon sends it only with the
  // greeting and on `get`; keep the last copy across the 20 Hz state ticks.
  property var languageNames: ({})
  readonly property var download: state.download || null             // {model, pct} while a model is fetched
  readonly property string agentName: state.agentName || ""          // omarchy's default coding agent
  readonly property bool agentMode: !!state.agentMode                // this recording goes to the agent
  readonly property var missing: state.missing || []                 // tools a stock machine still lacks (voxtype, wtype…)
  readonly property var strings: state.strings || ({})               // bar wording in the language being dictated
  readonly property bool warm: !!state.warm                          // the microphone stream is kept open between recordings
  property var sources: []                                           // microphones (sent with the greeting and on `get`)

  // ---- history (fetched on demand; the daemon says when it changed) ----
  property var historyItems: []
  property int historyTotal: 0
  property string historyQuery: ""
  signal historyChanged()

  property string daemonLog: ""
  property int restarts: 0
  property string daemonError: ""

  readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/speech-to-text"
  readonly property string socketPath: runtimeDir + "/ctl.sock"
  readonly property string repoDir: decodeURIComponent(String(Qt.resolvedUrl("..")).replace(/^file:\/\//, "").replace(/\/$/, ""))
  readonly property string daemonScript: repoDir + "/daemon/sttd.py"

  // ---- commands ----
  function send(obj) {
    if (!sockConnected) return false
    sock.write(JSON.stringify(obj) + "\n")
    sock.flush()
    return true
  }
  function toggle(langCode, enter, agent) { return send({ cmd: "toggle", lang: langCode || null, enter: !!enter, agent: !!agent }) }
  function start(langCode) { return send({ cmd: "start", lang: langCode || null }) }
  function stop(enter) { return send({ cmd: "stop", enter: !!enter }) }
  function cancel() { return send({ cmd: "cancel" }) }
  function refresh() { return send({ cmd: "get" }) }
  function clearError() { return send({ cmd: "clearError" }) }
  function setConfig(patch) { return send({ cmd: "set", config: patch }) }
  function setSetting(key, value) { var p = {}; p[key] = value; return setConfig(p) }
  function rebind() { return send({ cmd: "rebind" }) }
  function setLang(code) { return send({ cmd: "setLang", lang: code }) }
  // While the panel captures a key, our own binds must not fire on it.
  function install() { return send({ cmd: "install" }) }   // omarchy-voxtype-install in a floating terminal
  function suspendBinds() { return send({ cmd: "suspendBinds" }) }
  function resumeBinds() { return send({ cmd: "resumeBinds" }) }
  function loadHistory(query, limit) {
    historyQuery = query || ""
    return send({ cmd: "history", query: historyQuery, limit: limit || 200, offset: 0 })
  }
  function deleteTake(id) { return send({ cmd: "delete", id: id }) }
  function clearHistory() { return send({ cmd: "clearHistory" }) }
  function copyTake(id) { return send({ cmd: "copy", id: id }) }
  function pasteTake(id, enter) { return send({ cmd: "paste", id: id, enter: !!enter }) }
  function editTake(id, text) { return send({ cmd: "edit", id: id, text: text }) }
  function play(id) { return send({ cmd: "play", id: id }) }
  function stopPlay() { return send({ cmd: "stopPlay" }) }

  // ---- daemon lifecycle ----
  Process {
    id: daemon
    command: ["python3", root.daemonScript]
    running: false
    stderr: SplitParser {
      onRead: function(line) {
        var l = root.daemonLog + line + "\n"
        if (l.length > 4000) l = l.slice(l.length - 4000)
        root.daemonLog = l
      }
    }
    onExited: function(code, status) {
      root.state = ({})
      if (code === 4) {   // the daemon saw its own source change (plugin update) and asked to be relaunched
        restartTimer.interval = 500
        restartTimer.restart()
        return
      }
      root.restarts += 1
      if (code !== 3 && root.restarts >= 3) root.daemonError = "daemon keeps exiting (code " + code + ") — check the log"
      restartTimer.interval = code === 3 ? 5000 : Math.min(10000, 1000 + root.restarts * 1000)  // 3 = another instance holds the lock
      restartTimer.restart()
    }
  }

  // Set while we wait for an orphaned daemon (from a previous shell) to honour
  // our quit; the socket dropping is the signal to start our own.
  property bool orphanQuit: false
  Timer {
    id: restartTimer
    interval: 1000
    repeat: false
    onTriggered: {
      if (daemon.running) { daemon.signal(15); return }
      if (root.sockConnected) { root.send({ cmd: "quit" }); root.orphanQuit = true; interval = 5000; restart(); return }
      daemon.running = true
    }
  }
  Timer { interval: 60000; running: daemon.running; repeat: false; onTriggered: root.restarts = 0 }

  // ---- control connection ----
  // Quickshell's Socket cannot recover from a refused connection, so a new
  // Socket object is created for every attempt.
  property var sock: null
  readonly property bool sockConnected: sock ? sock.connected === true : false

  Component {
    id: sockComp
    Socket {
      path: root.socketPath
      connected: true
      parser: SplitParser {
        onRead: function(line) {
          var msg
          try { msg = JSON.parse(line) } catch (e) { return }
          if (!msg) return
          if (msg.type === "state") {
            if (msg.languageNames) root.languageNames = msg.languageNames
            if (msg.sources) root.sources = msg.sources
            root.state = msg
            if (root.daemonError !== "") root.daemonError = ""
          } else if (msg.type === "history") {
            if (String(msg.query || "") === root.historyQuery) {
              root.historyItems = msg.items || []
              root.historyTotal = msg.total || 0
            }
          } else if (msg.type === "history-changed") {
            root.historyChanged()
            root.loadHistory(root.historyQuery)
          }
        }
      }
      onConnectionStateChanged: {
        root.sockConnectedChanged()
        if (connected) root.loadHistory(root.historyQuery)
        if (!connected) {
          root.state = ({})
          if (root.orphanQuit) { root.orphanQuit = false; restartTimer.interval = 1000; restartTimer.restart() }
          reconnectTimer.restart()
        }
      }
      onError: function(err) { reconnectTimer.restart() }
    }
  }

  function connectSocket() {
    if (sock) { sock.destroy(); sock = null }
    sock = sockComp.createObject(root)
    sockConnectedChanged()
  }

  Timer { id: reconnectTimer; interval: 800; repeat: false; onTriggered: if (!root.sockConnected) root.connectSocket() }
  Timer { interval: 3000; running: !root.sockConnected; repeat: true; onTriggered: if (!root.sockConnected) root.connectSocket() }

  Component.onCompleted: {
    daemon.running = true
    connectSocket()
  }
  Component.onDestruction: {
    if (daemon.running) daemon.signal(15)
  }
}
