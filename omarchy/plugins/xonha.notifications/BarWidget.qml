import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "xonha.notifications"
  implicitWidth: Style.space(26)
  implicitHeight: barSize

  property string lastAnchor: ""

  function publishAnchor() {
    if (!bar || !root.QsWindow.window || !root.QsWindow.window.screen) return
    var point = root.mapToItem(null, root.width, root.height)
    var screen = root.QsWindow.window.screen.name
    var anchor = [screen, Math.round(point.x), Math.round(point.y)].join(":")
    if (anchor === lastAnchor) return
    lastAnchor = anchor
    Quickshell.execDetached(["omarchy-shell", "notifications", "setBarAnchor",
      screen, String(Math.round(point.x)), String(Math.round(point.y))])
  }

  onBarChanged: Qt.callLater(publishAnchor)
  Timer {
    interval: 500
    repeat: true
    running: root.bar !== null
    onTriggered: root.publishAnchor()
  }

  Text {
    anchors.centerIn: parent
    text: "󰂚"
    font.family: Style.font.family
    font.pixelSize: Style.space(17)
    color: mouse.containsMouse ? Color.accent : Color.foreground
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "xonha.notifications", "{}"])
  }
}
