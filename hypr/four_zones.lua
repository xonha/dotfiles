-- Tiled 4K workspace: two rows with 2/5 | 3/5 width columns.
-- The 4K bar sits between the rows; its layer surface is 30px high.
local middle_bar_height = 30
local zone_by_window = {}
local span_mode_by_window = {}
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

local function place_stacked(targets, box)
  for index, target in ipairs(targets) do
    local top = math.floor(box.h * (index - 1) / #targets)
    local bottom = math.floor(box.h * index / #targets)
    target:place({ x = box.x, y = box.y + top, w = box.w, h = bottom - top })
  end
end

hl.layout.register("four_zones", {
  recalculate = function(ctx)
    local buckets = { {}, {}, {}, {} }
    local span_target, span_zone, span_id, span_mode

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
      if span_mode_by_window[id] then
        span_target, span_zone, span_id, span_mode = target, zone, id,
            span_mode_by_window[id]
      end
    end

    local boxes = zone_boxes(ctx.area)
    if span_mode == "row" then
      local wide_start = span_zone <= 2 and 1 or 3
      local other_start = wide_start == 1 and 3 or 1

      -- Keep the other windows visible in the opposite row. Their saved zones
      -- stay unchanged, so switching the toggle off restores the four zones.
      for zone = wide_start, wide_start + 1 do
        for _, target in ipairs(buckets[zone]) do
          if target_id(target) ~= span_id then
            local destination = #buckets[other_start] <= #buckets[other_start + 1]
                and other_start or other_start + 1
            table.insert(buckets[destination], target)
          end
        end
        buckets[zone] = {}
      end

      local left, right = boxes[wide_start], boxes[wide_start + 1]
      span_target:place({ x = left.x, y = left.y, w = left.w + right.w, h = left.h })
    elseif span_mode == "half_cell" then
      local row_start = span_zone <= 2 and 1 or 3
      local other_zone = span_zone == row_start and row_start + 1 or row_start
      local left_width = math.floor(ctx.area.w / 2)
      local right_width = ctx.area.w - left_width
      local left_box = { x = ctx.area.x, y = boxes[row_start].y,
        w = left_width, h = boxes[row_start].h }
      local right_box = { x = ctx.area.x + left_width, y = boxes[row_start].y,
        w = right_width, h = boxes[row_start].h }
      local cell = span_zone == row_start and left_box or right_box
      local other_cell = span_zone == row_start and right_box or left_box

      -- If several windows shared the focused zone, keep them visible in the
      -- adjacent cell while the focused window fills its own 2x2 cell.
      for _, target in ipairs(buckets[span_zone]) do
        if target_id(target) ~= span_id then
          table.insert(buckets[other_zone], target)
        end
      end

      buckets[span_zone] = {}
      span_target:place(cell)
      place_stacked(buckets[other_zone], other_cell)
      buckets[other_zone] = {}
    end

    for zone, box in ipairs(boxes) do
      place_stacked(buckets[zone], box)
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

local function toggle_span(mode)
  local workspace = samsung_workspace()
  local window = hl.get_active_window()
  if not workspace or not window or not window.workspace or
      window.workspace.id ~= workspace.id then return end

  local id = tostring(window.stable_id)
  local previous_mode = span_mode_by_window[id]
  for _, candidate in ipairs(hl.get_windows()) do
    if candidate.workspace and candidate.workspace.id == workspace.id then
      span_mode_by_window[tostring(candidate.stable_id)] = nil
    end
  end
  if previous_mode ~= mode then span_mode_by_window[id] = mode end

  hl.dispatch(hl.dsp.window.fullscreen({ window = window, action = "unset" }))
  hl.dispatch(hl.dsp.window.float({ window = window, action = "disable" }))
  hl.dispatch(hl.dsp.layout("refresh"))
  hl.dispatch(hl.dsp.focus({ window = window }))
end

return {
  move_active = function(zone)
    local window = hl.get_active_window()
    if window then span_mode_by_window[tostring(window.stable_id)] = nil end
    show_window(window, zone)
  end,

  toggle_row_wide = function()
    toggle_span("row")
  end,

  toggle_half_cell = function()
    toggle_span("half_cell")
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
