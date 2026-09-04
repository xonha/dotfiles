-- Monitor layout is managed by HyprDynamicMonitors.
-- Hyprland 0.56's Lua API has no hl.source() equivalent, so read the generated
-- Hyprlang destination and translate its monitor rules into hl.monitor calls.
-- The HyprDynamicMonitors service runs `hyprctl reload` after replacing it.

local path = os.getenv("HOME") .. "/.config/hypr/monitors.conf"
local file = io.open(path, "r")

if file then
    for line in file:lines() do
        local rule = line:match("^%s*monitor%s*=%s*(.-)%s*$")
        if rule and not rule:match("^#") then
            local fields = {}
            for field in rule:gmatch("([^,]+)") do
                fields[#fields + 1] = field:gsub("^%s+", ""):gsub("%s+$", "")
            end

            local output = fields[1]
            if output and output ~= "" then
                local spec = { output = output }
                if fields[2] == "disable" then
                    spec.disabled = true
                else
                    spec.mode = fields[2] or "preferred"
                    spec.position = fields[3] or "auto"
                    spec.scale = tonumber(fields[4]) or 1
                end
                hl.monitor(spec)
            end
        end
    end
    file:close()
end
