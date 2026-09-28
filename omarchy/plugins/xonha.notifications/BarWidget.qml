import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "xonha.notifications"
  implicitWidth: Style.space(26)
  implicitHeight: barSize

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
