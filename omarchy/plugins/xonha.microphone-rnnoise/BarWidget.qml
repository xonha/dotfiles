import QtQuick
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "xonha.microphone-rnnoise"

  readonly property var source: Pipewire.defaultAudioSource
  readonly property bool muted: !source || !source.audio || source.audio.muted
  readonly property bool open: !muted

  visible: open
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: visible ? button.implicitHeight : 0

  PwObjectTracker { objects: root.source ? [root.source] : [] }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: "Blue Snowball (RNNoise) aberto"
    iconComponent: Component {
      Item {
        anchors.fill: parent

        SequentialAnimation on opacity {
          running: root.open
          loops: Animation.Infinite
          NumberAnimation { to: 0.35; duration: 500; easing.type: Easing.InOutQuad }
          NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutQuad }
        }

        Text {
          anchors.centerIn: parent
          text: ""
          color: Color.flatColor("red", "#f38ba8")
          font.family: "Symbols Nerd Font Mono"
          font.pixelSize: Style.font.icon
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
      }
    }
  }
}
