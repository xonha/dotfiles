import QtQuick
import qs.Commons

Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property bool muted: false
  property bool pulse: false

  implicitWidth: iconSize
  implicitHeight: iconSize
  width: iconSize
  height: iconSize

  onPulseChanged: if (!pulse) opacity = 1.0

  SequentialAnimation on opacity {
    running: root.pulse
    loops: Animation.Infinite
    NumberAnimation { to: 0.45; duration: 500; easing.type: Easing.InOutQuad }
    NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutQuad }
  }

  Text {
    anchors.centerIn: parent
    text: root.muted ? " " : ""
    color: root.color
    font.family: "Symbols Nerd Font Mono"
    font.pixelSize: root.iconSize
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }
}
