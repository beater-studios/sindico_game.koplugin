-- The game window. Every screen is laid out on a Canvas (ui/canvas.lua) in the units of the mockups and painted by
-- this one widget, which finds what was tapped in the canvas tap areas.
local Blitbuffer = require("ffi/blitbuffer")
local DataStorage = require("datastorage")
local Device = require("device")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local LuaSettings = require("luasettings")
local UIManager = require("ui/uimanager")
local logger = require("logger")

local Canvas = require("sindico_game/ui/canvas")
local Content = require("sindico_game/content")
local Engine = require("sindico_game/engine")
local Portrait = require("sindico_game/portrait")
local Refresh = require("sindico_game/refresh")
local SavedState = require("sindico_game/saved_state")
local sentence_case = require("sindico_game/ui/sentence_case")

local BLACK, DARK, MID, LIGHT, PALE, PAPER, WHITE =
    Canvas.BLACK, Canvas.DARK, Canvas.MID, Canvas.LIGHT, Canvas.PALE, Canvas.PAPER, Canvas.WHITE
local SANS, SANS_BOLD = Canvas.SANS, Canvas.SANS_BOLD
local SERIF, SERIF_BOLD, SERIF_ITALIC = Canvas.SERIF, Canvas.SERIF_BOLD, Canvas.SERIF_ITALIC
local STATUS_TOP = 774
-- The card screens fill the page down to the status strip: the footer sits right above it, the answers above
-- the footer, and the card takes the rest.
local FOOTER_TOP = 722
local ANSWERS_TOP = 640
local CARD_BOTTOM = 628
local RESULT_STYLES = { "highlight", "note" }
local GALLERY_TILES = 12
-- The icon of each way to reach an ending, in the gallery: the meter that ran out, the lost election, the full
-- terms, the cards that ran out, and a story (an ending a choice leads to, without a trigger).
local TRIGGER_ICONS = {
    ["zero:residents"] = "residents", ["zero:funds"] = "funds", ["zero:building"] = "building", ["zero:patience"] = "patience",
    election_lost = "ballot", all_mandates = "crown", no_cards = "cards",
}

local Screen = InputContainer:extend{
    name = "sindico_game_screen",
    covers_fullscreen = true,
    stop_events_propagation = true,
    plugin_dir = ".",
}

function Screen:init()
    Portrait.open(self, self.setup)
end

function Screen:settings_path()
    return DataStorage:getSettingsDir() .. "/sindico_game.lua"
end

function Screen:setup()
    local size = Device.screen:getSize()
    self.dimen = Geom:new{ x = 0, y = 0, w = size.w, h = size.h }
    self.refresh = Refresh.new(8)
    self.lang = Content.language_from(G_reader_settings and G_reader_settings:readSetting("language"))
    self.strings = Content.strings(self.plugin_dir, self.lang)
    self.engine = Engine.new({ content = Content.load(self.plugin_dir, self.lang) })
    self:load_saved()
    self.ges_events = {
        Tap = { GestureRange:new{ ges = "tap", range = self.dimen } },
        Swipe = { GestureRange:new{ ges = "swipe", range = self.dimen } },
    }
    if Device:hasKeys() then
        self.key_events.Back = { { Device.input.group.Back } }
    end
    self:show_title()
end

-- The records, the options and the game in progress are read apart: a game that does not fit the current
-- content is dropped and the records stay.
function Screen:load_saved()
    self.settings = LuaSettings:open(self:settings_path())
    self.stats = Engine.restore_stats(self.settings:readSetting("stats"))
    self.result_style = SavedState.one_of(self.settings:readSetting("result_style"), RESULT_STYLES, "highlight")
    self.show_status = self.settings:readSetting("show_status") ~= false
    local engine = self.engine
    local restored = SavedState.restore(function(data) return engine:restore(data) end,
        self.settings:readSetting("game"), logger.warn)
    if not restored then
        engine.state = nil
        self.settings:delSetting("game")
    end
end

function Screen:save_game()
    self.settings:saveSetting("game", self.engine:serialize())
    self.settings:saveSetting("stats", self.stats)
    self.settings:flush()
end

function Screen:save_options()
    self.settings:saveSetting("result_style", self.result_style)
    self.settings:saveSetting("show_status", self.show_status)
    self.settings:flush()
end

function Screen:asset(path)
    return self.plugin_dir .. "/assets/" .. path
end

function Screen:has_game()
    local s = self.engine.state
    return s and not s.ending and s.current ~= nil
end

-- --- Showing a screen ---

-- kind names the layout for the e-ink updates: the same kind again is updated without a flash, a new kind (or
-- every ninth update) flashes. A card and the result of a decision share the kind "play".
function Screen:present(canvas, mode, kind)
    if self.canvas then
        self.canvas:free()
    end
    self.canvas, self.mode = canvas, mode
    self.content_height = canvas:content_height()
    self.layout_problems = canvas.problems
    self:build_status()
    local refresh = self.refresh:mode(kind or mode)
    UIManager:setDirty(self, function()
        return refresh, self.dimen
    end)
end

function Screen:new_canvas()
    return Canvas.new(self.dimen.w, self.dimen.h)
end

-- Every text laid out on the current screen, for the checks.
function Screen:shown_texts()
    local texts = {}
    for _, item in ipairs(self.canvas and self.canvas.items or {}) do
        if item.widget and item.widget.text then
            texts[#texts + 1] = item.widget.text
        end
    end
    return texts
end

function Screen:paintTo(bb, x, y)
    self.dimen.x, self.dimen.y = x, y
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)
    if self.canvas then
        local ok, err = pcall(self.canvas.paint, self.canvas, bb, x, y)
        if not ok then
            logger.warn("sindico_game: could not draw the screen", self.mode, err)
        end
    end
    if self.status_canvas then
        self.status_canvas:paint(bb, x, y)
    end
end

-- --- The status strip: date, time and battery, read again on each tap ---

local function battery_level()
    if not Device:hasBattery() then
        return nil
    end
    local ok, level = pcall(function() return Device:getPowerDevice():getCapacity() end)
    return ok and tonumber(level) or nil
end

function Screen:status_text()
    local now = os.date("*t")
    local twelve = G_reader_settings and G_reader_settings:isTrue("twelve_hour_clock")
    local time = twelve and string.format("%d:%02d %s", (now.hour - 1) % 12 + 1, now.min, now.hour < 12 and "AM" or "PM")
        or string.format("%02d:%02d", now.hour, now.min)
    local values = {
        weekday = self.strings.weekdays[now.wday], day = tostring(now.day), month = self.strings.months[now.month], time = time,
    }
    return (self.strings.status_date:gsub("{(%a+)}", values))
end

function Screen:build_status()
    if self.status_canvas then
        self.status_canvas:free()
        self.status_canvas = nil
    end
    if not self.show_status then
        return
    end
    local c = self:new_canvas()
    self.status_shown = self:status_text()
    local level = battery_level()
    c:line(0, STATUS_TOP, Canvas.UNITS_W, STATUS_TOP, LIGHT, 1)
    local right = 584
    if level then
        local percent = level .. "%"
        right = right - c:text(right, STATUS_TOP + 13, percent, SANS_BOLD, 13, { anchor = "right", middle = true }) - 6
        c:box(right - 22, STATUS_TOP + 7, right - 2, STATUS_TOP + 19, { fill = WHITE, border = BLACK, width = 1.5, radius = 2 })
        if level > 0 then
            c:box(right - 22, STATUS_TOP + 7, right - 22 + 20 * math.min(level, 100) / 100, STATUS_TOP + 19, { fill = BLACK, radius = 2 })
        end
        c:box(right - 2, STATUS_TOP + 10, right, STATUS_TOP + 16, { fill = BLACK })
        right = right - 32
    end
    c:text(right, STATUS_TOP + 13, self.status_shown, SANS, 13, { anchor = "right", middle = true, color = DARK })
    self.status_canvas = c
    self.status_rect = Geom:new{ x = 0, y = c:y(STATUS_TOP), w = self.dimen.w, h = self.dimen.h - c:y(STATUS_TOP) }
end

-- Only the strip is updated, without a flash and outside the count of updates.
function Screen:update_status()
    if self.show_status and self:status_text() ~= self.status_shown then
        self:build_status()
        local rect = self.status_rect
        UIManager:setDirty(self, function()
            return "ui", Geom:new{ x = self.dimen.x + rect.x, y = self.dimen.y + rect.y, w = rect.w, h = rect.h }
        end)
    end
end

-- --- Pieces shared by the screens ---

function Screen:button(c, x0, y0, x1, y1, text, action, opts)
    opts = opts or {}
    local enabled = action ~= nil or opts.sample
    c:box(x0, y0, x1, y1, {
        fill = opts.dark and BLACK or WHITE, border = (not opts.dark) and (enabled and BLACK or LIGHT) or nil,
        width = opts.border or 3, radius = opts.radius or 12,
    })
    c:text((x0 + x1) / 2, (y0 + y1) / 2, text, SANS_BOLD, opts.size or 19, {
        anchor = "center", middle = true, color = opts.dark and WHITE or (enabled and BLACK or LIGHT),
        room = x1 - x0 - 16, name = opts.name or "button",
    })
    if action then
        c:hit(x0, y0, x1, y1, action)
    end
end

function Screen:arrows(c, x, y, delta, size)
    if not delta or delta == 0 then
        return x
    end
    local file = self:asset(delta > 0 and "icons/arrow_up.svg" or "icons/arrow_down.svg")
    for _ = 1, math.abs(delta) >= 10 and 2 or 1 do
        c:image(file, x, y, size, size, { alpha = true })
        x = x + size
    end
    return x
end

function Screen:meters(c, values, deltas, top)
    deltas, top = deltas or {}, top or 10
    local cell = (Canvas.UNITS_W - 32) / #Engine.METERS
    for i, key in ipairs(Engine.METERS) do
        local x = 16 + (i - 1) * cell
        c:image(self:asset("icons/" .. key .. ".svg"), x, top, 40, 40, { alpha = true })
        local delta = deltas[key] or 0
        local font = delta ~= 0 and SANS_BOLD or SANS
        local arrows_w = delta == 0 and 0 or (math.abs(delta) >= 10 and 20 or 10) + 2
        local label = self.strings["meter_" .. key]
        local room = cell - 48 - arrows_w
        -- A long name with two arrows gets a point smaller.
        local size = c:measure(label, font, 13) <= room and 13 or 12
        local w = c:text(x + 46, top + 3, label, font, size, { room = room, name = "meter" })
        self:arrows(c, x + 48 + w, top + 6, delta, 10)
        local x0, x1 = x + 46, x + cell - 10
        c:box(x0, top + 25, x1, top + 37, { fill = WHITE, border = BLACK, width = 2, radius = 6 })
        local value = values[key] or 0
        if value > 0 then
            c:box(x0, top + 25, x0 + (x1 - x0) * value / 100, top + 37, { fill = value <= 20 and BLACK or DARK, radius = 6 })
        end
    end
    c:line(16, top + 54, 584, top + 54, BLACK, 2)
end

-- The meters a decision changed, as icons, names and arrows in a row. Returns the end of the row.
function Screen:delta_chips(c, x, y, deltas, size, measure_only)
    size = size or 15
    for _, key in ipairs(Engine.METERS) do
        local delta = deltas and deltas[key]
        if delta and delta ~= 0 then
            local label = self.strings["meter_" .. key]
            if not measure_only then
                c:image(self:asset("icons/" .. key .. ".svg"), x, y - 2, size + 7, size + 7, { alpha = true })
            end
            x = x + size + 11
            local w = measure_only and c:measure(label, SANS_BOLD, size) or c:text(x, y, label, SANS_BOLD, size)
            x = x + w + 3
            if measure_only then
                x = x + (math.abs(delta) >= 10 and 2 or 1) * (size - 1)
            else
                x = self:arrows(c, x, y + 2, delta, size - 1)
            end
            x = x + 18
        end
    end
    return x
end

function Screen:chips_width(c, deltas, size)
    return self:delta_chips(c, 0, 0, deltas, size, true) - 18
end

function Screen:answer_buttons(c, top, card)
    local half = (Canvas.UNITS_W - 32 - 14) / 2
    self:button(c, 16, top, 16 + half, top + 70, "‹ " .. sentence_case(card.left.label),
        function() self:decide("left") end, { name = "choice label " .. card.id })
    self:button(c, 584 - half, top, 584, top + 70, sentence_case(card.right.label) .. " ›",
        function() self:decide("right") end, { name = "choice label " .. card.id })
end

-- back: the screen the minutes go back to, the card by default.
function Screen:card_footer(c, top, back)
    local s = self.engine.state
    back = back or function() self:show_card() end
    self:button(c, 16, top, 104, top + 36, self.strings.minutes_button,
        function() self:show_minutes(s, back) end,
        { size = 15, radius = 8, border = 2, name = "footer button" })
    self:button(c, 496, top, 584, top + 36, self.strings.menu_button,
        function() self:show_title() end, { size = 15, radius = 8, border = 2, name = "footer button" })
    local month = self.engine:month()
    c:text(300, top + 4, string.format(self.strings.card_footer, s.mandate, month, Engine.MANDATE_MONTHS), SANS, 14,
        { anchor = "center", room = 380, name = "card footer" })
    -- The term as a strip of months, the months gone filled.
    local step = 7
    local x0 = 300 - Engine.MANDATE_MONTHS * step / 2
    for m = 1, Engine.MANDATE_MONTHS do
        c:box(x0 + (m - 1) * step, top + 26, x0 + (m - 1) * step + 5, top + 31,
            { fill = m <= month and BLACK or WHITE, border = BLACK, width = 1 })
    end
end

-- The bar on top of the paged screens. Returns its bottom.
function Screen:header(c, title, subtitle, back)
    self:button(c, 16, 14, 112, 50, "‹ " .. self.strings.back, back, { size = 15, radius = 8, name = "back button" })
    c:text(318, 18, title, SERIF_BOLD, 24, { anchor = "center", room = 400, name = "list title" })
    local bottom = 62
    if subtitle then
        c:text(300, 58, subtitle, SERIF_ITALIC, 15, { anchor = "center", color = MID, room = 568, name = "list subtitle" })
        bottom = 84
    end
    c:line(16, bottom, 584, bottom, BLACK, 2)
    return bottom
end

function Screen:pager(c, top)
    local list = self.list
    local total = math.max(1, #list.pages)
    self:button(c, 16, top, 120, top + 44, "‹", list.page > 1 and function() self:turn_list_page(-1) end or nil, { size = 22 })
    self:button(c, 480, top, 584, top + 44, "›", list.page < total and function() self:turn_list_page(1) end or nil, { size = 22 })
    c:text(300, top + 22, string.format(self.strings.page_of, list.page, total), SANS, 16, { anchor = "center", middle = true })
end

function Screen:mini_meters(c, x, y, width, values)
    local cell = width / #Engine.METERS
    for i, key in ipairs(Engine.METERS) do
        local cx = x + (i - 1) * cell
        -- The icons are black circles, so on the black banner only their white symbol shows.
        c:image(self:asset("icons/" .. key .. ".svg"), cx, y, 24, 24, { alpha = true })
        local value = values[key] or 0
        if value > 0 then
            c:box(cx + 30, y + 7, cx + 30 + (cell - 40) * value / 100, y + 17, { fill = LIGHT, radius = 5 })
        end
        c:box(cx + 30, y + 7, cx + cell - 10, y + 17, { border = WHITE, width = 1.5, radius = 5 })
    end
end

-- --- Home ---

function Screen:layout_title(c)
    c:image(self:asset("building.png"), 202, 20, 196, 242)
    c:text(300, 270, self.engine.content.meta.fullname, SERIF_BOLD, 40, { anchor = "center" })
    c:text(300, 324, self.strings.subtitle, SERIF_ITALIC, 20, { anchor = "center", color = MID })
    local half = (Canvas.UNITS_W - 32 - 14) / 2
    local s = self.engine.state
    c:box(16, 368, 584, 478, { fill = BLACK, radius = 14 })
    c:text(554, 400, "›", SANS_BOLD, 34, { anchor = "right", color = WHITE })
    local rows, last_row
    if self:has_game() then
        c:text(36, 382, self.strings.continue_title, SANS_BOLD, 24, { color = WHITE, room = 480, name = "continue" })
        c:text(36, 416, string.format(self.strings.card_footer, s.mandate, self.engine:month(), Engine.MANDATE_MONTHS),
            SANS, 15, { color = LIGHT, room = 480, name = "continue" })
        self:mini_meters(c, 36, 444, 528, s.meters)
        c:hit(16, 368, 584, 478, function() self:show_card() end)
        rows = {
            { self.strings.new_game, function() self:confirm_new_game() end, self.strings.gallery, function() self:show_gallery() end },
            { self.strings.help, function() self:show_help() end, self.strings.settings, function() self:show_settings() end },
        }
        last_row = { self.strings.about, function() self:show_about() end, self.strings.quit, function() self:close_game() end }
    else
        c:text(36, 390, self.strings.new_game, SANS_BOLD, 24, { color = WHITE, room = 480, name = "new game" })
        c:text(36, 428, self.strings.new_game_detail, SANS, 15, { color = LIGHT, room = 480, name = "new game" })
        c:hit(16, 368, 584, 478, function() self:start_game() end)
        rows = {
            { self.strings.gallery, function() self:show_gallery() end, self.strings.help, function() self:show_help() end },
            { self.strings.settings, function() self:show_settings() end, self.strings.about, function() self:show_about() end },
        }
    end
    for r, row in ipairs(rows) do
        local y = 494 + (r - 1) * 74
        self:button(c, 16, y, 16 + half, y + 62, row[1], row[2], { name = "menu button" })
        self:button(c, 584 - half, y, 584, y + 62, row[3], row[4], { name = "menu button" })
    end
    if last_row then
        self:button(c, 16, 646, 16 + half, 696, last_row[1], last_row[2], { size = 17, name = "menu button" })
        self:button(c, 584 - half, 646, 584, 696, last_row[3], last_row[4], { size = 17, name = "menu button" })
    else
        self:button(c, 16, 646, 584, 696, self.strings.quit, function() self:close_game() end, { size = 17, name = "menu button" })
    end
end

function Screen:show_title()
    local c = self:new_canvas()
    self:layout_title(c)
    self:present(c, "title")
end

function Screen:confirm_new_game()
    if not self:has_game() then
        return self:start_game()
    end
    local c = self:new_canvas()
    self:layout_title(c)
    -- Only the dialog answers taps.
    c.hits = {}
    c:fade(0.65)
    c:box(40, 280, 560, 520, { fill = WHITE, border = BLACK, width = 3, radius = 18 })
    c:text(300, 306, self.strings.confirm_title, SERIF_BOLD, 26, { anchor = "center", room = 480, name = "confirm title" })
    c:paragraph(70, 354, 460, string.format(self.strings.confirm_text, self.engine:month(), Engine.MANDATE_MONTHS),
        SERIF, 18, { color = DARK, room = 76, name = "confirm text" })
    local half = (520 - 32 - 14) / 2
    self:button(c, 56, 440, 56 + half, 498, self.strings.back, function() self:show_title() end, { size = 18, name = "confirm button" })
    self:button(c, 544 - half, 440, 544, 498, self.strings.confirm_start, function() self:start_game() end,
        { dark = true, size = 18, name = "confirm button" })
    self:present(c, "confirm", "title")
end

function Screen:start_game()
    self.engine:new_game()
    self.new_ending = nil
    self:save_game()
    self:show_card()
end

-- --- Cards and results ---

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

function Screen:character(id)
    return self.engine.content.characters[id] or { name = "", role = "" }
end

-- What the last decision led to, with the reelection when there was one.
function Screen:last_result(s)
    local result = self.engine:choice_text(s.last, "result", "result") or self.strings.first_day
    if s.last and s.last.reelected then
        result = string.format(self.strings.reelected, s.mandate) .. " " .. result
    end
    return result
end

function Screen:show_card()
    local s = self.engine.state
    local card = s and self.engine:current_card()
    if not card then
        return self:show_ending()
    end
    local c = self:new_canvas()
    if self.result_style == "note" then
        self:layout_card_note(c, s, card)
    else
        self:layout_card(c, s, card)
    end
    self:present(c, "card", "play")
end

function Screen:layout_card(c, s, card)
    local character = self:character(card.char)
    self:meters(c, s.meters, s.last and s.last.deltas)
    -- The portrait takes the room the question leaves in the card.
    local text_h = c:measure_paragraph(card.text, SERIF, 23, 520)
    local size = clamp(CARD_BOTTOM - 96 - 30 - 84 - text_h, 120, 260)
    c:box(16, 78, 584, CARD_BOTTOM, { fill = WHITE, border = BLACK, width = 3, radius = 18 })
    -- The portrait, the name and the request are centered in the card.
    local block = size + 14 + 70 + text_h
    local top = math.max(96, 78 + (CARD_BOTTOM - 78 - block) / 2)
    c:image(self:asset("portraits/" .. card.char .. ".png"), 300 - size / 2, top, size, size, { frame = 2 })
    local y = top + size + 14
    c:text(300, y, character.name, SERIF_BOLD, 24, { anchor = "center", room = 540, name = "character name" })
    c:text(300, y + 32, character.role, SERIF_ITALIC, 16, { anchor = "center", color = MID, room = 540, name = "character role" })
    y = y + 70
    c:paragraph(40, y, 520, card.text, SERIF, 23, { room = CARD_BOTTOM - 10 - y, name = "card text " .. card.id })
    self:answer_buttons(c, ANSWERS_TOP, card)
    self:card_footer(c, FOOTER_TOP)
end

function Screen:layout_card_note(c, s, card)
    local character = self:character(card.char)
    self:meters(c, s.meters)
    -- The note with what the last decision led to.
    local previous = s.last and s.last.card and self.engine.content.by_id[s.last.card]
    local text_x = previous and 122 or 36
    local width = 570 - text_x
    local top = 78
    local y = top + 14
    if previous then
        local choice = previous[s.last.side]
        c:text(text_x, y, string.format(self.strings.answer_to, self:character(previous.char).name, sentence_case(choice.label)),
            SANS_BOLD, 13, { color = MID, room = width, name = "note heading" })
        y = y + 22
    end
    local result = self:last_result(s)
    local result_h = c:measure_paragraph(result, SERIF_ITALIC, 19, width)
    local note_bottom = y + result_h + (previous and 36 or 14)
    if previous then
        note_bottom = math.max(note_bottom, top + 108)
    end
    -- The note box goes under what was already laid out in it.
    table.insert(c.items, 1, {
        kind = "box", x = c:x(16), y = c:y(top), w = c:px(568), h = c:px(note_bottom - top),
        fill = PAPER, border = BLACK, bw = math.max(1, c:px(2)), r = c:px(14),
    })
    if previous then
        c:image(self:asset("portraits/" .. previous.char .. ".png"), 30, top + 16, 76, 76, { frame = 2 })
    end
    local end_y = c:paragraph(text_x, y, width, result, SERIF_ITALIC, 19, { align = "left", background = PAPER })
    if previous then
        self:delta_chips(c, text_x, end_y + 8, s.last.deltas, 14)
    end
    -- The next card: the portrait takes the room the note and the question leave.
    local text_h = c:measure_paragraph(card.text, SERIF, 21, 528)
    local avail = CARD_BOTTOM - (note_bottom + 16)
    local size = clamp(avail - text_h - 62 - 24, 90, 220)
    y = note_bottom + 16 + math.max(0, (avail - (size + 12 + 62 + text_h)) / 2)
    c:image(self:asset("portraits/" .. card.char .. ".png"), 300 - size / 2, y, size, size, { frame = 2 })
    y = y + size + 12
    c:text(300, y, character.name, SERIF_BOLD, 23, { anchor = "center", room = 540, name = "character name" })
    c:text(300, y + 30, character.role, SERIF_ITALIC, 15, { anchor = "center", color = MID, room = 540, name = "character role" })
    y = y + 62
    c:paragraph(36, y, 528, card.text, SERIF, 21, { room = CARD_BOTTOM - y, name = "card text " .. card.id })
    self:answer_buttons(c, ANSWERS_TOP, card)
    self:card_footer(c, FOOTER_TOP)
end

function Screen:show_result()
    local s = self.engine.state
    local previous = s.last and s.last.card and self.engine.content.by_id[s.last.card]
    if not previous then
        return self:show_card()
    end
    local c = self:new_canvas()
    local character = self:character(previous.char)
    self:meters(c, s.meters, s.last.deltas)
    -- The card, shrunk to a summary.
    local text_bottom = 150 + c:measure_paragraph(previous.text, SERIF, 15, 400)
    local summary_bottom = math.max(94 + 120, text_bottom) + 16
    c:box(16, 78, 584, summary_bottom, { fill = WHITE, border = MID, width = 2, radius = 16 })
    c:image(self:asset("portraits/" .. previous.char .. ".png"), 32, 94, 120, 120, { frame = 2 })
    c:text(168, 94, character.name, SERIF_BOLD, 20, { room = 400, name = "character name" })
    c:text(168, 122, character.role, SERIF_ITALIC, 14, { color = MID, room = 400, name = "character role" })
    c:paragraph(168, 150, 400, previous.text, SERIF, 15, { align = "left", color = DARK })
    -- The answer chosen and, large, what it led to.
    local label = string.format(self.strings.you_answered, sentence_case(previous[s.last.side].label))
    local chip_w = math.min(568, c:measure(label, SANS_BOLD, 17) + 40)
    local y = summary_bottom + 18
    c:box(300 - chip_w / 2, y, 300 + chip_w / 2, y + 40, { fill = BLACK, radius = 20 })
    c:text(300, y + 20, label, SANS_BOLD, 17, { anchor = "center", middle = true, color = WHITE, room = 548, name = "answer chip" })
    local box_top = y + 58
    local box_bottom = ANSWERS_TOP - 36
    local result = self:last_result(s)
    -- The result type shrinks for a long result on a long card, so it fits the box.
    local size, result_h
    for _, candidate in ipairs({ 29, 25, 22 }) do
        size, result_h = candidate, c:measure_paragraph(result, SERIF_BOLD, candidate, 512)
        if 34 + result_h + 22 + 22 + 24 <= box_bottom - box_top then
            break
        end
    end
    local content_h = 34 + result_h + 22 + 22
    if content_h + 24 > box_bottom - box_top then
        c:problem("result does not fit its box: " .. previous.id)
    end
    c:box(16, box_top, 584, box_bottom, { fill = PAPER, border = BLACK, width = 3, radius = 18 })
    -- The heading, the result and the meters that changed, centered in the box.
    local inner = box_top + math.max(12, (box_bottom - box_top - content_h) / 2)
    c:text(300, inner, self.strings.result_heading, SANS_BOLD, 13,
        { anchor = "center", color = MID, room = 540, name = "result heading" })
    local end_y = c:paragraph(44, inner + 34, 512, result, SERIF_BOLD, size, { background = PAPER })
    self:delta_chips(c, 300 - self:chips_width(c, s.last.deltas) / 2, end_y + 22, s.last.deltas)
    -- The button sits where the answers were, so the same tap goes on.
    c:text(300, ANSWERS_TOP - 24, self.strings.swipe_hint, SANS, 13, { anchor = "center", color = MID, room = 560, name = "swipe hint" })
    self:button(c, 16, ANSWERS_TOP, 584, ANSWERS_TOP + 70, self.strings.next_card, function() self:next_card() end,
        { dark = true, size = 23, radius = 14, name = "next card" })
    -- The minutes go back to this result, which the card screen would skip.
    self:card_footer(c, FOOTER_TOP, function() self:show_result() end)
    self:present(c, "result", "play")
end

function Screen:next_card()
    self:show_card()
end

function Screen:decide(side)
    if self.mode ~= "card" or not self:has_game() then return end
    self.engine:choose(side)
    local s = self.engine.state
    if s.ending then
        self.new_ending = not self.stats.endings[s.ending]
        self.engine:record_ending(self.stats)
        if self.new_ending then
            self.stats.newest_ending = s.ending
        end
        self.settings:delSetting("game")
        self.settings:saveSetting("stats", self.stats)
        self.settings:flush()
        self:show_ending(s)
        return
    end
    self:save_game()
    if s.last and s.last.reelected then
        -- A new term arrives with a clean full update.
        self.refresh:reset()
    end
    if self.result_style == "highlight" then
        self:show_result()
    else
        self:show_card()
    end
end

-- A decision, and on to the next card when the result shows on a screen of its own: for the checks and tools.
function Screen:play(side)
    self:decide(side)
    if self.mode == "result" then
        self:next_card()
    end
end

-- --- Ending ---

function Screen:counted_endings()
    local total = 0
    for _, ending in ipairs(self.engine.content.endings) do
        if self.stats.endings[ending.id] or ending.trigger ~= "no_cards" then
            total = total + 1
        end
    end
    return total
end

function Screen:found_endings()
    local found = 0
    for _, ending in ipairs(self.engine.content.endings) do
        if self.stats.endings[ending.id] then
            found = found + 1
        end
    end
    return found
end

function Screen:ending_icon(ending)
    return self:asset("icons/" .. (TRIGGER_ICONS[ending.trigger or ""] or "story") .. ".svg")
end

function Screen:ending_good(ending)
    local good = ending.good
    if good == nil then
        good = ending.trigger == nil or ending.trigger == "all_mandates"
    end
    return good
end

function Screen:show_ending(state)
    local s = state or self.engine.state
    local ending = self.engine.content.ending_by_id[s.ending] or { title = "", text = "" }
    local c = self:new_canvas()
    if self.new_ending then
        local label = self.strings.new_ending
        local w = c:measure(label, SANS_BOLD, 14) + 32
        c:box(300 - w / 2, 18, 300 + w / 2, 48, { fill = BLACK, radius = 15 })
        c:text(300, 33, label, SANS_BOLD, 14, { anchor = "center", middle = true, color = WHITE, room = 560, name = "new ending" })
    end
    -- A long ending text gets a smaller building.
    local text_h = c:measure_paragraph(ending.text, SERIF, 18, 552)
    local image_h = clamp(516 - text_h - 84 - 62, 100, 188)
    c:image(self:asset(self:ending_good(ending) and "building.png" or "building_damaged.png"), 300 - image_h * 0.4, 62,
        image_h * 0.8, image_h)
    local y = 62 + image_h + 10
    c:text(300, y, ending.title, SERIF_BOLD, 30, { anchor = "center", room = 568, name = "ending title" })
    c:text(300, y + 44, string.format(self.strings.ending_progress, self:found_endings(), self:counted_endings()), SANS, 14,
        { anchor = "center", color = MID, room = 560, name = "ending progress" })
    c:paragraph(24, y + 74, 552, ending.text, SERIF, 18, { room = 518 - (y + 74), name = "ending text " .. tostring(s.ending) })
    local won = Engine.completed_mandates(s)
    local tiles = {
        { tostring(won), won == 1 and self.strings.full_terms_one or self.strings.full_terms_many },
        { tostring(Engine.total_days(s)), self.strings.days_in_office },
        { tostring(s.decisions), self.strings.decisions },
    }
    local tw = (Canvas.UNITS_W - 32 - 24) / 3
    for i, tile in ipairs(tiles) do
        local x = 16 + (i - 1) * (tw + 12)
        c:box(x, 528, x + tw, 600, { fill = PAPER, border = BLACK, width = 2, radius = 12 })
        c:text(x + tw / 2, 536, tile[1], SERIF_BOLD, 28, { anchor = "center" })
        c:text(x + tw / 2, 578, tile[2], SANS, 13, { anchor = "center", color = DARK, room = tw - 12, name = "ending tile" })
    end
    local half = (Canvas.UNITS_W - 32 - 14) / 2
    self:button(c, 16, 620, 584, 682, self.strings.new_game, function() self:start_game() end,
        { dark = true, size = 21, name = "menu button" })
    self:button(c, 16, 694, 16 + half, 744, self.strings.read_minutes,
        function() self:show_minutes(s, function() self:show_ending(s) end) end, { size = 17, name = "menu button" })
    self:button(c, 584 - half, 694, 584, 744, self.strings.home, function() self:leave_ending() end,
        { size = 17, name = "menu button" })
    self:present(c, "ending")
end

function Screen:leave_ending()
    self.engine.state = nil
    self.new_ending = nil
    self:show_title()
end

-- --- Paged screens ---

-- pages: a list of page descriptions; render(index) lays out one of them.
function Screen:show_list(pages, render, back)
    self.list = { pages = pages, page = 1, render = render, back = back }
    render(1)
end

function Screen:turn_list_page(delta)
    local list = self.list
    local target = list and list.page + delta
    if target and target >= 1 and target <= #list.pages then
        list.page = target
        list.render(target)
    end
end

-- Minutes: a page of a minutes book, with a heading for each term and the month in the margin.
local MARGIN, PAGE_TOP, PAGE_BOTTOM = 108, 98, 700
local MINUTES_WIDTH = 584 - 30 - MARGIN - 14

function Screen:show_minutes(state, back)
    local c = self:new_canvas()
    local rows = {}
    for _, entry in ipairs(state.minutes or {}) do
        local text = self.engine:choice_text(entry, "minutes", "text") or ""
        rows[#rows + 1] = { mandate = entry.mandate, month = entry.month, text = text,
            h = c:measure_paragraph(text, SERIF, 18, MINUTES_WIDTH) + 18 }
    end
    c:free()
    -- Each page starts with the heading of its term, and a new term opens a heading of its own.
    local pages, page, y, mandate = {}, {}, PAGE_TOP, nil
    for _, row in ipairs(rows) do
        local heading = row.mandate ~= mandate or #page == 0
        local need = row.h + (heading and 48 or 0)
        if #page > 0 and y + need > PAGE_BOTTOM - 8 then
            pages[#pages + 1] = page
            page, y, heading = {}, PAGE_TOP, true
            need = row.h + 48
        end
        page[#page + 1] = { row = row, heading = heading }
        y, mandate = y + need, row.mandate
    end
    if #page > 0 or #pages == 0 then
        pages[#pages + 1] = page
    end
    self:show_list(pages, function(index) self:layout_minutes(pages[index], back) end, back)
end

function Screen:layout_minutes(page, back)
    local c = self:new_canvas()
    local top = self:header(c, self.strings.minutes_title, self.strings.minutes_summary, back)
    c:box(16, PAGE_TOP, 584, PAGE_BOTTOM, { fill = WHITE, border = BLACK, width = 2, radius = 6 })
    if #page == 0 then
        c:paragraph(40, top + 60, 520, self.strings.minutes_empty, SERIF_ITALIC, 18, { color = DARK })
    end
    local y, margin_top, last_month = PAGE_TOP, nil, nil
    for _, item in ipairs(page) do
        local row = item.row
        if item.heading then
            if margin_top then
                c:line(MARGIN, margin_top, MARGIN, y - 4, MID, 1.5)
            end
            c:box(18, y + 2, 582, y + 34, { fill = PAPER, radius = 4 })
            c:text(32, y + 18, string.format(self.strings.term_heading, row.mandate), SANS_BOLD, 14,
                { middle = true, color = DARK, room = 540, name = "term heading" })
            c:line(16, y + 36, 584, y + 36, MID, 1)
            y = y + 48
            margin_top, last_month = y - 12, nil
        end
        if row.month ~= last_month then
            c:text(MARGIN - 12, y + 2, string.format(self.strings.month_short, row.month), SANS_BOLD, 14,
                { anchor = "right", color = DARK, room = MARGIN - 24, name = "month" })
            last_month = row.month
        end
        local bottom = c:paragraph(MARGIN + 14, y, MINUTES_WIDTH, row.text, SERIF, 18, { align = "left" })
        c:line(MARGIN + 8, bottom + 8, 570, bottom + 8, PALE, 1)
        y = bottom + 18
    end
    if margin_top then
        c:line(MARGIN, margin_top, MARGIN, PAGE_BOTTOM, MID, 1.5)
    end
    self:pager(c, 716)
    self:present(c, "list")
end

-- Gallery: the endings as a collection, found ones first, the rest as locked tiles.
function Screen:show_gallery(page)
    local found, locked = {}, {}
    for _, ending in ipairs(self.engine.content.endings) do
        if self.stats.endings[ending.id] then
            found[#found + 1] = ending
        elseif ending.trigger ~= "no_cards" then
            locked[#locked + 1] = ending
        end
    end
    local tiles = {}
    for _, ending in ipairs(found) do tiles[#tiles + 1] = { ending = ending, found = true } end
    for _, ending in ipairs(locked) do tiles[#tiles + 1] = { ending = ending } end
    local pages = {}
    for i = 1, math.max(1, math.ceil(#tiles / GALLERY_TILES)) do
        pages[i] = i
    end
    local back = function() self:show_title() end
    self.list = { pages = pages, page = clamp(page or 1, 1, #pages), back = back }
    self.list.render = function(index) self:layout_gallery(tiles, found, index) end
    self.list.render(self.list.page)
end

function Screen:layout_gallery(tiles, found, index)
    local c = self:new_canvas()
    local top = self:header(c, self.strings.gallery_title, nil, self.list.back)
    local total = #tiles
    c:text(16, top + 16, string.format(self.strings.gallery_progress, #found, total), SANS_BOLD, 16,
        { room = 250, name = "gallery progress" })
    local record = self.stats.best_mandates == 1 and self.strings.record_one
        or string.format(self.strings.record_many, self.stats.best_mandates)
    local records = self.stats.games == 1 and string.format(self.strings.gallery_records_one, record)
        or string.format(self.strings.gallery_records_many, self.stats.games, record)
    c:text(584, top + 18, records, SANS, 14, { anchor = "right", color = DARK, room = 310, name = "gallery records" })
    c:box(16, top + 46, 584, top + 58, { fill = WHITE, border = BLACK, width = 1.5, radius = 6 })
    if #found > 0 then
        c:box(16, top + 46, 16 + 568 * #found / math.max(1, total), top + 58, { fill = DARK, radius = 6 })
    end
    local gap, columns = 10, 3
    local tw, th = (568 - (columns - 1) * gap) / columns, 116
    local first = (index - 1) * GALLERY_TILES
    for i = 1, GALLERY_TILES do
        local tile = tiles[first + i]
        if not tile then break end
        local x = 16 + ((i - 1) % columns) * (tw + gap)
        local y = top + 76 + math.floor((i - 1) / columns) * (th + gap)
        local ending = tile.ending
        if tile.found then
            c:box(x, y, x + tw, y + th, { fill = WHITE, border = BLACK, width = 2.5, radius = 12 })
            c:image(self:ending_icon(ending), x + 12, y + 14, 40, 40, { alpha = true })
            c:paragraph(x + 62, y + 14, tw - 72, ending.title, SERIF_BOLD, 15, { align = "left", room = 68, name = "gallery tile" })
            local count = self.stats.endings[ending.id]
            c:text(x + 12, y + th - 26, count == 1 and self.strings.seen_once or string.format(self.strings.seen_many, count),
                SANS, 12, { color = MID, room = tw - 70, name = "gallery tile" })
            if ending.id == self.stats.newest_ending then
                c:box(x + tw - 52, y + th - 30, x + tw - 10, y + th - 10, { fill = BLACK, radius = 10 })
                c:text(x + tw - 31, y + th - 20, self.strings.new_badge, SANS_BOLD, 11,
                    { anchor = "center", middle = true, color = WHITE, room = 40, name = "new badge" })
            end
            local position = first + i
            c:hit(x, y, x + tw, y + th, function() self:show_gallery_ending(found, position, index) end)
        else
            c:box(x, y, x + tw, y + th, { fill = PAPER, border = LIGHT, width = 1.5, radius = 12 })
            c:image(self:ending_icon(ending), x + tw / 2 - 18, y + 26, 36, 36, { alpha = true })
            c:text(x + tw / 2, y + th - 26, self.strings.undiscovered, SANS, 12,
                { anchor = "center", color = MID, room = tw - 16, name = "gallery tile" })
        end
    end
    self:pager(c, 716)
    self:present(c, "list")
end

-- One ending found, with its text; the pager goes through the endings found.
function Screen:show_gallery_ending(found, position, gallery_page)
    local pages = {}
    for i = 1, #found do pages[i] = i end
    local back = function() self:show_gallery(gallery_page) end
    self.list = { pages = pages, page = position, back = back }
    self.list.render = function(index)
        local ending = found[index]
        local c = self:new_canvas()
        self:header(c, self.strings.gallery_title, nil, back)
        c:box(16, 80, 584, 700, { fill = WHITE, border = BLACK, width = 3, radius = 18 })
        c:image(self:asset(self:ending_good(ending) and "building.png" or "building_damaged.png"), 236, 100, 128, 158)
        c:text(300, 274, ending.title, SERIF_BOLD, 28, { anchor = "center", room = 540, name = "ending title" })
        local count = self.stats.endings[ending.id] or 1
        c:text(300, 316, count == 1 and self.strings.seen_once or string.format(self.strings.seen_many, count), SANS, 14,
            { anchor = "center", color = MID, room = 540, name = "ending seen" })
        c:paragraph(40, 352, 520, ending.text, SERIF, 19, { room = 332, name = "gallery ending " .. ending.id })
        self:pager(c, 716)
        self:present(c, "list")
    end
    self.list.render(position)
end

-- How to play: numbered steps, with an example where the help item asks for one.
function Screen:show_help()
    local c = self:new_canvas()
    local items = self.engine.content.help
    local heights = {}
    for i, item in ipairs(items) do
        local h = 36 + c:measure_paragraph(item.text, SERIF, 17, 508) + 26
        if item.figure == "answers" then h = h + 64 elseif item.figure == "meters" then h = h + 72 end
        heights[i] = h
    end
    c:free()
    local pages, page, y = {}, {}, 84 + 22
    for i, h in ipairs(heights) do
        if #page > 0 and y + h > 704 then
            pages[#pages + 1] = page
            page, y = {}, 84 + 22
        end
        page[#page + 1] = i
        y = y + h
    end
    pages[#pages + 1] = page
    local back = function() self:show_title() end
    self:show_list(pages, function(index) self:layout_help(pages[index], back) end, back)
end

function Screen:layout_help(page, back)
    local c = self:new_canvas()
    local y = self:header(c, self.strings.help, nil, back) + 22
    for _, i in ipairs(page) do
        local item = self.engine.content.help[i]
        c:box(16, y, 60, y + 44, { fill = BLACK, radius = 22 })
        c:text(38, y + 22, tostring(i), SANS_BOLD, 20, { anchor = "center", middle = true, color = WHITE })
        c:text(76, y + 2, item.title, SERIF_BOLD, 21, { room = 508, name = "help title" })
        local bottom = c:paragraph(76, y + 36, 508, item.text, SERIF, 17, { align = "left", color = DARK })
        if item.figure == "answers" then
            local half = (508 - 12) / 2
            local card = self.engine.content.by_id.neide_clothesline or self.engine.content.cards[1]
            self:button(c, 76, bottom + 10, 76 + half, bottom + 56, "‹ " .. sentence_case(card.left.label), nil,
                { size = 15, sample = true, name = "help example" })
            self:button(c, 584 - half, bottom + 10, 584, bottom + 56, sentence_case(card.right.label) .. " ›", nil,
                { size = 15, sample = true, name = "help example" })
            bottom = bottom + 64
        elseif item.figure == "meters" then
            local cell = 508 / #Engine.METERS
            for m, key in ipairs(Engine.METERS) do
                local cx = 76 + (m - 1) * cell
                c:image(self:asset("icons/" .. key .. ".svg"), cx, bottom + 10, 34, 34, { alpha = true })
                c:text(cx + 17, bottom + 50, self.strings["meter_" .. key], SANS, 12,
                    { anchor = "center", color = DARK, room = cell, name = "help meter" })
            end
            bottom = bottom + 72
        end
        y = bottom + 26
    end
    self:pager(c, 716)
    self:present(c, "list")
end

local function bare_url(url)
    return (url:gsub("^https?://", ""):gsub("/$", ""))
end

function Screen:show_about()
    local back = function() self:show_title() end
    self:show_list({ 1 }, function() self:layout_about(back) end, back)
end

function Screen:layout_about(back)
    local meta = self.engine.content.meta
    local c = self:new_canvas()
    local top = self:header(c, self.strings.about_title, nil, back)
    c:image(self:asset("icon.png"), 252, top + 20, 96, 96)
    c:text(300, top + 128, meta.fullname, SERIF_BOLD, 30, { anchor = "center" })
    c:text(300, top + 172, string.format(self.strings.about_line, meta.version, meta.author), SANS, 15,
        { anchor = "center", color = DARK, room = 560, name = "about line" })
    c:text(300, top + 196, bare_url(meta.website), SANS, 15, { anchor = "center", color = DARK, room = 560, name = "about line" })
    local items = {
        { self.strings.source_code, bare_url(meta.homepage) },
        { self.strings.licenses, self.strings.licenses_text },
        { self.strings.no_warranty, self.strings.no_warranty_text },
    }
    local y = top + 236
    for _, item in ipairs(items) do
        local h = 50 + c:measure_paragraph(item[2], SERIF, 16, 528)
        c:box(16, y, 584, y + h, { fill = WHITE, border = BLACK, width = 2, radius = 12 })
        c:text(36, y + 12, item[1], SERIF_BOLD, 17, { room = 528, name = "about heading" })
        c:paragraph(36, y + 40, 528, item[2], SERIF, 16, { align = "left", color = DARK })
        y = y + h + 12
    end
    if y > STATUS_TOP then
        c:problem("about screen taller than its room")
    end
    self:present(c, "list")
end

-- Settings: where the result of a choice shows, the status strip and the language.
function Screen:show_settings()
    local c = self:new_canvas()
    local top = self:header(c, self.strings.settings, nil, function() self:show_title() end)
    c:text(16, top + 18, self.strings.after_choice, SERIF_BOLD, 21, { room = 568, name = "settings heading" })
    c:text(16, top + 50, self.strings.after_choice_hint, SANS, 14, { color = DARK, room = 568, name = "settings hint" })
    local half = (Canvas.UNITS_W - 32 - 14) / 2
    local options = {
        { "highlight", self.strings.style_highlight, self.strings.style_highlight_text },
        { "note", self.strings.style_note, self.strings.style_note_text },
    }
    local y = top + 80
    for i, option in ipairs(options) do
        local x = 16 + (i - 1) * (half + 14)
        local selected = self.result_style == option[1]
        c:box(x, y, x + half, y + 334, { fill = WHITE, border = selected and BLACK or LIGHT, width = selected and 4 or 1.5, radius = 14 })
        self:style_sketch(c, option[1], x + half / 2 - 75, y + 16)
        c:text(x + 18, y + 232, option[2], SANS_BOLD, 17, { room = half - 66, name = "settings option" })
        c:paragraph(x + 18, y + 262, half - 36, option[3], SANS, 14, { align = "left", color = DARK, room = 64, name = "settings option" })
        c:box(x + half - 40, y + 230, x + half - 16, y + 254, { fill = WHITE, border = BLACK, width = 2, radius = 12 })
        if selected then
            c:box(x + half - 34, y + 236, x + half - 22, y + 248, { fill = BLACK, radius = 6 })
        end
        c:hit(x, y, x + half, y + 334, function()
            self.result_style = option[1]
            self:save_options()
            self:show_settings()
        end)
    end
    y = y + 354
    c:line(16, y, 584, y, LIGHT, 1)
    c:text(16, y + 20, self.strings.status_setting, SANS_BOLD, 17, { room = 480, name = "settings row" })
    c:text(16, y + 46, self.strings.status_setting_hint, SANS, 14, { color = DARK, room = 480, name = "settings row" })
    c:box(518, y + 20, 584, y + 56, { fill = self.show_status and BLACK or WHITE, border = BLACK, width = 2, radius = 18 })
    local knob = self.show_status and 550 or 522
    c:box(knob, y + 24, knob + 30, y + 52, { fill = self.show_status and WHITE or BLACK, radius = 14 })
    c:hit(16, y + 8, 584, y + 72, function()
        self.show_status = not self.show_status
        self:save_options()
        self:show_settings()
    end)
    c:line(16, y + 78, 584, y + 78, LIGHT, 1)
    c:text(16, y + 96, self.strings.language_setting, SANS_BOLD, 17, { room = 568, name = "settings row" })
    c:text(16, y + 122, self.strings.language_value, SANS, 14, { color = DARK, room = 568, name = "settings row" })
    self:present(c, "settings")
end

-- A small drawing of a result style, without text, so it reads in any language.
function Screen:style_sketch(c, style, x, y)
    local w, h = 150, 200
    c:box(x, y, x + w, y + h, { fill = WHITE, border = MID, width = 1, radius = 4 })
    for i = 0, 3 do
        local cx = x + 8 + i * 34
        c:box(cx, y + 8, cx + 8, y + 16, { fill = BLACK, radius = 4 })
        c:box(cx + 10, y + 10, cx + 30, y + 15, { border = BLACK, width = 1, radius = 2 })
    end
    c:line(x + 6, y + 22, x + w - 6, y + 22, BLACK, 1)
    if style == "highlight" then
        c:box(x + 8, y + 28, x + w - 8, y + 66, { border = MID, width = 1, radius = 4 })
        c:box(x + 14, y + 33, x + 42, y + 61, { fill = PALE })
        for l = 0, 2 do c:line(x + 48, y + 38 + l * 8, x + w - 14, y + 38 + l * 8, MID, 1.5) end
        c:box(x + 40, y + 72, x + w - 40, y + 82, { fill = BLACK, radius = 5 })
        c:box(x + 8, y + 88, x + w - 8, y + 144, { fill = PAPER, border = BLACK, width = 1.5, radius = 5 })
        for l = 0, 1 do c:line(x + 22, y + 104 + l * 14, x + w - 22, y + 104 + l * 14, BLACK, 4) end
        c:box(x + 8, y + 152, x + w - 8, y + 172, { fill = BLACK, radius = 4 })
    else
        c:box(x + 8, y + 28, x + w - 8, y + 66, { fill = PAPER, border = BLACK, width = 1, radius = 4 })
        c:box(x + 14, y + 33, x + 38, y + 57, { fill = PALE })
        for l = 0, 2 do c:line(x + 46, y + 38 + l * 8, x + w - 14, y + 38 + l * 8, BLACK, 1.5) end
        c:box(x + 52, y + 74, x + w - 52, y + 120, { fill = PALE, border = BLACK, width = 1 })
        for l = 0, 2 do c:line(x + 22, y + 130 + l * 8, x + w - 22, y + 130 + l * 8, BLACK, 1.5) end
        c:box(x + 8, y + 158, x + 72, y + 176, { border = BLACK, width = 1.5, radius = 4 })
        c:box(x + 78, y + 158, x + w - 8, y + 176, { border = BLACK, width = 1.5, radius = 4 })
    end
    c:line(x + 6, y + h - 14, x + w - 6, y + h - 14, LIGHT, 1)
end

-- --- Input ---

function Screen:onTap(_, ges)
    self:update_status()
    local action = self.canvas and self.canvas:action_at(ges.pos.x - self.dimen.x, ges.pos.y - self.dimen.y)
    if action then
        action()
    end
    return true
end

function Screen:onSwipe(_, ges)
    self:update_status()
    local west, east = ges.direction == "west", ges.direction == "east"
    if not (west or east) then
        return false
    end
    if self.mode == "card" then
        self:decide(west and "left" or "right")
    elseif self.mode == "result" then
        self:next_card()
    elseif self.mode == "list" then
        self:turn_list_page(west and 1 or -1)
    else
        return false
    end
    return true
end

function Screen:close_game()
    UIManager:close(self)
end

-- The Back key of devices with keys goes back one screen, and closes the game from the home screen.
function Screen:onBack()
    if self.mode == "card" or self.mode == "settings" or self.mode == "confirm" then
        self:show_title()
    elseif self.mode == "result" then
        self:next_card()
    elseif self.mode == "list" then
        self.list.back()
    elseif self.mode == "ending" then
        self:leave_ending()
    else
        self:close_game()
    end
    return true
end

-- KOReader sends Close to every window before it quits (USB mode on a Kobo, closing the window on a computer).
function Screen:onClose(arg)
    if not (arg and arg.keep_screensaver) then
        self:close_game()
    end
end

function Screen:onResume()
    self.refresh:reset()
end

Screen.onSetRotationMode = Portrait.ignore_rotation

function Screen:onCloseWidget()
    if self.canvas then
        self.canvas:free()
    end
    if self.status_canvas then
        self.status_canvas:free()
    end
    Portrait.close(self)
    UIManager:setDirty(nil, "full")
end

return Screen
