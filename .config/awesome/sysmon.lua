local awful = require("awful")
local wibox = require("wibox")
local vicious = require("vicious")

local sysmon = {}

-- CPU
sysmon.cpu = wibox.widget.textbox()
local cpu_tooltip = awful.tooltip({ objects = {sysmon.cpu} })
vicious.register(sysmon.cpu, vicious.widgets.cpu, function(widget, args)
    awful.spawn.easy_async(
        {"sh", "-c", "ps -eo comm,%cpu --sort=-%cpu --no-headers | head -1"},
        function(stdout)
            local name, pct = stdout:match("^(%S+)%s+(%S+)")
            if name then
                cpu_tooltip:set_text(name .. " " .. pct .. "%")
            end
        end
    )
    return " " .. args[1] .. "% "
end, 3)

-- Memory
sysmon.mem = wibox.widget.textbox()
local mem_tooltip = awful.tooltip({ objects = {sysmon.mem} })
vicious.register(sysmon.mem, vicious.widgets.mem, function(widget, args)
    mem_tooltip:set_text(string.format("Memory: %sMB / %sMB", args[2], args[3]))
    return " " .. args[1] .. "% "
end, 5)

-- Network – try all common interfaces, show whichever is active
local net_widget = wibox.widget.textbox(" ↓0B ↑0B ")
local net_tooltip = awful.tooltip({ objects = {net_widget} })

local function format_bytes(bytes)
    if bytes >= 1048576 then
        return string.format("%.1fM", bytes / 1048576)
    elseif bytes >= 1024 then
        return string.format("%.0fK", bytes / 1024)
    else
        return string.format("%dB", bytes)
    end
end

vicious.register(net_widget, vicious.widgets.net,
    function(widget, args)
        local down, up = 0, 0
        local active_iface = "none"
        for key, val in pairs(args) do
            local iface = key:match("^{(.+) down_b}$")
            if iface and iface ~= "lo" then
                local d = tonumber(val) or 0
                local u = tonumber(args["{" .. iface .. " up_b}"] or 0) or 0
                if d + u > down + up then
                    down, up = d, u
                    active_iface = iface
                end
            end
        end
        net_tooltip:set_text("Network: " .. active_iface)
        return " ↓" .. format_bytes(down) .. " ↑" .. format_bytes(up) .. " "
    end, 2)
sysmon.net = net_widget

return sysmon
