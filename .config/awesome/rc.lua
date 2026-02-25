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

local tag_labels_path = os.getenv("HOME") .. "/.cache/awesome/tag_labels"

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
beautiful.init(gears.filesystem.get_configuration_dir() .. "themes/default/theme.lua")
beautiful.wallpaper = '/usr/share/xfce4/backdrops/Journey_home_by_Juliette_Taka.png'

-- This is used later as the default terminal and editor to run.
terminal = "x-terminal-emulator"
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


mylauncher = awful.widget.launcher({ image = beautiful.awesome_icon,
                                     menu = mymainmenu })

-- Menubar configuration
menubar.utils.terminal = terminal -- Set the terminal for applications that require it
-- }}}

-- Keyboard map indicator and switcher
mykeyboardlayout = awful.widget.keyboardlayout()

-- {{{ Wibar
-- Create a textclock widget
mytextclock = wibox.widget.textclock()

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
    awful.tag({ "1", "2", "3", "4", "5", "6", "7", "8", "9" }, s, awful.layout.layouts[1])

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
    tag.connect_signal("property::selected", function() update_tag_label() end)
    tag.connect_signal("property::name", function() update_tag_label() end)
    -- Create an imagebox widget which will contain an icon indicating which layout we're using.
    -- We need one layoutbox per screen.
    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(gears.table.join(
                           awful.button({ }, 1, function () awful.layout.inc( 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(-1) end),
                           awful.button({ }, 4, function () awful.layout.inc( 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(-1) end)))
    -- Create a taglist widget
    s.mytaglist = awful.widget.taglist {
        screen  = s,
        filter  = awful.widget.taglist.filter.all,
        buttons = taglist_buttons,
        widget_template = {
            {
                {
                    id     = "text_role",
                    widget = wibox.widget.textbox,
                },
                left   = 6,
                right  = 6,
                widget = wibox.container.margin,
            },
            id     = "background_role",
            widget = wibox.container.background,
            create_callback = function(self, t)
                self:get_children_by_id("text_role")[1].text = " " .. get_display_label(t) .. " "
            end,
            update_callback = function(self, t)
                self:get_children_by_id("text_role")[1].text = " " .. get_display_label(t) .. " "
            end,
        },
    }

    -- Create a tasklist widget
    s.mytasklist = awful.widget.tasklist {
        screen  = s,
        filter  = awful.widget.tasklist.filter.currenttags,
        buttons = tasklist_buttons
    }

    -- Create the wibox
    s.mywibox = awful.wibar({ position = "top", screen = s })

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
        s.mytasklist, -- Middle widget
        { -- Right widgets
            layout = wibox.layout.fixed.horizontal,
            mykeyboardlayout,
            wibox.widget.systray(),
            battery,
            mytextclock,
            s.mylayoutbox,
        },
    }
end)

load_tag_labels()
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
        {description = "lock screen", group="custom"}),
    awful.key({ modkey, "Shift"   }, "s",
        function ()
            awful.spawn.with_shell("~/bin/speech_to_text.sh")
        end,
        {description = "speech to text", group="custom"}),
    awful.key({}, "XF86MonBrightnessUp",
        function ()
            awful.spawn("brightnessctl set +5%", false)
        end,
        {description = "increase brightness", group="system"}),
    awful.key({}, "XF86MonBrightnessDown",
        function ()
            awful.spawn("brightnessctl set 5%-", false)
        end,
        {description = "decrease brightness", group="system"}),
    awful.key({ modkey,           }, "s",      hotkeys_popup.show_help,
              {description="show help", group="awesome"}),
    awful.key({ modkey,           }, "Left",   function() awful.tag.viewprev(); focus_client_under_mouse() end,
              {description = "view previous", group = "tag"}),
    awful.key({ modkey,           }, "Right",  function() awful.tag.viewnext(); focus_client_under_mouse() end,
              {description = "view next", group = "tag"}),
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
    end, {description = "move client to previous tag and follow", group = "tag"}),
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
    end, {description = "move client to next tag and follow", group = "tag"}),
    awful.key({ modkey,           }, "Escape", function() awful.tag.history.restore(); focus_client_under_mouse() end,
              {description = "go back", group = "tag"}),

    awful.key({ modkey,           }, "j",
        function ()
            awful.client.focus.byidx( 1)
        end,
        {description = "focus next by index", group = "client"}
    ),
    awful.key({ modkey,           }, "k",
        function ()
            awful.client.focus.byidx(-1)
        end,
        {description = "focus previous by index", group = "client"}
    ),
    awful.key({ modkey,           }, "w", function () mymainmenu:show() end,
              {description = "show main menu", group = "awesome"}),

    -- Layout manipulation
    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end,
              {description = "swap with next client by index", group = "client"}),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end,
              {description = "swap with previous client by index", group = "client"}),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end,
              {description = "focus the next screen", group = "screen"}),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end,
              {description = "focus the previous screen", group = "screen"}),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto,
              {description = "jump to urgent client", group = "client"}),
    awful.key({ modkey,           }, "Tab",
        function ()
            awful.client.focus.history.previous()
            if client.focus then
                client.focus:raise()
            end
        end,
        {description = "go back", group = "client"}),

    -- Standard program
    awful.key({ modkey,           }, "e",
        function ()
            local c = client.focus
            if c and c.pid then
                awful.spawn.easy_async(
                    {"sh", "-c", "for pid in $(pgrep -P " .. c.pid .. "); do pty=$(readlink /proc/$pid/fd/0 2>/dev/null); cwd=$(readlink /proc/$pid/cwd 2>/dev/null); if [ -n \"$pty\" ] && [ -n \"$cwd\" ]; then echo \"$(stat -c %X $pty) $cwd\"; fi; done | sort -rn | head -1 | cut -d' ' -f2-"},
                    function(stdout)
                        local dir = stdout:match("^%s*(.-)%s*$")
                        if dir and dir ~= "" then
                            awful.spawn(terminal .. " --working-directory=" .. dir)
                        else
                            awful.spawn(terminal)
                        end
                    end
                )
            else
                awful.spawn(terminal)
            end
        end,
        {description = "open a terminal", group = "launcher"}),
    awful.key({ modkey, "Control" }, "r", awesome.restart,
              {description = "reload awesome", group = "awesome"}),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit,
              {description = "quit awesome", group = "awesome"}),

    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)          end,
              {description = "increase master width factor", group = "layout"}),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)          end,
              {description = "decrease master width factor", group = "layout"}),
    awful.key({ modkey, "Control" }, "k",     function () awful.client.incwfact(-0.05)        end,
              {description = "decrease height of client", group = "layout"}),

    awful.key({ modkey, "Control" }, "j",     function () awful.client.incwfact(0.05)         end,
              {description = "increase height of client", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1, nil, true) end,
              {description = "increase the number of master clients", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1, nil, true) end,
              {description = "decrease the number of master clients", group = "layout"}),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1, nil, true)    end,
              {description = "increase the number of columns", group = "layout"}),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1, nil, true)    end,
              {description = "decrease the number of columns", group = "layout"}),
    -- awful.key({ modkey,           }, "space", function () awful.layout.inc( 1)                end,
    --           {description = "select next", group = "layout"}),
    -- awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(-1)                end,
    --           {description = "select previous", group = "layout"}),

    awful.key({ modkey, "Control" }, "n",
              function ()
                  local c = awful.client.restore()
                  -- Focus restored client
                  if c then
                    c:emit_signal(
                        "request::activate", "key.unminimize", {raise = true}
                    )
                  end
              end,
              {description = "restore minimized", group = "client"}),

    -- Prompt
    awful.key({ modkey }, "space", function () awful.util.spawn("xfce4-appfinder") end,
              {description = "launch app finder", group = "launcher"}),
    --awful.key({ modkey },            "space",     function () awful.screen.focused().mypromptbox:run() end,
    --          {description = "run prompt", group = "launcher"}),

    awful.key({ modkey }, "x",
              function ()
                  awful.prompt.run {
                    prompt       = "Run Lua code: ",
                    textbox      = awful.screen.focused().mypromptbox.widget,
                    exe_callback = awful.util.eval,
                    history_path = awful.util.get_cache_dir() .. "/history_eval"
                  }
              end,
              {description = "lua execute prompt", group = "awesome"}),
    -- Menubar
    awful.key({ modkey }, "p", function() menubar.show() end,
              {description = "show the menubar", group = "launcher"}),

    -- Workspace label
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
                          end
                          t:emit_signal("property::name")
                          save_tag_labels()
                      end,
                  }
              end,
              {description = "set tag label", group = "tag"})
)

clientkeys = gears.table.join(
    awful.key({ modkey,           }, "f",
        function (c)
            c.fullscreen = not c.fullscreen
            c:raise()
        end,
        {description = "toggle fullscreen", group = "client"}),
    awful.key({ modkey, "Shift"   }, "c",      function (c) c:kill()                         end,
              {description = "close", group = "client"}),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ,
              {description = "toggle floating", group = "client"}),
    awful.key({ modkey }, "Return", function (c) c:swap(awful.client.getmaster()) end,
              {description = "move to master", group = "client"}),
    awful.key({ modkey,           }, "o",      function (c) c:move_to_screen()               end,
              {description = "move to screen", group = "client"}),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end,
              {description = "toggle keep on top", group = "client"}),
    awful.key({ modkey,           }, "n",
        function (c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
        end ,
        {description = "minimize", group = "client"}),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized = not c.maximized
            c:raise()
        end ,
        {description = "(un)maximize", group = "client"}),
    awful.key({ modkey, "Control" }, "m",
        function (c)
            c.maximized_vertical = not c.maximized_vertical
            c:raise()
        end ,
        {description = "(un)maximize vertically", group = "client"}),
    awful.key({ modkey, "Shift"   }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c:raise()
        end ,
        {description = "(un)maximize horizontally", group = "client"})
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it work on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 9 do
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
                  {description = "view tag #"..i, group = "tag"}),
        -- Toggle tag display.
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = awful.screen.focused()
                      local tag = screen.tags[i]
                      if tag then
                         awful.tag.viewtoggle(tag)
                         focus_client_under_mouse()
                      end
                  end,
                  {description = "toggle tag #" .. i, group = "tag"}),
        -- Move client to tag.
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:move_to_tag(tag)
                          end
                     end
                  end,
                  {description = "move focused client to tag #"..i, group = "tag"}),
        -- Toggle tag on focused client.
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:toggle_tag(tag)
                          end
                      end
                  end,
                  {description = "toggle focused client on tag #" .. i, group = "tag"})
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
        rule = { class = 'x-terminal-emulator'},
        properties = { slave = true }
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
    if not awesome.startup and c.class == "X-terminal-emulator" then
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

-- Enable sloppy focus, so that focus follows mouse.
client.connect_signal("mouse::enter", function(c)
    c:emit_signal("request::activate", "mouse_enter", {raise = false})
end)

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

-- Compositor for opacity support
awful.util.spawn_with_shell('picom --daemon')

-- Lock screen script
awful.util.spawn_with_shell('xset +dpms && xset dpms 720 720 720')
awful.util.spawn_with_shell('~/.config/awesome/locker.sh')
awful.util.spawn_with_shell('~/bin/volume-hotkeys.sh')

awesome.connect_signal("exit", function(restart)
    save_tag_labels()
    awful.spawn.with_shell("pkill -f volume-hotkeys.sh")
end)

