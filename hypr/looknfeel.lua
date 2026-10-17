local samsung_4k = "Samsung Electric Company U32J59x HCJR902462"

local function update_rounding()
  local connected = false
  for _, monitor in ipairs(hl.get_monitors()) do
    if monitor.description == samsung_4k then
      connected = true
      break
    end
  end

  hl.config({ decoration = { rounding = connected and 6 or 0 } })
end

update_rounding()
hl.on("monitor.layout_changed", update_rounding)
