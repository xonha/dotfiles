--!nonstrict

local label = "…"
local busy = false
local color = "#cba6f7"

local function render()
  barWidget.setGlyph("calendar")
  barWidget.setGlyphColor(color)
  barWidget.setColor(color)
  barWidget.setText(if barWidget.isVertical() then "" else label)
  barWidget.setTooltip("Calendário")
end

local function refresh()
  if busy then return end
  busy = true
  noctalia.runAsync({ "date", "+%a %d/%m" }, function(result)
    busy = false
    if result.exitCode == 0 then
      label = (result.stdout or ""):gsub("^%s+", ""):gsub("%s+$", "")
    end
    render()
  end)
end

function update()
  noctalia.setUpdateInterval(60000)
  refresh()
end

render()
refresh()
