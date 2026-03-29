-- If LuaRocks is installed, make sure that packages installed through it are
-- found (e.g. lgi). If LuaRocks is not installed, do nothing.
pcall(require, "luarocks.loader")

-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
local battery = require("battery")
local sysmon = require("sysmon")
local calendar = require("calendar")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
local naughty = require("naughty")
-- naughty default position is top_right
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup")
-- Enable hotkeys help widget for VIM and other apps
-- when client with a matching name is opened:
require("awful.hotkeys_popup.keys")

-- Load Debian menu entries
local debian = require("debian.menu")
local has_fdo, freedesktop = pcall(require, "freedesktop")

-- Focus the client under the mouse cursor (for after tag switches)
local function focus_client_under_mouse()
    gears.timer {
        timeout   = 0.05,
        autostart = true,
        single_shot = true,
        callback  = function()
            local c = mouse.current_client
            if c then
                c:emit_signal("request::activate", "mouse_enter", {raise = false})
            end
        end,
    }
end

-- {{{ Workspace labels
tag_labels = {}      -- manual labels keyed by tag object (global for awesome-client access)
tag_colors = {}      -- per-tag background colors keyed by tag object
local tag_color_palette = { "none", "#cc3333", "#3366cc", "#33aa55" }

local tag_labels_path = os.getenv("HOME") .. "/.cache/awesome/tag_labels"
local tag_colors_path = os.getenv("HOME") .. "/.cache/awesome/tag_colors"

local function save_tag_labels()
    os.execute("mkdir -p " .. os.getenv("HOME") .. "/.cache/awesome")
    local f = io.open(tag_labels_path, "w")
    if not f then return end
    for t, label in pairs(tag_labels) do
        if t.screen and t.index then
            f:write(t.screen.index .. "," .. t.index .. "," .. label .. "\n")
        end
    end
    f:close()
end

local function load_tag_labels()
    local f = io.open(tag_labels_path, "r")
    if not f then return end
    for line in f:lines() do
        local si, ti, label = line:match("^(%d+),(%d+),(.+)$")
        if si and ti and label then
            local s = screen[tonumber(si)]
            if s then
                local t = s.tags[tonumber(ti)]
                if t then
                    tag_labels[t] = label
                    t:emit_signal("property::name")
                end
            end
        end
    end
    f:close()
end

local function lighten_color(hex, amount)
    local r = tonumber(hex:sub(2, 3), 16)
    local g = tonumber(hex:sub(4, 5), 16)
    local b = tonumber(hex:sub(6, 7), 16)
    r = math.floor(r + (255 - r) * amount)
    g = math.floor(g + (255 - g) * amount)
    b = math.floor(b + (255 - b) * amount)
    return string.format("#%02x%02x%02x", r, g, b)
end

local function save_tag_colors()
    os.execute("mkdir -p " .. os.getenv("HOME") .. "/.cache/awesome")
    local f = io.open(tag_colors_path, "w")
    if not f then return end
    for t, color in pairs(tag_colors) do
        if t.screen and t.index then
            f:write(t.screen.index .. "," .. t.index .. "," .. color .. "\n")
        end
    end
    f:close()
end

local function load_tag_colors()
    local f = io.open(tag_colors_path, "r")
    if not f then return end
    for line in f:lines() do
        local si, ti, color = line:match("^(%d+),(%d+),(.+)$")
        if si and ti and color then
            local s = screen[tonumber(si)]
            if s then
                local t = s.tags[tonumber(ti)]
                if t then
                    tag_colors[t] = color
                    t:emit_signal("property::name")
                end
            end
        end
    end
    f:close()
end

local function get_display_label(t)
    local num = t.index or t.name
    local label = tag_labels[t]
    if label then
        return num .. ": " .. label
    else
        return tostring(num)
    end
end
-- }}}

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = tostring(err) })
        in_error = false
    end)
end
-- }}}

-- {{{ Variable definitions
-- Themes define colours, icons, font and wallpapers.
beautiful.init(gears.filesystem.get_themes_dir() .. "default/theme.lua")
beautiful.systray_icon_size = 24
beautiful.systray_icon_spacing = 4
-- {{{ Random wallpaper rotation
math.randomseed(os.time())
local wallpaper_dir = '/usr/share/backgrounds/'
local wallpaper_blacklist_path = os.getenv("HOME") .. "/.cache/awesome/wallpaper_blacklist"

local function load_wallpaper_blacklist()
    local blacklist = {}
    local f = io.open(wallpaper_blacklist_path, "r")
    if f then
        for line in f:lines() do
            blacklist[line] = true
        end
        f:close()
    end
    return blacklist
end

local function get_wallpapers()
    local wallpapers = {}
    local blacklist = load_wallpaper_blacklist()
    local p = io.popen('find "' .. wallpaper_dir .. '" -type f \\( -name "*.png" -o -name "*.jpg" -o -name "*.webp" \\)'
        .. ' | grep -v -i -e "^.*/ubuntu" -e "Brandmark" -e "Unleash_Your_Robot"')
    if p then
        for file in p:lines() do
            if not blacklist[file] then
                table.insert(wallpapers, file)
            end
        end
        p:close()
    end
    return wallpapers
end

local function pick_random_wallpaper()
    local wallpapers = get_wallpapers()
    if #wallpapers > 0 then
        beautiful.wallpaper = wallpapers[math.random(#wallpapers)]
        for s in screen do
            gears.wallpaper.maximized(beautiful.wallpaper, s, true)
        end
    end
end

local function blacklist_wallpaper()
    if not beautiful.wallpaper then return end
    os.execute("mkdir -p " .. os.getenv("HOME") .. "/.cache/awesome")
    local f = io.open(wallpaper_blacklist_path, "a")
    if f then
        f:write(beautiful.wallpaper .. "\n")
        f:close()
    end
    naughty.notify({ title = "Wallpaper blacklisted", text = beautiful.wallpaper, timeout = 3 })
    pick_random_wallpaper()
end

pick_random_wallpaper()

gears.timer {
    timeout     = 5 * 60 * 60, -- 5 hours
    autostart   = true,
    callback    = pick_random_wallpaper,
}
-- }}}

-- This is used later as the default terminal and editor to run.
terminal = "kitty"
editor = os.getenv("EDITOR") or "editor"
editor_cmd = terminal .. " -e " .. editor

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
modkey = "Mod4"

-- Table of layouts to cover with awful.layout.inc, order matters.
awful.layout.layouts = {
    -- awful.layout.suit.floating,
    awful.layout.suit.tile,
    -- awful.layout.suit.tile.left,
    -- awful.layout.suit.tile.bottom,
    -- awful.layout.suit.tile.top,
    -- awful.layout.suit.fair,
    -- awful.layout.suit.fair.horizontal,
    -- awful.layout.suit.spiral,
    -- awful.layout.suit.spiral.dwindle,
    -- awful.layout.suit.max,
    -- awful.layout.suit.max.fullscreen,
    -- awful.layout.suit.magnifier,
    -- awful.layout.suit.corner.nw,
    -- awful.layout.suit.corner.ne,
    -- awful.layout.suit.corner.sw,
    -- awful.layout.suit.corner.se,
}
-- }}}

-- {{{ Menu
-- Create a launcher widget and a main menu
myawesomemenu = {
   { "hotkeys", function() hotkeys_popup.show_help(nil, awful.screen.focused()) end },
   { "manual", terminal .. " -e man awesome" },
   { "edit config", editor_cmd .. " " .. awesome.conffile },
   { "restart", awesome.restart },
   { "quit", function() awesome.quit() end },
}

local menu_awesome = { "awesome", myawesomemenu, beautiful.awesome_icon }
local menu_terminal = { "open terminal", terminal }

if has_fdo then
    mymainmenu = freedesktop.menu.build({
        before = { menu_awesome },
        after =  { menu_terminal }
    })
else
    mymainmenu = awful.menu({
        items = {
                  menu_awesome,
                  { "Debian", debian.menu.Debian_menu.Debian },
                  menu_terminal,
                }
    })
end


mylauncher = wibox.widget.textbox(" [A] ")
mylauncher:buttons(gears.table.join(
    awful.button({}, 1, function() mymainmenu:toggle() end)
))

-- Menubar configuration
menubar.utils.terminal = terminal -- Set the terminal for applications that require it
-- }}}

-- Keyboard map indicator and switcher
mykeyboardlayout = awful.widget.keyboardlayout()

-- {{{ Wibar
-- Create a textclock widget
mytextclock = wibox.widget.textclock()
mytextclock:buttons(gears.table.join(
    awful.button({}, 1, function() calendar.toggle() end)
))

-- Create a wibox for each screen and add it
local taglist_buttons = gears.table.join(
                    awful.button({ }, 1, function(t) t:view_only() end),
                    awful.button({ modkey }, 1, function(t)
                                              if client.focus then
                                                  client.focus:move_to_tag(t)
                                              end
                                          end),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ modkey }, 3, function(t)
                                              if client.focus then
                                                  client.focus:toggle_tag(t)
                                              end
                                          end),
                    awful.button({ }, 4, function(t) awful.tag.viewprev(t.screen) end),
                    awful.button({ }, 5, function(t) awful.tag.viewnext(t.screen) end)
                )

local tasklist_buttons = gears.table.join(
                     awful.button({ }, 1, function (c)
                                              if c == client.focus then
                                                  c.minimized = true
                                              else
                                                  c:emit_signal(
                                                      "request::activate",
                                                      "tasklist",
                                                      {raise = true}
                                                  )
                                              end
                                          end),
                     awful.button({ }, 3, function()
                                              awful.menu.client_list({ theme = { width = 250 } })
                                          end),
                     awful.button({ }, 4, function ()
                                              awful.client.focus.byidx(1)
                                          end),
                     awful.button({ }, 5, function ()
                                              awful.client.focus.byidx(-1)
                                          end))

local function set_wallpaper(s)
    -- Wallpaper
    if beautiful.wallpaper then
        local wallpaper = beautiful.wallpaper
        -- If wallpaper is a function, call it with the screen
        if type(wallpaper) == "function" then
            wallpaper = wallpaper(s)
        end
        gears.wallpaper.maximized(wallpaper, s, true)
    end
end

-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
screen.connect_signal("property::geometry", set_wallpaper)

-- {{{ Tag switch popup
local tag_popup_widget = wibox.widget {
    id     = "text_role",
    align  = "center",
    valign = "center",
    font   = "sans bold 48",
    widget = wibox.widget.textbox,
}

local tag_popup = awful.popup {
    widget = {
        tag_popup_widget,
        margins = 24,
        widget  = wibox.container.margin,
    },
    bg            = "#222222ee",
    shape         = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, 12) end,
    ontop         = true,
    visible       = false,
    placement     = awful.placement.centered,
}

local tag_popup_timer = gears.timer {
    timeout     = 0.5,
    single_shot = true,
    callback    = function()
        tag_popup.visible = false
    end,
}

local function show_tag_popup(t)
    local function display(text)
        tag_popup_widget:set_text(text)
        tag_popup.screen = t.screen
        tag_popup.visible = true
        awful.placement.centered(tag_popup, { parent = t.screen })
        tag_popup_timer:again()
    end

    display(get_display_label(t))
end
-- }}}

awful.screen.connect_for_each_screen(function(s)
    -- Wallpaper
    set_wallpaper(s)

    -- Each screen has its own tag table.
    awful.tag({ "1", "2", "3", "4", "5", "6", "7", "8", "9", "10",
                "11", "12", "13", "14", "15", "16", "17", "18", "19", "20" }, s, awful.layout.layouts[1])

    -- Create a promptbox for each screen
    s.mypromptbox = awful.widget.prompt()
    -- Persistent tag label widget (shows current tag label next to promptbox)
    s.mytaglabel = wibox.widget.textbox()
    local function update_tag_label()
        local t = s.selected_tag
        if t and tag_labels[t] then
            s.mytaglabel:set_text(" " .. tag_labels[t] .. " ")
        else
            s.mytaglabel:set_text("")
        end
    end
    tag.connect_signal("property::selected", function(t)
        if t.screen == s then update_tag_label() end
    end)
    tag.connect_signal("property::name", function(t)
        if t.screen == s then update_tag_label() end
    end)
    -- Create an imagebox widget which will contain an icon indicating which layout we're using.
    -- Create taglist widgets (2 rows of 10)
    local taglist_template = {
        {
            {
                {
                    id     = "text_role",
                    align  = "center",
                    widget = wibox.widget.textbox,
                },
                left   = 6,
                right  = 6,
                widget = wibox.container.margin,
            },
            id     = "color_role",
            widget = wibox.container.background,
        },
        id     = "background_role",
        forced_width = 36,
        widget = wibox.container.background,
        create_callback = function(self, t)
            self:get_children_by_id("text_role")[1].text = " " .. get_display_label(t) .. " "
            local color = tag_colors[t]
            if color and t.selected then color = lighten_color(color, 0.4) end
            self:get_children_by_id("color_role")[1].bg = color
            local cr = self:get_children_by_id("color_role")[1]
            if t.selected then
                cr.shape = gears.shape.rectangle
                cr.shape_border_color = "#ffff00"
                cr.shape_border_width = 2
            else
                cr.shape_border_color = nil
                cr.shape_border_width = 0
            end
        end,
        update_callback = function(self, t)
            self:get_children_by_id("text_role")[1].text = " " .. get_display_label(t) .. " "
            local color = tag_colors[t]
            if color and t.selected then color = lighten_color(color, 0.4) end
            self:get_children_by_id("color_role")[1].bg = color
            local cr = self:get_children_by_id("color_role")[1]
            if t.selected then
                cr.shape = gears.shape.rectangle
                cr.shape_border_color = "#ffff00"
                cr.shape_border_width = 2
            else
                cr.shape_border_color = nil
                cr.shape_border_width = 0
            end
        end,
    }

    s.mytaglist_top = awful.widget.taglist {
        screen  = s,
        filter  = function(t) return t.index <= 10 end,
        buttons = taglist_buttons,
        widget_template = taglist_template,
    }

    s.mytaglist_bottom = awful.widget.taglist {
        screen  = s,
        filter  = function(t) return t.index > 10 end,
        buttons = taglist_buttons,
        widget_template = taglist_template,
    }

    s.mytaglist = wibox.widget {
        s.mytaglist_top,
        s.mytaglist_bottom,
        layout = wibox.layout.fixed.vertical,
    }

    -- Window list button: shows count, click for menu
    s.winlist_label = wibox.widget.textbox()
    s.winlist_menu = nil

    local function update_winlist(screen)
        local t = screen.selected_tag
        if not t then screen.winlist_label:set_text(""); return end
        local visible, hidden = 0, 0
        for _, c in ipairs(client.get()) do
            for _, ct in ipairs(c:tags()) do
                if ct == t then
                    if c.minimized then hidden = hidden + 1 else visible = visible + 1 end
                    break
                end
            end
        end
        if visible == 0 and hidden == 0 then
            screen.winlist_label:set_text("")
        elseif hidden > 0 then
            screen.winlist_label:set_text("  [" .. visible .. "+" .. hidden .. "]  ")
        else
            screen.winlist_label:set_text("  [" .. visible .. "]  ")
        end
    end

    local function show_winlist_menu(screen)
        if screen.winlist_menu then screen.winlist_menu:hide(); screen.winlist_menu = nil; return end
        local t = screen.selected_tag
        if not t then return end
        local items = {}
        for _, c in ipairs(client.get()) do
            for _, ct in ipairs(c:tags()) do
                if ct == t then
                    local prefix = c.minimized and "  " or ""
                    local name = (c.class or c.name or "?")
                    if c.name and c.name ~= c.class then
                        name = name .. " - " .. c.name
                    end
                    table.insert(items, { prefix .. name, function()
                        if c.minimized then c.minimized = false end
                        c:emit_signal("request::activate", "winlist", {raise = true})
                    end })
                    break
                end
            end
        end
        if #items > 0 then
            screen.winlist_menu = awful.menu({ items = items, theme = { width = 400 } })
            screen.winlist_menu:show()
        end
    end

    s.winlist_button = wibox.widget {
        s.winlist_label,
        widget = wibox.container.background,
    }
    s.winlist_button:buttons(gears.table.join(
        awful.button({}, 1, function() show_winlist_menu(s) end)
    ))

    update_winlist(s)
    local us = s
    client.connect_signal("manage", function() update_winlist(us) end)
    client.connect_signal("unmanage", function() update_winlist(us) end)
    client.connect_signal("property::minimized", function() update_winlist(us) end)
    client.connect_signal("tagged", function() update_winlist(us) end)
    client.connect_signal("untagged", function() update_winlist(us) end)
    tag.connect_signal("property::selected", function() update_winlist(us) end)

    -- Create the wibox
    s.mywibox = awful.wibar({ position = "top", screen = s, height = 58 })

    -- Add widgets to the wibox
    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        { -- Left widgets
            layout = wibox.layout.fixed.horizontal,
            mylauncher,
            s.mytaglist,
            s.mypromptbox,
            s.mytaglabel,
        },
        s.winlist_button, -- Middle widget
        { -- Right widgets
            layout = wibox.layout.fixed.horizontal,
            sysmon.cpu,
            sysmon.mem,
            sysmon.net,
            wibox.container.place(wibox.container.constraint(wibox.widget.systray(), "exact", nil, 32), "center", "center"),
            battery,
            mytextclock,
        },
    }
end)

load_tag_labels()
load_tag_colors()
-- }}}

-- {{{ Mouse bindings
root.buttons(gears.table.join(
    awful.button({ }, 3, function () mymainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings
globalkeys = gears.table.join(
    awful.key({ modkey, "Control" }, "l",
        function ()
            awful.spawn("xautolock -locknow")
        end,
        {description = "lock screen", group="system"}),
    awful.key({ modkey, "Shift"   }, "s",
        function ()
            awful.spawn.with_shell("~/bin/speech_to_text.sh")
        end,
        {description = "speech to text", group="system"}),
    awful.key({}, "XF86MonBrightnessUp",
        function ()
            awful.spawn("brightnessctl set +5%", false)
        end,
        {description = "brightness up", group="system"}),
    awful.key({}, "XF86MonBrightnessDown",
        function ()
            awful.spawn("brightnessctl set 5%-", false)
        end,
        {description = "brightness down", group="system"}),
    awful.key({ modkey,           }, "s",      hotkeys_popup.show_help,
              {description="show help", group="awesome"}),

    -- Workspaces
    -- Focus tiles with Alt+Mod+arrows
    awful.key({ modkey, "Mod1"  }, "Up", function()
        awful.client.focus.byidx(-1)
    end, {description = "focus tile up", group = "windows"}),
    awful.key({ modkey, "Mod1"  }, "Down", function()
        awful.client.focus.byidx(1)
    end, {description = "focus tile down", group = "windows"}),
    awful.key({ modkey, "Mod1"  }, "Left", function()
        awful.client.focus.byidx(-1)
    end, {description = "focus tile left", group = "windows"}),
    awful.key({ modkey, "Mod1"  }, "Right", function()
        awful.client.focus.byidx(1)
    end, {description = "focus tile right", group = "windows"}),

    awful.key({ modkey,           }, "Left",   function() awful.tag.viewprev(); focus_client_under_mouse() end,
              {description = "previous workspace", group = "workspaces"}),
    awful.key({ modkey,           }, "Right",  function() awful.tag.viewnext(); focus_client_under_mouse() end,
              {description = "next workspace", group = "workspaces"}),
    awful.key({ modkey,           }, "Up", function()
        local s = awful.screen.focused()
        local t = s.selected_tag
        if not t then return end
        local idx = t.index - 10
        if idx >= 1 and s.tags[idx] then
            s.tags[idx]:view_only()
            focus_client_under_mouse()
        end
    end, {description = "workspace row up", group = "workspaces"}),
    awful.key({ modkey,           }, "Down", function()
        local s = awful.screen.focused()
        local t = s.selected_tag
        if not t then return end
        local idx = t.index + 10
        if idx <= #s.tags and s.tags[idx] then
            s.tags[idx]:view_only()
            focus_client_under_mouse()
        end
    end, {description = "workspace row down", group = "workspaces"}),
    awful.key({ modkey, "Shift"  }, "Left",   function()
        if client.focus then
            local tag = client.focus.screen.selected_tag
            local tags = client.focus.screen.tags
            local idx = tag.index - 1
            if idx < 1 then idx = #tags end
            client.focus:move_to_tag(tags[idx])
        end
        awful.tag.viewprev()
        focus_client_under_mouse()
    end, {description = "move app left", group = "workspaces"}),
    awful.key({ modkey, "Shift"  }, "Right",  function()
        if client.focus then
            local tag = client.focus.screen.selected_tag
            local tags = client.focus.screen.tags
            local idx = tag.index + 1
            if idx > #tags then idx = 1 end
            client.focus:move_to_tag(tags[idx])
        end
        awful.tag.viewnext()
        focus_client_under_mouse()
    end, {description = "move app right", group = "workspaces"}),
    awful.key({ modkey, "Shift"  }, "Up", function()
        if client.focus then
            local s = client.focus.screen
            local t = s.selected_tag
            if not t then return end
            local idx = t.index - 10
            if idx >= 1 and s.tags[idx] then
                client.focus:move_to_tag(s.tags[idx])
                s.tags[idx]:view_only()
                focus_client_under_mouse()
            end
        end
    end, {description = "move app row up", group = "workspaces"}),
    awful.key({ modkey, "Shift"  }, "Down", function()
        if client.focus then
            local s = client.focus.screen
            local t = s.selected_tag
            if not t then return end
            local idx = t.index + 10
            if idx <= #s.tags and s.tags[idx] then
                client.focus:move_to_tag(s.tags[idx])
                s.tags[idx]:view_only()
                focus_client_under_mouse()
            end
        end
    end, {description = "move app row down", group = "workspaces"}),
    awful.key({ modkey, "Control" }, "Left", function()
        local s = awful.screen.focused()
        local t = s.selected_tag
        if not t or t.index <= 1 then return end
        local other = s.tags[t.index - 1]
        local t_clients = t:clients()
        local o_clients = other:clients()
        for _, c in ipairs(t_clients) do c:move_to_tag(other) end
        for _, c in ipairs(o_clients) do c:move_to_tag(t) end
        tag_labels[t], tag_labels[other] = tag_labels[other], tag_labels[t]
        t:emit_signal("property::name")
        other:emit_signal("property::name")
        save_tag_labels()
        other:view_only()
        focus_client_under_mouse()
    end, {description = "swap workspace left", group = "workspaces"}),
    awful.key({ modkey, "Control" }, "Right", function()
        local s = awful.screen.focused()
        local t = s.selected_tag
        if not t or t.index >= #s.tags then return end
        local other = s.tags[t.index + 1]
        local t_clients = t:clients()
        local o_clients = other:clients()
        for _, c in ipairs(t_clients) do c:move_to_tag(other) end
        for _, c in ipairs(o_clients) do c:move_to_tag(t) end
        tag_labels[t], tag_labels[other] = tag_labels[other], tag_labels[t]
        t:emit_signal("property::name")
        other:emit_signal("property::name")
        save_tag_labels()
        other:view_only()
        focus_client_under_mouse()
    end, {description = "swap workspace right", group = "workspaces"}),
    awful.key({ modkey, "Control" }, "Up", function()
        local s = awful.screen.focused()
        local t = s.selected_tag
        if not t then return end
        local idx = t.index - 10
        if idx < 1 or not s.tags[idx] then return end
        local other = s.tags[idx]
        local t_clients = t:clients()
        local o_clients = other:clients()
        for _, c in ipairs(t_clients) do c:move_to_tag(other) end
        for _, c in ipairs(o_clients) do c:move_to_tag(t) end
        tag_labels[t], tag_labels[other] = tag_labels[other], tag_labels[t]
        t:emit_signal("property::name")
        other:emit_signal("property::name")
        save_tag_labels()
        other:view_only()
        focus_client_under_mouse()
    end, {description = "swap workspace row up", group = "workspaces"}),
    awful.key({ modkey, "Control" }, "Down", function()
        local s = awful.screen.focused()
        local t = s.selected_tag
        if not t then return end
        local idx = t.index + 10
        if idx > #s.tags or not s.tags[idx] then return end
        local other = s.tags[idx]
        local t_clients = t:clients()
        local o_clients = other:clients()
        for _, c in ipairs(t_clients) do c:move_to_tag(other) end
        for _, c in ipairs(o_clients) do c:move_to_tag(t) end
        tag_labels[t], tag_labels[other] = tag_labels[other], tag_labels[t]
        t:emit_signal("property::name")
        other:emit_signal("property::name")
        save_tag_labels()
        other:view_only()
        focus_client_under_mouse()
    end, {description = "swap workspace row down", group = "workspaces"}),
    awful.key({ modkey,           }, "Escape", function() awful.tag.history.restore(); focus_client_under_mouse() end,
              {description = "last workspace", group = "workspaces"}),
    awful.key({ modkey }, "/",
              function ()
                  awful.prompt.run {
                      prompt       = "Tag label: ",
                      textbox      = awful.screen.focused().mypromptbox.widget,
                      exe_callback = function(input)
                          local t = awful.screen.focused().selected_tag
                          if not t then return end
                          if input and input ~= "" then
                              tag_labels[t] = input
                          else
                              tag_labels[t] = nil
                              tag_colors[t] = nil
                              save_tag_colors()
                          end
                          t:emit_signal("property::name")
                          save_tag_labels()
                      end,
                  }
              end,
              {description = "rename workspace", group = "workspaces"}),
    awful.key({ modkey }, ".",
              function()
                  local t = awful.screen.focused().selected_tag
                  if not t then return end
                  local current_color = tag_colors[t] or "none"
                  local idx = 1
                  for i = 1, #tag_color_palette do
                      if tag_color_palette[i] == current_color then idx = i; break end
                  end
                  idx = (idx % #tag_color_palette) + 1
                  local new_color = tag_color_palette[idx]
                  if new_color == "none" then new_color = nil end
                  tag_colors[t] = new_color
                  save_tag_colors()
                  t:emit_signal("property::name")
              end,
              {description = "cycle workspace color", group = "workspaces"}),

    -- Windows
    awful.key({ modkey,           }, "j", function () awful.client.incwfact(-0.05) end,
              {description = "shorter", group = "layout"}),
    awful.key({ modkey,           }, "k", function () awful.client.incwfact( 0.05) end,
              {description = "taller", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end,
              {description = "swap with next window", group = "windows"}),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end,
              {description = "swap with previous window", group = "windows"}),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto,
              {description = "jump to urgent window", group = "windows"}),
    awful.key({ modkey,           }, "Tab",
        function ()
            sloppy_suppressed = true
            -- First press: go to previously focused client (tracking stays on so history updates)
            awful.client.focus.history.previous()
            if client.focus then client.focus:raise() end
            -- Disable tracking for subsequent cycling while Mod is held
            awful.client.focus.history.disable_tracking()
            keygrabber.run(function(mod, key, event)
                if event == "release" and (key == "Super_L" or key == "Super_R") then
                    keygrabber.stop()
                    awful.client.focus.history.enable_tracking()
                    sloppy_suppressed = false
                    return
                end
                if event ~= "press" then return end
                if key == "Tab" then
                    local shift = false
                    for _, m in ipairs(mod) do if m == "Shift" then shift = true end end
                    awful.client.focus.byidx(shift and -1 or 1)
                    if client.focus then client.focus:raise() end
                end
            end)
        end,
        {description = "switch to previous window", group = "windows"}),
    awful.key({ modkey, "Shift"  }, "Tab",
        function ()
            sloppy_suppressed = true
            awful.client.focus.byidx(-1)
            if client.focus then client.focus:raise() end
            gears.timer.start_new(0.3, function() sloppy_suppressed = false end)
        end,
        {description = "previous window", group = "windows"}),
    awful.key({ modkey, "Control" }, "n",
              function ()
                  local c = awful.client.restore()
                  if c then
                    c:emit_signal(
                        "request::activate", "key.unminimize", {raise = true}
                    )
                  end
              end,
              {description = "restore minimized", group = "windows"}),

    -- Layout
    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)          end,
              {description = "wider master", group = "layout"}),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)          end,
              {description = "narrower master", group = "layout"}),

    -- Launcher
    awful.key({ modkey,           }, "e",
        function ()
            local c = client.focus
            if c and c.pid then
                awful.spawn.easy_async(
                    {"sh", "-c", "for pid in $(pgrep -P " .. c.pid .. "); do pty=$(readlink /proc/$pid/fd/0 2>/dev/null); cwd=$(readlink /proc/$pid/cwd 2>/dev/null); if [ -n \"$pty\" ] && [ -n \"$cwd\" ]; then echo \"$(stat -c %X $pty) $cwd\"; fi; done | sort -rn | head -1 | cut -d' ' -f2-"},
                    function(stdout)
                        local dir = stdout:match("^%s*(.-)%s*$")
                        if dir and dir ~= "" then
                            awful.spawn(terminal .. " --directory=" .. dir)
                        else
                            awful.spawn(terminal)
                        end
                    end
                )
            else
                awful.spawn(terminal)
            end
        end,
        {description = "terminal", group = "launcher"}),
    awful.key({ modkey }, "space", function () awful.util.spawn("xfce4-appfinder") end,
              {description = "app finder", group = "launcher"}),
    awful.key({ modkey,           }, "w", function () mymainmenu:show() end,
              {description = "main menu", group = "awesome"}),
    awful.key({ modkey, "Control" }, "r", awesome.restart,
              {description = "reload awesome", group = "awesome"}),
    awful.key({ modkey, "Shift"   }, "w", pick_random_wallpaper,
              {description = "random wallpaper", group = "awesome"}),
    awful.key({ modkey, "Shift", "Control" }, "w", blacklist_wallpaper,
              {description = "blacklist current wallpaper", group = "awesome"}),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit,
              {description = "quit awesome", group = "awesome"}),
    awful.key({ modkey }, "x",
              function ()
                  awful.prompt.run {
                    prompt       = "Run Lua code: ",
                    textbox      = awful.screen.focused().mypromptbox.widget,
                    exe_callback = awful.util.eval,
                    history_path = awful.util.get_cache_dir() .. "/history_eval"
                  }
              end,
              {description = "lua prompt", group = "awesome"}),
    awful.key({ modkey, "Shift"  }, "minus",
        function ()
            local s = awful.screen.focused()
            if not s then return end
            local t = s.selected_tag
            if not t then return end
            for _, c in ipairs(client.get()) do
                if c.minimized then
                    for _, ct in ipairs(c:tags()) do
                        if ct == t then
                            c.minimized = false
                            break
                        end
                    end
                end
            end
        end,
        {description = "restore all hidden tiles", group = "windows"})
)

clientkeys = gears.table.join(
    awful.key({ modkey,           }, "f",
        function (c)
            c.fullscreen = not c.fullscreen
            c:raise()
        end,
        {description = "fullscreen", group = "windows"}),
    awful.key({ modkey, "Shift"   }, "c",      function (c) c:kill()                         end,
              {description = "close window", group = "windows"}),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ,
              {description = "toggle floating", group = "windows"}),
    awful.key({ modkey }, "Return", function (c)
            c.maximized = not c.maximized
            c:raise()
        end,
              {description = "maximize", group = "windows"}),
    awful.key({ modkey,           }, "m", function (c) c:swap(awful.client.getmaster()) end,
        {description = "make master", group = "windows"}),
    awful.key({ modkey,           }, "n",
        function (c)
            c.minimized = true
        end ,
        {description = "minimize", group = "windows"}),
    awful.key({ modkey,           }, "o",      function (c) c:move_to_screen()               end,
              {description = "move to screen", group = "windows"}),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end,
              {description = "keep on top", group = "windows"}),
    awful.key({ modkey,           }, "p",
        function (c)
            if c.floating and c.ontop then
                -- Snap back into tiling
                c.floating = false
                c.ontop = false
            else
                -- Pop out: float, ontop, center at reasonable size
                c.floating = true
                c.ontop = true
                local geo = c.screen.workarea
                local w = math.floor(geo.width * 0.5)
                local h = math.floor(geo.height * 0.5)
                c:geometry({ x = geo.x + (geo.width - w) / 2, y = geo.y + (geo.height - h) / 2, width = w, height = h })
                c:raise()
            end
        end,
        {description = "pop out / snap back", group = "windows"}),
    awful.key({ modkey,           }, "minus",
        function (c)
            c.minimized = true
        end,
        {description = "hide tile", group = "windows"})
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it work on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 10 do
    globalkeys = gears.table.join(globalkeys,
        -- View tag only.
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = awful.screen.focused()
                        local tag = screen.tags[i]
                        if tag then
                           tag:view_only()
                           focus_client_under_mouse()
                        end
                  end,
                  {}),
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:move_to_tag(tag)
                          end
                     end
                  end,
                  {}),
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                        local screen = awful.screen.focused()
                        local tag = screen.tags[i + 10]
                        if tag then
                           tag:view_only()
                           focus_client_under_mouse()
                        end
                  end,
                  {})
    )
end

clientbuttons = gears.table.join(
    awful.button({ }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
    end),
    awful.button({ modkey }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.move(c)
    end),
    awful.button({ modkey }, 3, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.resize(c)
    end)
)

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = awful.client.focus.filter,
                     raise = true,
                     keys = clientkeys,
                     buttons = clientbuttons,
                     screen = awful.screen.preferred,
                     placement = awful.placement.no_overlap+awful.placement.no_offscreen
     },
    },

    -- Floating clients.
    { rule_any = {
        instance = {
          "DTA",  -- Firefox addon DownThemAll.
          "copyq",  -- Includes session name in class.
          "pinentry",
        },
        class = {
          "Arandr",
          "Blueman-manager",
          "Gpick",
          "Kruler",
          "MessageWin",  -- kalarm.
          "Sxiv",
          "Tor Browser", -- Needs a fixed window size to avoid fingerprinting by screen size.
          "Wpa_gui",
          "veromix",
          "xtightvncviewer"},

        -- Note that the name property shown in xprop might be set slightly after creation of the client
        -- and the name shown there might not match defined rules here.
        name = {
          "Event Tester",  -- xev.
        },
        role = {
          "AlarmWindow",  -- Thunderbird's calendar.
          "ConfigManager",  -- Thunderbird's about:config.
          "pop-up",       -- e.g. Google Chrome's (detached) Developer Tools.
        }
      }, properties = { floating = true }},

    -- Add titlebars to normal clients and dialogs
    { rule_any = {type = { "normal", "dialog" }
      }, properties = { titlebars_enabled = true }
    },

    -- Set terminal to be slave
    {
        rule_any = { class = {'x-terminal-emulator', 'Gnome-terminal', 'kitty'} },
        properties = { slave = true, size_hints_honor = false }
    },
    -- Floating and centered xfce4-appfinder
    {
        rule = { class = "Xfce4-appfinder" },
        properties = {
            floating = true,
            placement = awful.placement.centered,
            ontop = true,
            skip_taskbar = true
        }
    }

    -- Set Firefox to always map on the tag named "2" on screen 1.
    -- { rule = { class = "Firefox" },
    --   properties = { screen = 1, tag = "2" } },
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c)
    -- Set the windows at the slave,
    -- i.e. put it at the end of others instead of setting it master.
    -- if not awesome.startup then awful.client.setslave(c) end
    if not awesome.startup and (c.class == "X-terminal-emulator" or c.class == "Gnome-terminal" or c.class == "kitty") then
        awful.client.setslave(c)
    end

    if awesome.startup
      and not c.size_hints.user_position
      and not c.size_hints.program_position then
        -- Prevent clients from being unreachable after screen count changes.
        awful.placement.no_offscreen(c)
    end
end)

-- Add a titlebar if titlebars_enabled is set to true in the rules.
client.connect_signal("request::titlebars", function(c)
    -- buttons for the titlebar
    local buttons = gears.table.join(
        awful.button({ }, 1, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.move(c)
        end),
        awful.button({ }, 3, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.resize(c)
        end)
    )

    awful.titlebar(c) : setup {
        { -- Left
            awful.titlebar.widget.iconwidget(c),
            buttons = buttons,
            layout  = wibox.layout.fixed.horizontal
        },
        { -- Middle
            { -- Title
                align  = "center",
                widget = awful.titlebar.widget.titlewidget(c)
            },
            buttons = buttons,
            layout  = wibox.layout.flex.horizontal
        },
        { -- Right
            awful.titlebar.widget.floatingbutton (c),
            awful.titlebar.widget.maximizedbutton(c),
            awful.titlebar.widget.stickybutton   (c),
            awful.titlebar.widget.ontopbutton    (c),
            awful.titlebar.widget.closebutton    (c),
            layout = wibox.layout.fixed.horizontal()
        },
        layout = wibox.layout.align.horizontal
    }
end)

-- Enable sloppy focus, so that focus follows mouse (debounced).
-- sloppy_suppressed is set briefly after keyboard-driven focus changes
-- to prevent mouse::enter from immediately stealing focus back.
local sloppy_suppressed = false
local focus_timer = gears.timer { timeout = 0.05, single_shot = true }
local focus_pending = nil
focus_timer:connect_signal("timeout", function()
    if focus_pending and focus_pending.valid and not sloppy_suppressed then
        focus_pending:emit_signal("request::activate", "mouse_enter", {raise = false})
    end
    focus_pending = nil
end)
client.connect_signal("mouse::enter", function(c)
    if sloppy_suppressed then return end
    focus_pending = c
    focus_timer:again()
end)

-- Re-check focus when a client disappears or the layout shifts,
-- so the window under a stationary mouse gets focused.
client.connect_signal("unmanage", function() focus_client_under_mouse() end)
client.connect_signal("property::minimized", function() focus_client_under_mouse() end)
awful.tag.attached_connect_signal(nil, "property::layout", function() focus_client_under_mouse() end)

client.connect_signal("focus", function(c)
    c.border_color = beautiful.border_focus
    c.opacity = 1
end)
client.connect_signal("unfocus", function(c)
    c.border_color = beautiful.border_normal
    c.opacity = 0.75
end)

-- Show popup on tag switch
tag.connect_signal("property::selected", function(t)
    if t.selected then show_tag_popup(t) end
end)

-- }}}

local function save_selected_tag()
    local s = awful.screen.focused()
    if s then
        local t = s.selected_tag
        if t then
            awful.spawn.with_shell("mkdir -p " .. os.getenv("HOME") .. "/.cache/awesome")
            local f = io.open(os.getenv("HOME") .. "/.cache/awesome/selected-tag", "w")
            if f then
                f:write(tostring(t.index))
                f:close()
            end
        end
    end
end

-- {{{ Monitor hotplug switching
do
    local lgi = require("lgi")
    local GLib = lgi.GLib
    local home = os.getenv("HOME")
    local env_file = home .. "/.cache/monitor-dpi-env"
    local state_file = home .. "/.cache/monitor-state"
    local client_tags_file = home .. "/.cache/awesome/client-tags"

    -- On startup: read cached DPI env so apps launched by awesome inherit correct scaling
    local f = io.open(env_file, "r")
    if f then
        for line in f:lines() do
            local key, val = line:match("^export%s+(%S+)=(%S+)")
            if key and val then
                GLib.setenv(key, val, true)
            end
        end
        f:close()
    end

    -- Save each client's tag indices to a file (X window IDs persist across restart)
    local function save_client_tags()
        awful.spawn.with_shell("mkdir -p " .. home .. "/.cache/awesome")
        local wf = io.open(client_tags_file, "w")
        if not wf then return end
        for _, c in ipairs(client.get()) do
            local tags = c:tags()
            if #tags > 0 then
                local indices = {}
                for _, t in ipairs(tags) do
                    table.insert(indices, tostring(t.index))
                end
                wf:write(c.window .. ":" .. table.concat(indices, ",") .. "\n")
            end
        end
        wf:close()
    end

    -- Restore client tag assignments after restart
    local function restore_client_tags()
        local rf = io.open(client_tags_file, "r")
        if not rf then return end
        local mappings = {}
        for line in rf:lines() do
            local wid, indices_str = line:match("^(%d+):(.+)$")
            if wid and indices_str then
                local indices = {}
                for idx in indices_str:gmatch("(%d+)") do
                    table.insert(indices, tonumber(idx))
                end
                mappings[tonumber(wid)] = indices
            end
        end
        rf:close()
        os.remove(client_tags_file)

        local s = awful.screen.focused()
        if not s then return end
        for _, c in ipairs(client.get()) do
            local tag_indices = mappings[c.window]
            if tag_indices then
                local tags = {}
                for _, idx in ipairs(tag_indices) do
                    if s.tags[idx] then
                        table.insert(tags, s.tags[idx])
                    end
                end
                if #tags > 0 then
                    c:tags(tags)
                    c.screen = s
                end
            end
        end
    end

    -- Dynamically find connected HDMI and eDP output names (they can change across reboots)
    local function find_output(pattern)
        local handle = io.popen("xrandr | grep -oP '" .. pattern .. "\\S+ connected' | head -1 | awk '{print $1}'")
        local result = handle:read("*a"):gsub("%s+", "")
        handle:close()
        return result
    end

    -- Find any output matching pattern (connected or disconnected) that still has a mode set
    local function find_any_output(pattern)
        local handle = io.popen("xrandr | grep -oP '" .. pattern .. "\\S+(?= (?:connected|disconnected))' | head -1")
        local result = handle:read("*a"):gsub("%s+", "")
        handle:close()
        return result
    end

    local function apply_monitor_config(new_state)
        local hdmi_out = find_output("HDMI-")
        local edp_out = find_output("eDP-")
        if edp_out == "" then edp_out = "eDP-1" end

        -- Write new state
        local wf = io.open(state_file, "w")
        if wf then
            wf:write(new_state)
            wf:close()
        end

        if new_state == "external" and hdmi_out ~= "" then
            -- External 4K monitor, laptop off
            awful.spawn.with_shell(
                "xrandr --output " .. edp_out .. " --off --output " .. hdmi_out .. " --mode 3840x2160 --pos 0x0 --rotate normal"
                .. " && echo 'Xft.dpi: 192' | xrdb -merge"
                .. " && printf 'export GDK_SCALE=2\\nexport GDK_DPI_SCALE=0.5\\n' > " .. env_file
            )
            awful.spawn.with_shell("echo 10.0 > " .. home .. "/.cache/kitty-font-size"
                .. "; for s in /tmp/kitty-*; do kitty @ --to=unix:$s set-font-size 10.0 2>/dev/null; done")
        else
            -- Laptop only — find HDMI output even if disconnected (NVIDIA may leave ghost mode)
            local hdmi_any = hdmi_out ~= "" and hdmi_out or find_any_output("HDMI-")
            local off_cmd = hdmi_any ~= "" and ("xrandr --output " .. hdmi_any .. " --off --output " .. edp_out .. " --auto --mode 2560x1600") or ("xrandr --output " .. edp_out .. " --auto --mode 2560x1600")
            awful.spawn.with_shell(
                off_cmd
                .. " && echo 'Xft.dpi: 96' | xrdb -merge"
                .. " && printf 'export GDK_SCALE=1\\nexport GDK_DPI_SCALE=1\\n' > " .. env_file
            )
            awful.spawn.with_shell("echo 15.0 > " .. home .. "/.cache/kitty-font-size"
                .. "; for s in /tmp/kitty-*; do kitty @ --to=unix:$s set-font-size 15.0 2>/dev/null; done")
        end
    end

    local function detect_monitor_state()
        local hdmi_out = find_output("HDMI-")
        return (hdmi_out ~= "") and "external" or "laptop"
    end

    local function read_cached_state()
        local sf = io.open(state_file, "r")
        if sf then
            local s = sf:read("*a"):gsub("%s+", "")
            sf:close()
            return s
        end
        return ""
    end

    -- On startup: apply correct config, then restore client tags and selected tag
    apply_monitor_config(detect_monitor_state())
    gears.timer {
        timeout = 0.5,
        single_shot = true,
        autostart = true,
        callback = function()
            restore_client_tags()
            -- Restore the tag that was selected before restart
            local tag_file = home .. "/.cache/awesome/selected-tag"
            local tf = io.open(tag_file, "r")
            if tf then
                local idx = tonumber(tf:read("*a"))
                tf:close()
                os.remove(tag_file)
                if idx then
                    local s = awful.screen.focused()
                    if s and s.tags[idx] then
                        s.tags[idx]:view_only()
                    end
                end
            end
        end,
    }

    -- Debounced hotplug: single timer that resets on each signal
    local hotplug_timer = nil
    local hotplug_attempt = 0

    local function handle_hotplug()
        hotplug_attempt = hotplug_attempt + 1
        local attempt = hotplug_attempt
        local new_state = detect_monitor_state()

        if new_state == read_cached_state() then
            -- State hasn't changed yet — retry a few times in case
            -- xrandr is reporting stale info during a transition
            if attempt <= 5 then
                gears.timer {
                    timeout = 1,
                    single_shot = true,
                    autostart = true,
                    callback = handle_hotplug,
                }
            end
            return
        end

        -- State changed — save all state while tags are still valid
        save_tag_labels()
        save_tag_colors()
        save_client_tags()
        save_selected_tag()
        apply_monitor_config(new_state)

        -- Verify xrandr applied correctly before restarting
        local verify_count = 0
        local verify_timer
        verify_timer = gears.timer {
            timeout = 1,
            autostart = true,
            callback = function()
                verify_count = verify_count + 1
                local current = detect_monitor_state()
                if current == new_state then
                    -- xrandr succeeded — restart awesome
                    verify_timer:stop()
                    awesome.restart()
                elseif verify_count >= 5 then
                    -- xrandr may have failed — retry the whole config
                    verify_timer:stop()
                    apply_monitor_config(new_state)
                    gears.timer {
                        timeout = 2,
                        single_shot = true,
                        autostart = true,
                        callback = function() awesome.restart() end,
                    }
                end
                -- otherwise keep polling
            end,
        }
    end

    awesome.connect_signal("screen::change", function()
        -- Reset attempt counter and debounce: restart the timer on each signal
        hotplug_attempt = 0
        if hotplug_timer then
            hotplug_timer:stop()
        end
        hotplug_timer = gears.timer {
            timeout = 1.5,
            single_shot = true,
            autostart = true,
            callback = handle_hotplug,
        }
    end)

    -- Watch for monitor changes via a stamp file touched by a udev rule
    -- Avoids sysfs polling which triggers expensive NVIDIA EDID probes on driver 580+
    local monitor_stamp = home .. "/.cache/monitor-hotplug-stamp"
    local last_stamp = ""
    gears.timer {
        timeout = 2,
        autostart = true,
        callback = function()
            local f = io.open(monitor_stamp, "r")
            if f then
                local content = f:read("*a")
                f:close()
                if content ~= last_stamp then
                    last_stamp = content
                    handle_hotplug()
                end
            end
        end,
    }
end
-- }}}

-- Compositor for opacity support
awful.util.spawn_with_shell('picom --daemon')

-- NetworkManager applet (WiFi selector in systray)
awful.util.spawn_with_shell('pgrep -x nm-applet || nm-applet')

-- Lock screen script
awful.util.spawn_with_shell('xset +dpms && xset dpms 720 720 720')
awful.util.spawn_with_shell('~/.config/awesome/locker.sh')
awful.util.spawn_with_shell('~/bin/volume-hotkeys.sh')

awesome.connect_signal("exit", function(restart)
    save_tag_labels()
    save_tag_colors()
    if restart then
        save_selected_tag()
    end
    awful.spawn.with_shell("pkill -f volume-hotkeys.sh")
end)

