--!nonstrict

local color = "#b4befe"
local glyph = "network-off"
local label = ""
local busy = false

local function render()
  barWidget.setVisible(label ~= "")
  barWidget.setGlyph(glyph)
  barWidget.setGlyphColor(color)
  barWidget.setColor(color)
  barWidget.setText(if barWidget.isVertical() then "" else label)
  barWidget.setTooltip(label == "Wired" and "Conexão cabeada" or (label ~= "" and label or "Rede desconectada"))
end

local function refresh()
  if busy then return end
  busy = true
  noctalia.runAsync({ "nmcli", "-t", "-f", "TYPE,NAME", "connection", "show", "--active" }, function(result)
    busy = false
    local first = (result.stdout or ""):match("([^\n]+)") or ""
    local kind, name = first:match("^([^:]+):(.+)$")
    if kind == nil or name == nil then
      glyph = "network-off"
      label = ""
    elseif kind == "802-3-ethernet" or kind == "ethernet" then
      glyph = "ethernet"
      label = "Wired"
    else
      glyph = "wifi"
      label = name
    end
    render()
  end)
end

function update()
  noctalia.setUpdateInterval(2000)
  refresh()
end

render()
refresh()
