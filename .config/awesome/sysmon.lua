local awful = require("awful")
local wibox = require("wibox")
local vicious = require("vicious")

local sysmon = {}

-- CPU
sysmon.cpu = wibox.widget.textbox()
vicious.register(sysmon.cpu, vicious.widgets.cpu, " $1% ", 3)
awful.tooltip({ objects = {sysmon.cpu}, text = "CPU usage" })

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

local net_ifaces = {}
for iface in io.popen("ls /sys/class/net/"):lines() do
    if iface ~= "lo" then
        table.insert(net_ifaces, iface)
    end
end

vicious.register(net_widget, vicious.widgets.net,
    function(widget, args)
        local down, up = 0, 0
        local active_iface = "none"
        for _, iface in ipairs(net_ifaces) do
            local d = args["{" .. iface .. " down_b}"] or 0
            local u = args["{" .. iface .. " up_b}"] or 0
            if d + u > down + up then
                down, up = d, u
                active_iface = iface
            end
        end
        net_tooltip:set_text("Network: " .. active_iface)
        return " ↓" .. format_bytes(down) .. " ↑" .. format_bytes(up) .. " "
    end, 2)
sysmon.net = net_widget

return sysmon
