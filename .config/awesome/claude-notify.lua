local awful = require("awful")
local naughty = require("naughty")
local gears = require("gears")

local SOUND = "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"
local LISTENER = os.getenv("HOME") .. "/.config/awesome/claude-notify-listener.py"
local listener_pid = nil
local active_notifications = {}

local function handle_message(line)
    local wid_str, project = line:match("^(%d+)|(.*)$")
    if not wid_str then return end
    local wid = tonumber(wid_str)

    -- Find the client and tag by window ID
    local t = nil
    local target_client = nil
    if wid > 0 then
        for _, c in ipairs(client.get()) do
            if c.window == wid then
                target_client = c
                local tags = c:tags()
                if #tags > 0 then
                    t = tags[1]
                end
                break
            end
        end
    end
    if not t then t = mouse.screen.selected_tag end

    -- Set urgent flag so mod+u can jump to it
    if target_client then
        target_client.urgent = true
    end

    -- Suppress notification if already viewing this workspace
    if t and t.selected and t.screen == mouse.screen then return end

    local num = t and tostring(t.index) or "?"
    local label = t and tag_labels and tag_labels[t]
    local tag_str = label and (num .. ": " .. label) or num

    local n = naughty.notify({
        title = "Claude Code [" .. tag_str .. "]",
        text = "Ready for input in " .. (project ~= "" and project or "unknown"),
        position = "bottom_right",
        timeout = 20,
    })

    if n then
        table.insert(active_notifications, n)
        n:connect_signal("destroyed", function()
            for i, nn in ipairs(active_notifications) do
                if nn == n then table.remove(active_notifications, i); break end
            end
        end)
    end

    if n and n.box and t then
        n.box:buttons(gears.table.join(
            awful.button({}, 1, function()
                t:view_only()
                for _, c in ipairs(client.get()) do
                    if c.window == wid then
                        c:raise()
                        client.focus = c
                        break
                    end
                end
                naughty.destroy(n)
            end),
            awful.button({}, 3, function()
                naughty.destroy(n)
            end)
        ))
    end

    awful.spawn({"paplay", SOUND})
end

-- Start the UDP listener
listener_pid = awful.spawn.with_line_callback("python3 -u " .. LISTENER, {
    stdout = handle_message,
})

-- Kill listener on awesome exit
awesome.connect_signal("exit", function()
    if listener_pid then
        awesome.kill(listener_pid, 9)
    end
end)

return {
    dismiss_all = function()
        for _, n in ipairs(active_notifications) do
            naughty.destroy(n)
        end
        active_notifications = {}
    end,
}
