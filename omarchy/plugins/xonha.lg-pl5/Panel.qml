import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "xonha.lg-pl5"
  ipcTarget: "xonha.lg-pl5"

  readonly property string statusCommand: (Quickshell.env("HOME") || "")
    + "/.config/omarchy/plugins/xonha.lg-pl5/bin/lg_pl5_status.sh"
  property bool connected: false
  property int batteryPercent: -1
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  visible: batteryPercent >= 0
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
  }

  Process {
    id: statusProcess
    command: [root.statusCommand]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var status = JSON.parse(text)
          root.connected = status.connected === true && Number.isInteger(status.percent)
            && status.percent >= 0 && status.percent <= 100
          root.batteryPercent = root.connected ? status.percent : -1
        } catch (e) {
          root.connected = false
          root.batteryPercent = -1
        }
      }
    }
  }

  Timer {
    interval: 10000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: refresh()

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰓃"
    foreground: root.foreground
    tooltipText: "LG PL5"
    onPressed: root.toggle()
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(240))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(150))

    Column {
      id: content
      width: parent.width
      spacing: Style.space(10)

      Text {
        textFormat: Text.PlainText
        text: "LG PL5"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
      }
      Text {
        textFormat: Text.PlainText
        text: root.batteryPercent >= 0 ? "Bateria: " + root.batteryPercent + "%" : "Bateria indisponível"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
    }
  }
}
