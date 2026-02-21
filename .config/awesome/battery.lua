local wibox = require("wibox")
local gears = require("gears")

local battery = wibox.widget {
    widget = wibox.widget.textbox,
    text = "🔋 --%",
}

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    return content
end

local function update_battery()
    local capacity = read_file("/sys/class/power_supply/BAT0/capacity")
    local status = read_file("/sys/class/power_supply/BAT0/status")

    if capacity then
        capacity = capacity:gsub("\n", "")
    else
        capacity = "?"
    end

    if status then
        status = status:gsub("\n", "")
    else
        status = "?"
    end

    local icon = "🔋"
    if status == "Charging" then
        icon = "⚡"
    elseif status == "Full" then
        icon = "🔌"
    end

    battery.text = icon .. " " .. capacity .. "%"
end

-- update every 30s
gears.timer {
    timeout = 30,
    autostart = true,
    call_now = true,
    callback = update_battery
}

return battery

