import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "NotificationLogic.js" as NotificationLogic

Item {
  id: root
  property var shell: null
  property var service: null
  property bool opened: false
  property bool focusPrimed: false

  readonly property var selectedScreen: {
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (service && screens[i].name === service.notificationMonitor) return screens[i]
    }
    // Opening the center explicitly must still allow fixing a disconnected output.
    return screens.length ? screens[0] : null
  }
  readonly property bool monitorConnected: service && selectedScreen && selectedScreen.name === service.notificationMonitor
  readonly property var monitorOptions: {
    var options = []
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) options.push({ value: screens[i].name, label: screens[i].name })
    if (service && !monitorConnected)
      options.unshift({ value: service.notificationMonitor, label: service.notificationMonitor + " (desconectado)" })
    return options
  }

  function open(payload) {
    opened = true
    focusPrimed = false
    focusTimer.restart()
    if (service) {
      service.historyViewing = true
      service.refreshHistory()
    }
    Qt.callLater(function() { content.forceActiveFocus() })
  }
  function close() {
    opened = false
    if (service) service.historyViewing = false
  }
  function dismiss() {
    close()
    if (shell) shell.hide("xonha.notifications")
  }
  Component.onDestruction: if (service) service.historyViewing = false

  Timer {
    id: focusTimer
    interval: 80
    onTriggered: root.focusPrimed = true
  }

  PanelWindow {
    id: window
    screen: root.selectedScreen
    visible: root.opened
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.namespace: "xonha-notification-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened
      ? (root.focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
      : WlrKeyboardFocus.None

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    Rectangle {
      id: card
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.margins: Style.gapsOut
      anchors.topMargin: Style.gapsOut + Style.space(32)
      width: Math.min(Style.space(460), window.width - Style.gapsOut * 2)
      height: Math.min(Style.space(640), window.height - anchors.topMargin - Style.gapsOut)
      color: Color.popups.background
      radius: Style.cornerRadius
      border.color: Color.popups.border
      border.width: Style.normalBorderWidth
      // Consume empty-space clicks inside the card.
      MouseArea { anchors.fill: parent }

      ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Style.space(18)
        spacing: Style.space(12)
        focus: true
        Keys.onEscapePressed: root.dismiss()

        RowLayout {
          Layout.fillWidth: true
          Text {
            Layout.fillWidth: true
            text: "Notificações"
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.space(19)
            font.bold: true
          }
          Text {
            text: "✕"
            color: Color.popups.text
            font.pixelSize: Style.space(18)
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.dismiss() }
          }
        }

        Dropdown {
          Layout.fillWidth: true
          label: "Monitor dos avisos"
          value: root.service ? root.service.notificationMonitor : ""
          options: root.monitorOptions
          onChanged: function(value) { if (root.service) root.service.setNotificationMonitor(value) }
        }

        Text {
          Layout.fillWidth: true
          visible: !root.monitorConnected
          text: "Monitor desconectado. Os avisos ficam ocultos até ele voltar."
          color: Color.accent
          wrapMode: Text.WordWrap
          font.pixelSize: Style.space(12)
        }

        Dropdown {
          Layout.fillWidth: true
          label: "Posição dos avisos"
          value: root.service ? root.service.notificationPosition : "top-center"
          options: [
            { value: "top-left", label: "Topo · esquerda" },
            { value: "top-center", label: "Topo · centro" },
            { value: "top-right", label: "Topo · direita" },
            { value: "bottom-left", label: "Base · esquerda" },
            { value: "bottom-center", label: "Base · centro" },
            { value: "bottom-right", label: "Base · direita" }
          ]
          onChanged: function(value) { if (root.service) root.service.setNotificationPosition(value) }
        }

        Dropdown {
          Layout.fillWidth: true
          label: "Notificações guardadas"
          value: root.service ? String(root.service.historyLimit) : "100"
          options: [ { value: "25", label: "25" }, { value: "100", label: "100" }, { value: "500", label: "500" } ]
          onChanged: function(value) { if (root.service) root.service.setHistoryLimit(Number(value)) }
        }

        RowLayout {
          Layout.fillWidth: true
          Text {
            Layout.fillWidth: true
            text: "Histórico"
            color: Color.popups.text
            font.family: Style.font.family
            font.bold: true
            font.pixelSize: Style.space(14)
          }
          Text {
            text: "Atualizar"
            color: Color.accent
            font.pixelSize: Style.space(12)
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.service) root.service.refreshHistory() }
          }
        }

        ListView {
          id: history
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          spacing: Style.space(8)
          model: root.service ? root.service.historyEntries : []
          ScrollBar.vertical: ScrollBar { }

          delegate: Rectangle {
            required property var modelData
            width: history.width - Style.space(12)
            height: entry.implicitHeight + Style.space(20)
            radius: Style.space(6)
            color: Qt.lighter(Color.popups.background, 1.18)
            Column {
              id: entry
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: Style.space(10)
              spacing: Style.space(4)
              Text {
                width: parent.width
                text: modelData.app + " · " + Qt.formatDateTime(new Date(modelData.timestamp), "dd/MM HH:mm")
                textFormat: Text.PlainText
                color: Qt.darker(Color.popups.text, 1.4)
                font.pixelSize: Style.space(11)
                elide: Text.ElideRight
              }
              Text {
                width: parent.width
                text: modelData.summary
                textFormat: Text.PlainText
                color: Color.popups.text
                font.pixelSize: Style.space(14)
                font.bold: true
                wrapMode: Text.Wrap
              }
              Text {
                width: parent.width
                visible: text.length > 0
                text: NotificationLogic.sanitizeBody(modelData.body)
                textFormat: Text.StyledText
                color: Color.popups.text
                font.pixelSize: Style.space(12)
                wrapMode: Text.Wrap
              }
            }
          }
          Text {
            anchors.centerIn: parent
            visible: history.count === 0
            text: "O histórico aparece aqui quando os avisos desaparecem."
            width: parent.width - Style.space(20)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: Qt.darker(Color.popups.text, 1.3)
            font.pixelSize: Style.space(13)
          }
        }
      }
    }
  }
}
