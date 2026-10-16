-- Tiled 4K workspace: two rows with 2/5 | 3/5 width columns.
-- The 4K bar sits between the rows; its layer surface is 30px high.
local middle_bar_height = 30
local zone_by_window = {}
local preferred_zone_by_class = {
  ["brave-cinhimbnkkaeohfgghhklpknlkffjgod-Default"] = 3, -- YouTube Music, lower left
}
local pending_launches = {}

local function target_id(target)
  local window = target.window
  return window and tostring(window.stable_id) or "target:" .. tostring(target.index)
end

local function zone_boxes(area)
  local left = math.floor(area.w * 2 / 5)
  local right = area.w - left
  local usable_height = area.h - middle_bar_height
  local upper = math.floor(usable_height / 2)
  local lower = usable_height - upper
  local right_x = area.x + left
  local lower_y = area.y + upper + middle_bar_height

  return {
    { x = area.x, y = area.y, w = left, h = upper },
    { x = right_x, y = area.y, w = right, h = upper },
    { x = area.x, y = lower_y, w = left, h = lower },
    { x = right_x, y = lower_y, w = right, h = lower },
  }
end

hl.layout.register("four_zones", {
  recalculate = function(ctx)
    local buckets = { {}, {}, {}, {} }

    for _, target in ipairs(ctx.targets) do
      local id = target_id(target)
      local zone = zone_by_window[id] or
          (target.window and preferred_zone_by_class[target.window.class])
      if not zone then
        zone = 1
        for index = 2, 4 do
          if #buckets[index] < #buckets[zone] then zone = index end
        end
      end
      zone_by_window[id] = zone
      table.insert(buckets[zone], target)
    end

    for zone, box in ipairs(zone_boxes(ctx.area)) do
      local targets = buckets[zone]
      for index, target in ipairs(targets) do
        local top = math.floor(box.h * (index - 1) / #targets)
        local bottom = math.floor(box.h * index / #targets)
        target:place({ x = box.x, y = box.y + top, w = box.w, h = bottom - top })
      end
    end
  end,

  layout_msg = function(_, msg)
    if msg == "refresh" then return true end
    return "four_zones: expected refresh"
  end,
})

-- Apply only to workspaces displayed on the Samsung, preserving other monitors.
hl.workspace_rule({ workspace = "m[DP-1]", layout = "lua:four_zones" })
hl.on("workspace.created", function(workspace)
  if workspace.monitor and workspace.monitor.name == "DP-1" then
    hl.workspace_rule({ workspace = tostring(workspace.id), layout = "lua:four_zones" })
  end
end)

local function samsung_workspace()
  local monitor = hl.get_monitor("DP-1")
  if not monitor or
      not (monitor.description or ""):find("Samsung Electric Company U32J59x", 1, true) then return nil end
  return monitor.active_workspace
end

local function first_available_zone(workspace)
  local counts = { 0, 0, 0, 0 }
  for _, window in ipairs(hl.get_windows()) do
    if window.workspace and window.workspace.id == workspace.id then
      local zone = zone_by_window[tostring(window.stable_id)]
      if zone then counts[zone] = counts[zone] + 1 end
    end
  end
  local best = 1
  for zone = 2, 4 do
    if counts[zone] < counts[best] then best = zone end
  end
  return best
end

local function show_window(window, zone)
  local workspace = samsung_workspace()
  if not window or not workspace then return end
  local id = tostring(window.stable_id)
  zone = zone or preferred_zone_by_class[window.class] or zone_by_window[id] or first_available_zone(workspace)

  if not window.workspace or window.workspace.id ~= workspace.id then
    hl.dispatch(hl.dsp.window.move({ window = window, workspace = workspace.name, follow = false }))
  end
  hl.dispatch(hl.dsp.window.fullscreen({ window = window, action = "unset" }))
  hl.dispatch(hl.dsp.window.float({ window = window, action = "disable" }))
  zone_by_window[id] = zone
  preferred_zone_by_class[window.class] = zone

  -- The layout tiles multiple windows in one zone vertically. Avoid mutating
  -- Hyprland groups here: group:add crashed the compositor on window events.
  hl.dispatch(hl.dsp.focus({ workspace = workspace.name }))
  hl.dispatch(hl.dsp.layout("refresh"))
  hl.dispatch(hl.dsp.focus({ window = window }))
end

hl.on("window.open", function(window)
  for index, pending in ipairs(pending_launches) do
    if pending.match(window) then
      table.remove(pending_launches, index)
      show_window(window, preferred_zone_by_class[window.class] or pending.zone)
      return
    end
  end
end)

hl.on("window.title", function(window)
  for index, pending in ipairs(pending_launches) do
    if pending.match(window) then
      table.remove(pending_launches, index)
      show_window(window, preferred_zone_by_class[window.class] or pending.zone)
      return
    end
  end
end)

return {
  move_active = function(zone)
    show_window(hl.get_active_window(), zone)
  end,

  launch_or_focus = function(match, command, default_zone)
    local workspace = samsung_workspace()
    for _, window in ipairs(hl.get_windows()) do
      if match(window) then
        if workspace then
          show_window(window, preferred_zone_by_class[window.class] or default_zone)
        else
          hl.dispatch(hl.dsp.focus({ window = window }))
        end
        return
      end
    end

    if not workspace then
      hl.dispatch(hl.dsp.exec_cmd(command))
      return
    end

    -- Repeated shortcuts while an app is starting should share the first launch.
    for _, pending in ipairs(pending_launches) do
      if pending.command == command then return end
    end

    local pending = { match = match, command = command, zone = default_zone }
    table.insert(pending_launches, pending)
    hl.timer(function()
      for index, candidate in ipairs(pending_launches) do
        if candidate == pending then
          table.remove(pending_launches, index)
          break
        end
      end
    end, { timeout = 30000, type = "oneshot" })
    hl.dispatch(hl.dsp.exec_cmd(command))
  end,
}
