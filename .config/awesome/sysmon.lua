local awful = require("awful")
local wibox = require("wibox")
local vicious = require("vicious")
local gears = require("gears")

local sysmon = {}

local graph_width = 140
local graph_height = 46
local border_color = "#555555"

local function make_graph(color)
    local g = wibox.widget.graph()
    g:set_width(graph_width)
    g:set_background_color("#1a1a1a")
    g:set_color(color)
    g.forced_height = graph_height
    return g
end

local function wrap_graph(g)
    return wibox.container.margin(
        wibox.container.place(
            wibox.container.background(
                wibox.container.constraint(g, "exact", graph_width, graph_height),
                nil, nil, border_color
            ),
            "center", "center"
        ),
        0, 4, 0, 0  -- left, right, top, bottom
    )
end

-- CPU graph
local cpu_graph = make_graph("#ff6e67")
local cpu_widget = wrap_graph(cpu_graph)
local cpu_tooltip = awful.tooltip({ objects = {cpu_widget} })
vicious.register(cpu_graph, vicious.widgets.cpu, function(widget, args)
    local val = args[1]
    if val < 30 then
        cpu_graph:set_color("#5af78e")     -- green
    elseif val < 60 then
        cpu_graph:set_color("#f3f99d")     -- yellow
    elseif val < 80 then
        cpu_graph:set_color("#ff9e64")     -- orange
    else
        cpu_graph:set_color("#ff6e67")     -- red
    end
    awful.spawn.easy_async(
        {"sh", "-c", "ps -eo comm,%cpu --sort=-%cpu --no-headers | head -1"},
        function(stdout)
            local name, pct = stdout:match("^(%S+)%s+(%S+)")
            if name then
                cpu_tooltip:set_text("CPU: " .. val .. "% | " .. name .. " " .. pct .. "%")
            end
        end
    )
    return val
end, 1)
local cpu_menu = nil
cpu_widget:buttons(gears.table.join(awful.button({}, 1, function()
    if cpu_menu then cpu_menu:hide(); cpu_menu = nil; return end
    awful.spawn.easy_async(
        {"sh", "-c", "ps -eo comm,%cpu --sort=-%cpu --no-headers | head -8"},
        function(stdout)
            local items = {}
            for line in stdout:gmatch("[^\n]+") do
                local name, pct = line:match("^(%S+)%s+(%S+)")
                if name then table.insert(items, { name .. "  " .. pct .. "%", nil }) end
            end
            cpu_menu = awful.menu({ items = items, theme = { width = 250 } })
            cpu_menu:show()
        end)
end)))
sysmon.cpu = cpu_widget

-- Memory graph
local mem_graph = make_graph("#5af78e")
local mem_widget = wrap_graph(mem_graph)
local mem_tooltip = awful.tooltip({ objects = {mem_widget} })
vicious.register(mem_graph, vicious.widgets.mem, function(widget, args)
    local val = args[1]
    if val < 30 then
        mem_graph:set_color("#5af78e")     -- green
    elseif val < 60 then
        mem_graph:set_color("#f3f99d")     -- yellow
    elseif val < 80 then
        mem_graph:set_color("#ff9e64")     -- orange
    else
        mem_graph:set_color("#ff6e67")     -- red
    end
    mem_tooltip:set_text(string.format("Mem: %s%% | %sMB / %sMB", val, args[2], args[3]))
    return val
end, 1)
local mem_menu = nil
mem_widget:buttons(gears.table.join(awful.button({}, 1, function()
    if mem_menu then mem_menu:hide(); mem_menu = nil; return end
    awful.spawn.easy_async(
        {"sh", "-c", "ps -eo comm,%mem --sort=-%mem --no-headers | head -8"},
        function(stdout)
            local items = {}
            for line in stdout:gmatch("[^\n]+") do
                local name, pct = line:match("^(%S+)%s+(%S+)")
                if name then table.insert(items, { name .. "  " .. pct .. "%", nil }) end
            end
            mem_menu = awful.menu({ items = items, theme = { width = 250 } })
            mem_menu:show()
        end)
end)))
sysmon.mem = mem_widget

-- Network graph (download)
local net_graph = make_graph("#57c7ff")
local net_widget = wrap_graph(net_graph)
local net_tooltip = awful.tooltip({ objects = {net_widget} })
local net_max = 1024 -- auto-scales

local function format_bytes(bytes)
    if bytes >= 1048576 then
        return string.format("%.1fM", bytes / 1048576)
    elseif bytes >= 1024 then
        return string.format("%.0fK", bytes / 1024)
    else
        return string.format("%dB", bytes)
    end
end

vicious.register(net_graph, vicious.widgets.net, function(widget, args)
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
    net_tooltip:set_text(active_iface .. " ↓" .. format_bytes(down) .. " ↑" .. format_bytes(up))
    -- Auto-scale: track max and normalize to 0-100
    if down > net_max then net_max = down end
    return (net_max > 0) and (down / net_max * 100) or 0
end, 1)
net_widget:buttons(gears.table.join(awful.button({}, 1, function()
    awful.spawn("gnome-system-monitor")
end)))
sysmon.net = net_widget

return sysmon
