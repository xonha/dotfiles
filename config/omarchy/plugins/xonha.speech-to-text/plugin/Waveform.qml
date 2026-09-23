import QtQuick

// The bar's picture of the microphone, in one of four styles:
//   bars   thin bars mirrored around the middle (the default)
//   wave   a smooth sine-like line whose swell follows the voice
//   pulse  a dot inside a ring that breathes with the voice
//   dots   a row of dots that grow with the voice
// `levels` holds 0..1 values, newest last. With `sine` on (the microphone is
// still opening) every style shows a travelling wave; with `idle` on
// (transcribing, or an error) it breathes gently instead.
Item {
  id: root

  property var levels: []
  property string style: "bars"
  property int bars: 20
  property real barWidth: 2
  property real gap: 2
  property color color: "white"
  property bool idle: false
  property bool sine: false
  property real minHeight: 2

  readonly property bool animated: idle || sine || style === "wave" || style === "pulse"
  implicitWidth: style === "pulse" ? height + 6 : bars * (barWidth + gap) - gap
  implicitHeight: 16

  property real phase: 0
  Timer {
    interval: 40
    repeat: true
    running: root.animated && root.visible
    onTriggered: { root.phase += root.sine ? 0.35 : 0.2; if (root.style === "wave") waveCanvas.requestPaint() }
  }
  onLevelsChanged: if (style === "wave") waveCanvas.requestPaint()
  onStyleChanged: if (style === "wave") waveCanvas.requestPaint()

  function levelAt(i) {
    var lv = levels || []
    var offset = lv.length - bars
    var v = offset + i >= 0 ? Number(lv[offset + i]) : 0
    return isFinite(v) ? Math.max(0, Math.min(1, v)) : 0
  }
  function breath(i) { return 0.12 + 0.1 * (1 + Math.sin(phase + i * 0.45)) / 2 }
  function travel(i) { return 0.15 + 0.75 * (1 + Math.sin(i * 0.7 - phase)) / 2 }
  function amp(i) { return sine ? travel(i) : idle ? breath(i) : levelAt(i) }
  // The loudest of the last few levels, smoothed: what a single shape should show.
  function recent() {
    if (sine) return 0.4 + 0.35 * (1 + Math.sin(phase * 1.5)) / 2
    if (idle) return 0.15 + 0.1 * (1 + Math.sin(phase)) / 2
    var lv = levels || [], m = 0
    for (var i = Math.max(0, lv.length - 4); i < lv.length; i++) m = Math.max(m, Number(lv[i]) || 0)
    return Math.min(1, m)
  }

  // ---- bars ----
  Row {
    visible: root.style === "bars"
    anchors.centerIn: parent
    spacing: root.gap
    Repeater {
      model: root.style === "bars" ? root.bars : 0
      Rectangle {
        required property int index
        readonly property real lv: root.amp(index)
        width: root.barWidth
        height: Math.max(root.minHeight, Math.round(lv * root.height))
        radius: root.barWidth / 2
        color: root.color
        anchors.verticalCenter: parent.verticalCenter
        Behavior on height { NumberAnimation { duration: 70 } }
      }
    }
  }

  // ---- dots ----
  Row {
    visible: root.style === "dots"
    anchors.centerIn: parent
    spacing: 0
    readonly property int count: Math.max(4, Math.round(root.bars / 2))
    readonly property real slot: root.implicitWidth / count
    Repeater {
      model: root.style === "dots" ? parent.count : 0
      Item {
        required property int index
        readonly property real lv: root.amp(Math.min(root.bars - 1, Math.round(index * root.bars / parent.count + root.bars / parent.count / 2)))
        width: parent.slot
        height: root.height
        Rectangle {
          anchors.centerIn: parent
          width: Math.max(2, Math.round(2 + lv * (Math.min(root.height, parent.width) - 3)))
          height: width
          radius: width / 2
          color: root.color
          opacity: 0.5 + 0.5 * lv
          Behavior on width { NumberAnimation { duration: 70 } }
        }
      }
    }
  }

  // ---- wave ----
  Canvas {
    id: waveCanvas
    visible: root.style === "wave"
    anchors.fill: parent
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      if (!visible) return
      var mid = height / 2, n = root.bars, span = width / Math.max(1, n - 1)
      ctx.strokeStyle = root.color
      ctx.lineWidth = 1.6
      ctx.lineCap = "round"
      ctx.beginPath()
      var steps = Math.max(24, Math.round(width))
      for (var s = 0; s <= steps; s++) {
        var x = width * s / steps
        var pos = x / span, i = Math.floor(pos), f = pos - i
        var a0 = root.amp(Math.min(n - 1, i)), a1 = root.amp(Math.min(n - 1, i + 1))
        var envelope = a0 + (a1 - a0) * f
        var y = mid + Math.sin(x * 0.55 - root.phase * 2) * envelope * (mid - 1)
        if (s === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
      }
      ctx.stroke()
    }
  }

  // ---- pulse ----
  Item {
    visible: root.style === "pulse"
    anchors.centerIn: parent
    width: root.height + 6
    height: root.height
    readonly property real lv: root.recent()
    Rectangle {   // ring
      anchors.centerIn: parent
      width: Math.round(root.height * (0.45 + 0.55 * parent.lv))
      height: width
      radius: width / 2
      color: "transparent"
      border.width: 1.5
      border.color: root.color
      opacity: 0.35 + 0.65 * parent.lv
      Behavior on width { NumberAnimation { duration: 90 } }
    }
    Rectangle {   // dot
      anchors.centerIn: parent
      width: Math.round(root.height * (0.2 + 0.3 * parent.lv))
      height: width
      radius: width / 2
      color: root.color
      Behavior on width { NumberAnimation { duration: 60 } }
    }
  }
}
