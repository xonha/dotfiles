// Derived from the `omarchy.audio` panel plugin in Omarchy
// (https://github.com/basecamp/omarchy) — Copyright (c) David Heinemeier
// Hansson, MIT. Audio Plus additions are marked with `Audio Plus` comments;
// see LICENSE and README.md.

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.Ui
import qs.Commons
import "Model.js" as Model

Panel {
  id: root
  moduleName: "rtome85.audio-plus"
  // Distinct from omarchy.audio's target so both plugins can be installed at
  // once without their IpcHandlers colliding.
  ipcTarget: "audio-plus"

  // ---- Audio Plus state -------------------------------------------------
  //
  // Audio Plus: the panel shows one list at a time. OUTPUT, INPUT and SOURCES
  // become a switch rather than three stacked sections, which is what gives the
  // panel one predictable shape instead of a height that depends on how many
  // sinks are plugged in and what is playing.
  property string activeTab: "output"

  // ---- mockup metrics ----------------------------------------------------
  //
  // The design's own numbers, in one place so they can be checked against it
  // rather than hunted through the file. Everything is expressed through
  // Style.space so a theme's spacing scale still moves them together, and the
  // two type sizes the design uses that no token carries are derived from the
  // body size so they track [font] base-size the same way the tokens do.
  //
  // The padding the card used to apply for us, now applied by the stage and
  // the drawer so the artwork and the switch can bleed past it.
  readonly property int contentInset: Style.spacing.panelPadding      // 18
  readonly property int stageHeight: Style.space(205)
  // Without a session there is no artwork and no track, so the part of the stage
  // under the mark keeps only the level and its status line, and shrinks to 114.
  // The mark band above it does not shrink with it: it is the same band, in the
  // same place, in both states.
  readonly property int stageIdleHeight: Style.space(114)
  readonly property int stageIdleTopInset: Style.space(25)
  readonly property int stageIdleGap: Style.space(7)
  // The mark band — the design's hero. Its own height is what centres the mark
  // and the switch, so the two are given the band and not each other, and it is
  // what the scrim under them is measured off.
  readonly property int markBandHeight: Style.space(54)
  // How far past the band its scrim takes to disappear. Long enough that the
  // ramp reads as light falling off the top of the artwork rather than as an
  // edge drawn across it.
  readonly property int markScrimFalloff: Style.space(20)
  readonly property int markBandGap: Style.space(14)
  readonly property int markLabelGap: Style.space(3)
  // 24 in the design. Nerd Font glyphs draw visually smaller than their point
  // size, which is why the icon runs two pixels ahead of it.
  readonly property int markIconSize: Math.round(Style.font.body * 2.167)     // 26
  readonly property int markTextSize: Style.font.title                        // 14
  readonly property int stageTitleSize: Math.round(Style.font.body * 1.583)   // 19
  readonly property int stageLevelSize: Math.round(Style.font.body * 2.667)   // 32
  // Every slider in the panel wears the same knob. Setting it in one place is
  // what keeps the master level from being the only one that looks its own way.
  readonly property int sliderKnobSize: Style.space(14)
  readonly property int tabPadY: Style.space(9)
  readonly property int rowHeight: Style.space(32)
  readonly property int rowPadX: Style.space(10)
  readonly property int rowGap: Style.space(9)
  readonly property int profileRowHeight: Style.space(24)
  readonly property int profileIndent: Style.space(31)
  readonly property var tabs: ["output", "input", "streams"]
  function tabLabel(tab) {
    return tab === "output" ? "OUTPUT" : (tab === "input" ? "INPUT" : "SOURCES")
  }
  function tabCount(tab) {
    if (tab === "output") return displayAudioSinks.length
    if (tab === "input") return displayAudioSources.length
    return sourceRowCount
  }
  function setActiveTab(tab) {
    if (activeTab === tab) return
    activeTab = tab
    closeProfiles()
    expandedSourceKey = ""
    // Land on the new list rather than leaving the cursor on a section that is
    // no longer drawn.
    if (cursorActive) {
      focusSection = tab
      selectedIndex = sectionHasSlider(tab) ? -1 : 0
      clampCursor()
    }
  }

  // Which SOURCES row has its media card open, keyed by PipeWire node id (or
  // MPRIS bus name for a player-only row) so the expansion survives the
  // display-model snapshot refresh below. One at a time: two open cards push
  // the rest of the panel off the bottom.
  property string expandedSourceKey: ""

  // Bluetooth codec picking. The open picker is identified by section plus the
  // PipeWire *device* id rather than by node: switching a profile destroys the
  // sink node and builds a new one, so a node-keyed picker would close itself
  // the moment it was used. Section is part of the key because one Bluetooth
  // card can own a row in OUTPUT and a row in INPUT at the same time, and only
  // the one that was clicked should fold open.
  property string expandedProfileSection: ""
  property string expandedProfileDevice: ""
  // device id -> { active: index, list: [profile] }, filled in lazily by
  // pw-dump the first time a device's picker is opened.
  property var deviceProfiles: ({})
  property string pendingProfileSection: ""
  property string pendingProfileDevice: ""

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
  // Materialized into a real JS array rather than passed through as
  // Mpris.players.values. That list fails Array.isArray across the QML/JS
  // engine boundary, and upstream's own Model helpers (mprisLabelsFor and
  // everything built on it) guard with Array.isArray -- so handing them the
  // raw list makes every MPRIS lookup silently see an empty list.
  readonly property var mprisPlayers: {
    var out = []
    var values = Mpris.players ? Mpris.players.values : []
    for (var i = 0; i < values.length; i++) out.push(values[i])
    return out
  }
  readonly property var mediaService: bar?.shell?.firstPartyServiceFor("omarchy.media")
  readonly property var activeMediaPlayer: mediaService ? mediaService.activePlayer : null

  // Audio Plus: the player the stage shows. The stage sits above the tab
  // switch and stays on screen whichever list is up, so media is never a tab
  // you have to go and find. Prefer the shell's active player so the stage and
  // the media bar widget always name the same one.
  // The PipeWire stream behind the stage's player, when it has one. A paused
  // browser tab has a session and no stream, so there is no level to read.
  readonly property var stageStreamNode: {
    if (!stagePlayer) return null
    for (var i = 0; i < displayAudioStreams.length; i++) {
      var n = displayAudioStreams[i]
      if (n && streamRepresentsPlayer(n, stagePlayer)) return n
    }
    return null
  }
  readonly property real stageStreamVolume: stageStreamNode && stageStreamNode.audio ? stageStreamNode.audio.volume : 0
  readonly property bool stageStreamMuted: stageStreamNode && stageStreamNode.audio ? stageStreamNode.audio.muted : false

  // The stage is drawn from the rows SOURCES itself lists, and from nothing
  // else. That is what keeps the two honest: the stage is one of those rows
  // shown large, its volume is set on that row, and when the tab is empty there
  // is nothing playing and the stage says so. Reading MPRIS directly here put
  // sessions on stage that SOURCES had already rejected -- a phantom with no
  // row anywhere to control it, beside a tab reading 0.
  readonly property var stagePlayer: {
    if (sourceRowCount === 0) return null
    var rows = []
    for (var i = 0; i < displayAudioStreams.length; i++) {
      var sp = streamPlayer(displayAudioStreams[i])
      if (sp) rows.push(sp)
    }
    for (var j = 0; j < displayOrphanPlayers.length; j++) rows.push(displayOrphanPlayers[j])
    if (rows.length === 0) return null
    // Prefer the one the rest of the shell considers active, so the stage and
    // the media bar widget always name the same player.
    for (var a = 0; a < rows.length; a++) {
      if (activeMediaPlayer && rows[a]
        && String(rows[a].dbusName) === String(activeMediaPlayer.dbusName)) return rows[a]
    }
    return rows[0]
  }

  readonly property var candidateSinks: {
    var list = []
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (n && n.isSink && !n.isStream) list.push(n)
    }
    return list
  }

  readonly property var candidateSources: {
    var list = []
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (n && !n.isSink && !n.isStream && isAudioSource(n)) {
        var name = n.name || ""
        if (name === "quickshell") continue
        list.push(n)
      }
    }
    return list
  }

  readonly property var candidateStreams: {
    var list = []
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (!n || !n.isStream || !isPlaybackStream(n)) continue
      // A tuning's output is a playback stream too, but it is the processing
      // itself rather than an application, so it does not belong in the list.
      if (String(n.name || "").indexOf("omarchy_speaker_tuning") === 0) continue
      list.push(n)
    }
    return list
  }

  property var sinkAvailability: ({})
  property bool sinkAvailabilityLoaded: false

  // Identify true playback streams without reading node.properties here:
  // PwNode.properties is invalid until the node is bound, and reading it while
  // capture streams are appearing (for example, when Voxtype starts recording)
  // can destabilize Quickshell's Pipewire service. Quickshell versions differ
  // in how `type` is exposed (media.class, enum name, or numeric enum), but
  // playback streams consistently accept audio input from clients and publish
  // `isSink: true`; capture streams publish as stream sources.
  function isPlaybackStream(node) {
    return Model.isPlaybackStream(node)
  }

  function isAudioSource(node) {
    return Model.isAudioSource(node)
  }

  property var cachedAudioSinks: []
  property var cachedAudioSources: []

  readonly property var rawAudioSinks: {
    var list = []
    for (var i = 0; i < candidateSinks.length; i++)
      if (sinkAvailable(candidateSinks[i])) list.push(candidateSinks[i])
    if (sink && list.indexOf(sink) < 0) list.unshift(sink)
    return list
  }

  readonly property var rawAudioSources: {
    var list = candidateSources.slice()
    if (source && list.indexOf(source) < 0) list.unshift(source)
    return list
  }

  readonly property var audioSinks: rawAudioSinks.length > 0 ? rawAudioSinks : cachedAudioSinks
  readonly property var audioSources: rawAudioSources.length > 0 ? rawAudioSources : cachedAudioSources

  readonly property var audioStreams: {
    var list = []
    for (var i = 0; i < candidateStreams.length; i++)
      if (candidateStreams[i].audio) list.push(candidateStreams[i])
    return list
  }

  // Feed Repeaters with panel-local snapshots instead of the live PipeWire
  // model. PipeWire can remove nodes while Quickshell is dispatching the
  // removal signal; rebuilding a Repeater from that signal path has crashed
  // in Quickshell's PipeWire service. The snapshot timer lets that mutation
  // settle first, and closed panels keep their repeaters detached entirely.
  property var displayAudioSinks: []
  property var displayAudioSources: []
  property var displayAudioStreams: []
  property var displayOrphanPlayers: []

  // MPRIS sessions with no playback stream to sit on. See Model.orphanPlayers.
  readonly property var orphanMediaPlayers: Model.orphanPlayers(mprisPlayers, audioStreams)

  // SOURCES renders streams first, then player-only rows; the keyboard cursor
  // walks that same combined order.
  readonly property int sourceRowCount: displayAudioStreams.length + displayOrphanPlayers.length

  // Audio Plus: a tab shows its whole list. Collapsing existed to keep a panel
  // short that was showing all three sections at once; showing one at a time
  // solves the same problem, and without a fold state to remember.
  readonly property var visibleAudioSinks: displayAudioSinks
  readonly property var visibleAudioSources: displayAudioSources

  // Rows each device section actually renders and the keyboard cursor walks:
  // the devices, plus the codec choices folded out under whichever one has its
  // picker open. Devices and codecs share one index space on purpose — that is
  // what lets j/k walk down into the picker and Enter apply, with no second
  // nested cursor to keep in sync.
  readonly property var outputRows: Model.deviceSectionRows(visibleAudioSinks,
    expandedProfileSection === "output" ? expandedProfileDevice : "", deviceProfiles)
  readonly property var inputRows: Model.deviceSectionRows(visibleAudioSources,
    expandedProfileSection === "input" ? expandedProfileDevice : "", deviceProfiles)

  // A DSP sink -- a speaker tuning, or EasyEffects -- can be the selected output
  // without being where loudness lives: changing its volume alters the level going
  // *into* the processing, so the slider would move while the speakers did not,
  // and on a chain with a limiter it would change the tone as well.
  //
  // omarchy-audio-output-sink resolves the *current* default output through any
  // such sink to the physical one, which is the same definition the volume keys
  // and the output switcher use. Resolving the default (rather than "whatever a
  // tuning fronts") is what keeps this correct when headphones or HDMI are
  // selected while a tuning still exists.
  property string volumeSinkName: ""

  // Carry sub-notch touchpad deltas between wheel events.
  property real wheelAccumulator: 0

  readonly property var volumeSink: {
    if (volumeSinkName === "" || !sink) return sink
    if (volumeSinkName === String(sink.name)) return sink
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (n && n.isSink && !n.isStream && String(n.name) === volumeSinkName && n.audio)
        return n
    }
    return sink
  }

  // Re-resolve whenever the selected output changes; the timer below is only a
  // safety net for the tuning being applied or removed underneath us.
  onSinkChanged: resolveVolumeSink()

  function resolveVolumeSink() {
    if (!volumeSinkProc.running) volumeSinkProc.running = true
  }

  readonly property real outputVolume: volumeSink && volumeSink.audio ? volumeSink.audio.volume : 0
  readonly property bool outputMuted: volumeSink && volumeSink.audio ? volumeSink.audio.muted : false
  readonly property real inputVolume: source && source.audio ? source.audio.volume : 0
  readonly property bool inputMuted: source && source.audio ? source.audio.muted : false

  onRawAudioSinksChanged: if (rawAudioSinks.length > 0) cachedAudioSinks = rawAudioSinks
  onRawAudioSourcesChanged: if (rawAudioSources.length > 0) cachedAudioSources = rawAudioSources

  // Single cursor model shared by keyboard and mouse. Sections:
  //   "output"  — output slider + sink device list
  //   "input"   — input slider + source device list
  //   "streams" — per-app playback streams
  // selectedIndex semantics within a section:
  //   -1            → on the slider row (h/l adjusts volume, m/Enter mute)
  //   0..N-1        → on the Nth device/stream row
  // Visuals derive from hasCursor/current via CursorSurface, never
  // from containsMouse — that's what keeps the highlight unique across
  // keyboard + mouse like wifi does.
  property string focusSection: "output"
  property int selectedIndex: -1
  property bool cursorActive: false

  // "header" is a virtual section for the hero output mute toggle; it sits
  // above the output section so the speaker can be muted from the keyboard.
  readonly property bool headerHasCursor: cursorActive && focusSection === "header"
  // Only channels that actually exist get a vote. A box with no default source
  // would otherwise report "input unmuted" forever, leaving the hero switch
  // able to mute but never to unmute.
  readonly property bool hasOutput: !!(volumeSink && volumeSink.audio)
  readonly property bool hasInput: !!(source && source.audio)
  readonly property bool anyAudible: (hasOutput && !outputMuted) || (hasInput && !inputMuted)
  readonly property string toggleHint: anyAudible ? "Mute" : "Unmute"

  readonly property color hoverFill: bar
    ? Style.hoverFillFor(bar.foreground, Color.accent)
    : "transparent"
  readonly property color selectedFill: bar
    ? Style.selectedFillFor(bar.foreground, Color.accent)
    : "transparent"

  function sectionCount(section) {
    if (section === "output") return outputRows.length
    if (section === "input") return inputRows.length
    if (section === "streams") return sourceRowCount
    return 0
  }

  function sectionVisible(section) {
    if (section === "output") return true
    if (section === "input") return displayAudioSources.length > 0 || !!source
    if (section === "streams") return sourceRowCount > 0
    return false
  }

  // Audio Plus: each tab owns its own levels. OUTPUT keeps the master slider,
  // INPUT its microphone one, and a SOURCES row carries its stream's inline --
  // so a level is only ever on screen while the list it belongs to is, and the
  // stage above is left to the one level you did not open the panel to set.
  function sectionHasSlider(section) {
    if (section === "output") return true
    if (section === "input") return !!source
    return false
  }

  // Order of visible sections, recomputed reactively so dropping a section
  // (e.g. no input devices) doesn't leave the cursor pointing at it.
  readonly property var visibleSections: sectionVisible(activeTab) ? [activeTab] : []

  function moveCursor(delta) {
    var sections = visibleSections
    if (sections.length === 0) return
    if (focusSection === "header") {
      if (delta > 0) { focusSection = sections[0]; selectedIndex = sectionHasSlider(sections[0]) ? -1 : 0 }
      return
    }
    var sIdx = sections.indexOf(focusSection)
    if (sIdx < 0) { focusSection = sections[0]; selectedIndex = sectionHasSlider(focusSection) ? -1 : 0; return }

    var idx = selectedIndex
    var max = sectionCount(focusSection) - 1  // last device index
    var hasSlider = sectionHasSlider(focusSection)
    var floor = hasSlider ? -1 : 0  // -1 = slider row

    if (delta > 0) {
      if (idx < max) { selectedIndex = idx + 1; return }
      // Fall through to next section.
      if (sIdx < sections.length - 1) {
        focusSection = sections[sIdx + 1]
        selectedIndex = sectionHasSlider(focusSection) ? -1 : 0
      }
    } else {
      if (idx > floor) { selectedIndex = idx - 1; return }
      // Escape upward.
      if (sIdx > 0) {
        focusSection = sections[sIdx - 1]
        var prevMax = sectionCount(focusSection) - 1
        selectedIndex = prevMax >= 0 ? prevMax : (sectionHasSlider(focusSection) ? -1 : 0)
      } else {
        focusSection = "header"
      }
    }
  }

  function setHeaderCursor() {
    cursorActive = true
    focusSection = "header"
    selectedIndex = -1
  }

  // Audio Plus: cycles the tab switch. Upstream used this to walk the stacked
  // sections, which no longer exist as a stack.
  function moveSection(delta) {
    var i = tabs.indexOf(activeTab)
    if (i < 0) i = 0
    setActiveTab(tabs[(i + delta + tabs.length) % tabs.length])
  }

  // Adjust the slider associated with the focused section. Output and
  // input sliders are real volume controls; on stream rows h/l adjusts
  // that stream's volume (so keyboard parity with the inline slider).
  //
  // On a device row h/l was a deliberate no-op upstream — the cursor is on a
  // discrete row, not on the slider, and silently moving the global slider
  // would surprise the user. Now that the device lists collapse, that free
  // binding becomes the tree-style expander: l opens the section, h closes
  // it. The global slider still never moves from a discrete row.
  function adjustVolume(delta) {
    if (focusSection === "output" && selectedIndex === -1) {
      setOutputVolume(outputVolume + delta)
      return
    }
    if (focusSection === "input" && selectedIndex === -1) {
      setInputVolume(inputVolume + delta)
      return
    }
    if ((focusSection === "output" || focusSection === "input") && selectedIndex >= 0) {
      // On a codec row h steps back out of the picker — the level above it is
      // the device list, which stays open. l has nothing further to open.
      if (rowIsProfile(focusSection, selectedIndex)) {
        if (delta < 0) closeProfiles()
        return
      }
      // A device row has no level to ride and, with the list always whole,
      // nothing to expand. h/l is already the panel's horizontal axis, so it
      // moves along the one horizontal control left: the tab switch.
      moveSection(delta)
      return
    }
    // Player-only rows have no stream, so no volume to ride: h/l is inert there.
    if (focusSection === "streams" && selectedIndex >= 0) {
      var s = sourceRowNode(selectedIndex)
      if (s && s.audio) s.audio.volume = Math.max(0, Math.min(1.5, s.audio.volume + delta))
    }
  }

  // Enter/Space: activate whatever the cursor is on.
  function activateCursor() {
    if (focusSection === "header") { toggleAllMuted(); return }
    if (focusSection === "output") {
      if (selectedIndex === -1) { toggleOutputMute(); return }
      var outRow = rowAt("output", selectedIndex)
      if (!outRow) return
      if (outRow.kind === "profile") setDeviceProfile(outRow.node, outRow.profile)
      else setDefaultSink(outRow.node)
      return
    }
    if (focusSection === "input") {
      if (selectedIndex === -1) { toggleInputMute(); return }
      var inRow = rowAt("input", selectedIndex)
      if (!inRow) return
      if (inRow.kind === "profile") setDeviceProfile(inRow.node, inRow.profile)
      else setDefaultSource(inRow.node)
      return
    }
    if (focusSection === "streams" && selectedIndex >= 0) {
      var st = sourceRowNode(selectedIndex)
      var sp = sourceRowPlayer(selectedIndex)
      // The row grows a chevron whenever there is a player behind it, so
      // Enter follows the chevron. Stream rows with no MPRIS session keep
      // upstream's meaning (mute), and 'm' still mutes those.
      if (sp) toggleSourceExpanded(st, sp)
      else if (st && st.audio) st.audio.muted = !st.audio.muted
    }
  }

  onOpenedChanged: {
    if (opened) {
      refreshDisplayAudioModels()
      activeTab = "output"
      focusSection = "output"
      selectedIndex = -1  // first keyboard cursor reveal starts on the master level
      cursorActive = false
      expandedSourceKey = ""
      expandedProfileSection = ""
      expandedProfileDevice = ""
      // Profiles are re-read per session: a device may have been switched from
      // elsewhere (wiremaze, pactl) while the panel was closed.
      deviceProfiles = ({})
      Qt.callLater(resetScroll)
    } else {
      clearDisplayAudioModels()
    }
  }

  // Clamp / repair the cursor whenever any list refreshes underneath us.
  onAudioSinksChanged: scheduleDisplayAudioModelRefresh()
  onAudioSourcesChanged: scheduleDisplayAudioModelRefresh()
  onAudioStreamsChanged: scheduleDisplayAudioModelRefresh()
  onOrphanMediaPlayersChanged: scheduleDisplayAudioModelRefresh()

  function listSnapshot(list) {
    return Model.listSnapshot(list)
  }

  function refreshDisplayAudioModels() {
    if (!opened) return
    displayAudioSinks = listSnapshot(audioSinks)
    displayAudioSources = listSnapshot(audioSources)
    displayAudioStreams = listSnapshot(audioStreams)
    displayOrphanPlayers = listSnapshot(orphanMediaPlayers)
    clampCursor()
  }

  function scheduleDisplayAudioModelRefresh() {
    if (!opened) return
    audioModelRefreshTimer.restart()
  }

  function clearDisplayAudioModels() {
    audioModelRefreshTimer.stop()
    displayAudioSinks = []
    displayAudioSources = []
    displayAudioStreams = []
    displayOrphanPlayers = []
  }

  // Keep the keyboard-focused row inside the visible viewport of the
  // ScrollView. Each cursor target (slider rows, SinkRow, SourceRow,
  // StreamRow) calls this when it gains hasCursor. Without it, j/k can
  // walk the selection off-screen — wifi uses ListView.positionViewAtIndex
  // for this; we don't have that affordance with a multi-section Column.
  function resetScroll() {
    if (!scrollArea) return
    var flick = scrollArea.contentItem
    if (flick && flick.contentY !== undefined) flick.contentY = 0
  }

  function ensureCursorVisible(item) {
    if (!item || !scrollArea) return
    var flick = scrollArea.contentItem
    if (!flick || flick.contentY === undefined) return
    var margin = 6
    var maxY = Math.max(0, (flick.contentHeight || 0) - flick.height)
    if (maxY <= Style.space(24)
      || (root.focusSection === "output" && root.selectedIndex === -1)) {
      flick.contentY = 0
      return
    }
    var pt = item.mapToItem(flick.contentItem || flick, 0, 0)
    var top = pt.y
    var bottom = top + (item.height || 0)
    var viewTop = flick.contentY
    var viewBottom = viewTop + flick.height
    if (top < viewTop + margin) flick.contentY = Math.max(0, Math.min(maxY, top - margin))
    else if (bottom > viewBottom - margin)
      flick.contentY = Math.max(0, Math.min(maxY, bottom + margin - flick.height))
  }

  function clampCursor() {
    var sections = visibleSections
    if (!sections || !sections.length) return
    // "header" is virtual and never appears in visibleSections, so it has to
    // be let through: muting republishes the PipeWire snapshot, and clamping
    // would knock the cursor off the hero switch on every toggle.
    if (focusSection === "header") return
    if (sections.indexOf(focusSection) < 0) {
      focusSection = visibleSections[0]
      selectedIndex = sectionHasSlider(focusSection) ? -1 : 0
      return
    }
    var count = sectionCount(focusSection)
    var hasSlider = sectionHasSlider(focusSection)
    var floor = hasSlider ? -1 : 0
    if (selectedIndex > count - 1) selectedIndex = Math.max(floor, count - 1)
    if (selectedIndex < floor) selectedIndex = floor
  }

  function outputIcon(volume) {
    // Match the old Waybar pulseaudio glyph set. The Material Design speaker
    // icons render visually smaller in JetBrainsMono Nerd Font.
    if (!sink || !sink.audio) return ""
    if (isHeadphones(sink)) return "󰋋"
    if (outputMuted) return ""
    var v = volume === undefined ? outputVolume : volume
    if (v >= 0.67) return ""
    if (v >= 0.34) return ""
    if (v > 0) return ""
    return ""
  }

  function inputIcon() {
    if (!source || !source.audio) return "󰍭"
    return inputMuted ? "󰍭" : "󰍬"
  }

  // Playful mood-name for a given output volume. Mirrors the brightness
  // panel's brightnessName ladder; bands are wide enough that small
  // tweaks don't rename the room you're in.
  function outputVolumeName(volume, muted) {
    return Model.outputVolumeName(volume, muted)
  }

  function setOutputVolume(v) {
    if (!volumeSink || !volumeSink.audio) return outputVolume
    var volume = Math.max(0, Math.min(1, v))
    volumeSink.audio.volume = volume
    return volume
  }

  function setInputVolume(v) {
    if (!source || !source.audio) return
    source.audio.volume = Math.max(0, Math.min(1, v))
  }

  function toggleOutputMute() {
    if (volumeSink && volumeSink.audio) volumeSink.audio.muted = !volumeSink.audio.muted
  }

  function toggleInputMute() {
    if (source && source.audio) source.audio.muted = !source.audio.muted
  }

  // The hero switch is the whole panel's on/off, so it carries both channels
  // at once. It reads as on while anything is still audible, which keeps
  // muting a single channel from the row below flipping the master switch.
  function toggleAllMuted() {
    var mute = anyAudible
    if (hasOutput) volumeSink.audio.muted = mute
    if (hasInput) source.audio.muted = mute
  }

  function setDefaultSink(node) {
    if (!node) return
    Pipewire.preferredDefaultAudioSink = node
    if (node.id !== undefined && node.name) {
      Quickshell.execDetached([
        "omarchy-audio-output-set-default",
        String(node.id),
        String(node.name)
      ])
    }
  }

  function setDefaultSource(node) {
    if (!node) return
    Pipewire.preferredDefaultAudioSource = node
    if (node.id !== undefined && node.name) {
      Quickshell.execDetached([
        "omarchy-audio-input-set-default",
        String(node.id),
        String(node.name)
      ])
    }
  }

  function sinkAvailable(node) {
    if (!node || !node.name || !sinkAvailabilityLoaded) return true
    var name = String(node.name)
    return sinkAvailability[name] !== false
  }

  function updateSinkAvailability(raw) {
    sinkAvailability = Model.parseSinkAvailability(raw)
    sinkAvailabilityLoaded = true
  }

  function friendlyDeviceLabel(text) {
    return Model.friendlyDeviceLabel(text)
  }

  function nodeLabel(node) {
    return Model.nodeLabel(node)
  }

  function nodeProps(node) {
    return Model.nodeProps(node)
  }

  function isHeadphones(node) {
    return Model.isHeadphones(node)
  }

  function sinkGlyph(node) {
    return Model.sinkGlyph(node)
  }

  function sourceGlyph(node) {
    return Model.sourceGlyph(node)
  }

  function friendlyStreamLabel(label) {
    return Model.friendlyStreamLabel(label)
  }

  function streamLabelKey(label) {
    return Model.streamLabelKey(label)
  }

  function streamLabelIsGeneric(label) {
    return Model.streamLabelIsGeneric(label)
  }

  function rawStreamLabel(node) {
    return Model.rawStreamLabel(node)
  }

  function mprisPlayerLabel(player) {
    return Model.mprisPlayerLabel(player)
  }

  function mprisPlayerIsProxy(player) {
    return Model.mprisPlayerIsProxy(player)
  }

  function streamRepresentsMprisPlayer(streamLabel, playerLabel) {
    return Model.streamRepresentsMprisPlayer(streamLabel, playerLabel)
  }

  function mprisLabelsFor(predicate) {
    return Model.mprisLabelsFor(mprisPlayers, predicate)
  }

  function matchingMprisStreamLabel(label) {
    return Model.matchingMprisStreamLabel(label, mprisPlayers)
  }

  function unmatchedMprisStreamLabel(label) {
    // Spotify exposes its PipeWire stream as "audio-src". For generic stream
    // names, use the one MPRIS player not already represented by another audio
    // stream (e.g. Chromium, or ALSA apps like cliamp).
    return Model.unmatchedMprisStreamLabel(label, mprisPlayers, displayAudioStreams)
  }

  function streamLabel(node) {
    return Model.streamLabel(node, mprisPlayers, displayAudioStreams)
  }

  function streamRepresentsPlayer(node, player) {
    return Model.streamRepresentsPlayer(node, player, mprisPlayers, displayAudioStreams)
  }

  // ---- Audio Plus: Bluetooth codec picking -------------------------------
  //
  // The "codec" a headset runs is a card profile on the PipeWire Device behind
  // the sink. Quickshell 0.3's Pipewire service exposes nodes only — there is
  // no PwDevice type and no profile params on PwNode — so the list is read with
  // pw-dump and the switch goes out through wpctl, the same shell-out shape the
  // panel already uses for sink availability.

  function deviceIdOf(node) {
    return Model.deviceIdOf(node)
  }

  function activeCodecLabel(node) {
    return Model.activeCodecLabel(node)
  }

  function profileLabel(profile) {
    return Model.profileLabel(profile)
  }

  function profileDetail(profile) {
    return Model.profileDetail(profile)
  }

  // A row earns a codec chevron when PipeWire says it is a Bluetooth device and
  // names the codec it is on. Both come off the node's own properties, so the
  // row can label itself without a single process being run; the list of
  // alternatives is fetched only when the picker is actually opened.
  function hasCodecPicker(node) {
    return Model.isBluetoothNode(node)
      && Model.deviceIdOf(node) !== ""
      && Model.activeCodecLabel(node) !== ""
  }

  function profilesExpanded(section, node) {
    var id = Model.deviceIdOf(node)
    return id !== "" && expandedProfileSection === section && expandedProfileDevice === id
  }

  // The flattened row a section index points at, and whether it is a codec.
  function sectionRows(section) {
    if (section === "output") return outputRows
    if (section === "input") return inputRows
    return []
  }

  function rowAt(section, index) {
    var rows = sectionRows(section)
    return index >= 0 && index < rows.length ? rows[index] : null
  }

  function rowIsProfile(section, index) {
    var row = rowAt(section, index)
    return !!row && row.kind === "profile"
  }

  function toggleProfiles(section, node) {
    var id = Model.deviceIdOf(node)
    if (id === "") return
    if (profilesExpanded(section, node)) { closeProfiles(); return }

    // Already read once this session: open on the cached list immediately and
    // refresh underneath, so reopening a picker never flashes an empty gap.
    if (deviceProfiles[id]) {
      expandedProfileSection = section
      expandedProfileDevice = id
      clampCursor()
      fetchProfiles("", id)
      return
    }
    fetchProfiles(section, id)
  }

  function closeProfiles() {
    var section = expandedProfileSection
    var id = expandedProfileDevice
    if (section === "" || id === "") return

    // Where the device row sits *before* its codecs collapse out from under
    // the cursor, so the cursor can land back on the device it belonged to
    // rather than on whichever row slides up into the old index.
    var deviceIndex = -1
    var rows = sectionRows(section)
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].kind === "device" && Model.deviceIdOf(rows[i].node) === id) {
        deviceIndex = i
        break
      }
    }

    expandedProfileSection = ""
    expandedProfileDevice = ""
    if (deviceIndex >= 0 && focusSection === section && selectedIndex >= deviceIndex)
      selectedIndex = deviceIndex
    clampCursor()
  }

  // Read one device's profiles. `section` is where to open the picker once the
  // answer arrives, or "" to only refresh the cache — which is what the reread
  // after a switch wants, since the picker has closed itself by then.
  function fetchProfiles(section, id) {
    if (id === "") return
    pendingProfileSection = section
    pendingProfileDevice = id
    if (deviceProfilesProc.running) deviceProfilesProc.running = false
    deviceProfilesProc.command = ["pw-dump", "-N", id]
    deviceProfilesProc.running = true
  }

  function applyProfileDump(raw) {
    var id = pendingProfileDevice
    if (id === "") return

    // Null means the output was not usable — half a dump from the process that
    // was killed when a second picker opened, or a device that went away
    // mid-read. Keep whatever was cached rather than blanking the list.
    var parsed = Model.parseDeviceProfiles(raw, id)
    if (!parsed) return

    // Reassigned wholesale: QML re-evaluates bindings on assignment, not on
    // mutation of the object a var property already points at.
    var next = {}
    for (var key in deviceProfiles) next[key] = deviceProfiles[key]
    next[id] = parsed
    deviceProfiles = next

    if (pendingProfileSection !== "") {
      expandedProfileSection = pendingProfileSection
      expandedProfileDevice = id
      pendingProfileSection = ""
      clampCursor()
    }
  }

  function setDeviceProfile(node, profile) {
    var id = Model.deviceIdOf(node)
    if (id === "" || !profile) return
    Quickshell.execDetached(["wpctl", "set-profile", id, String(profile.index)])
    // Picking a codec is the end of that errand, the same way picking a device
    // is — fold the list back up.
    closeProfiles()
    // The switch tears the sink node down and builds a new one, and the card
    // can refuse a codec the headset will not actually negotiate, so re-read
    // rather than assuming the choice stuck.
    profileRefreshTimer.deviceId = id
    profileRefreshTimer.restart()
  }

  // ---- Audio Plus: media controls on now-playing sources -----------------

  function streamKey(node) {
    return Model.streamKey(node)
  }

  // A SOURCES row is identified by its PipeWire node when it has one, and by
  // its MPRIS session otherwise. Model.playerRowKey namespaces the latter so
  // the two can never collide.
  function sourceRowKey(node, player) {
    return node ? Model.streamKey(node) : Model.playerRowKey(player)
  }

  // The node behind a SOURCES row index, or null for a player-only row.
  function sourceRowNode(index) {
    if (index < 0 || index >= displayAudioStreams.length) return null
    return displayAudioStreams[index]
  }

  // The player behind a SOURCES row index, whichever kind of row it is.
  function sourceRowPlayer(index) {
    if (index < 0 || index >= sourceRowCount) return null
    if (index < displayAudioStreams.length) return streamPlayer(displayAudioStreams[index])
    return displayOrphanPlayers[index - displayAudioStreams.length] || null
  }

  function sourceExpanded(node, player) {
    var key = sourceRowKey(node, player)
    return key !== "" && expandedSourceKey === key
  }

  function toggleSourceExpanded(node, player) {
    var key = sourceRowKey(node, player)
    if (key === "") return
    expandedSourceKey = expandedSourceKey === key ? "" : key
  }

  // The MPRIS player behind a playback stream, or null for a stream with no
  // media session. Null is what decides a row gets no chevron and no card.
  function streamPlayer(node) {
    return Model.playerForStream(node, mprisPlayers, displayAudioStreams)
  }

  // Route through omarchy.media when it is loaded, so acting on a row updates
  // the same preferred-player state the media bar widget and the media
  // keybinds read — otherwise the panel and the bar disagree about which
  // player is "active". Fall back to plain MPRIS when that plugin is off.
  function runPlayerAction(player, action) {
    if (!player) return false
    if (mediaService)
      return mediaService.runAction(action, false, mediaService.playerKey(player))

    if (action === "next" && player.canGoNext) { player.next(); return true }
    if (action === "previous" && player.canGoPrevious) { player.previous(); return true }
    if (action === "playPause") {
      if (player.isPlaying && player.canPause) { player.pause(); return true }
      if (!player.isPlaying && player.canPlay) { player.play(); return true }
      if (player.canTogglePlaying) { player.togglePlaying(); return true }
    }
    return false
  }

  function playerCanAct(player, action) {
    if (!player) return false
    if (action === "next") return !!player.canGoNext
    if (action === "previous") return !!player.canGoPrevious
    return !!(player.canTogglePlaying || player.canPlay || player.canPause)
  }

  // Player the transport keys act on: the focused SOURCES row when the cursor
  // is on one, otherwise whatever the shell considers active — so p/n/b work
  // even while the cursor is up on the output slider.
  function keyboardMediaPlayer() {
    if (focusSection === "streams" && selectedIndex >= 0) {
      var player = sourceRowPlayer(selectedIndex)
      if (player) return player
    }
    return activeMediaPlayer
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  PwObjectTracker { objects: root.candidateSinks }
  PwObjectTracker { objects: root.candidateSources }
  PwObjectTracker { objects: root.audioStreams }

  PwNodePeakMonitor {
    id: inputPeakMonitor
    node: root.source
    enabled: root.opened && !!root.source
  }

  Process {
    id: sinkAvailabilityProc
    command: ["omarchy-audio-sink-availability"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateSinkAvailability(text)
    }
  }

  Process {
    id: volumeSinkProc
    command: ["omarchy-audio-output-sink"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.volumeSinkName = String(text).trim()
    }
  }

  Timer {
    interval: 5000
    running: root.opened
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!sinkAvailabilityProc.running) sinkAvailabilityProc.running = true
  }

  // Runs whether or not the panel is open: the bar shows and scrolls the output
  // volume too, so an unresolved sink there would read and change the virtual
  // tuning sink instead of the speakers.
  Timer {
    interval: 15000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.resolveVolumeSink()
  }

  Process {
    id: deviceProfilesProc
    command: ["pw-dump", "-N"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyProfileDump(text)
    }
  }

  // Long enough for WirePlumber to tear the old node down, publish the new one
  // and settle on a profile — including refusing the one that was asked for.
  Timer {
    id: profileRefreshTimer
    property string deviceId: ""
    interval: 600
    repeat: false
    onTriggered: if (deviceId !== "") root.fetchProfiles("", deviceId)
  }

  Timer {
    id: audioModelRefreshTimer
    interval: 75
    repeat: false
    onTriggered: root.refreshDisplayAudioModels()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.outputIcon()
    onPressed: function(b) {
      if (b === Qt.RightButton) root.toggleAllMuted()
      else root.toggle()
    }

    onWheelMoved: function(delta) {
      if (!root.hasOutput) return
      var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
      root.wheelAccumulator = wheel.remainder
      if (wheel.steps === 0) return
      var shortcut = wheel.steps > 0 ? "omarchy:audio.raise" : "omarchy:audio.lower"
      for (var i = 0; i < Math.abs(wheel.steps); i++)
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.global('" + shortcut + "')"])
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    // Audio Plus: the card stops padding its own content so the stage's artwork
    // and the tab switch can reach the panel's edges. The drawer puts that
    // padding back on itself, so the card's outer size and the effective
    // content width are unchanged.
    padding: 0
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveCursor(dy)
        else if (dx !== 0) root.adjustVolume(dx * 0.05)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        var key = t.toLowerCase()

        // Transport keys work wherever the cursor is: on a SOURCES row they
        // drive that row's player, elsewhere the shell's active one. They sit
        // off the hjkl cluster on purpose — those already move the cursor and
        // ride the stream volume.
        // Audio Plus: the tab switch. One list is on screen at a time, so a
        // digit is the whole gesture — there is nothing to scroll past.
        if (key === "1" || key === "2" || key === "3") {
          root.setActiveTab(root.tabs[Number(key) - 1])
          return
        }

        if (key === "p" || key === "n" || key === "b") {
          var player = root.keyboardMediaPlayer()
          if (!player) return
          root.runPlayerAction(player, key === "p" ? "playPause" : (key === "n" ? "next" : "previous"))
          return
        }

        if (!root.cursorActive) return

        // 'e' expands/collapses whatever the cursor is on: the device list for
        // output/input, the media card for a SOURCES row. Same thing l/h do on
        // a device row, kept as a section-level shortcut that also works from
        // the slider row.
        if (key === "e") {
          if (root.focusSection === "streams"
            && root.selectedIndex >= 0 && root.selectedIndex < root.sourceRowCount)
            root.toggleSourceExpanded(root.sourceRowNode(root.selectedIndex),
                                      root.sourceRowPlayer(root.selectedIndex))
          return
        }

        // 'c' folds the codec list out under the focused Bluetooth device row,
        // and folds it back up from anywhere inside it. It sits off hjkl
        // because h/l already run the section expander, and off 'e' so that
        // stays the one key that opens and closes sections.
        if (key === "c") {
          if (root.focusSection !== "output" && root.focusSection !== "input") return
          var codecRow = root.rowAt(root.focusSection, root.selectedIndex)
          if (!codecRow) return
          if (codecRow.kind === "profile") root.closeProfiles()
          else if (root.hasCodecPicker(codecRow.node))
            root.toggleProfiles(root.focusSection, codecRow.node)
          return
        }

        // 'm' mutes whatever the cursor is on: focused section's slider
        // for output/input, the focused stream for streams.
        if (key === "m") {
          if (root.focusSection === "streams" && root.selectedIndex >= 0) {
            var s = root.sourceRowNode(root.selectedIndex)
            if (s && s.audio) s.audio.muted = !s.audio.muted
          } else if (root.focusSection === "input") {
            root.toggleInputMute()
          } else {
            root.toggleOutputMute()
          }
        }
      }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        Binding {
          target: scrollArea.contentItem
          property: "interactive"
          value: panelColumn.implicitHeight > scrollArea.height
        }

        Column {
          id: panelColumn
          width: scrollArea.availableWidth
          // The stage, the switch and the drawer meet flush: each already owns
          // its own padding, and a gap between them would read as three cards
          // rather than one panel.
          spacing: 0
          // ---------- The stage ----------
          //
          // Audio Plus: what is playing, at full size, above the switch — so it
          // is on screen whichever list is up rather than being a tab you have
          // to go and find. With a session it is that session's artwork, track
          // and transport; without one it holds the master level instead, and
          // shrinks to the height that alone needs. The mark rides the top of
          // it either way.
          Stage {
            width: parent.width
          }

          // ---------- The switch ----------
          Row {
            id: tabStrip
            width: parent.width
            spacing: 0

            Repeater {
              model: root.tabs

              Item {
                id: tabItem
                required property var modelData
                required property int index
                readonly property bool selected: root.activeTab === modelData
                width: tabStrip.width / root.tabs.length
                implicitHeight: tabInner.implicitHeight + root.tabPadY * 2 + Style.space(2)
                height: implicitHeight

                Rectangle {
                  anchors.fill: parent
                  color: tabItem.selected
                    ? Style.selectedFillFor(root.bar.foreground, Color.accent)
                    : (tabArea.containsMouse
                      ? Style.hoverFillFor(root.bar.foreground, Color.accent)
                      : Style.normalFillFor(root.bar.foreground, Color.accent))
                }

                Row {
                  id: tabInner
                  anchors.centerIn: parent
                  anchors.verticalCenterOffset: -Style.space(1)
                  spacing: Style.space(6)

                  Text {
                    text: root.tabLabel(tabItem.modelData)
                    color: tabItem.selected ? root.bar.foreground : Qt.darker(root.bar.foreground, 1.5)
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 1.2
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    text: root.tabCount(tabItem.modelData)
                    color: tabItem.selected ? Color.accent : Qt.darker(root.bar.foreground, 1.7)
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                // Which list is up, said once more at the bottom edge, so the
                // switch still reads when the fills are close in value.
                Rectangle {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  height: Style.space(2)
                  color: tabItem.selected ? Color.accent : "transparent"
                }

                MouseArea {
                  id: tabArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.setActiveTab(tabItem.modelData)
                }
              }
            }
          }

          // ---------- The drawer ----------
          //
          // One list at a time, and no taller than that list: the card is sized
          // from this, so a floor here would be dead space under a short list
          // rather than a steadier panel. The height moves between tabs because
          // the lists differ — that is the honest shape of what is in them.
          //
          // Its inset is the panel's own on all four sides, so the space under
          // the last row matches the space over the first and the space beside
          // both.
          Item {
            id: listArea
            width: parent.width
            implicitHeight: listColumn.implicitHeight + root.contentInset * 2
            height: implicitHeight

            Column {
              id: listColumn
              y: root.contentInset
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: root.contentInset
              anchors.rightMargin: root.contentInset
              spacing: root.rowGap

              // OUTPUT owns the master level, the way INPUT owns the mic one.
              CursorSurface {
                id: masterSliderRow
                visible: root.activeTab === "output"
                width: parent.width
                height: masterSlider.height + Style.spacing.controlGap
                hasCursor: root.cursorActive && root.focusSection === "output" && root.selectedIndex === -1
                onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(masterSliderRow)
                foreground: root.bar.foreground
                outline: true

                Item {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(6)
                  anchors.rightMargin: Style.space(6)

                  Text {
                    id: masterPercent
                    text: Math.round((masterSlider.dragging ? masterSlider.liveValue : root.outputVolume) * 100) + "%"
                    color: Qt.darker(root.bar.foreground, 1.4)
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: root.outputMuted ? 0.5 : 1.0
                  }

                  PanelSlider {
                    id: masterSlider
                    bar: root.bar
                    anchors.left: parent.left
                    anchors.right: masterPercent.left
                    anchors.rightMargin: Style.space(10)
                    anchors.verticalCenter: parent.verticalCenter
                    knobSize: root.sliderKnobSize
                    minimum: 0
                    maximum: 1
                    step: 0.05
                    value: root.outputVolume
                    opacity: root.outputMuted ? 0.5 : 1.0
                    enabled: !!root.sink

                    onMoved: function(v) { root.setOutputVolume(v) }
                    onRightClicked: root.toggleOutputMute()
                  }
                }

                HoverHandler {
                  onHoveredChanged: if (hovered) {
                    root.cursorActive = true
                    root.focusSection = "output"
                    root.selectedIndex = -1
                  }
                }
              }

              // INPUT keeps a level of its own, inside its own tab.
              CursorSurface {
                id: inputSliderRow
                visible: root.activeTab === "input" && !!root.source
                width: parent.width
                height: inputControls.implicitHeight + Style.spacing.controlGap
                hasCursor: root.cursorActive && root.focusSection === "input" && root.selectedIndex === -1
                onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(inputSliderRow)
                foreground: root.bar.foreground
                outline: true

                Column {
                  id: inputControls
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(6)
                  anchors.rightMargin: Style.space(6)
                  spacing: Style.space(5)

                  Item {
                    width: parent.width
                    implicitHeight: Math.max(inputSlider.implicitHeight, microphonePercent.implicitHeight)

                    Text {
                      id: microphonePercent
                      text: Math.round((inputSlider.dragging ? inputSlider.liveValue : root.inputVolume) * 100) + "%"
                      color: Qt.darker(root.bar.foreground, 1.4)
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      opacity: root.inputMuted ? 0.5 : 1.0
                    }

                    PanelSlider {
                      id: inputSlider
                      bar: root.bar
                      knobSize: root.sliderKnobSize
                      anchors.left: parent.left
                      anchors.right: microphonePercent.left
                      anchors.rightMargin: Style.space(8)
                      anchors.verticalCenter: parent.verticalCenter
                      minimum: 0
                      maximum: 1
                      step: 0.05
                      value: root.inputVolume
                      opacity: root.inputMuted ? 0.5 : 1.0
                      enabled: !!root.source

                      onMoved: function(v) { root.setInputVolume(v) }
                      onRightClicked: root.toggleInputMute()
                    }
                  }

                  Rectangle {
                    width: parent.width
                    height: Math.max(Style.space(5), Style.spacing.xs)
                    color: Util.alpha(root.bar.foreground, 0.18)
                    opacity: root.inputMuted ? 0.35 : 1.0

                    Rectangle {
                      height: parent.height
                      width: parent.width * Math.max(0, Math.min(1, inputPeakMonitor.peak))
                      color: root.bar.foreground
                      Behavior on width { NumberAnimation { duration: 70 } }
                    }
                  }
                }

                HoverHandler {
                  onHoveredChanged: if (hovered) {
                    root.cursorActive = true
                    root.focusSection = "input"
                    root.selectedIndex = -1
                  }
                }
              }

              // Only the active tab's model has rows in it, so the three
              // Repeaters never draw at once and the rows keep the one index
              // space their section's cursor walks.
              // The design has its rows meet flush: they are one list, not a
              // stack of cards. The gap above belongs between the level and the
              // list, not inside it.
              Column {
                id: rowList
                width: parent.width
                spacing: 0
                Repeater {
                  model: root.activeTab === "output" ? root.outputRows : []

                  Item {
                    id: outputRowItem
                    required property var modelData
                    required property int index
                    width: rowList.width
                    implicitHeight: modelData.kind === "profile"
                      ? outputProfileRow.implicitHeight
                      : outputSinkRow.implicitHeight
                    height: implicitHeight

                    SinkRow {
                      id: outputSinkRow
                      visible: outputRowItem.modelData.kind === "device"
                      width: parent.width
                      node: outputRowItem.modelData.node
                      rowIndex: visible ? outputRowItem.index : -1
                    }

                    ProfileRow {
                      id: outputProfileRow
                      visible: outputRowItem.modelData.kind === "profile"
                      width: parent.width
                      section: "output"
                      node: outputRowItem.modelData.node
                      profile: outputRowItem.modelData.profile
                      rowIndex: visible ? outputRowItem.index : -1
                    }
                  }
                }

                Repeater {
                  model: root.activeTab === "input" ? root.inputRows : []

                  Item {
                    id: inputRowItem
                    required property var modelData
                    required property int index
                    width: rowList.width
                    implicitHeight: modelData.kind === "profile"
                      ? inputProfileRow.implicitHeight
                      : inputSourceRow.implicitHeight
                    height: implicitHeight

                    SourceRow {
                      id: inputSourceRow
                      visible: inputRowItem.modelData.kind === "device"
                      width: parent.width
                      node: inputRowItem.modelData.node
                      rowIndex: visible ? inputRowItem.index : -1
                    }

                    ProfileRow {
                      id: inputProfileRow
                      visible: inputRowItem.modelData.kind === "profile"
                      width: parent.width
                      section: "input"
                      node: inputRowItem.modelData.node
                      profile: inputRowItem.modelData.profile
                      rowIndex: visible ? inputRowItem.index : -1
                    }
                  }
                }

                Repeater {
                  model: root.activeTab === "streams" ? root.displayAudioStreams : []

                  StreamRow {
                    required property var modelData
                    required property int index
                    width: rowList.width
                    node: modelData
                    rowIndex: index
                  }
                }

                Repeater {
                  model: root.activeTab === "streams" ? root.displayOrphanPlayers : []

                  PlayerRow {
                    required property var modelData
                    required property int index
                    width: rowList.width
                    player: modelData
                    // Continue the stream rows' numbering so one cursor walks both.
                    rowIndex: root.displayAudioStreams.length + index
                  }
                }
              }


              // An empty tab says what would fill it rather than sitting blank.
              Text {
                visible: root.tabCount(root.activeTab) === 0
                width: parent.width
                topPadding: Style.space(24)
                horizontalAlignment: Text.AlignHCenter
                text: root.activeTab === "streams"
                  ? "Nothing is using audio"
                  : (root.activeTab === "input" ? "No input devices" : "No output devices")
                color: Qt.darker(root.bar.foreground, 1.6)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }
          }
        }
      }
    }
  }

  // ---- Reusable inline components ----

  // Audio Plus: the mark band. The panel's fixed head — what it is, how loud it
  // is, and the switch that silences it — riding the top of the stage, over the
  // artwork, so that none of the three moves when a session starts or ends.
  //
  // It draws no ground of its own: the stage lays a scrim under it, because a
  // band that painted itself opaque would cut the artwork off in a straight
  // line rather than sit on it.
  //
  // Everything in it sits on the band's middle, the switch included: the band's
  // own height is the only thing that places them, so a theme with a taller
  // switch or a bigger font opens it up rather than knocking the mark askew.
  component MarkBand: Item {
    implicitHeight: root.markBandHeight
    height: implicitHeight

    Row {
      anchors.left: parent.left
      anchors.leftMargin: root.contentInset
      anchors.verticalCenter: parent.verticalCenter
      spacing: root.markBandGap

      Text {
        text: root.outputIcon()
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: root.markIconSize
        opacity: root.outputMuted ? 0.5 : 1.0
        anchors.verticalCenter: parent.verticalCenter
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.markLabelGap

        Text {
          text: "Audio"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: root.markTextSize
          font.bold: true
        }

        // The master volume in words, which is the one thing about the panel
        // that the stage no longer says in either state.
        Text {
          text: root.outputVolumeName(root.outputVolume, root.outputMuted).toUpperCase()
          color: Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1.2
        }
      }
    }

    ToggleSwitch {
      id: markSwitch
      checked: root.anyAudible
      hasCursor: root.headerHasCursor
      foreground: root.bar.foreground
      anchors.right: parent.right
      anchors.rightMargin: root.contentInset
      anchors.verticalCenter: parent.verticalCenter
      onHovered: function(on) { if (on) root.setHeaderCursor() }
      onToggled: root.toggleAllMuted()

      PanelToolTip {
        visible: markSwitch.containsMouse
        text: root.toggleHint
        fontFamily: root.bar.fontFamily
      }
    }
  }

  // Audio Plus: the stage — the panel's subject, under the mark band. With a
  // session it is that session's artwork, track and transport; without one it
  // is the master level, which is the thing you would have come for instead,
  // and the stage shrinks to what that alone needs.
  //
  // It is not a cursor target. Transport is p/n/b from anywhere in the panel,
  // and a source's volume is set on its row in SOURCES, so the stage has
  // nothing the keyboard needs to land on.
  component Stage: Item {
    id: stage

    readonly property var player: root.stagePlayer
    readonly property bool hasMedia: !!player
    readonly property color ground: root.bar ? root.bar.background : Color.background
    readonly property string artUrl: player && player.trackArtUrl ? player.trackArtUrl : ""

    implicitHeight: hasMedia
      ? root.stageHeight
      : root.markBandHeight + root.stageIdleHeight
    height: implicitHeight
    clip: true

    // Rounded-corner stencil for the artwork: `clip` is a rectangular scissor
    // and ignores the radius. Costs nothing at Omarchy's default of square
    // corners — the layer below is switched off and this never renders.
    Rectangle {
      id: stageArtMask
      anchors.fill: parent
      radius: Style.cornerRadius
      bottomLeftRadius: 0
      bottomRightRadius: 0
      visible: false
      layer.enabled: true
    }

    Image {
      anchors.fill: parent
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      source: stage.artUrl
      visible: stage.hasMedia && source !== "" && status === Image.Ready
      opacity: 0.55

      layer.enabled: Style.cornerRadius > 0
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: stageArtMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
      }
    }

    // The art has to lose to the text over it under every cover, light or dark,
    // so the ramp bottoms out at the panel background rather than at a partial
    // tint.
    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      bottomLeftRadius: 0
      bottomRightRadius: 0
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(stage.ground.r, stage.ground.g, stage.ground.b, stage.hasMedia ? 0.62 : 1.0) }
        GradientStop { position: 0.22; color: Qt.rgba(stage.ground.r, stage.ground.g, stage.ground.b, stage.hasMedia ? 0.24 : 1.0) }
        GradientStop { position: 0.50; color: Qt.rgba(stage.ground.r, stage.ground.g, stage.ground.b, stage.hasMedia ? 0.82 : 1.0) }
        GradientStop { position: 0.85; color: Qt.rgba(stage.ground.r, stage.ground.g, stage.ground.b, stage.hasMedia ? 0.98 : 1.0) }
        GradientStop { position: 1.0; color: stage.ground }
      }
    }

    // The mark rides the artwork, so it carries a scrim of its own: the stage's
    // ramp is measured off the stage and lands differently in the two heights,
    // and neither reading of it can be counted on to hold up a light cover. This
    // one is measured off the band instead — it covers exactly the strip the
    // mark and the switch occupy, whatever the stage is doing, and is gone by
    // the time the artwork is meant to be seen.
    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: root.markBandHeight + root.markScrimFalloff
      visible: stage.hasMedia
      radius: Style.cornerRadius
      bottomLeftRadius: 0
      bottomRightRadius: 0
      // It barely tapers across the band itself — both lines have to hold up,
      // not just the top one — and then falls away over the run below it. The
      // stage's own ramp is thinnest right where the volume's name sits, which
      // is the reading this is here to rescue.
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(stage.ground.r, stage.ground.g, stage.ground.b, 0.55) }
        // The band's own bottom edge, wherever the theme's spacing puts it.
        GradientStop {
          position: root.markBandHeight / (root.markBandHeight + root.markScrimFalloff)
          color: Qt.rgba(stage.ground.r, stage.ground.g, stage.ground.b, 0.45)
        }
        GradientStop { position: 1.0; color: Qt.rgba(stage.ground.r, stage.ground.g, stage.ground.b, 0.0) }
      }
    }

    MarkBand {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
    }

    // With a session: the track.
    Column {
      visible: stage.hasMedia
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: root.contentInset
      anchors.rightMargin: root.contentInset
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(13)
      spacing: Style.space(5)

      Text {
        textFormat: Text.PlainText
        text: stage.player && stage.player.trackTitle
          ? stage.player.trackTitle
          : root.mprisPlayerLabel(stage.player) || "Media player"
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: root.stageTitleSize
        font.bold: true
        font.letterSpacing: -0.4
        elide: Text.ElideRight
        width: parent.width
      }

      Text {
        textFormat: Text.PlainText
        text: {
          var who = stage.player && stage.player.trackArtist ? String(stage.player.trackArtist) : ""
          var app = root.mprisPlayerLabel(stage.player)
          // The title above falls back to the player's own name when the
          // session publishes no track, so repeating it here would print the
          // same words twice.
          if (!(stage.player && stage.player.trackTitle)) return who
          if (who !== "" && app !== "") return who + " · " + app
          return who !== "" ? who : app
        }
        color: Qt.darker(root.bar.foreground, 1.4)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        width: parent.width
        visible: text !== ""
      }

      Item {
        width: parent.width
        implicitHeight: Math.max(stageTransport.implicitHeight, stageLevel.implicitHeight)

        Row {
          id: stageTransport
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(14)

          PanelActionButton {
            iconText: "󰒮"
            tooltipText: "Previous"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            fontSize: Style.font.body
            size: Style.space(28)
            enabled: root.playerCanAct(stage.player, "previous")
            opacity: enabled ? 1.0 : 0.4
            onClicked: root.runPlayerAction(stage.player, "previous")
          }

          PanelActionButton {
            iconText: stage.player && stage.player.isPlaying ? "󰏤" : "󰐊"
            tooltipText: stage.player && stage.player.isPlaying ? "Pause" : "Play"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            fontSize: Style.font.iconLarge
            size: Style.space(28)
            enabled: root.playerCanAct(stage.player, "playPause")
            opacity: enabled ? 1.0 : 0.4
            onClicked: root.runPlayerAction(stage.player, "playPause")
          }

          PanelActionButton {
            iconText: "󰒭"
            tooltipText: "Next"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            fontSize: Style.font.body
            size: Style.space(28)
            enabled: root.playerCanAct(stage.player, "next")
            opacity: enabled ? 1.0 : 0.4
            onClicked: root.runPlayerAction(stage.player, "next")
          }
        }

        // A readout, not a control: this stream's volume is set on its row in
        // SOURCES, where every per-app level lives.
        Row {
          id: stageLevel
          visible: !!root.stageStreamNode
          anchors.right: parent.right
          anchors.rightMargin: Style.space(2)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)

          Text {
            text: root.stageStreamMuted ? "󰝟" : "󰕾"
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: Math.round(root.stageStreamVolume * 100) + "%"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            opacity: root.stageStreamMuted ? 0.5 : 1.0
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }

    // Without one: the master level, which is what you would have come for. It
    // hangs from the stage's own top rather than the panel's bottom, so the
    // shorter stage crops the empty space below the level and not the space the
    // level needs.
    Column {
      visible: !stage.hasMedia
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: root.contentInset
      anchors.rightMargin: root.contentInset
      anchors.top: parent.top
      anchors.topMargin: root.markBandHeight + root.stageIdleTopInset
      spacing: root.stageIdleGap

      Text {
        text: Math.round(root.outputVolume * 100) + "%"
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: root.stageLevelSize
        font.bold: true
        font.letterSpacing: -1
        opacity: root.outputMuted ? 0.5 : 1.0
        elide: Text.ElideRight
        width: parent.width
      }

      Text {
        text: "NOTHING PLAYING"
        // Brighter than the name beside the mark: the design reads the state
        // first and the mood second.
        color: Qt.darker(root.bar.foreground, 1.15)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1.2
        elide: Text.ElideRight
        width: parent.width
      }
    }
  }

  // Audio Plus: the trailing "AAC ›" on a Bluetooth device row — the codec the
  // device is running now, plus the chevron that folds the alternatives out
  // underneath it. The codec comes straight off the node's PipeWire
  // properties, so the row reads correctly before anything has been fetched.
  //
  // Its MouseArea has to win over the row's, which is why every row that hosts
  // one declares that row-wide area first. hoverEnabled stays off here so the
  // row underneath still tracks the pointer and owns the panel cursor.
  component CodecTag: Item {
    id: codecTag
    required property var node
    required property string section
    required property bool expanded
    required property color foreground

    implicitWidth: codecTagRow.implicitWidth + Style.space(6)
    implicitHeight: codecTagRow.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Row {
      id: codecTagRow
      anchors.centerIn: parent
      spacing: Style.space(4)

      Text {
        textFormat: Text.PlainText
        text: root.activeCodecLabel(codecTag.node)
        color: Qt.darker(codecTag.foreground, 1.5)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: codecTag.expanded ? "󰅀" : "󰅂"
        color: Qt.darker(codecTag.foreground, 1.4)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        width: Style.space(12)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.toggleProfiles(codecTag.section, codecTag.node)
    }
  }

  // Audio Plus: one codec choice, folded out under its device row. It is a row
  // in the section's own index space rather than a nested list, so the cursor
  // walks into it with j/k and Enter picks — same contract as every other row.
  component ProfileRow: CursorSurface {
    id: profileRow
    required property var node
    required property var profile
    required property int rowIndex
    required property string section

    readonly property bool isActive: {
      var entry = root.deviceProfiles[root.deviceIdOf(node)]
      return !!entry && !!profile && entry.active === profile.index
    }

    hasCursor: root.cursorActive && root.focusSection === section && root.selectedIndex === rowIndex
    onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(profileRow)
    current: isActive
    foreground: root.bar.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill
    implicitHeight: root.profileRowHeight

    Row {
      id: profileInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      // Indented past where the device glyph sits, so the list reads as
      // belonging to the row above it rather than as more devices.
      anchors.leftMargin: root.profileIndent
      anchors.rightMargin: root.rowPadX
      spacing: root.rowGap

      Text {
        id: profileMark
        text: profileRow.isActive ? "󰄬" : ""
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        width: Style.space(11)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: profileName
        textFormat: Text.PlainText
        text: root.profileLabel(profileRow.profile)
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: profileRow.isActive
        width: Style.space(74)
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        text: root.profileDetail(profileRow.profile)
        color: Qt.darker(root.bar.foreground, 1.6)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        width: parent.width - profileMark.width - profileName.width - Style.space(16)
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) {
        root.cursorActive = true
        root.focusSection = profileRow.section
        root.selectedIndex = profileRow.rowIndex
      }
      onClicked: root.setDeviceProfile(profileRow.node, profileRow.profile)
    }
  }

  // Output device row — cursor target inside the "output" section. Mouse
  // hover updates the panel cursor at the root; visuals come entirely
  // from hasCursor/current via CursorSurface, never from containsMouse.
  component SinkRow: CursorSurface {
    id: sinkRow
    required property var node
    required property int rowIndex

    readonly property bool isActive: root.sink && node && root.sink.id === node.id
    // Audio Plus: a Bluetooth row says which codec it is running and folds the
    // alternatives out underneath itself.
    readonly property bool hasCodec: root.hasCodecPicker(node)
    readonly property bool codecOpen: root.profilesExpanded("output", node)

    hasCursor: root.cursorActive && root.focusSection === "output" && root.selectedIndex === rowIndex
    onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(sinkRow)
    current: isActive
    foreground: root.bar.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill
    implicitHeight: root.rowHeight

    // Deliberately declared before the content row so the codec tag's own
    // MouseArea sits above it and still wins its clicks; this one picks up
    // presses on the glyph and the device name, which select the device.
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) {
        root.cursorActive = true
        root.focusSection = "output"
        root.selectedIndex = sinkRow.rowIndex
      }
      onClicked: root.setDefaultSink(sinkRow.node)
    }

    Row {
      id: sinkInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: root.rowPadX
      anchors.rightMargin: root.rowPadX
      spacing: root.rowGap

      // The design marks the device in use with a check and the rest with a
      // chevron, rather than leaning on the row fill alone.
      Text {
        id: sinkRowMark
        text: sinkRow.isActive ? "󰄬" : "󰅂"
        color: sinkRow.isActive ? Color.accent : Qt.darker(root.bar.foreground, 1.5)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        width: Style.space(12)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: sinkGlyphText
        text: root.sinkGlyph(sinkRow.node)
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.title
        width: Style.space(14)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        text: root.nodeLabel(sinkRow.node)
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        font.bold: sinkRow.isActive
        elide: Text.ElideRight
        // Row skips invisible children, so the codec tag only costs its own
        // width plus one gap when the device actually has one.
        width: parent.width - sinkRowMark.width - sinkGlyphText.width - root.rowGap * 2
          - (sinkRow.hasCodec ? sinkCodecTag.width + root.rowGap : 0)
        anchors.verticalCenter: parent.verticalCenter
      }

      CodecTag {
        id: sinkCodecTag
        visible: sinkRow.hasCodec
        node: sinkRow.node
        section: "output"
        expanded: sinkRow.codecOpen
        foreground: root.bar.foreground
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  // Input device row — sibling of SinkRow for the "input" section.
  component SourceRow: CursorSurface {
    id: sourceRow
    required property var node
    required property int rowIndex

    readonly property bool isActive: root.source && node && root.source.id === node.id
    // A Bluetooth card owns the microphone too — the mic only exists at all in
    // the HSP/HFP profiles — so an input row gets the same picker.
    readonly property bool hasCodec: root.hasCodecPicker(node)
    readonly property bool codecOpen: root.profilesExpanded("input", node)

    hasCursor: root.cursorActive && root.focusSection === "input" && root.selectedIndex === rowIndex
    onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(sourceRow)
    current: isActive
    foreground: root.bar.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill
    implicitHeight: root.rowHeight

    // Same layering as SinkRow: declared first so the codec tag wins its own
    // clicks.
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) {
        root.cursorActive = true
        root.focusSection = "input"
        root.selectedIndex = sourceRow.rowIndex
      }
      onClicked: root.setDefaultSource(sourceRow.node)
    }

    Row {
      id: sourceInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: root.rowPadX
      anchors.rightMargin: root.rowPadX
      spacing: root.rowGap

      // The design marks the device in use with a check and the rest with a
      // chevron, rather than leaning on the row fill alone.
      Text {
        id: sourceRowMark
        text: sourceRow.isActive ? "󰄬" : "󰅂"
        color: sourceRow.isActive ? Color.accent : Qt.darker(root.bar.foreground, 1.5)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        width: Style.space(12)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: sourceGlyphText
        text: root.sourceGlyph(sourceRow.node)
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.title
        width: Style.space(14)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        text: root.nodeLabel(sourceRow.node)
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        font.bold: sourceRow.isActive
        elide: Text.ElideRight
        width: parent.width - sourceRowMark.width - sourceGlyphText.width - root.rowGap * 2
          - (sourceRow.hasCodec ? sourceCodecTag.width + root.rowGap : 0)
        anchors.verticalCenter: parent.verticalCenter
      }

      CodecTag {
        id: sourceCodecTag
        visible: sourceRow.hasCodec
        node: sourceRow.node
        section: "input"
        expanded: sourceRow.codecOpen
        foreground: root.bar.foreground
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  // Per-app stream row — cursor target inside the "streams" section.
  // The stream has its own slider inline, so h/l from the keyboard adjusts
  // THIS stream's volume (not the global output) when the cursor sits here.
  //
  // Audio Plus: a stream PipeWire can tie back to an MPRIS session grows a
  // chevron. Expanding it reveals the artwork, the track, and
  // prev/play-pause/next for that player specifically — so a panel that
  // already says "Spotify · 85%" can also skip the track, instead of sending
  // the user off to a second widget to do it. Streams with no session (a
  // game, a notification sound) render exactly as upstream.
  component StreamRow: CursorSurface {
    id: streamRow
    required property var node
    required property int rowIndex

    readonly property real streamVolume: node && node.audio ? node.audio.volume : 0
    readonly property bool streamMuted: node && node.audio ? node.audio.muted : false
    readonly property var player: root.streamPlayer(node)
    readonly property bool hasMedia: player !== null
    readonly property bool expanded: hasMedia && root.sourceExpanded(node, null)
    readonly property bool isActive: root.streamRepresentsPlayer(node, root.activeMediaPlayer)

    hasCursor: root.cursorActive && root.focusSection === "streams" && root.selectedIndex === rowIndex
    onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(streamRow)
    current: isActive
    foreground: root.bar.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill
    implicitHeight: streamColumn.implicitHeight + Style.spacing.xl

    Column {
      id: streamColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(2)

      Item {
        id: streamHeader
        width: parent.width
        implicitHeight: streamHeaderRow.implicitHeight

        // Deliberately declared before the content row so the mute glyph's own
        // MouseArea sits above it and still wins its clicks; this one only
        // picks up presses on the label, the percentage, and the chevron.
        MouseArea {
          anchors.fill: parent
          enabled: streamRow.hasMedia
          cursorShape: Qt.PointingHandCursor
          onClicked: root.toggleSourceExpanded(streamRow.node, streamRow.player)
        }

        Row {
          id: streamHeaderRow
          anchors.fill: parent
          spacing: Style.space(8)

          Text {
            id: streamMuteIcon
            text: streamRow.streamMuted ? "󰝟" : "󰕾"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.title
            width: Style.space(22)
            horizontalAlignment: Text.AlignHCenter
            anchors.verticalCenter: parent.verticalCenter
            opacity: streamRow.streamMuted ? 0.5 : 1.0

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (streamRow.node && streamRow.node.audio)
                  streamRow.node.audio.muted = !streamRow.node.audio.muted
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            text: root.streamLabel(streamRow.node)
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
            font.bold: streamRow.isActive
            elide: Text.ElideRight
            // Row skips invisible children, so the chevron only costs its own
            // width plus one gap when it is actually there.
            width: parent.width - streamMuteIcon.width - streamPct.width
              - (streamRow.hasMedia ? streamChevron.width + Style.space(8) : 0)
              - Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            id: streamPct
            text: Math.round(streamRow.streamVolume * 100) + "%"
            color: Qt.darker(root.bar.foreground, 1.5)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            width: Style.space(36)
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
            opacity: streamRow.streamMuted ? 0.5 : 1.0
          }

          Text {
            id: streamChevron
            visible: streamRow.hasMedia
            text: streamRow.expanded ? "󰅀" : "󰅂"
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            width: Style.space(12)
            horizontalAlignment: Text.AlignHCenter
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }

      PanelSlider {
        bar: root.bar
        knobSize: root.sliderKnobSize
        width: parent.width
        minimum: 0
        maximum: 1.5
        step: 0.05
        value: streamRow.streamVolume
        opacity: streamRow.streamMuted ? 0.5 : 1.0

        onMoved: function(v) {
          if (streamRow.node && streamRow.node.audio) streamRow.node.audio.volume = v
        }
        onRightClicked: {
          if (streamRow.node && streamRow.node.audio)
            streamRow.node.audio.muted = !streamRow.node.audio.muted
        }
      }

      // Media card. Column skips invisible children outright, so a collapsed
      // row costs nothing in height and the panel keeps its compact shape.
      MediaCard {
        width: parent.width
        visible: streamRow.expanded
        player: streamRow.player
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
      propagateComposedEvents: true
      onContainsMouseChanged: if (containsMouse) {
        root.cursorActive = true
        root.focusSection = "streams"
        root.selectedIndex = streamRow.rowIndex
      }
    }
  }
  // Shared media card: artwork, track, transport. Rendered by a SOURCES row
  // backed by a PipeWire stream and by one backed only by an MPRIS session,
  // so both kinds of row look and behave identically once expanded.
  component MediaCard: Item {
    id: mediaCard
    property var player: null

    implicitHeight: mediaCardRow.implicitHeight + Style.spacing.md

        Row {
          id: mediaCardRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          spacing: Style.space(10)

          BorderSurface {
            id: artFrame
            width: Style.space(82)
            height: Style.space(52)
            radius: Style.spacing.labelGap
            color: Style.normalFillFor(root.bar.foreground, Color.accent)
            borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)

            Image {
              anchors.fill: parent
              anchors.margins: Style.space(2)
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              // Art URLs are whatever the player published — a missing or
              // unreadable file just leaves the note placeholder showing.
              source: mediaCard.player && mediaCard.player.trackArtUrl ? mediaCard.player.trackArtUrl : ""
              visible: source !== "" && status === Image.Ready
            }

            Text {
              anchors.centerIn: parent
              visible: !mediaCard.player || !mediaCard.player.trackArtUrl
              text: "󰝚"
              color: Qt.darker(root.bar.foreground, 1.3)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.heading
            }
          }

          Column {
            width: parent.width - artFrame.width - Style.space(10)
            spacing: Style.space(3)

            Text {
              textFormat: Text.PlainText
              text: mediaCard.player && mediaCard.player.trackTitle
                ? mediaCard.player.trackTitle
                : "Nothing playing"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: mediaCard.player && mediaCard.player.trackArtist ? mediaCard.player.trackArtist : ""
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
              visible: text !== ""
            }

            Row {
              spacing: Style.space(2)

              PanelActionButton {
                iconText: "󰒮"
                tooltipText: "Previous"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                fontSize: Style.font.bodySmall
                size: Style.space(24)
                enabled: root.playerCanAct(mediaCard.player, "previous")
                opacity: enabled ? 1.0 : 0.4
                onClicked: root.runPlayerAction(mediaCard.player, "previous")
              }

              PanelActionButton {
                iconText: mediaCard.player && mediaCard.player.isPlaying ? "󰏤" : "󰐊"
                tooltipText: mediaCard.player && mediaCard.player.isPlaying ? "Pause" : "Play"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                fontSize: Style.font.icon
                size: Style.space(24)
                enabled: root.playerCanAct(mediaCard.player, "playPause")
                opacity: enabled ? 1.0 : 0.4
                onClicked: root.runPlayerAction(mediaCard.player, "playPause")
              }

              PanelActionButton {
                iconText: "󰒭"
                tooltipText: "Next"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                fontSize: Style.font.bodySmall
                size: Style.space(24)
                enabled: root.playerCanAct(mediaCard.player, "next")
                opacity: enabled ? 1.0 : 0.4
                onClicked: root.runPlayerAction(mediaCard.player, "next")
              }
            }
          }
        }
  }

  // SOURCES row backed only by an MPRIS session, with no PipeWire stream of
  // its own. Chromium and Brave tear their audio stream down the moment they
  // are paused, so without this row the one player the user actually wants to
  // press play on is the one that has disappeared from the panel. No volume
  // slider: there is no stream to attach a volume to.
  component PlayerRow: CursorSurface {
    id: playerRow
    required property var player
    required property int rowIndex

    readonly property bool expanded: root.sourceExpanded(null, player)
    readonly property bool isActive: !!(root.activeMediaPlayer && player
      && String(root.activeMediaPlayer.dbusName) === String(player.dbusName))

    hasCursor: root.cursorActive && root.focusSection === "streams" && root.selectedIndex === rowIndex
    onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(playerRow)
    current: isActive
    foreground: root.bar.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill
    implicitHeight: playerColumn.implicitHeight + Style.spacing.xl

    Column {
      id: playerColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(2)

      Item {
        id: playerHeader
        width: parent.width
        implicitHeight: playerHeaderRow.implicitHeight

        // Declared first so the play/pause glyph's own MouseArea stays above
        // it and keeps its clicks; this one only takes the label and chevron.
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.toggleSourceExpanded(null, playerRow.player)
        }

        Row {
          id: playerHeaderRow
          anchors.fill: parent
          spacing: Style.space(8)

          Text {
            id: playerGlyph
            text: playerRow.player && playerRow.player.isPlaying ? "󰏤" : "󰐊"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.title
            width: Style.space(22)
            horizontalAlignment: Text.AlignHCenter
            anchors.verticalCenter: parent.verticalCenter
            opacity: playerRow.player && playerRow.player.isPlaying ? 1.0 : 0.7

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.runPlayerAction(playerRow.player, "playPause")
            }
          }

          Text {
            textFormat: Text.PlainText
            text: root.mprisPlayerLabel(playerRow.player) || "Media player"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
            font.bold: playerRow.isActive
            elide: Text.ElideRight
            width: parent.width - playerGlyph.width - playerChevron.width - Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            id: playerChevron
            text: playerRow.expanded ? "󰅀" : "󰅂"
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            width: Style.space(12)
            horizontalAlignment: Text.AlignHCenter
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }

      MediaCard {
        width: parent.width
        visible: playerRow.expanded
        player: playerRow.player
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
      propagateComposedEvents: true
      onContainsMouseChanged: if (containsMouse) {
        root.cursorActive = true
        root.focusSection = "streams"
        root.selectedIndex = playerRow.rowIndex
      }
    }
  }

}
