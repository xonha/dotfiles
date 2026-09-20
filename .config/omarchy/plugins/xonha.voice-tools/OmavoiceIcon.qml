import QtQuick
import QtQuick.Effects
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

  Image {
    id: sourceImage
    anchors.fill: parent
    source: Qt.resolvedUrl(root.muted ? "microphone-muted.svg" : "microphone.svg")
    sourceSize.width: Math.round(root.iconSize * Screen.devicePixelRatio)
    sourceSize.height: Math.round(root.iconSize * Screen.devicePixelRatio)
    fillMode: Image.PreserveAspectFit
    visible: false
    layer.enabled: true
  }

  MultiEffect {
    anchors.fill: sourceImage
    source: sourceImage
    colorization: 1.0
    colorizationColor: root.color
  }
}
