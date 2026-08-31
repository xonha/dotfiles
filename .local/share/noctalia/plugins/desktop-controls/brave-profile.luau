--!nonstrict

local label = "…"
local busy = false
local script = "/home/henrique/.config/scripts/browser-profile.sh"

local function trim(value)
  return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function render()
  barWidget.setImage("/usr/share/icons/Papirus/24x24/apps/brave.svg", false, 18, 18)
  barWidget.setText(if barWidget.isVertical() then "" else label)
  barWidget.setTooltip(`Navegador padrão: {label} — clique para trocar`)
end

local function refresh()
  if busy then return end
  busy = true
  noctalia.runAsync({ script, "--status" }, function(result)
    busy = false
    label = if result.exitCode == 0 then trim(result.stdout) else "Erro"
    if label == "" then label = "Outro" end
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
  noctalia.runAsync({ script, "--cycle" }, function(result)
    busy = false
    if result.exitCode ~= 0 then
      noctalia.notifyError("Brave", result.stderr ~= "" and result.stderr or "Não foi possível trocar o perfil")
    end
    refresh()
  end)
end

render()
refresh()
