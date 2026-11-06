// Taskbar - a window list and pinned launcher bar for Omarchy, per monitor.
//
// Copyright (c) 2026 IntelligentWolf Ltd. MIT licensed, see LICENSE.
//
// The bar draws one surface per monitor. By default each bar lists the windows
// on its own output ("monitor" scope) as icons, which is the cheap answer to
// "what is running here". Widen it to "all" and every bar instead lists every
// window on the desk, bucketed under the output it lives on and ordered the way
// the screens are physically arranged, so one glance at one screen answers
// "where is that window". Narrow it to "workspace" and a bar lists only what is
// actually on display on it right now.
//
// Right-clicking any button offers "Pin to <screen>". A pin is remembered
// against that output (see PinStore.qml), keeps its icon whether or not the app
// is running, and starts the app on that screen when clicked. Pinned icons hold
// the front of their monitor's group in the order they were pinned; a pinned
// app that is running shows its real windows in that slot instead.
//
// Every window is pinnable. One with a desktop entry is pinned as that entry;
// one without -- an agent terminal started as `ghostty --class=... -e claude`
// is in no application database -- is pinned as the command line it is running.
//
// Hovering a window shows a live thumbnail of it rather than a text tooltip:
// which of four terminals is the one you want is a question a title rarely
// answers and a picture always does. See TaskbarPreview.qml.
//
// Nothing here imports Omarchy's internal `qs.*` modules. Everything it needs
// about the bar (theme colours, font, size, popup coordination) arrives on the
// injected `bar` object, which is the documented third-party contract in
// $OMARCHY_PATH/shell/plugins/bar/README.md.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: root

  // Injected by the bar after load. See ModuleSlot.injectProps() in
  // $OMARCHY_PATH/shell/plugins/bar/Bar.qml:1766.
  property var bar: null
  property string moduleName: "intelligentwolf.taskbar"
  property var settings: ({})

  // ---------------------------------------------------------------- settings

  // Fallbacks are duplicated from manifest.json barWidget.defaults: the bar
  // hands over only what shell.json actually stores, so an unset key arrives
  // as undefined rather than as its manifest default.
  function setting(key, fallback) {
    var value = settings ? settings[key] : undefined
    return value === undefined || value === null ? fallback : value
  }

  readonly property string scope: String(setting("scope", "monitor"))
  readonly property string labelMode: String(setting("label", "none"))
  readonly property bool showIcons: setting("showIcons", true) === true
  readonly property bool showMonitorLabels: setting("showMonitorLabels", true) === true && wantsGroupHeadings
  readonly property bool showEmptyMonitors: setting("showEmptyMonitors", false) === true
  readonly property int maxLabelWidth: Math.max(40, Number(setting("maxLabelWidth", 120)))
  readonly property int groupSpacing: Math.max(0, Number(setting("groupSpacing", 12)))
  readonly property string monitorAliases: String(setting("monitorAliases", ""))
  readonly property int maxWidthPercent: Math.max(0, Math.min(100, Number(setting("maxWidthPercent", 35))))

  // ------------------------------------------------------------- bar context

  readonly property bool vertical: bar ? bar.vertical === true : false
  readonly property string barPosition: bar ? String(bar.position || "top") : "top"
  readonly property int barSize: bar ? bar.barSize : 26
  readonly property color foreground: bar ? bar.barForeground : "#ffffff"
  readonly property color urgentColor: bar ? bar.urgent : "#ff5555"
  readonly property string fontFamily: bar ? bar.fontFamily : "monospace"

  readonly property int iconSize: Math.round(barSize * 0.62)
  readonly property int buttonHeight: Math.max(16, barSize - 6)
  readonly property int labelPixelSize: Math.max(9, Math.round(barSize * 0.42))
  readonly property int groupPixelSize: Math.max(8, Math.round(barSize * 0.36))

  // The output this particular bar surface is drawn on. QsWindow is the
  // Quickshell attached property the bar itself uses for the same lookup
  // (Bar.qml:154 targetWindow). Every scope but "all" is anchored to it.
  readonly property string ownScreen: QsWindow.window && QsWindow.window.screen
    ? String(QsWindow.window.screen.name || "") : ""

  // Aliased, not just given an id: an id is only in scope inside this file, and
  // the pin store is part of the widget's surface for anything driving it.
  readonly property alias pins: pinStore

  PinStore { id: pinStore }

  TaskbarMenu {
    id: contextMenu
    bar: root.bar
  }

  TaskbarPreview {
    id: preview
    bar: root.bar
  }

  // Windows waits before showing a taskbar preview so that sweeping the pointer
  // across the bar does not strobe a card per button. Same idea here.
  Timer {
    id: previewDelay
    interval: 400
    property Item target: null
    property var cell: null
    onTriggered: {
      if (!previewDelay.target || !previewDelay.cell) return
      if (contextMenu.open) return
      preview.anchorItem = previewDelay.target
      preview.toplevel = previewDelay.cell.toplevel.wayland
      preview.title = root.previewTitleFor(previewDelay.cell)
      preview.open = true
    }
  }

  function showPreviewFor(anchorItem, cell) {
    // Only a running window has anything to show. A pinned launcher is an icon
    // the user chose and put there; there is nothing to preview and nothing to
    // explain.
    if (contextMenu.open || cell.kind !== "window"
        || !cell.toplevel || !cell.toplevel.wayland) return
    previewDelay.target = anchorItem
    previewDelay.cell = cell
    previewDelay.restart()
  }

  function hidePreview() {
    previewDelay.stop()
    previewDelay.target = null
    previewDelay.cell = null
    preview.open = false
    preview.toplevel = null
  }

  // ------------------------------------------------------------------- model

  // Bound, not called once: reading DesktopEntries.applications is what makes
  // the entry index populate at all, and it repopulates as apps are installed.
  readonly property int desktopEntryCount: DesktopEntries.applications.values.length

  readonly property var aliasMap: {
    var map = ({})
    var parts = root.monitorAliases.split(",")
    for (var i = 0; i < parts.length; i++) {
      var pair = parts[i].split("=")
      if (pair.length !== 2) continue
      var key = pair[0].trim()
      var value = pair[1].trim()
      if (key && value) map[key] = value
    }
    return map
  }

  function entryById(id) {
    // Both a real early-out and the dependency that re-resolves every icon and
    // name once the entry index finishes loading, instead of leaving them stuck
    // on the empty answer the first evaluation saw.
    if (root.desktopEntryCount === 0 || !id) return null
    var entry = DesktopEntries.byId(String(id))
    if (!entry) entry = DesktopEntries.heuristicLookup(String(id))
    return entry || null
  }

  function desktopEntryFor(toplevel) {
    var appId = toplevel && toplevel.wayland ? String(toplevel.wayland.appId || "") : ""
    return root.entryById(appId)
  }

  // A pin's identity, and how a running window is matched back to one. The
  // Wayland app id is the only name the compositor actually reports, so it is
  // the one thing a window and a pin can always agree on -- including for
  // windows with no desktop entry, which are pinned by command line instead.
  function appIdOf(toplevel) {
    return toplevel && toplevel.wayland ? String(toplevel.wayland.appId || "") : ""
  }

  function pidOf(toplevel) {
    var ipc = toplevel ? toplevel.lastIpcObject : null
    return ipc && ipc.pid ? Number(ipc.pid) : 0
  }

  function entryIdFor(toplevel) {
    var entry = root.desktopEntryFor(toplevel)
    return entry ? String(entry.id) : ""
  }

  function iconPathFor(name) {
    if (name) {
      var themed = Quickshell.iconPath(String(name), true)
      if (themed.length > 0) return themed
    }
    return Quickshell.iconPath("application-x-executable", true)
  }

  // Apps without a .desktop file (org.omarchy.agent, one-off Electron shells)
  // would otherwise show a reverse-DNS id. Take the last segment and capitalise
  // it: org.omarchy.agent -> Agent, com.mitchellh.ghostty -> Ghostty.
  function prettyAppId(appId) {
    var segments = String(appId).split(".")
    var last = segments[segments.length - 1]
    if (!last) return String(appId)
    return last.charAt(0).toUpperCase() + last.slice(1)
  }

  function appNameFor(toplevel) {
    var entry = root.desktopEntryFor(toplevel)
    if (entry && entry.name) return String(entry.name)
    var appId = toplevel && toplevel.wayland ? String(toplevel.wayland.appId || "") : ""
    if (appId) return root.prettyAppId(appId)
    return String(toplevel && toplevel.title ? toplevel.title : "")
  }

  // A pin with a desktop entry gets that entry's name and icon. One pinned by
  // command line has neither, so it falls back to the same derived name the
  // running window already shows, which keeps the row consistent whether the
  // app happens to be running or not.
  function pinEntryFor(pin) {
    return pin && pin.desktop ? root.entryById(pin.desktop) : null
  }

  function launcherNameFor(pin) {
    var entry = root.pinEntryFor(pin)
    if (entry && entry.name) return String(entry.name)
    return root.prettyAppId(pin ? pin.appId : "")
  }

  function iconForCell(cell) {
    if (cell.kind === "launcher") {
      var entry = root.pinEntryFor(cell.pin)
      if (entry) return root.iconPathFor(entry.icon)
      return root.iconPathFor(cell.pin ? cell.pin.appId : "")
    }
    var windowEntry = root.desktopEntryFor(cell.toplevel)
    return root.iconPathFor(windowEntry ? windowEntry.icon : "")
  }

  // The text a button would carry with all the room in the world. Compaction is
  // applied by buttonTextFor, so measuring can ask for the full-fidelity width
  // without the answer depending on the decision it is feeding.
  function fullLabelForCell(cell) {
    if (root.labelMode === "none" || root.vertical) return ""
    if (cell.kind === "launcher") return root.launcherNameFor(cell.pin)
    if (root.labelMode === "title") return String(cell.toplevel.title || root.appNameFor(cell.toplevel))
    return root.appNameFor(cell.toplevel)
  }

  function buttonTextFor(cell) {
    return root.compactButtons ? "" : root.fullLabelForCell(cell)
  }

  // The preview's caption. The thumbnail says which window it is; the caption
  // only has to name it, so this drops the screen and workspace the old tooltip
  // carried - you are looking at the bar on the screen in question.
  function previewTitleFor(cell) {
    var title = String(cell.toplevel.title || "")
    var app = root.appNameFor(cell.toplevel)
    if (!title) return app
    // Most apps already put their name in the title ("... - Vivaldi"), and
    // prefixing it again reads as a stutter. Only name the app when the title
    // does not - a terminal titled with a bare path needs the context.
    if (title.toLowerCase().indexOf(app.toLowerCase()) !== -1) return title
    return app + " — " + title
  }

  // ObjectModel.values is not a plain JS Array in every Quickshell build, so
  // copy through an index loop rather than assuming slice()/sort() exist.
  function toArray(values) {
    var out = []
    for (var i = 0; i < values.length; i++) out.push(values[i])
    return out
  }

  function byWorkspaceThenArrival(left, right) {
    return (left.order - right.order) || (left.seq - right.seq)
  }

  // Hyprland's own record of the output this bar surface is on, which is where
  // "the workspace currently showing here" comes from. Matched by name because
  // that is the only identifier Quickshell's screen and Hyprland's monitor
  // objects share.
  readonly property var ownMonitor: {
    if (!root.ownScreen) return null
    var monitors = Hyprland.monitors.values
    for (var i = 0; i < monitors.length; i++)
      if (String(monitors[i].name || "") === root.ownScreen) return monitors[i]
    return null
  }

  readonly property int ownWorkspaceId: {
    var workspace = root.ownMonitor ? root.ownMonitor.activeWorkspace : null
    return workspace ? workspace.id : 0
  }

  // Only "all" spans the whole desk, so it is the only scope where a heading
  // tells you something you could not already see.
  readonly property bool wantsGroupHeadings: root.scope === "all"

  // Groups, left to right the way the screens are actually laid out. Reading
  // each toplevel's .monitor and .workspace inside this binding is deliberate:
  // that is what registers the dependency that rebuilds the list when a window
  // is dragged to another screen or workspace, not only when one opens or
  // closes. Calling pins.pinsFor() does the same job for the pin file.
  readonly property var groups: {
    var monitors = root.toArray(Hyprland.monitors.values)
    var toplevels = root.toArray(Hyprland.toplevels.values)

    monitors.sort(function(left, right) {
      return (left.x - right.x) || (left.y - right.y)
    })

    var buckets = ({})
    var orphans = []
    for (var i = 0; i < toplevels.length; i++) {
      var toplevel = toplevels[i]
      var monitor = toplevel.monitor
      var workspace = toplevel.workspace
      var workspaceId = workspace ? workspace.id : 0
      // "workspace" scope is the visible desktop: a window parked on another
      // workspace of this same output is not on screen, so it is not listed.
      if (root.scope === "workspace" && workspaceId !== root.ownWorkspaceId) continue
      var record = { toplevel: toplevel, order: workspaceId, seq: i }
      var name = monitor ? String(monitor.name || "") : ""
      if (!name) {
        orphans.push(record)
        continue
      }
      if (!buckets[name]) buckets[name] = []
      buckets[name].push(record)
    }

    var result = []
    for (var m = 0; m < monitors.length; m++) {
      var monitorName = String(monitors[m].name || "")
      var monitorDescription = String(monitors[m].description || "")
      if (root.scope !== "all" && root.ownScreen && monitorName !== root.ownScreen) continue

      var records = buckets[monitorName] || []
      records.sort(root.byWorkspaceThenArrival)

      // Pinned slots hold the front of the group in pin order. A pin whose app
      // is running here is filled by its real windows; one that is not becomes
      // a launcher. Everything else running here follows.
      var items = []
      var claimed = ({})
      var pinned = root.pins.pinsFor(monitorName, monitorDescription)
      for (var p = 0; p < pinned.length; p++) {
        var matched = false
        for (var r = 0; r < records.length; r++) {
          if (claimed[records[r].seq] === true) continue
          if (root.appIdOf(records[r].toplevel) !== pinned[p].appId) continue
          claimed[records[r].seq] = true
          items.push({ kind: "window", toplevel: records[r].toplevel,
                       monitorName: monitorName, monitorDescription: monitorDescription })
          matched = true
        }
        if (!matched)
          items.push({ kind: "launcher", pin: pinned[p],
                       monitorName: monitorName, monitorDescription: monitorDescription })
      }
      for (var u = 0; u < records.length; u++) {
        if (claimed[records[u].seq] === true) continue
        items.push({ kind: "window", toplevel: records[u].toplevel,
                     monitorName: monitorName, monitorDescription: monitorDescription })
      }

      if (items.length === 0 && !root.showEmptyMonitors) continue
      result.push({
        key: monitorName,
        label: root.aliasMap[monitorName] || monitorName,
        items: items
      })
    }

    // A window Hyprland has not placed on an output yet still gets a seat.
    // A taskbar that quietly drops windows is worse than no taskbar.
    if (orphans.length > 0 && root.scope === "all") {
      orphans.sort(root.byWorkspaceThenArrival)
      var loose = []
      for (var o = 0; o < orphans.length; o++)
        loose.push({ kind: "window", toplevel: orphans[o].toplevel,
                     monitorName: "", monitorDescription: "" })
      result.push({ key: "", label: "unassigned", items: loose })
    }

    return result
  }

  // Flattened so one delegate can drive either orientation. Each cell carries
  // the leading gap it needs, which keeps the positioners plain and means the
  // first group never starts with a stray indent.
  readonly property var cells: {
    var result = []
    for (var g = 0; g < root.groups.length; g++) {
      var group = root.groups[g]
      result.push({ kind: "group", label: group.label, gap: g === 0 ? 0 : root.groupSpacing })
      if (group.items.length === 0) {
        result.push({ kind: "empty", gap: 0 })
        continue
      }
      for (var i = 0; i < group.items.length; i++) result.push(group.items[i])
    }
    return result
  }

  // ------------------------------------------------------------- compaction

  // A bar shows a whole desktop's worth of windows in the space left over
  // beside the menu, the workspaces and a centre-anchored clock. On a narrow
  // output the full-fidelity row runs straight into that clock, so the widget
  // gives up detail before it gives up windows: first the button labels, then
  // the monitor names. Every window keeps its button and its tooltip, which is
  // where the name, title, screen and workspace live either way.
  //
  // The budget is a share of this bar surface rather than a pixel count so one
  // setting behaves the same across a mixed-resolution desk. It cannot be
  // derived from the neighbouring widgets without reaching into the bar's
  // internals, so it is a knob, defaulted to a share that leaves the centre
  // section alone on a 16:10 laptop panel.
  readonly property int barSurfaceWidth: QsWindow.window ? QsWindow.window.width : 0
  readonly property int widthBudget: vertical || maxWidthPercent === 0 || barSurfaceWidth <= 0
    ? 0 : Math.round(barSurfaceWidth * maxWidthPercent / 100)

  FontMetrics {
    id: labelMetrics
    font.family: root.fontFamily
    font.pixelSize: root.labelPixelSize
  }

  FontMetrics {
    id: groupMetrics
    font.family: root.fontFamily
    font.pixelSize: root.groupPixelSize
  }

  // Measured from font metrics, not from the laid-out row: measuring the row
  // would make its width depend on the compaction this decides, which is a
  // binding loop. Mirrors the delegates' own width arithmetic below.
  function measure(withButtonLabels, withGroupLabels) {
    var total = 0
    for (var i = 0; i < root.cells.length; i++) {
      var cell = root.cells[i]
      if (i > 0) total += 2 // Row.spacing
      if (cell.kind === "group") {
        total += cell.gap
        if (withGroupLabels && root.showMonitorLabels)
          total += Math.ceil(groupMetrics.advanceWidth(String(cell.label))) + 4
      } else if (cell.kind === "empty") {
        total += Math.ceil(labelMetrics.advanceWidth("—")) + 6
      } else {
        var text = withButtonLabels ? root.fullLabelForCell(cell) : ""
        var width = root.showIcons ? root.iconSize : 0
        if (text.length > 0) {
          if (root.showIcons) width += 5
          width += Math.min(root.maxLabelWidth, Math.ceil(labelMetrics.advanceWidth(text)))
        }
        total += Math.max(width, root.iconSize) + 12
      }
    }
    return total
  }

  readonly property bool compactButtons: widthBudget > 0 && measure(true, true) > widthBudget
  readonly property bool compactGroups: widthBudget > 0 && measure(false, true) > widthBudget

  // ----------------------------------------------------------------- actions

  function addressOf(toplevel) {
    // HyprlandToplevel.address carries no 0x prefix; hyprctl's `address:`
    // selector requires one.
    var address = String(toplevel && toplevel.address ? toplevel.address : "")
    if (!address) return ""
    return address.indexOf("0x") === 0 ? address : "0x" + address
  }

  // Hyprland 0.56 parses hyprctl dispatch arguments as Lua, the same form
  // Omarchy's own workspace widget uses (bar/widgets/Workspaces.qml:33).
  // execDetached takes an argv vector, so no shell ever sees this string and
  // there is nothing to quote or mis-quote.
  function dispatch(lua) {
    Quickshell.execDetached(["hyprctl", "dispatch", lua])
  }

  function focusWindow(toplevel) {
    var address = root.addressOf(toplevel)
    if (!address) return
    Quickshell.execDetached(["hyprctl", "eval",
      "require('hypr.four_zones').focus_window('" + address + "')"])
  }

  function closeWindow(toplevel) {
    if (toplevel && toplevel.wayland) toplevel.wayland.close()
  }

  function findWindowOnMonitor(appId, monitorName) {
    var toplevels = Hyprland.toplevels.values
    for (var i = 0; i < toplevels.length; i++) {
      var toplevel = toplevels[i]
      if (root.appIdOf(toplevel) !== appId) continue
      var monitor = toplevel.monitor
      if (monitorName && (!monitor || String(monitor.name || "") !== monitorName)) continue
      return toplevel
    }
    return null
  }

  function notify(headline, body) {
    // Pinning and launching are user-initiated and can fail. A console warning
    // nobody will ever read is not feedback, so failures land where the user
    // can actually see them.
    Quickshell.execDetached(["omarchy-notification-send", "-u", "critical",
                             String(headline), String(body)])
  }

  // Focus the target output first so the new window opens there, then hand over
  // to uwsm-app. That is the same path Omarchy's own launcher takes (see
  // shell/services/AppLibrary.qml:84): it puts the app in a scope under
  // app-graphical.slice instead of letting it inherit wayland-wm@.service.
  //
  // A pin with a desktop entry goes through gtk-launch, which resolves ids that
  // UWSM alone rejects. One pinned by command line is run as the argv it was
  // recorded from.
  //
  // The two steps have to be ordered, so this is the one place a shell is
  // involved. Everything variable arrives as a positional parameter, which bash
  // expands without re-tokenizing, so a recorded command line is never reparsed.
  function launchPin(pin, monitorName) {
    if (!pin) return
    var focusFirst = monitorName ? "hl.dsp.focus({ monitor = \"" + monitorName + "\" })" : ""
    var argv = ["bash", "-lc",
                '[ -n "$1" ] && hyprctl dispatch "$1" >/dev/null; shift; exec uwsm-app -- "$@"',
                "bash", focusFirst]
    if (pin.desktop) {
      argv.push("gtk-launch")
      argv.push(String(pin.desktop) + ".desktop")
    } else if (pin.exec && pin.exec.length > 0) {
      for (var i = 0; i < pin.exec.length; i++) argv.push(String(pin.exec[i]))
    } else {
      root.notify("Taskbar", "That pin has nothing to launch.")
      return
    }
    Quickshell.execDetached(argv)
  }

  // Left click. A launcher prefers an existing window of its app on that screen
  // over starting a second copy: in "workspace" scope the app may well be
  // running on another workspace of the same output, where the list cannot
  // show it.
  function activateCell(cell) {
    if (cell.kind === "window") {
      root.focusWindow(cell.toplevel)
      return
    }
    var existing = root.findWindowOnMonitor(cell.pin.appId, cell.monitorName)
    if (existing) root.focusWindow(existing)
    else root.launchPin(cell.pin, cell.monitorName)
  }

  // Turn a NUL-separated /proc cmdline into argv. The reader rewrites NUL to
  // 0x1F (unit separator) because NUL does not survive the pipe as text, and
  // 0x1F cannot appear in a command line -- unlike a newline, which the agent
  // prompts here genuinely contain. Only the trailing empty from the final
  // separator is dropped, so a genuinely empty argument is preserved.
  function parseCmdline(text) {
    var parts = String(text || "").split("\u001f")
    while (parts.length > 0 && parts[parts.length - 1] === "") parts.pop()
    return parts
  }

  Process {
    id: cmdlineReader

    // { monitorName, monitorDescription, appId, name }
    property var pending: null

    stdout: StdioCollector { id: cmdlineOutput }

    onExited: function(exitCode) {
      var request = cmdlineReader.pending
      cmdlineReader.pending = null
      if (!request) return
      var argv = root.parseCmdline(cmdlineOutput.text)
      if (exitCode !== 0 || argv.length === 0) {
        root.notify("Could not pin " + request.name,
                    "Its command line could not be read, so there would be no way to start it again.")
        return
      }
      root.pins.pin(request.monitorName, request.monitorDescription,
                    { appId: request.appId, exec: argv })
    }
  }

  // Pinning a window with a desktop entry records the entry. Pinning one
  // without -- an agent terminal started as `ghostty --class=... -e claude` is
  // in no application database -- records the command line it is running, which
  // is the only faithful way to start that window again.
  function pinWindow(cell) {
    var appId = root.appIdOf(cell.toplevel)
    if (!appId) {
      root.notify("Could not pin", "That window reports no application id.")
      return
    }
    var desktop = root.entryIdFor(cell.toplevel)
    if (desktop) {
      root.pins.pin(cell.monitorName, cell.monitorDescription, { appId: appId, desktop: desktop })
      return
    }
    var pid = root.pidOf(cell.toplevel)
    if (!pid) {
      root.notify("Could not pin " + root.appNameFor(cell.toplevel),
                  "It has no desktop entry and no process to read a command line from.")
      return
    }
    if (cmdlineReader.running) return
    cmdlineReader.pending = {
      monitorName: cell.monitorName,
      monitorDescription: cell.monitorDescription,
      appId: appId,
      name: root.appNameFor(cell.toplevel)
    }
    cmdlineReader.command = ["bash", "-c",
                             "tr '\\0' '\\037' < /proc/\"$1\"/cmdline", "bash", String(pid)]
    cmdlineReader.running = true
  }

  function menuActionsFor(cell) {
    var actions = []
    var isLauncher = cell.kind === "launcher"
    var appId = isLauncher ? String(cell.pin.appId) : root.appIdOf(cell.toplevel)
    var pinned = root.pins.isPinned(cell.monitorName, cell.monitorDescription, appId)
    var where = root.aliasMap[cell.monitorName] || cell.monitorName || "this bar"

    actions.push({
      label: (pinned ? "Unpin from " : "Pin to ") + where,
      enabled: true,
      trigger: function() {
        if (pinned) root.pins.unpin(cell.monitorName, cell.monitorDescription, appId)
        else root.pinWindow(cell)
      }
    })

    if (isLauncher) {
      actions.push({
        label: "Launch here",
        enabled: true,
        trigger: function() { root.activateCell(cell) }
      })
    } else {
      actions.push({
        label: "Close window",
        enabled: true,
        danger: true,
        trigger: function() { root.closeWindow(cell.toplevel) }
      })
    }

    return actions
  }

  function openMenu(anchorItem, cell) {
    root.hidePreview()
    contextMenu.close()
    contextMenu.anchorItem = anchorItem
    contextMenu.actions = root.menuActionsFor(cell)
    contextMenu.open = true
  }

  // -------------------------------------------------------------------- view

  visible: cells.length > 0
  implicitWidth: visible ? (vertical ? barSize : Math.ceil(horizontalRow.implicitWidth)) : 0
  implicitHeight: visible ? (vertical ? Math.ceil(verticalColumn.implicitHeight) : barSize) : 0

  Row {
    id: horizontalRow
    visible: !root.vertical
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2

    Repeater {
      model: root.vertical ? [] : root.cells
      delegate: cellDelegate
    }
  }

  Column {
    id: verticalColumn
    visible: root.vertical
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 2

    Repeater {
      model: root.vertical ? root.cells : []
      delegate: cellDelegate
    }
  }

  Component {
    id: cellDelegate

    Loader {
      required property var modelData

      sourceComponent: modelData.kind === "group" ? groupMarker
        : (modelData.kind === "empty" ? emptyMarker : taskButton)

      onLoaded: {
        if (modelData.kind === "group") {
          item.label = String(modelData.label)
          item.gap = Number(modelData.gap)
        } else if (modelData.kind !== "empty") {
          item.cell = modelData
        }
      }
    }
  }

  // A monitor heading. Horizontal bars get the output name; a 28px vertical bar
  // has no room for "HDMI-A-1", so it gets a rule and the name lives in the
  // button tooltips instead.
  Component {
    id: groupMarker

    Item {
      id: markerRoot

      property string label: ""
      property int gap: 0

      readonly property bool showText: root.showMonitorLabels && !root.vertical && !root.compactGroups
      readonly property bool showRule: root.showMonitorLabels && root.vertical && gap > 0

      implicitWidth: root.vertical ? root.barSize
        : gap + (showText ? Math.ceil(markerText.implicitWidth) + 4 : 0)
      implicitHeight: root.vertical ? (showRule ? gap + 5 : gap) : root.barSize

      Text {
        id: markerText
        visible: markerRoot.showText
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: markerRoot.gap
        text: markerRoot.label
        color: root.foreground
        opacity: 0.45
        font.family: root.fontFamily
        font.pixelSize: root.groupPixelSize
        textFormat: Text.PlainText
      }

      Rectangle {
        visible: markerRoot.showRule
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: Math.round(root.barSize * 0.5)
        height: 1
        color: root.foreground
        opacity: 0.3
      }
    }
  }

  // Only reachable with showEmptyMonitors on: says "this screen is empty"
  // rather than leaving a heading dangling with nothing after it.
  Component {
    id: emptyMarker

    Item {
      implicitWidth: root.vertical ? root.barSize : Math.ceil(dash.implicitWidth) + 6
      implicitHeight: root.vertical ? Math.round(root.barSize * 0.5) : root.barSize

      Text {
        id: dash
        anchors.centerIn: parent
        text: "—"
        color: root.foreground
        opacity: 0.3
        font.family: root.fontFamily
        font.pixelSize: root.labelPixelSize
        textFormat: Text.PlainText
      }
    }
  }

  // One button, for a running window or for a pinned app that is not running.
  Component {
    id: taskButton

    Item {
      id: buttonRoot

      property var cell: null

      readonly property bool isLauncher: cell !== null && cell.kind === "launcher"
      readonly property var toplevel: cell && cell.kind === "window" ? cell.toplevel : null
      readonly property bool isActive: toplevel !== null && toplevel.wayland !== null
        && toplevel.wayland === ToplevelManager.activeToplevel
      readonly property bool urgent: toplevel !== null && toplevel.urgent === true
      readonly property string buttonLabel: cell ? root.buttonTextFor(cell) : ""
      readonly property string iconSource: cell && root.showIcons ? root.iconForCell(cell) : ""
      readonly property bool hasIcon: root.showIcons && iconSource.length > 0
        && iconImage.status !== Image.Error

      readonly property int horizontalPadding: 6
      readonly property int contentWidth: {
        var width = 0
        if (hasIcon) width += root.iconSize
        if (buttonLabel.length > 0) {
          if (hasIcon) width += content.spacing
          width += Math.min(root.maxLabelWidth, Math.ceil(buttonText.implicitWidth))
        }
        // A window with neither a resolvable icon nor a label still needs a
        // target you can hit and hover for its tooltip.
        return Math.max(width, root.iconSize)
      }

      implicitWidth: root.vertical ? root.barSize : contentWidth + horizontalPadding * 2
      implicitHeight: root.vertical ? root.buttonHeight : root.barSize

      Rectangle {
        anchors.centerIn: parent
        width: root.vertical ? root.buttonHeight : parent.width
        height: root.buttonHeight
        radius: Math.min(6, height / 2)
        color: root.foreground
        opacity: buttonRoot.isActive ? 0.18 : (pointer.containsMouse ? 0.1 : 0)
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
      }

      // The urgency mark sits on the bar's inner edge - the one facing the
      // desktop - so it underlines a top bar and overlines a bottom one, the
      // same way the bar marks an open panel.
      Rectangle {
        visible: buttonRoot.urgent
        width: root.vertical ? 2 : Math.round(parent.width * 0.5)
        height: root.vertical ? Math.round(parent.height * 0.5) : 2
        radius: 1
        color: root.urgentColor
        x: root.vertical
          ? (root.barPosition === "left" ? parent.width - width : 0)
          : Math.round((parent.width - width) / 2)
        y: root.vertical
          ? Math.round((parent.height - height) / 2)
          : (root.barPosition === "bottom" ? 0 : parent.height - height)
      }

      Row {
        id: content
        anchors.centerIn: parent
        spacing: 5

        Image {
          id: iconImage
          visible: buttonRoot.hasIcon
          width: root.iconSize
          height: root.iconSize
          anchors.verticalCenter: parent.verticalCenter
          fillMode: Image.PreserveAspectFit
          // Decode at physical pixels. Image sizes in logical pixels, which
          // leaves PNG icons visibly soft on a HiDPI panel.
          sourceSize.width: Math.round(root.iconSize * Screen.devicePixelRatio)
          sourceSize.height: Math.round(root.iconSize * Screen.devicePixelRatio)
          source: buttonRoot.iconSource
          // A pinned app that is not running is dimmer than a live window, so
          // the row still reads at a glance as "these are open, these are not".
          opacity: buttonRoot.isLauncher ? 0.4 : (buttonRoot.isActive ? 1 : 0.75)
        }

        Text {
          id: buttonText
          visible: buttonRoot.buttonLabel.length > 0
          anchors.verticalCenter: parent.verticalCenter
          width: Math.min(root.maxLabelWidth, implicitWidth)
          text: buttonRoot.buttonLabel
          color: buttonRoot.urgent ? root.urgentColor : root.foreground
          opacity: buttonRoot.isLauncher ? 0.4 : (buttonRoot.isActive ? 1 : 0.7)
          font.family: root.fontFamily
          font.pixelSize: root.labelPixelSize
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }
      }

      MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onClicked: function(mouse) {
          if (!buttonRoot.cell) return
          // Any click ends the hover: leaving a preview hanging over a menu it
          // does not belong to is what made the old tooltip feel broken.
          root.hidePreview()
          if (mouse.button === Qt.RightButton) {
            root.openMenu(buttonRoot, buttonRoot.cell)
          } else if (mouse.button === Qt.MiddleButton) {
            // Middle click stays the fast path for closing; a launcher has
            // nothing to close.
            if (buttonRoot.toplevel) root.closeWindow(buttonRoot.toplevel)
          } else {
            root.activateCell(buttonRoot.cell)
          }
        }

        onEntered: if (buttonRoot.cell) root.showPreviewFor(buttonRoot, buttonRoot.cell)
        onExited: root.hidePreview()
      }
    }
  }
}
