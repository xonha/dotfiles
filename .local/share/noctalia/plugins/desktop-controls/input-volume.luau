--!nonstrict

local busy = false
local muted = true
local level = ""

local function render()
  barWidget.setVisible(not muted)
  barWidget.setGlyph("microphone")
  barWidget.setGlyphColor("#74c7ec")
  barWidget.setColor("#74c7ec")
  barWidget.setText(if barWidget.isVertical() then "" else level)
  barWidget.setTooltip("Volume do microfone")
end

local function refresh()
  if busy then return end
  busy = true
  noctalia.runAsync({ "wpctl", "get-volume", "@DEFAULT_SOURCE@" }, function(result)
    busy = false
    local output = result.stdout or ""
    muted = output:find("[MUTED]", 1, true) ~= nil
    local value = output:match("Volume:%s+([%d.]+)")
    level = value ~= nil and (tostring(math.floor(tonumber(value) * 100 + 0.5)) .. "%") or ""
    render()
  end)
end

function update()
  noctalia.setUpdateInterval(1000)
  refresh()
end

render()
refresh()
