local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")

local calendar = {}

local cal_popup = nil
local cal_month_offset = 0

local function build_calendar(month_offset)
    local now = os.time()
    local target = os.date("*t", now)
    target.month = target.month + month_offset
    target.day = 1
    local t = os.time(target)
    local info = os.date("*t", t)
    local today = os.date("*t", now)

    local year, month = info.year, info.month
    local header = os.date("%B %Y", t)

    -- First day of month (1=Sun in os.date, convert to Mon=1)
    local first_wday = os.date("*t", os.time({year=year, month=month, day=1})).wday
    first_wday = first_wday == 1 and 7 or first_wday - 1

    -- Days in month
    local days_in = os.date("*t", os.time({year=year, month=month+1, day=0})).day

    local rows = {
        {
            layout = wibox.layout.fixed.horizontal,
            {widget = wibox.widget.textbox, text = " Mo ", align = "center", font = "monospace bold 10"},
            {widget = wibox.widget.textbox, text = " Tu ", align = "center", font = "monospace bold 10"},
            {widget = wibox.widget.textbox, text = " We ", align = "center", font = "monospace bold 10"},
            {widget = wibox.widget.textbox, text = " Th ", align = "center", font = "monospace bold 10"},
            {widget = wibox.widget.textbox, text = " Fr ", align = "center", font = "monospace bold 10"},
            {widget = wibox.widget.textbox, text = " Sa ", align = "center", font = "monospace bold 10"},
            {widget = wibox.widget.textbox, text = " Su ", align = "center", font = "monospace bold 10"},
        }
    }

    local row = {layout = wibox.layout.fixed.horizontal}
    -- Pad first week
    for i = 1, first_wday - 1 do
        table.insert(row, {widget = wibox.widget.textbox, text = "    ", font = "monospace 10"})
    end

    for day = 1, days_in do
        local is_today = (month_offset == 0 and day == today.day)
        local label = string.format(" %2d ", day)
        local w
        if is_today then
            w = {
                {widget = wibox.widget.textbox, text = label, font = "monospace bold 10"},
                bg = "#4488cc",
                fg = "#ffffff",
                widget = wibox.container.background,
            }
        else
            w = {widget = wibox.widget.textbox, text = label, font = "monospace 10"}
        end
        table.insert(row, w)

        if #row % 7 == 0 or day == days_in then
            local count = #row
            -- Pad remaining days
            while count < 7 do
                table.insert(row, {widget = wibox.widget.textbox, text = "    ", font = "monospace 10"})
                count = count + 1
            end
            table.insert(rows, row)
            row = {layout = wibox.layout.fixed.horizontal}
        end
    end

    return {
        {
            {
                {
                    {widget = wibox.widget.textbox, text = " ◀ ", font = "monospace bold 12"},
                    buttons = gears.table.join(awful.button({}, 1, function()
                        cal_month_offset = cal_month_offset - 1
                        calendar.toggle(true)
                    end)),
                    widget = wibox.container.background,
                },
                {widget = wibox.widget.textbox, text = header, align = "center", font = "sans bold 11"},
                {
                    {widget = wibox.widget.textbox, text = " ▶ ", font = "monospace bold 12"},
                    buttons = gears.table.join(awful.button({}, 1, function()
                        cal_month_offset = cal_month_offset + 1
                        calendar.toggle(true)
                    end)),
                    widget = wibox.container.background,
                },
                layout = wibox.layout.align.horizontal,
            },
            {
                layout = wibox.layout.fixed.vertical,
                table.unpack(rows),
            },
            layout = wibox.layout.fixed.vertical,
        },
        margins = 8,
        widget = wibox.container.margin,
    }
end

function calendar.toggle(force_refresh)
    if cal_popup and not force_refresh then
        cal_popup.visible = false
        cal_popup = nil
        cal_month_offset = 0
        return
    end

    if cal_popup then
        cal_popup.visible = false
        cal_popup = nil
    end

    cal_popup = awful.popup {
        widget = build_calendar(cal_month_offset),
        bg = "#222222ee",
        shape = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, 8) end,
        ontop = true,
        visible = true,
        placement = function(d)
            awful.placement.top_right(d, {
                margins = {top = 25, right = 50},
                parent = awful.screen.focused(),
            })
        end,
    }
end

return calendar
