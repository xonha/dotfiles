--!nonstrict

local active = false
local busy = false

local function render()
  barWidget.setVisible(active)
  barWidget.setGlyph("keyboard")
  barWidget.setGlyphColor("#94e2d5")
  barWidget.setText(if barWidget.isVertical() then "" else "Keyd")
  barWidget.setTooltip("Keyd ativo — clique para desativar")
end

local function refresh()
  if busy then return end
  busy = true
  noctalia.runAsync({ "systemctl", "is-active", "keyd.service" }, function(result)
    busy = false
    active = result.exitCode == 0
    render()
  end)
end

function update()
  noctalia.setUpdateInterval(2000)
  refresh()
end

function onClick()
  if busy then return end
  busy = true
  local action = if active then "--stop" else "--start"
  noctalia.runAsync({ "/home/henrique/.config/scripts/keyd.sh", action }, function(result)
    busy = false
    if result.exitCode ~= 0 then
      noctalia.notifyError("Keyd", result.stderr ~= "" and result.stderr or "Não foi possível alterar o serviço")
    end
    refresh()
  end)
end

render()
refresh()
