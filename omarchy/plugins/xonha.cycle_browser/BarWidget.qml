import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "xonha.cycle_browser"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property string scriptPath: String(setting(
    "scriptPath",
    (Quickshell.env("HOME") || "") + "/.config/scripts/cycle-browser-profile.sh"
  ) || "").replace(/^~/, Quickshell.env("HOME") || "")
  property string profile: "Outro"
  property bool loading: false
  readonly property string browserName: {
    var value = profile.toLowerCase()
    if (value === "main" || value === "pessoal") return "Brave"
    if (value === "maistodos") return "Chrome"
    if (value === "devbot") return "Edge"
    return "Desconhecido"
  }
  readonly property color profileColor: {
    var value = profile.toLowerCase()
    if (value === "maistodos") return "#cba6f7"
    if (value === "devbot") return "#89b4fa"
    return root.bar ? root.bar.barForeground : Color.foreground
  }

  function readProfile() {
    if (scriptPath === "" || statusProc.running) return
    statusProc.command = [scriptPath, "--status"]
    statusProc.running = true
  }

  function cycleProfile() {
    if (scriptPath === "" || loading) return
    loading = true
    cycleProc.command = [scriptPath, "--cycle"]
    cycleProc.running = true
  }

  Process {
    id: statusProc
    stdout: StdioCollector {
      onStreamFinished: {
        var value = String(text || "").trim()
        if (value !== "") root.profile = value
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.profile = "Outro"
    }
  }

  Process {
    id: cycleProc
    onExited: function(exitCode) {
      root.loading = false
      if (exitCode === 0) root.readProfile()
    }
  }

  Component.onCompleted: root.readProfile()

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf0ac"
    foreground: root.profileColor
    tooltipText: root.loading
      ? "Trocando perfil do navegador..."
      : "Navegador: " + root.browserName + "\nPerfil: " + root.profile + "\nClique para alternar"
    onPressed: function(button) {
      if (button === Qt.LeftButton) root.cycleProfile()
      else if (button === Qt.MiddleButton) root.readProfile()
    }
  }
}
