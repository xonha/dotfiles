import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Adapted from zimixin/omarchy-fingerprint (MIT) for system fprintd.
Panel {
  id: root
  moduleName: "xonha.fingerprint"
  ipcTarget: "xonha.fingerprint"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string action: home + "/.config/omarchy/plugins/xonha.fingerprint/bin/fingerprint_device.py"

  property var readers: []
  property string selectedReader: ""
  property string preferredReader: ""
  property bool statusReady: false

  function readerLabel(reader) {
    if (reader === "chipsailing") return "External Reader"
    if (reader === "synaptics") return "Internal Reader"
    return reader || "Desconhecido"
  }

  function selectedDevice() {
    for (var i = 0; i < readers.length; i++) {
      if (readers[i].reader === selectedReader) return readers[i]
    }
    return null
  }

  function totalPrints() {
    var count = 0
    for (var i = 0; i < readers.length; i++) count += Number(readers[i].count) || 0
    return count
  }

  function nextFinger() {
    var selected = selectedDevice()
    var enrolled = selected && Array.isArray(selected.fingers) ? selected.fingers : []
    var choices = ["right-index-finger", "right-thumb", "left-index-finger", "left-thumb"]
    for (var i = 0; i < choices.length; i++) {
      if (enrolled.indexOf(choices[i]) < 0) return choices[i]
    }
    return ""
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function applyStatus(content) {
    var data = null
    try { data = JSON.parse(String(content || "")) } catch (e) { return }
    if (!data || !Array.isArray(data.readers)) return
    readers = data.readers.filter(function(d) {
      return d.reader === "chipsailing" || d.reader === "synaptics"
    })
    preferredReader = data.preferred || ""
    statusReady = true
    if (!selectedDevice()) {
      selectedReader = readers.length ? (preferredReader || readers[0].reader) : ""
    }
  }

  function open() { root.controller.show(); root.refresh() }
  function close() { root.controller.hide() }
  function toggle() { if (root.opened) root.close(); else root.open() }

  function runAction(kind) {
    if (!root.bar || !root.selectedDevice()) return
    var finger = kind === "enroll" ? root.nextFinger() : ""
    if (kind === "enroll" && !finger) return
    root.close()
    var command = root.action + " " + kind + " --reader " + root.selectedReader
    if (finger) command += " --finger " + finger
    root.bar.run('omarchy-launch-floating-terminal-with-presentation "' + command + '"')
  }

  Process {
    id: statusProc
    command: [root.action, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
  }

  Timer {
    interval: 15000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: refresh()

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    fixedWidth: Style.bar.iconSlot
    fixedHeight: button.vertical ? Style.bar.iconSlot : -1
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.refresh()
      else root.toggle()
    }

    Text {
      anchors.centerIn: parent
      text: ""
      color: root.statusReady && root.totalPrints() ? root.foreground : root.urgent
      font.family: root.fontFamily
      font.pixelSize: Style.bar.iconFont
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(480))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onActivateRequested: root.refresh()
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refresh()
        if (t === "v" || t === "V") root.runAction("verify")
        if (t === "e" || t === "E") root.runAction("enroll")
      }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(8)

        Text {
          text: "Leitores de digital"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
        }
        Text {
          width: parent.width
          text: !root.statusReady ? "Aguardando fprintd…"
            : root.readers.length === 0 ? "Nenhum leitor conectado"
            : root.preferredReader ? "Autenticação: " + root.readerLabel(root.preferredReader)
            : "Cadastre uma digital para autenticar"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        PanelSectionHeader {
          width: parent.width
          text: "LEITORES"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Repeater {
          model: root.readers
          ReaderRow {
            width: column.width
            device: modelData
          }
        }

        PanelSectionHeader {
          width: parent.width
          text: "AÇÕES · " + root.readerLabel(root.selectedReader)
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Row {
          width: parent.width
          spacing: Style.space(8)
          ActionTile {
            width: (parent.width - parent.spacing) / 2
            label: "Cadastrar"
            hint: root.nextFinger() || "Sem posição livre"
            enabled: !!root.selectedDevice() && !!root.nextFinger()
            onClicked: root.runAction("enroll")
          }
          ActionTile {
            width: (parent.width - parent.spacing) / 2
            label: "Testar"
            hint: "verificar digital"
            enabled: !!root.selectedDevice() && root.selectedDevice().count > 0
            onClicked: root.runAction("verify")
          }
        }

        Text {
          width: parent.width
          text: "Com o dongle conectado, o PAM usa o leitor com mais digitais. "
            + "Para preferir o dongle: 2 nele e 1 no interno. Sem o dongle, usa o interno."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }

  component ReaderRow: Rectangle {
    id: row
    property var device: ({})
    height: details.implicitHeight + Style.space(16)
    radius: Style.cornerRadius
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b,
                   root.selectedReader === device.reader ? 0.13 : 0.05)
    border.width: 1
    border.color: root.selectedReader === device.reader ? root.foreground : root.dim

    Column {
      id: details
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(3)
      Text {
        text: root.readerLabel(row.device.reader) + " · " + row.device.count + " digital(is)"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }
      Text {
        width: parent.width
        text: row.device.fingers && row.device.fingers.length
          ? row.device.fingers.join(", ") : "Nenhuma digital cadastrada"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }
    MouseArea {
      anchors.fill: parent
      onClicked: root.selectedReader = row.device.reader
    }
  }

  component ActionTile: Rectangle {
    id: tile
    property string label: ""
    property string hint: ""
    signal clicked()
    height: Style.space(42)
    radius: Style.cornerRadius
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07)
    border.width: 1
    border.color: root.dim
    opacity: enabled ? 1 : 0.45

    Column {
      anchors.centerIn: parent
      spacing: Style.space(2)
      Text {
        text: tile.label
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }
      Text {
        text: tile.hint
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
    MouseArea {
      anchors.fill: parent
      enabled: tile.enabled
      onClicked: tile.clicked()
    }
  }
}
