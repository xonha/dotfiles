--!nonstrict

local color = "#94e2d5"
local capsOn = false

local function readCapsLock()
  local entries = noctalia.listDir("/sys/class/leds")
  if type(entries) ~= "table" then return false end
  for _, name in ipairs(entries) do
    if type(name) == "string" and name:lower():find("capslock", 1, true) then
      local value = noctalia.readFile("/sys/class/leds/" .. name .. "/brightness")
      if tonumber((value or ""):match("%d+")) == 1 then return true end
    end
  end
  return false
end

local function render()
  barWidget.setVisible(capsOn)
  barWidget.setGlyph("capslock")
  barWidget.setGlyphColor(color)
  barWidget.setColor(color)
  barWidget.setText(if barWidget.isVertical() then "" else "Caps")
  barWidget.setTooltip("Caps Lock ativo")
end

function update()
  noctalia.setUpdateInterval(250)
  capsOn = readCapsLock()
  render()
end

render()
