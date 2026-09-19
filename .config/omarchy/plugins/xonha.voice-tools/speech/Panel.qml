import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar widget + popup for Speech to Text. In the bar: a microphone icon that,
// while a recording runs, turns into a waveform (yellow sine while the microphone
// connects, green voice levels once it listens) with the words as they are
// recognised; it folds back the moment the text has been pasted. The popup
// has two tabs: History (every recording, with play / copy / paste / delete) and
// Settings (one key and an auto-send switch per language; the rest is
// tucked under Advanced). All state lives in the daemon (see Service.qml);
// this file renders and forwards.
Panel {
  id: root
  moduleName: "alanfortlink.speech-to-text"
  ipcTarget: "alanfortlink.speech-to-text"
  manageIpc: false

  readonly property var svc: bar && bar.shell ? bar.shell.serviceFor("alanfortlink.speech-to-text") : null
  readonly property bool connected: svc ? svc.connected : false
  readonly property bool recording: svc ? svc.recording : false
  readonly property bool transcribing: svc ? svc.transcribing : false
  readonly property bool listening: svc ? svc.listening : false      // audio is flowing
  readonly property bool connecting: recording && !listening          // pw-record is still opening the microphone
  readonly property bool busy: recording || transcribing
  readonly property var cfg: svc ? svc.config : ({})
  readonly property var download: svc ? svc.download : null
  readonly property bool alwaysShow: setting("alwaysShow", true)
  readonly property int maxTextWidth: Style.space(setting("maxTextWidth", 360))
  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(fg, 1.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal
  readonly property int rowH: Style.spacing.controlHeight
  readonly property int trailInset: Style.space(6)   // ToggleSwitch's hover ring pad; trailing controls line up with it
  readonly property int labelW: Style.space(104)     // one label column for every form row

  // Traffic-light colours for the recording: yellow while the microphone connects,
  // green once it listens. The shell's Color singleton does not expose them,
  // so they come from the current theme's colors.toml (with fallbacks).
  property color yellow: "#f9e2af"
  property color green: "#a6e3a1"
  FileView {
    id: themeFile
    path: Color.currentThemePath + "/colors.toml"
    watchChanges: true
    onLoaded: root.readThemeColors()
    onFileChanged: reload()
    onTextChanged: root.readThemeColors()
  }
  function readThemeColors() {
    var t = String(themeFile.text() || "")
    var y = t.match(/^\s*yellow\s*=\s*"(#[0-9a-fA-F]{6})"/m), g = t.match(/^\s*green\s*=\s*"(#[0-9a-fA-F]{6})"/m)
    if (y) yellow = y[1]
    if (g) green = g[1]
  }
  readonly property color takeColor: connecting ? yellow : recording ? green : fg

  // A failed recording shows its reason in the bar for a moment; a successful one
  // shows nothing — the text is already where it belongs.
  property bool showError: false
  Timer { id: errorTimer; interval: 4000; onTriggered: root.showError = false }
  onTranscribingChanged: {
    if (transcribing || !svc) return
    if (svc.error !== "") { showError = true; errorTimer.restart() }
  }
  onRecordingChanged: if (recording) { showError = false; errorTimer.stop() }

  readonly property bool expanded: !vertical && (busy || showError || download !== null)
  visible: alwaysShow || expanded
  implicitWidth: expanded ? strip.implicitWidth : button.implicitWidth
  implicitHeight: button.implicitHeight
  Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

  // Idle: left = popup, right = dictate. While recording the strip is the
  // control: left = stop, right = discard.
  function pressed(b) {
    if (!svc) return
    if (recording) {
      if (b === Qt.RightButton) svc.cancel()
      else if (b === Qt.LeftButton) svc.toggle(null, false)
      return
    }
    if (b === Qt.RightButton) svc.toggle(null, false)
    else if (b === Qt.MiddleButton) svc.cancel()
    else root.toggle()
  }

  // ---- text helpers ----
  function langName(code) {
    if (svc && svc.languageNames && svc.languageNames[code]) return svc.languageNames[code]
    for (var i = 0; i < langs.length; i++) if (langs[i].code === code) return langs[i].label || code
    return code
  }
  function keyFor(code) { return langs.length && langs[0].code === code ? String(langs[0].key || "") : "" }   // the default entry's dictate key
  readonly property string defaultLang: langs.length ? langs[0].code : ""
  function t(key, fallback) { var st = svc ? svc.strings : null; return st && st[key] ? st[key] : fallback }
  readonly property string agentName: svc && svc.agentName !== "" ? svc.agentName : "agent"
  function clock(secs) {
    var s = Math.floor(secs || 0)
    return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60)
  }
  function when(ts) {
    var d = new Date((ts || 0) * 1000), now = new Date()
    var hm = Qt.formatTime(d, "HH:mm")
    if (d.toDateString() === now.toDateString()) return hm
    var y = new Date(now.getTime() - 86400000)
    if (d.toDateString() === y.toDateString()) return "Yesterday " + hm
    return Qt.formatDate(d, "d MMM") + " " + hm
  }
  function subtitle() {
    if (!svc) return "Service not loaded"
    if (!connected) return svc.daemonError !== "" ? svc.daemonError : "Starting…"
    if (connecting) return t("opening", "Opening the microphone…")
    if (recording) return t("listening", "Listening…").replace(/…$/, "") + " · " + svc.langLabel + " · " + clock(svc.elapsed) + (svc.agentMode ? " · to " + agentName : "")
    if (transcribing) return t("transcribing", "Transcribing…")
    if (download) return "Getting ready for " + (download.lang || download.model) + " · " + download.pct + "%"
    return "Idle · " + svc.langLabel
  }
  readonly property string liveText: {
    if (!svc) return ""
    if (connecting) return t("opening", "Opening microphone…")
    if (recording) return svc.partial !== "" ? svc.partial : t("listening", "Listening…")
    if (transcribing) return svc.partial !== "" ? svc.partial : (svc.agentMode ? "Sending to " + agentName + "…" : t("transcribing", "Transcribing…"))
    if (showError) return svc.error
    if (download) return "Getting ready for " + (download.lang || download.model) + " · " + download.pct + "%"
    return ""
  }
  readonly property bool livePlaceholder: recording ? (svc && svc.partial === "") : (transcribing || (download !== null && !showError))
  // The popup shows the end of a long transcript (Text cannot left-elide wrapped text).
  readonly property string liveTail: liveText.length > 420 ? "…" + liveText.slice(-420) : liveText

  // ---------- bar: idle icon ----------
  BarIconButton {
    id: button
    anchors.fill: parent
    visible: !root.expanded
    bar: root.bar
    text: "󰍬"
    active: root.busy || root.showError
    useActiveColor: true
    activeColor: root.busy ? root.takeColor : Color.urgent
    tooltipText: (root.connected ? (root.svc.missing.length ? "Speech to text · click to install " + root.svc.missing.join(", ") : "Speech to text") : "Speech to text · starting")
                 + (root.svc && root.svc.error !== "" ? " · " + root.svc.error : "")
                 + (root.keyFor(root.defaultLang) !== "" ? " · " + root.keyFor(root.defaultLang) + ": dictate " + root.langName(root.defaultLang) : "")
                 + " · right-click: dictate"
    onPressed: function(b) { root.pressed(b) }
  }

  // ---------- bar: live strip ----------
  Item {
    id: strip
    anchors.fill: parent
    visible: root.expanded
    implicitWidth: stripRow.implicitWidth + Style.spacing.xxxl

    Row {
      id: stripRow
      anchors.centerIn: parent
      spacing: Style.spacing.md

      Waveform {
        anchors.verticalCenter: parent.verticalCenter
        height: Style.bar.iconCanvas
        style: ["bars", "wave", "pulse", "dots"].indexOf(String(root.cfg.animation)) >= 0 ? String(root.cfg.animation) : "bars"
        bars: 18
        levels: root.svc ? root.svc.levels : []
        sine: root.connecting || (root.download !== null && !root.busy)
        idle: root.transcribing || (!root.recording && root.showError)
        color: root.showError && !root.busy ? Color.urgent : root.download !== null && !root.busy ? root.yellow : root.takeColor
        Behavior on color { ColorAnimation { duration: 250 } }
      }

      TextMetrics { id: liveMetrics; text: root.liveText; font.family: root.fontFamily; font.pixelSize: Style.font.body }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.liveText
        color: root.showError && !root.busy ? Color.urgent : root.livePlaceholder ? root.dim : root.fg
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.italic: root.livePlaceholder
        elide: Text.ElideLeft
        width: Math.min(liveMetrics.advanceWidth + 2, root.maxTextWidth)
        visible: text !== ""
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.recording
        text: root.clock(root.svc ? root.svc.elapsed : 0)
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      onClicked: function(mouse) { root.pressed(mouse.button) }
      onEntered: if (root.bar && root.recording) root.bar.showTooltip(strip, "Click: stop and paste · right-click: discard")
      onExited: if (root.bar) root.bar.hideTooltip(strip)
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    // omarchy-shell alanfortlink.speech-to-text dictate  (same as `stt toggle`)
    function dictate() { if (root.svc) root.svc.toggle(null, false) }
    function dictateSend() { if (root.svc) root.svc.toggle(null, true) }
    function cancel() { if (root.svc) root.svc.cancel() }
    function history() { root.tab = "history"; root.open() }
    function settings() { root.tab = "settings"; root.open() }
    // Arm key capture for the language at `index` (what clicking its key button does).
    function capture(index: int) { root.tab = "settings"; root.open(); root.startCapture(index, "key") }
    function captureAgent(index: int) { root.tab = "settings"; root.open(); root.startCapture(index, "agentKey") }
  }

  onOpenedChanged: {
    endCapture()
    if (opened && svc) { svc.refresh(); svc.loadHistory(""); expandedTake = 0 }
  }
  onTabChanged: endCapture()

  // Anything that pastes or starts typing must run after the popup has given
  // the keyboard back to the window underneath, or the text lands in here.
  property var deferredFn: null
  Timer { id: deferred; interval: 220; onTriggered: { var f = root.deferredFn; root.deferredFn = null; if (f) f() } }
  function closeThen(fn) { deferredFn = fn; close(); deferred.restart() }

  // ---------- popup ----------
  readonly property var tabs: [ { key: "history", label: "History" }, { key: "settings", label: "Settings" } ]
  property string tab: "history"
  property bool clearConfirm: false
  property int expandedTake: 0
  property bool advancedOpen: false
  property int captureIndex: -1        // language row waiting for a key press (-1: none)
  property string captureField: "key"  // "key" (dictate) or "agentKey" (send to the agent)
  property string captureNote: ""
  Timer { id: noteClear; interval: 3500; onTriggered: root.captureNote = "" }
  function note(t) { captureNote = t; noteClear.restart() }

  // The daemon pushes state ~20×/s while recording; derive the lists from
  // JSON text so the rows are not rebuilt on every push.
  readonly property string langsJson: JSON.stringify(svc ? svc.languages : [])
  readonly property var langs: JSON.parse(langsJson)
  readonly property string namesJson: JSON.stringify(svc ? svc.languageNames : ({}))
  readonly property var addableLangs: {   // every language, even ones already there: a second entry can send, ask the agent…
    var names = JSON.parse(namesJson), out = []
    for (var code in names) out.push({ value: code, label: names[code] + " (" + code + ")" })
    out.sort(function(a, b) { return a.value === "auto" ? -1 : b.value === "auto" ? 1 : a.label.localeCompare(b.label) })
    return out
  }
  readonly property string enginesJson: JSON.stringify(svc ? svc.engines : [])
  readonly property var engineOpts: JSON.parse(enginesJson).map(function(e) {
    return { value: e, label: ({ voxtype: "Omarchy built-in (voxtype)", "whisper-cpp": "whisper.cpp", command: "Custom command" })[e] || e }
  })
  readonly property var langOpts: langs.map(function(l) { return { value: l.code, label: l.label || l.code } })
  readonly property string sourcesJson: JSON.stringify(svc ? svc.sources : [])
  readonly property var micOpts: {
    var list = JSON.parse(sourcesJson), cur = String(cfg.device || "default")
    var opts = [ { value: "default", label: "System default" } ]
    for (var i = 0; i < list.length; i++) opts.push({ value: String(list[i].name), label: String(list[i].label) })
    if (cur !== "default" && !list.some(function(m) { return String(m.name) === cur })) opts.push({ value: cur, label: cur + " (not connected)" })
    return opts
  }
  readonly property string conflictsJson: JSON.stringify(svc ? svc.conflicts : [])
  readonly property var conflicts: JSON.parse(conflictsJson)
  function conflictText() {
    return conflicts.map(function(c) {
      return (c.mods ? c.mods + " " : "") + c.key + " is already used by “" + c.takenBy + "” — pick another key"
    }).join("\n")
  }

  function saveLangs(list) { if (svc) svc.setSetting("languages", list) }
  function patchLang(index, key, value) {
    var list = JSON.parse(langsJson)
    if (index < 0 || index >= list.length) return false
    list[index][key] = value
    saveLangs(list)
    return true
  }
  function addLang(code) {
    if (!code) return
    var list = JSON.parse(langsJson)
    list.push({ code: code, key: "", autoSend: false, agentKey: "", engineArgs: "" })
    saveLangs(list)
  }
  function langTitle(l) {   // "English", or "English · 2" for a second entry of the same language
    var id = String(l.id || l.code), n = id.indexOf("-") > 0 ? id.slice(id.indexOf("-") + 1) : ""
    return langName(l.code) + (n ? " " + n : "")
  }
  function moveLang(index, delta) {   // the first language is the default
    var list = JSON.parse(langsJson), j = index + delta
    if (index < 0 || index >= list.length || j < 0 || j >= list.length) return
    var t = list[index]; list[index] = list[j]; list[j] = t
    saveLangs(list)
  }
  function removeLang(index) {
    var list = JSON.parse(langsJson)
    if (list.length <= 1) return
    list.splice(index, 1)
    saveLangs(list)
  }

  // ---- key capture ----
  // While a row is armed the daemon takes our own binds down (so pressing the
  // current key is captured instead of starting a recording) and puts them back after.
  function startCapture(index, field) {
    if (index < 0 || index >= langs.length) return
    captureIndex = index
    captureField = field || "key"
    if (svc) svc.suspendBinds()
    keyCatcher.forceActiveFocus()
  }
  function endCapture() {
    if (captureIndex === -1) return
    captureIndex = -1
    if (svc) svc.resumeBinds()
  }
  // Qt key event -> Hyprland bind spec ("CTRL SHIFT F13"). "" for a lone modifier;
  // null for a bare key that must not become a global bind (a letter, digit…).
  function keySpec(event) {
    var k = event.key
    if (k === Qt.Key_Control || k === Qt.Key_Shift || k === Qt.Key_Alt || k === Qt.Key_Meta || k === Qt.Key_AltGr || k === Qt.Key_Super_L || k === Qt.Key_Super_R) return ""
    var mods = []
    if (event.modifiers & Qt.ControlModifier) mods.push("CTRL")
    if (event.modifiers & Qt.ShiftModifier) mods.push("SHIFT")
    if (event.modifiers & Qt.AltModifier) mods.push("ALT")
    if (event.modifiers & Qt.MetaModifier) mods.push("SUPER")
    var name = "", bareOk = false
    // F13–F24 reach Qt as XF86Tools/XF86Launch* keysyms; their xkb key codes are fixed (evdev KEY_F13 = 183, +8).
    var code = event.nativeScanCode
    if (code >= 191 && code <= 202) { name = "F" + (13 + code - 191); bareOk = true }
    else if (k >= Qt.Key_F1 && k <= Qt.Key_F35) { name = "F" + (k - Qt.Key_F1 + 1); bareOk = true }
    else {
      var special = {}
      special[Qt.Key_Pause] = "PAUSE"; special[Qt.Key_Print] = "PRINT"; special[Qt.Key_ScrollLock] = "SCROLL_LOCK"
      special[Qt.Key_Insert] = "INSERT"; special[Qt.Key_Menu] = "MENU"; special[Qt.Key_CapsLock] = "CAPS_LOCK"
      special[Qt.Key_Home] = "HOME"; special[Qt.Key_End] = "END"; special[Qt.Key_PageUp] = "PAGE_UP"; special[Qt.Key_PageDown] = "PAGE_DOWN"
      var table = {}
      table[Qt.Key_Space] = "SPACE"; table[Qt.Key_Return] = "RETURN"; table[Qt.Key_Enter] = "KP_Enter"; table[Qt.Key_Tab] = "TAB"
      table[Qt.Key_Backspace] = "BACKSPACE"; table[Qt.Key_Delete] = "DELETE"
      table[Qt.Key_Left] = "LEFT"; table[Qt.Key_Right] = "RIGHT"; table[Qt.Key_Up] = "UP"; table[Qt.Key_Down] = "DOWN"
      table[Qt.Key_Minus] = "MINUS"; table[Qt.Key_Equal] = "EQUAL"; table[Qt.Key_Comma] = "COMMA"; table[Qt.Key_Period] = "PERIOD"
      table[Qt.Key_Slash] = "SLASH"; table[Qt.Key_Semicolon] = "SEMICOLON"; table[Qt.Key_Apostrophe] = "APOSTROPHE"
      table[Qt.Key_BracketLeft] = "BRACKETLEFT"; table[Qt.Key_BracketRight] = "BRACKETRIGHT"; table[Qt.Key_Backslash] = "BACKSLASH"; table[Qt.Key_QuoteLeft] = "GRAVE"
      if (special[k] !== undefined) { name = special[k]; bareOk = true }
      else if (table[k] !== undefined) name = table[k]
      else if (k >= Qt.Key_A && k <= Qt.Key_Z) name = String.fromCharCode(65 + (k - Qt.Key_A))
      else if (k >= Qt.Key_0 && k <= Qt.Key_9) name = String.fromCharCode(48 + (k - Qt.Key_0))
      else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) > 32) name = event.text.toUpperCase()
    }
    if (name === "") return code > 0 ? "?" : ""
    if (!mods.length && !bareOk) return null
    return (mods.length ? mods.join(" ") + " " : "") + name
  }
  function finishCapture(event) {
    if (captureIndex === -1) return false
    if (event.key === Qt.Key_Escape && !(event.modifiers & ~Qt.KeypadModifier)) { endCapture(); return true }
    if ((event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) && !(event.modifiers & ~Qt.KeypadModifier)) {
      var i = captureIndex, f = captureField
      captureIndex = -1
      patchLang(i, f, "")
      if (svc) svc.resumeBinds()
      return true
    }
    var spec = keySpec(event)
    if (spec === "") return true   // a lone modifier: keep waiting
    if (spec === "?") { note("That key has no name I can bind — try another"); return true }
    if (spec === null) { note("Add a modifier (CTRL, SUPER…): a bare key would be taken from every app"); return true }
    var index = captureIndex, field = captureField
    captureIndex = -1
    patchLang(index, field, spec)
    if (svc) svc.resumeBinds()
    return true
  }

  KeyboardPanel {
    id: panel
    anchorItem: root
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(560))
    contentHeight: panel.fittedContentHeight(topBlock.implicitHeight + Style.space(10) + body.implicitHeight + Style.space(4))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.clearConfirm || root.captureIndex !== -1 || (settingsLoader.item ? settingsLoader.item.pickerOpen === true : false)
      onCloseRequested: root.close()
      // Tab moves between the panel's controls; with nothing focused it switches panels like elsewhere.
      onTabRequested: function(direction) {
        var n = keyCatcher.activeFocus ? null : keyCatcher.nextItemInFocusChain(direction > 0)
        if (n && n !== keyCatcher) n.forceActiveFocus(Qt.TabFocusReason)
        else root.switchPanel(direction)
      }
      onMoveRequested: function(dx, dy) {
        var n = keyCatcher.nextItemInFocusChain(dy > 0 || dx > 0)
        if (n && n !== keyCatcher) n.forceActiveFocus(Qt.TabFocusReason)
      }
      Keys.onPressed: function(event) {
        if (root.finishCapture(event)) { event.accepted = true; return }
        if (clearDialog.handleKey(event)) event.accepted = true
      }

      ConfirmDialog {
        id: clearDialog
        anchors.fill: parent
        z: 10
        opened: root.clearConfirm
        message: "Delete every recording and its text?"
        confirmText: "Delete all"
        selectedIndex: 0
        foreground: root.fg
        fontFamily: root.fontFamily
        onCanceled: root.clearConfirm = false
        onConfirmed: { root.clearConfirm = false; if (root.svc) root.svc.clearHistory() }
      }
      Connections { target: root; function onClearConfirmChanged() { if (root.clearConfirm) { clearDialog.selectedIndex = 0; keyCatcher.forceActiveFocus() } } }

      // ---------- Fixed top: hero · live text · error · language · tabs ----------
      Column {
        id: topBlock
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(10)

        PanelHero {
          width: parent.width
          title: "Speech to Text"
          meta: root.subtitle()
          detail: root.connected ? root.keyFor(root.defaultLang) : ""
          foreground: root.fg
          fontFamily: root.fontFamily
          iconComponent: Component {
            Text {
              text: "󰍬"
              color: root.recording ? root.takeColor : root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
          trailingControl: Component {
            Row {
              spacing: Style.space(4)
              PanelActionButton {
                visible: root.busy
                iconText: "󰜺"
                tooltipText: "Discard this recording"
                foreground: root.fg
                hoverColor: Color.urgent
                fontFamily: root.fontFamily
                onClicked: if (root.svc) root.svc.cancel()
              }
              Button {
                text: root.recording ? "Stop" : root.transcribing ? "Working…" : "Dictate"
                enabled: root.connected && !root.transcribing
                foreground: root.fg
                fontFamily: root.fontFamily
                bordered: true
                // The text is pasted into the focused window, so the popup gets out of the way first.
                onClicked: root.closeThen(function() { if (root.svc) root.svc.toggle(null, false) })
              }
            }
          }
        }

        // A stock machine may not have the dictation engine yet: say so, and install it from here.
        Rectangle {
          width: parent.width
          visible: root.connected && root.svc.missing.length > 0
          height: missingCol.implicitHeight + Style.space(16)
          radius: Style.cornerRadius
          color: Style.normalFillFor(root.fg, Color.accent)
          Column {
            id: missingCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Style.space(8)
            spacing: Style.space(6)
            Text {
              width: parent.width
              text: "Dictation needs " + (root.svc ? root.svc.missing.join(", ") : "") + " to be installed. Omarchy's installer takes care of it (about 150 MB, asks for your password)."
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.Wrap
            }
            Button {
              text: "Install"
              iconText: "󰇚"
              foreground: root.fg
              fontFamily: root.fontFamily
              bordered: true
              onClicked: { if (root.svc) root.svc.install(); root.close() }
            }
          }
        }

        Text {
          width: parent.width
          visible: root.busy
          text: root.liveTail
          color: root.livePlaceholder ? root.dim : root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.italic: root.livePlaceholder
          wrapMode: Text.Wrap
        }

        Row {
          width: parent.width
          visible: root.svc && root.svc.error !== ""
          spacing: Style.space(6)
          Text {
            width: parent.width - errClear.width - parent.spacing
            text: root.svc ? root.svc.error : ""
            color: Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
            anchors.verticalCenter: parent.verticalCenter
          }
          PanelActionButton {
            id: errClear
            iconText: "󰅖"
            tooltipText: "Dismiss"
            foreground: root.fg
            fontFamily: root.fontFamily
            onClicked: if (root.svc) root.svc.clearError()
          }
        }

        // ---------- Tabs: History · Settings ----------
        Item {
          id: tabStrip
          width: parent.width
          height: Style.space(26)
          PanelSeparator {  // baseline the active tab's underline sits on
            anchors.bottom: parent.bottom
            foreground: root.fg
          }
          Row {
            anchors.fill: parent
            Repeater {
              model: root.tabs
              delegate: Item {
                id: tabItem
                required property var modelData
                readonly property bool current: root.tab === tabItem.modelData.key
                width: tabStrip.width / root.tabs.length
                height: tabStrip.height
                Text {
                  id: tabLabel
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.verticalCenterOffset: -Style.space(1)
                  text: tabItem.modelData.label
                  color: tabItem.current ? Color.accent : (tabArea.containsMouse ? root.fg : root.dim)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: tabItem.current
                }
                Rectangle {  // a dot on Settings while a key could not be applied
                  anchors.left: tabLabel.right
                  anchors.leftMargin: Style.space(3)
                  anchors.top: tabLabel.top
                  anchors.topMargin: Style.space(2)
                  width: Style.space(4); height: width
                  radius: width / 2
                  color: Color.urgent
                  visible: tabItem.modelData.key === "settings" && root.conflicts.length > 0 && !tabItem.current
                }
                Rectangle {  // 2px accent underline under the active label
                  anchors.bottom: parent.bottom
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: Math.round(tabLabel.implicitWidth) + Style.space(12)
                  height: Style.space(2)
                  radius: height / 2
                  color: Color.accent
                  visible: tabItem.current
                }
                MouseArea {
                  id: tabArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.tab = tabItem.modelData.key
                }
              }
            }
          }
        }
      }

      // ---------- Scrolling body: the active tab ----------
      ScrollView {
        id: scrollArea
        anchors.top: topBlock.bottom
        anchors.topMargin: Style.space(10)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        readonly property bool overflows: body.implicitHeight > height + 1
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: overflows ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        // The Flickable takes the wheel only while there is something to
        // scroll, so a short tab never bounces; no fling inertia, so the wheel
        // moves the page and stops when the finger does.
        Binding { target: scrollArea.contentItem; property: "interactive"; value: scrollArea.overflows }
        Binding { target: scrollArea.contentItem; property: "flickDeceleration"; value: 20000 }
        Binding { target: scrollArea.contentItem; property: "maximumFlickVelocity"; value: 1500 }
        Binding { target: scrollArea.contentItem; property: "boundsBehavior"; value: Flickable.StopAtBounds }

        Item {
          id: body
          width: scrollArea.availableWidth
          implicitWidth: width
          implicitHeight: historyLoader.active ? historyLoader.implicitHeight : settingsLoader.implicitHeight
          Loader { id: historyLoader; width: body.width; active: root.opened && root.tab === "history"; sourceComponent: historyView; visible: active }
          Loader { id: settingsLoader; width: body.width; active: root.opened && root.tab === "settings"; sourceComponent: settingsView; visible: active }
        }
      }
    }
  }

  // ======================= shared rows =======================
  // One compact settings row: label on the left, switch on the right.
  component SwitchRow: Item {
    id: sw
    property string label: ""
    property string summary: ""     // dim caption before the switch
    property bool checked: false
    property bool enabled: root.connected
    signal toggled()
    width: parent ? parent.width : 200
    height: root.rowH
    opacity: enabled ? 1 : 0.5
    Text {
      id: swSummary
      anchors.right: swToggle.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      visible: sw.summary !== ""
      text: sw.summary
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
      width: Math.min(implicitWidth, sw.width * 0.5)
      horizontalAlignment: Text.AlignRight
    }
    Text {
      anchors.left: parent.left
      anchors.right: sw.summary !== "" ? swSummary.left : swToggle.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: sw.label
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }
    ToggleSwitch {
      id: swToggle
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      cursorPad: root.trailInset
      checked: sw.checked
      interactive: sw.enabled
      foreground: root.fg
      onToggled: sw.toggled()
    }
    MouseArea {  // the whole row toggles, like a real settings list
      anchors.fill: parent
      anchors.rightMargin: swToggle.width
      enabled: sw.enabled
      onClicked: sw.toggled()
    }
  }

  component RowLabel: Text {
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    width: root.labelW
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    elide: Text.ElideRight
  }

  component Note: Text {
    width: parent ? parent.width : 200
    color: root.fg
    opacity: 0.6
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.Wrap
  }

  component Section: Column {
    property string title: ""
    width: parent ? parent.width : 200
    spacing: Style.space(10)
    PanelSeparator { width: parent.width; foreground: root.fg }
    PanelSectionHeader { text: parent.title; foreground: root.fg; fontFamily: root.fontFamily }
  }

  // A text field that follows a config value but never overwrites what the
  // user is typing: it re-reads the value only while unfocused, commits on
  // Enter / focus loss, Esc puts the old value back, Tab moves on.
  component ConfigField: TextField {
    id: cf
    property string key: ""
    property var current: root.cfg[key]
    property var commit: null   // function(text) -> bool; default: setSetting(key, text)
    foreground: root.fg
    enabled: root.connected
    opacity: enabled ? 1 : 0.5
    onCurrentChanged: if (!activeFocus) text = current === undefined || current === null ? "" : String(current)
    Component.onCompleted: text = current === undefined || current === null ? "" : String(current)
    function revert() { text = current === undefined || current === null ? "" : String(current) }
    onEditingFinished: {
      var v = text
      if (String(current === undefined || current === null ? "" : current) === v) return
      var ok = commit ? commit(v) : (root.svc ? root.svc.setSetting(key, v) : false)
      if (ok === false) revert()
    }
    Keys.onEscapePressed: function(e) { revert(); keyCatcher.forceActiveFocus(); e.accepted = true }
    Keys.onTabPressed: function(e) { var n = cf.nextItemInFocusChain(true); if (n) n.forceActiveFocus(Qt.TabFocusReason); e.accepted = true }
    Keys.onBacktabPressed: function(e) { var n = cf.nextItemInFocusChain(false); if (n) n.forceActiveFocus(Qt.BacktabFocusReason); e.accepted = true }
  }

  // ======================= History =======================
  Component {
    id: historyView
    Column {
      spacing: Style.space(8)

      TextField {
        id: search
        width: parent.width - root.trailInset
        placeholderText: "Search recordings…"
        foreground: root.fg
        onTextEdited: searchDebounce.restart()
        Timer { id: searchDebounce; interval: 250; onTriggered: if (root.svc) root.svc.loadHistory(search.text) }
        Keys.onEscapePressed: function(e) { if (text !== "") { text = ""; if (root.svc) root.svc.loadHistory(""); e.accepted = true } }
      }

      ListView {
        id: list
        width: parent.width
        height: Math.max(Style.space(60), Math.min(contentHeight, Style.space(400)))
        clip: true
        spacing: Style.space(6)
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        flickDeceleration: 20000
        maximumFlickVelocity: 1500
        model: root.svc ? root.svc.historyItems : []
        ScrollBar.vertical: ScrollBar { policy: list.interactive ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
        // The daemon replaces the whole list on every change; keep the scroll position.
        property real keepY: 0
        onModelChanged: Qt.callLater(function() { if (keepY <= contentHeight - height) contentY = keepY })
        onContentYChanged: if (!moving || dragging || flicking) keepY = contentY

        Text {
          anchors.centerIn: parent
          width: parent.width - Style.space(20)
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
          visible: list.count === 0
          text: !root.connected ? "Waiting for the daemon…"
              : root.svc && root.svc.historyQuery !== "" ? "No matches"
              : root.keyFor(root.defaultLang) !== "" ? "No recordings yet — press " + root.keyFor(root.defaultLang) + " and talk"
              : "No recordings yet — click Dictate, or set a key in Settings"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        delegate: Rectangle {
          id: row
          required property var modelData
          required property int index
          readonly property bool expandedRow: root.expandedTake === modelData.id
          readonly property bool playingRow: root.svc && root.svc.playing === modelData.id
          width: list.width - (list.interactive ? Style.space(8) : root.trailInset)
          height: rowCol.implicitHeight + Style.space(12)
          radius: Style.cornerRadius
          color: rowHover.hovered ? Style.hoverFillFor(root.fg, Color.accent) : Style.normalFillFor(root.fg, Color.accent)
          HoverHandler { id: rowHover }
          property bool copied: false
          Timer { id: copiedTimer; interval: 1200; onTriggered: row.copied = false }

          Column {
            id: rowCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.space(6)
            spacing: Style.space(3)

            Row {
              width: parent.width
              spacing: Style.space(4)
              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - actions.width - parent.spacing
                text: root.when(row.modelData.createdAt) + " · " + root.langName(row.modelData.lang) + " · " + root.clock(row.modelData.duration)
                      + (row.modelData.audio === "" ? " · no audio" : "")
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
              Row {
                id: actions
                spacing: 0
                PanelActionButton {
                  iconText: row.playingRow ? "󰓛" : "󰐊"
                  tooltipText: row.playingRow ? "Stop" : "Play"
                  enabled: row.modelData.audio !== ""
                  opacity: enabled ? 1 : 0.35
                  foreground: row.playingRow ? Color.accent : root.fg
                  fontFamily: root.fontFamily
                  onClicked: if (root.svc) { if (row.playingRow) root.svc.stopPlay(); else root.svc.play(row.modelData.id) }
                }
                PanelActionButton {
                  iconText: row.copied ? "󰄬" : "󰆏"
                  tooltipText: "Copy"
                  foreground: row.copied ? Color.accent : root.fg
                  fontFamily: root.fontFamily
                  onClicked: { if (root.svc) root.svc.copyTake(row.modelData.id); row.copied = true; copiedTimer.restart() }
                }
                PanelActionButton {
                  iconText: "󰆴"
                  tooltipText: "Delete"
                  foreground: root.fg
                  hoverColor: Color.urgent
                  fontFamily: root.fontFamily
                  onClicked: if (root.svc) root.svc.deleteTake(row.modelData.id)
                }
              }
            }

            Text {
              id: takeText
              width: parent.width
              text: row.modelData.text
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.Wrap
              maximumLineCount: row.expandedRow ? 400 : 3
              elide: Text.ElideRight
              MouseArea {
                anchors.fill: parent
                cursorShape: (takeText.truncated || row.expandedRow) ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.expandedTake = row.expandedRow ? 0 : row.modelData.id
              }
            }
            Text {
              visible: takeText.truncated || row.expandedRow
              text: row.expandedRow ? "less" : "more…"
              color: Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.expandedTake = row.expandedRow ? 0 : row.modelData.id }
            }
          }
        }
      }

      Row {
        width: parent.width - root.trailInset
        spacing: Style.space(6)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - clearBtn.width - parent.spacing
          text: {
            var total = root.svc ? root.svc.historyTotal : 0, shown = list.count
            if (root.svc && root.svc.historyQuery !== "") return shown + " of " + total + " recordings match"
            if (shown < total) return "showing " + shown + " of " + total + " recordings"
            return total + " recording" + (total === 1 ? "" : "s")
          }
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
        Button {
          id: clearBtn
          text: "Clear all"
          enabled: root.svc && root.svc.historyTotal > 0
          foreground: root.fg
          fontFamily: root.fontFamily
          onClicked: root.clearConfirm = true
        }
      }
    }
  }

  // ======================= Settings =======================
  Component {
    id: settingsView
    Column {
      id: settings
      spacing: Style.space(14)
      readonly property bool pickerOpen: addPicker.popupOpen

      // ---------- Languages: one row each; the first is the default ----------
      Column {
        width: parent.width
        spacing: Style.space(10)
        PanelSectionHeader { text: "LANGUAGES"; foreground: root.fg; fontFamily: root.fontFamily }

        readonly property int keyW: Style.space(108)
        readonly property int sendW: Style.space(70)
        readonly property int actW: Style.space(72)

        Row {   // column headings
          width: parent.width - root.trailInset
          spacing: Style.space(8)
          Item { width: parent.width - parent.parent.keyW * 2 - parent.parent.sendW - parent.parent.actW - parent.spacing * 4; height: 1 }
          Text { width: parent.parent.keyW; text: "DICTATE"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
          Text { width: parent.parent.sendW; text: "+ RETURN"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
          Text { width: parent.parent.keyW; text: "ASK " + root.agentName; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
        }

        Repeater {
          model: root.langs
          Rectangle {
            id: langRow
            required property var modelData
            required property int index
            readonly property bool armedKey: root.captureIndex === index && root.captureField === "key"
            readonly property bool armedAgent: root.captureIndex === index && root.captureField === "agentKey"
            readonly property var cols: parent
            width: parent.width - root.trailInset
            height: root.rowH + Style.space(8)
            radius: Style.cornerRadius
            color: (armedKey || armedAgent) ? Style.selectedFillFor(root.fg, Color.accent) : langHover.hovered ? Style.hoverFillFor(root.fg, Color.accent) : Style.normalFillFor(root.fg, Color.accent)
            HoverHandler { id: langHover }

            Row {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(2)
              spacing: Style.space(8)

              Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - langRow.cols.keyW * 2 - langRow.cols.sendW - langRow.cols.actW - parent.spacing * 4
                Text {
                  width: parent.width
                  text: root.langTitle(langRow.modelData)
                  color: root.fg
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                }
                Text {
                  visible: langRow.index === 0
                  text: "default"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              // Keys: click to capture the next key press, right-click to clear.
              Button {
                anchors.verticalCenter: parent.verticalCenter
                width: langRow.cols.keyW
                text: langRow.armedKey ? "Press…" : (langRow.modelData.key ? langRow.modelData.key : "Set")
                selected: langRow.armedKey
                enabled: root.connected
                foreground: langRow.modelData.key || langRow.armedKey ? root.fg : root.dim
                fontFamily: root.fontFamily
                bordered: true
                tooltipText: langRow.armedKey ? "Press a key · Backspace clears · Esc cancels" : "Dictate: press to start, again to stop and paste"
                onClicked: { if (langRow.armedKey) root.endCapture(); else root.startCapture(langRow.index, "key") }
                onRightClicked: { root.endCapture(); root.patchLang(langRow.index, "key", "") }
              }

              Item {
                width: langRow.cols.sendW
                height: root.rowH
                ToggleSwitch {
                  anchors.centerIn: parent
                  cursorPad: root.trailInset
                  checked: !!langRow.modelData.autoSend
                  interactive: root.connected
                  foreground: root.fg
                  onToggled: root.patchLang(langRow.index, "autoSend", !langRow.modelData.autoSend)
                }
              }

              Button {
                anchors.verticalCenter: parent.verticalCenter
                width: langRow.cols.keyW
                text: langRow.armedAgent ? "Press…" : (langRow.modelData.agentKey ? langRow.modelData.agentKey : "Set")
                selected: langRow.armedAgent
                enabled: root.connected
                foreground: langRow.modelData.agentKey || langRow.armedAgent ? root.fg : root.dim
                fontFamily: root.fontFamily
                bordered: true
                tooltipText: langRow.armedAgent ? "Press a key · Backspace clears · Esc cancels" : "Ask " + root.agentName + ": the text opens your default coding agent instead of being pasted"
                onClicked: { if (langRow.armedAgent) root.endCapture(); else root.startCapture(langRow.index, "agentKey") }
                onRightClicked: { root.endCapture(); root.patchLang(langRow.index, "agentKey", "") }
              }

              Row {
                anchors.verticalCenter: parent.verticalCenter
                width: langRow.cols.actW
                spacing: 0
                PanelActionButton {
                  iconText: "󰅃"
                  tooltipText: langRow.index === 1 ? "Make default" : "Move up"
                  enabled: langRow.index > 0
                  opacity: enabled ? 1 : 0.25
                  foreground: root.fg
                  fontFamily: root.fontFamily
                  onClicked: root.moveLang(langRow.index, -1)
                }
                PanelActionButton {
                  iconText: "󰅀"
                  tooltipText: "Move down"
                  enabled: langRow.index < root.langs.length - 1
                  opacity: enabled ? 1 : 0.25
                  foreground: root.fg
                  fontFamily: root.fontFamily
                  onClicked: root.moveLang(langRow.index, 1)
                }
                PanelActionButton {
                  iconText: "󰆴"
                  tooltipText: "Remove language"
                  enabled: root.langs.length > 1
                  opacity: enabled ? 1 : 0.25
                  foreground: root.fg
                  hoverColor: Color.urgent
                  fontFamily: root.fontFamily
                  onClicked: root.removeLang(langRow.index)
                }
              }
            }
          }
        }

        SearchableDropdown {
          id: addPicker
          width: parent.width - root.trailInset
          showLabel: false
          triggerLabel: "Add a language…"
          placeholderText: "Search languages…"
          value: ""
          options: root.addableLangs
          foreground: root.fg
          fontFamily: root.fontFamily
          onChanged: function(v) { root.addLang(v); value = "" }
        }

        Note {
          visible: root.captureNote !== "" || root.conflicts.length > 0
          text: root.captureNote !== "" ? root.captureNote : root.conflictText()
          color: Color.urgent
          opacity: 1
        }
        Note { text: "The first entry is the default. + Return also presses Return after pasting. Add the same language twice for one key that sends and one that does not. Esc discards while recording." }
      }

      // ---------- The two switches that matter ----------
      Section {
        title: "RECORDING"
        SwitchRow {
          label: "Live text while talking"
          summary: checked ? "uses CPU while recording" : ""
          checked: root.cfg.liveText !== false
          onToggled: if (root.svc) root.svc.setSetting("liveText", root.cfg.liveText === false)
        }
        SwitchRow {
          label: "Keep the audio of every recording"
          checked: root.cfg.keepAudio !== false
          onToggled: if (root.svc) root.svc.setSetting("keepAudio", root.cfg.keepAudio === false)
        }
        // Bar animation: four live tiles, each showing its style with a pretend voice.
        Column {
          id: animCol
          width: parent.width
          spacing: Style.space(6)
          Text { text: "Bar animation"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.body }

          // A synthetic voice envelope shared by the previews: phrases with pauses.
          property var demoLevels: []
          property real demoT: 0
          Timer {
            interval: 50
            repeat: true
            running: settingsLoader.active && root.opened
            onTriggered: {
              var col = animCol
              col.demoT += 0.05
              var phrase = (Math.sin(col.demoT * 0.9) + 1) / 2 > 0.35          // talking vs. a pause
              var v = phrase ? 0.25 + 0.55 * Math.abs(Math.sin(col.demoT * 7.3) * Math.sin(col.demoT * 2.1)) + Math.random() * 0.15 : 0.03 + Math.random() * 0.04
              var lv = col.demoLevels.slice(-47)
              lv.push(Math.min(1, v))
              col.demoLevels = lv
            }
          }

          Row {
            width: parent.width - root.trailInset
            spacing: Style.space(8)
            Repeater {
              model: [ { key: "bars", label: "Bars" }, { key: "wave", label: "Wave" }, { key: "pulse", label: "Pulse" }, { key: "dots", label: "Dots" } ]
              Rectangle {
                id: tile
                required property var modelData
                readonly property bool current: String(root.cfg.animation || "bars") === modelData.key
                width: (parent.width - parent.spacing * 3) / 4
                height: Style.space(52)
                radius: Style.cornerRadius
                color: current ? Style.selectedFillFor(root.fg, Color.accent) : tileHover.hovered ? Style.hoverFillFor(root.fg, Color.accent) : Style.normalFillFor(root.fg, Color.accent)
                border.width: current ? 1 : 0
                border.color: Color.accent
                HoverHandler { id: tileHover }
                Column {
                  anchors.centerIn: parent
                  spacing: Style.space(6)
                  Waveform {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: Style.bar.iconCanvas
                    style: tile.modelData.key
                    bars: 18
                    levels: animCol.demoLevels
                    color: root.green
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: tile.modelData.label
                    color: tile.current ? Color.accent : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: tile.current
                  }
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  enabled: root.connected
                  onClicked: if (root.svc) root.svc.setSetting("animation", tile.modelData.key)
                }
              }
            }
          }
        }
        Row {
          width: parent.width
          spacing: Style.space(8)
          RowLabel { text: "Keep history" }
          Dropdown {
            width: parent.width - root.labelW - parent.spacing - root.trailInset
            showLabel: false
            enabled: root.connected
            value: String(root.cfg.historyDays === undefined ? 30 : root.cfg.historyDays)
            options: [ { value: "1", label: "For a day" }, { value: "7", label: "For a week" }, { value: "30", label: "For a month" },
                       { value: "90", label: "For 3 months" }, { value: "365", label: "For a year" }, { value: "0", label: "Forever" } ]
            foreground: root.fg
            fontFamily: root.fontFamily
            onChanged: function(v) { if (root.svc) root.svc.setSetting("historyDays", parseInt(v)); value = Qt.binding(function() { return String(root.cfg.historyDays === undefined ? 30 : root.cfg.historyDays) }) }
          }
        }
        Note { text: "Older recordings and their audio are deleted automatically." }
      }

      // ---------- Advanced (collapsed) ----------
      Column {
        width: parent.width
        spacing: Style.space(10)
        PanelSeparator { width: parent.width; foreground: root.fg }
        Item {
          width: parent.width
          height: root.rowH
          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: (root.advancedOpen ? "󰅀 " : "󰅂 ") + "Advanced"
            color: advHover.hovered ? root.fg : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
          HoverHandler { id: advHover }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.advancedOpen = !root.advancedOpen }
        }

        Column {
          width: parent.width
          spacing: Style.space(10)
          visible: root.advancedOpen

          Row {
            width: parent.width
            spacing: Style.space(8)
            RowLabel { text: "Recognition" }
            Dropdown {
              width: parent.width - root.labelW - parent.spacing - root.trailInset
              showLabel: false
              enabled: root.connected
              value: String(root.cfg.engine || "voxtype")
              options: root.engineOpts
              foreground: root.fg
              fontFamily: root.fontFamily
              onChanged: function(v) { if (root.svc) root.svc.setSetting("engine", v); value = Qt.binding(function() { return String(root.cfg.engine || "voxtype") }) }
            }
          }
          Note {
            visible: root.cfg.engine === "voxtype" || !root.cfg.engine
            text: "Uses Omarchy's dictation model (change it with omarchy-voxtype-model). English-only models are swapped for the multilingual one automatically."
          }
          Row {
            width: parent.width
            spacing: Style.space(8)
            visible: root.cfg.engine === "command"
            RowLabel { text: "Command" }
            ConfigField {
              width: parent.width - root.labelW - parent.spacing - root.trailInset
              placeholderText: "whisper-cli -m model.bin -l {lang} -nt -np -f {file}"
              key: "engineCommand"
            }
          }
          Note { visible: root.cfg.engine === "command"; text: "{file} is a 16 kHz mono WAV, {lang} the language code; stdout is the text." }
          Row {
            width: parent.width
            spacing: Style.space(8)
            visible: root.cfg.engine === "whisper-cpp"
            RowLabel { text: "Model" }
            ConfigField {
              width: parent.width - root.labelW - parent.spacing - root.trailInset
              placeholderText: "~/.local/share/voxtype/models/ggml-base.bin"
              key: "whisperModel"
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(8)
            RowLabel { text: "After recording" }
            Dropdown {
              width: parent.width - root.labelW - parent.spacing - root.trailInset
              showLabel: false
              enabled: root.connected
              value: String(root.cfg.outputMode || "paste")
              options: [ { value: "paste", label: "Paste at the cursor" }, { value: "type", label: "Type it out key by key" }, { value: "clipboard", label: "Copy to the clipboard only" } ]
              foreground: root.fg
              fontFamily: root.fontFamily
              onChanged: function(v) { if (root.svc) root.svc.setSetting("outputMode", v); value = Qt.binding(function() { return String(root.cfg.outputMode || "paste") }) }
            }
          }
          Row {
            width: parent.width
            spacing: Style.space(8)
            visible: (root.cfg.outputMode || "paste") === "paste"
            RowLabel { text: "Paste keys" }
            Dropdown {
              width: parent.width - root.labelW - parent.spacing - root.trailInset
              showLabel: false
              enabled: root.connected
              value: String(root.cfg.pasteKeys || "auto")
              options: [ { value: "auto", label: "Auto (Ctrl+Shift+V in terminals, Ctrl+V elsewhere)" }, { value: "ctrl+v", label: "Ctrl+V" }, { value: "ctrl+shift+v", label: "Ctrl+Shift+V" }, { value: "shift+insert", label: "Shift+Insert" } ]
              foreground: root.fg
              fontFamily: root.fontFamily
              onChanged: function(v) { if (root.svc) root.svc.setSetting("pasteKeys", v); value = Qt.binding(function() { return String(root.cfg.pasteKeys || "auto") }) }
            }
          }
          SwitchRow {
            visible: (root.cfg.outputMode || "paste") === "paste"
            label: "Restore the clipboard after pasting"
            checked: root.cfg.restoreClipboard !== false
            onToggled: if (root.svc) root.svc.setSetting("restoreClipboard", root.cfg.restoreClipboard === false)
          }
          SwitchRow {
            label: "Notify when a recording fails"
            checked: root.cfg.notify !== false
            onToggled: if (root.svc) root.svc.setSetting("notify", root.cfg.notify === false)
          }
          Row {
            width: parent.width
            spacing: Style.space(8)
            RowLabel { text: "Max recording (s)" }
            NumberField {
              anchors.verticalCenter: parent.verticalCenter
              enabled: root.connected
              value: Number(root.cfg.maxDurationSecs || 300)
              from: 5
              to: 3600
              stepSize: 5
              foreground: root.fg
              fontFamily: root.fontFamily
              onModified: function(v) { if (root.svc) root.svc.setSetting("maxDurationSecs", v) }
            }
          }
          Row {
            width: parent.width
            spacing: Style.space(8)
            RowLabel { text: "Microphone" }
            Dropdown {
              width: parent.width - root.labelW - parent.spacing - root.trailInset
              showLabel: false
              enabled: root.connected
              value: String(root.cfg.device || "default")
              options: root.micOpts
              foreground: root.fg
              fontFamily: root.fontFamily
              onChanged: function(v) { if (root.svc) root.svc.setSetting("device", v); value = Qt.binding(function() { return String(root.cfg.device || "default") }) }
            }
          }
          Note { text: "A Bluetooth headset switches to its low-quality headset profile while its microphone is open, which pauses or degrades whatever it is playing. Pick another microphone here to avoid that." }
          Row {
            width: parent.width
            spacing: Style.space(8)
            RowLabel { text: "Keep mic open" }
            Dropdown {
              width: parent.width - root.labelW - parent.spacing - root.trailInset
              showLabel: false
              enabled: root.connected
              readonly property string mode: !root.cfg.warmMic ? "off" : String(root.cfg.warmHoldSecs || 0)
              value: mode
              options: [ { value: "off", label: "No — open it on each key press" }, { value: "120", label: "For 2 minutes after a recording" },
                         { value: "600", label: "For 10 minutes after a recording" }, { value: "0", label: "Always" } ]
              foreground: root.fg
              fontFamily: root.fontFamily
              onChanged: function(v) {
                if (root.svc) root.svc.setConfig(v === "off" ? { warmMic: false } : { warmMic: true, warmHoldSecs: parseInt(v) })
                value = Qt.binding(function() { return mode })
              }
            }
          }
          Note { text: "While the microphone is kept open a recording starts instantly and even includes the half second before the key press. A Bluetooth headset stays in headset mode (call-quality sound) for that time, so with one, prefer a timed option." }
          Row {
            width: parent.width
            spacing: Style.space(8)
            RowLabel { text: "Agent command" }
            ConfigField {
              width: parent.width - root.labelW - parent.spacing - root.trailInset
              placeholderText: "omarchy-agent-prompt {text}"
              key: "agentCommand"
            }
          }
          Note { text: "Runs with {text} replaced by the (quoted) transcription. The default opens Omarchy's default agent (" + root.agentName + ", set with: omarchy default agent <name>)." }
          Note { text: "Saved to ~/.config/speech-to-text/config.json; key bindings apply immediately." }
        }
      }
    }
  }
}
