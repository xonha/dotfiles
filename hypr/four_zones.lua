-- Tiled 4K workspace: two rows with 2/5 | 3/5 width columns.
-- The navbar is on the top edge, so the rows use the normal Hyprland gap.
local middle_bar_height = 0
local stash_prefix = "special:four-zones-"
local zone_priority = { 4, 2, 3, 1 } -- lower right, upper right, lower left, upper left
local zone_by_window = {}
local span_mode_by_window = {}
local preferred_zone_by_class = {
  ["brave-cinhimbnkkaeohfgghhklpknlkffjgod-Default"] = 3, -- YouTube Music, lower left
}
local pending_launches = {}

local function least_populated_zone(count)
  local best = zone_priority[1]
  for index = 2, #zone_priority do
    local zone = zone_priority[index]
    if count(zone) < count(best) then best = zone end
  end
  return best
end

local function target_id(target)
  local window = target.window
  return window and tostring(window.stable_id) or "target:" .. tostring(target.index)
end

local function stashed_zone(window)
  local name = window.workspace and window.workspace.name or ""
  local zone = tonumber(name:match("^special:four%-zones%-(%d)$"))
  return zone and zone >= 1 and zone <= 4 and zone or nil
end

local function assigned_zone(window)
  return zone_by_window[tostring(window.stable_id)] or stashed_zone(window)
      or preferred_zone_by_class[window.class]
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

local function place_full(targets, box)
  for _, target in ipairs(targets) do target:place(box) end
end

hl.layout.register("four_zones", {
  recalculate = function(ctx)
    local buckets = { {}, {}, {}, {} }
    local span_target, span_zone, span_id, span_mode

    for _, target in ipairs(ctx.targets) do
      local id = target_id(target)
      local zone = target.window and assigned_zone(target.window) or zone_by_window[id]
      if not zone then
        zone = least_populated_zone(function(index) return #buckets[index] end)
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
      if span_mode then place_stacked(buckets[zone], box)
      else place_full(buckets[zone], box) end
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
    if window.workspace and (window.workspace.id == workspace.id or stashed_zone(window)) then
      local zone = assigned_zone(window)
      if zone then counts[zone] = counts[zone] + 1 end
    end
  end
  return least_populated_zone(function(zone) return counts[zone] end)
end

local function show_window(window, zone)
  local workspace = samsung_workspace()
  if not window or not workspace then return end
  local id = tostring(window.stable_id)
  zone = zone or assigned_zone(window) or first_available_zone(workspace)

  -- Keep only the selected window on this zone's visible workspace. A named
  -- special workspace holds each replaced window until its app shortcut is used.
  for _, candidate in ipairs(hl.get_windows()) do
    if candidate.stable_id ~= window.stable_id and candidate.workspace and
        candidate.workspace.id == workspace.id and not candidate.floating and
        assigned_zone(candidate) == zone then
      hl.dispatch(hl.dsp.window.move({ window = candidate,
        workspace = stash_prefix .. zone, follow = false }))
    end
  end

  if not window.workspace or window.workspace.id ~= workspace.id then
    hl.dispatch(hl.dsp.window.move({ window = window, workspace = workspace.name, follow = false }))
  end
  hl.dispatch(hl.dsp.window.fullscreen({ window = window, action = "unset" }))
  hl.dispatch(hl.dsp.window.float({ window = window, action = "disable" }))
  zone_by_window[id] = zone
  preferred_zone_by_class[window.class] = zone

  -- Avoid Hyprland groups here: group:add crashed the compositor on window events.
  hl.dispatch(hl.dsp.focus({ workspace = workspace.name }))
  hl.dispatch(hl.dsp.layout("refresh"))
  hl.dispatch(hl.dsp.focus({ window = window }))
end

local function reconcile_visible_zones()
  local workspace = samsung_workspace()
  if not workspace then return end

  local active = hl.get_active_window()
  for zone = 1, 4 do
    local occupants = {}
    local keep
    for _, window in ipairs(hl.get_windows()) do
      if window.workspace and window.workspace.id == workspace.id and
          not window.floating and assigned_zone(window) == zone then
        table.insert(occupants, window)
        if not keep or (active and active.stable_id == window.stable_id) then
          keep = window
        end
      end
    end
    for _, window in ipairs(occupants) do
      if window.stable_id ~= keep.stable_id then
        hl.dispatch(hl.dsp.window.move({ window = window,
          workspace = stash_prefix .. zone, follow = false }))
      end
    end
  end
end

local function schedule_reconcile()
  hl.timer(reconcile_visible_zones, { timeout = 100, type = "oneshot" })
end

hl.on("config.reloaded", schedule_reconcile)
hl.on("workspace.active", schedule_reconcile)
hl.on("window.move_to_workspace", schedule_reconcile)

hl.on("window.open", function(window)
  schedule_reconcile()
  for index, pending in ipairs(pending_launches) do
    if pending.match(window) then
      table.remove(pending_launches, index)
      show_window(window, preferred_zone_by_class[window.class] or pending.zone)
      return
    end
  end
  local workspace = samsung_workspace()
  if workspace and window.workspace and window.workspace.id == workspace.id and
      not window.floating then show_window(window) end
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

local function restore_stashed_without_samsung()
  if samsung_workspace() then return end
  local workspace
  for _, monitor in ipairs(hl.get_monitors()) do
    if monitor.name ~= "FALLBACK" and monitor.active_workspace then
      workspace = monitor.active_workspace
      break
    end
  end
  if not workspace then return end

  for _, window in ipairs(hl.get_windows()) do
    if stashed_zone(window) then
      hl.dispatch(hl.dsp.window.move({ window = window,
        workspace = workspace.name, follow = false }))
    end
  end
end

hl.on("monitor.layout_changed", restore_stashed_without_samsung)
hl.on("config.reloaded", restore_stashed_without_samsung)

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
    local matches = {}
    for _, window in ipairs(hl.get_windows()) do
      if match(window) then table.insert(matches, window) end
    end
    if #matches > 0 then
      local window = matches[1]
      local active = hl.get_active_window()
      for index, candidate in ipairs(matches) do
        if active and candidate.stable_id == active.stable_id then
          window = matches[index % #matches + 1]
          break
        end
      end
      if workspace then
        show_window(window, preferred_zone_by_class[window.class] or default_zone)
      else
        if stashed_zone(window) then
          local active_workspace = hl.get_active_workspace()
          if active_workspace and not active_workspace.special then
            hl.dispatch(hl.dsp.window.move({ window = window,
              workspace = active_workspace.name, follow = false }))
          end
        end
        hl.dispatch(hl.dsp.focus({ window = window }))
      end
      return
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
