local bit = require("bit")
local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ImageWidget = require("ui/widget/imagewidget")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local LuaSettings = require("luasettings")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local Content = require("sindico_game/content")
local Engine = require("sindico_game/engine")
local MeterBar = require("sindico_game/ui/meter_bar")
local title_case = require("sindico_game/ui/title_case")

local Device_screen = Device.screen

local SERIF = "noto/NotoSerif-Regular.ttf"
local SERIF_ITALIC = "noto/NotoSerif-Italic.ttf"
local SERIF_BOLD = "noto/NotoSerif-Bold.ttf"
local FULL_REFRESH_EVERY = 10
local STRONG_DELTA = 10

local METER_LABELS = {
    residents = "Moradores",
    funds = "Caixa",
    building = "Prédio",
    patience = "Paciência",
}

local Screen = InputContainer:extend{
    name = "sindico_game_screen",
    covers_fullscreen = true,
    stop_events_propagation = true,
    plugin_dir = ".",
}

function Screen:init()
    -- The layout only fits portrait; odd rotation modes are landscape.
    local rotation = Device_screen:getRotationMode()
    if bit.band(rotation, 1) == 1 then
        self.restore_rotation = rotation
        Device_screen:setRotationMode(Device_screen.DEVICE_ROTATED_UPRIGHT)
    end
    self.dimen = Geom:new{ x = 0, y = 0, w = Device_screen:getWidth(), h = Device_screen:getHeight() }
    self.width, self.height = self.dimen.w, self.dimen.h
    self.margin = Device_screen:scaleBySize(20)
    self.text_width = self.width - 2 * self.margin
    self.settings = LuaSettings:open(DataStorage:getSettingsDir() .. "/sindico_game.lua")
    self.stats = self.settings:readSetting("stats") or Engine.new_stats()
    self.engine = Engine.new({ content = Content.load(self.plugin_dir) })
    local saved = self.settings:readSetting("game")
    if saved and not saved.ending then
        self.engine:load(saved)
    end
    self.ges_events = {
        Swipe = { GestureRange:new{ ges = "swipe", range = self.dimen } },
    }
    self:show_title()
end

function Screen:scaled(value)
    return Device_screen:scaleBySize(value)
end

function Screen:set_content(widget, refresh)
    if self[1] then
        self[1]:free()
    end
    self.content_height = widget:getSize().h
    self[1] = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        padding = 0,
        margin = 0,
        width = self.width,
        height = self.height,
        widget,
    }
    UIManager:setDirty(self, function()
        return refresh or "ui", self.dimen
    end)
end

function Screen:text_line(text, face, size, bold)
    return TextWidget:new{
        text = text,
        face = Font:getFace(face or "cfont", size or 18),
        bold = bold,
        max_width = self.text_width,
    }
end

function Screen:centered(widget, height)
    return CenterContainer:new{
        dimen = Geom:new{ w = self.width, h = height or widget:getSize().h },
        widget,
    }
end

function Screen:menu_button(text, callback)
    return Button:new{
        text = text,
        width = self.width - 2 * self:scaled(90),
        padding_v = self:scaled(10),
        radius = self:scaled(8),
        bordersize = self:scaled(2),
        text_font_face = "cfont",
        text_font_size = 20,
        callback = callback,
    }
end

function Screen:has_game()
    local s = self.engine.state
    return s and not s.ending and s.current ~= nil
end

function Screen:show_title()
    self.mode = "title"
    local buttons = {}
    if self:has_game() then
        local s = self.engine.state
        buttons[#buttons + 1] = self:menu_button(
            string.format("Continuar (Mandato %d, Mês %d)", s.mandate, self.engine:month()),
            function() self:show_card("full") end)
    end
    buttons[#buttons + 1] = self:menu_button("Novo Jogo", function() self:confirm_new_game() end)
    buttons[#buttons + 1] = self:menu_button("Galeria de Finais", function() self:show_gallery() end)
    buttons[#buttons + 1] = self:menu_button("Como Jogar", function() self:show_help() end)
    buttons[#buttons + 1] = self:menu_button("Sobre", function() self:show_about() end)
    buttons[#buttons + 1] = self:menu_button("Sair", function() self:close_game() end)

    local title = self:centered(self:text_line("O Síndico", SERIF_BOLD, 40))
    local subtitle = self:centered(self:text_line("Edifício Primavera", SERIF_ITALIC, 20))
    local top, gap, button_gap, bottom = self:scaled(20), self:scaled(10), self:scaled(8), self:scaled(16)
    local used = top + gap + title:getSize().h + subtitle:getSize().h + gap + bottom
    for _, button in ipairs(buttons) do
        used = used + button:getSize().h + button_gap
    end
    local image_h = self.height - used

    local group = VerticalGroup:new{ align = "center" }
    group[#group + 1] = VerticalSpan:new{ width = top }
    group[#group + 1] = self:centered(ImageWidget:new{
        file = self.plugin_dir .. "/assets/building.png",
        width = math.floor(image_h * 420 / 520),
        height = image_h,
    })
    group[#group + 1] = VerticalSpan:new{ width = gap }
    group[#group + 1] = title
    group[#group + 1] = subtitle
    group[#group + 1] = VerticalSpan:new{ width = gap }
    for _, button in ipairs(buttons) do
        group[#group + 1] = self:centered(button)
        group[#group + 1] = VerticalSpan:new{ width = button_gap }
    end
    self:set_content(group, "full")
end

function Screen:confirm_new_game()
    if not self:has_game() then
        return self:start_game()
    end
    UIManager:show(ConfirmBox:new{
        text = "Começar de novo? O mandato em andamento será perdido.",
        ok_text = "Começar",
        cancel_text = "Voltar",
        ok_callback = function() self:start_game() end,
    })
end

function Screen:start_game()
    self.engine:new_game()
    self:save_game()
    self:show_card("full")
end

function Screen:save_game()
    self.settings:saveSetting("game", self.engine:serialize())
    self.settings:saveSetting("stats", self.stats)
    self.settings:flush()
end

function Screen:svg_icon(name, size)
    return ImageWidget:new{
        file = self.plugin_dir .. "/assets/icons/" .. name .. ".svg",
        width = size,
        height = size,
        alpha = true,
    }
end

function Screen:meter_label(name, delta)
    local row = HorizontalGroup:new{
        align = "center",
        TextWidget:new{
            text = METER_LABELS[name],
            face = Font:getFace("cfont", 12),
            bold = delta ~= 0,
        },
    }
    if delta ~= 0 then
        local arrow = delta > 0 and "arrow_up" or "arrow_down"
        local size = self:scaled(13)
        row[#row + 1] = HorizontalSpan:new{ width = self:scaled(3) }
        row[#row + 1] = self:svg_icon(arrow, size)
        if math.abs(delta) >= STRONG_DELTA then
            row[#row + 1] = self:svg_icon(arrow, size)
        end
    end
    return row
end

function Screen:meters_row()
    local s = self.engine.state
    local deltas = s.last and s.last.deltas or {}
    local column = math.floor(self.text_width / #Engine.METERS)
    local icon_size = self:scaled(34)
    local row = HorizontalGroup:new{ align = "center" }
    for _, name in ipairs(Engine.METERS) do
        local cell = HorizontalGroup:new{
            align = "center",
            self:svg_icon(name, icon_size),
            HorizontalSpan:new{ width = self:scaled(4) },
            VerticalGroup:new{
                align = "left",
                self:meter_label(name, deltas[name] or 0),
                VerticalSpan:new{ width = self:scaled(3) },
                MeterBar:new{
                    value = s.meters[name],
                    width = column - icon_size - self:scaled(12),
                    height = self:scaled(13),
                },
            },
        }
        row[#row + 1] = LeftContainer:new{
            dimen = Geom:new{ w = column, h = icon_size + self:scaled(4) },
            cell,
        }
    end
    return self:centered(row)
end

function Screen:footer_button(text, callback)
    return Button:new{
        text = text,
        width = self:scaled(76),
        bordersize = self:scaled(2),
        radius = self:scaled(6),
        padding_v = self:scaled(3),
        text_font_face = "cfont",
        text_font_size = 15,
        callback = callback,
    }
end

function Screen:show_card(refresh)
    self.mode = "card"
    local s = self.engine.state
    local card = self.engine:current_card()
    if not card then
        return self:show_ending()
    end
    local character = self.engine.content.characters[card.char] or { name = "", role = "" }
    local group = VerticalGroup:new{ align = "center" }

    group[#group + 1] = VerticalSpan:new{ width = self:scaled(10) }
    group[#group + 1] = self:meters_row()
    group[#group + 1] = VerticalSpan:new{ width = self:scaled(6) }
    group[#group + 1] = self:centered(LineWidget:new{
        dimen = Geom:new{ w = self.text_width, h = self:scaled(2) },
        background = Blitbuffer.COLOR_BLACK,
    })

    local result = s.last and s.last.result or "Primeiro dia de mandato. O interfone já tocou."
    if s.last and s.last.reelected then
        result = string.format("Reeleito! Começa o mandato %d. %s", s.mandate, result or "")
    end
    group[#group + 1] = self:centered(TextBoxWidget:new{
        text = result,
        face = Font:getFace(SERIF_ITALIC, 16),
        width = self.text_width,
        height = self:scaled(50),
        alignment = "center",
        height_overflow_show_ellipsis = true,
    })

    local portrait = self:scaled(250)
    group[#group + 1] = self:centered(ImageWidget:new{
        file = self.plugin_dir .. "/assets/portraits/" .. card.char .. ".png",
        width = portrait,
        height = portrait,
    })
    group[#group + 1] = VerticalSpan:new{ width = self:scaled(6) }
    group[#group + 1] = self:centered(self:text_line(character.name, SERIF_BOLD, 22))
    group[#group + 1] = self:centered(self:text_line(character.role, SERIF_ITALIC, 15))
    group[#group + 1] = VerticalSpan:new{ width = self:scaled(8) }

    group[#group + 1] = self:centered(TextBoxWidget:new{
        text = card.text,
        face = Font:getFace(SERIF, 24),
        width = self.text_width,
        height = self:scaled(218),
        alignment = "center",
        height_overflow_show_ellipsis = true,
    })

    local half = math.floor((self.text_width - self:scaled(10)) / 2)
    local function choice_button(side, label)
        return Button:new{
            text = label,
            width = half,
            padding_v = self:scaled(12),
            radius = self:scaled(8),
            bordersize = self:scaled(3),
            text_font_face = "cfont",
            text_font_size = 19,
            callback = function() self:decide(side) end,
        }
    end
    group[#group + 1] = self:centered(HorizontalGroup:new{
        choice_button("left", "‹ " .. title_case(card.left.label)),
        HorizontalSpan:new{ width = self:scaled(10) },
        choice_button("right", title_case(card.right.label) .. " ›"),
    })
    group[#group + 1] = VerticalSpan:new{ width = self:scaled(6) }

    local footer_h = self:scaled(36)
    local side_w = self:scaled(76)
    group[#group + 1] = self:centered(HorizontalGroup:new{
        align = "center",
        self:footer_button("Ata", function()
            self:show_minutes(s, function() self:show_card("full") end)
        end),
        CenterContainer:new{
            dimen = Geom:new{ w = self.text_width - 2 * side_w, h = footer_h },
            TextWidget:new{
                text = string.format("Mandato %d, mês %d de %d", s.mandate, self.engine:month(), Engine.MANDATE_MONTHS),
                face = Font:getFace("cfont", 14),
            },
        },
        self:footer_button("Menu", function() self:show_title() end),
    })

    self:set_content(group, refresh)
end

function Screen:decide(side)
    if self.mode ~= "card" or not self:has_game() then return end
    self.engine:choose(side)
    local s = self.engine.state
    if s.ending then
        self.engine:record_ending(self.stats)
        self.settings:delSetting("game")
        self.settings:saveSetting("stats", self.stats)
        self.settings:flush()
        self:show_ending(s)
        return
    end
    self:save_game()
    local refresh = "ui"
    if s.decisions % FULL_REFRESH_EVERY == 0 or (s.last and s.last.reelected) then
        refresh = "full"
    end
    self:show_card(refresh)
end

function Screen:show_ending(state)
    self.mode = "ending"
    local s = state or self.engine.state
    local ending = self.engine.content.ending_by_id[s.ending] or { title = "Fim", text = "" }
    local good = ending.good
    if good == nil then
        good = ending.trigger == nil or ending.trigger == "all_mandates"
    end
    local group = VerticalGroup:new{ align = "center" }
    local image_h = math.floor(self.height * 0.27)
    group[#group + 1] = VerticalSpan:new{ width = self:scaled(18) }
    group[#group + 1] = self:centered(ImageWidget:new{
        file = self.plugin_dir .. (good and "/assets/building.png" or "/assets/building_damaged.png"),
        width = math.floor(image_h * 420 / 520),
        height = image_h,
    })
    group[#group + 1] = VerticalSpan:new{ width = self:scaled(10) }
    group[#group + 1] = self:centered(TextBoxWidget:new{
        text = ending.title,
        face = Font:getFace(SERIF_BOLD, 26),
        width = self.text_width,
        alignment = "center",
    })
    group[#group + 1] = VerticalSpan:new{ width = self:scaled(8) }
    group[#group + 1] = self:centered(TextBoxWidget:new{
        text = ending.text,
        face = Font:getFace(SERIF, 20),
        width = self.text_width,
        height = self:scaled(230),
        alignment = "center",
        height_overflow_show_ellipsis = true,
    })
    local won = Engine.completed_mandates(s)
    group[#group + 1] = self:centered(self:text_line(
        string.format("%d %s completos, %d dias, %d decisões", won, won == 1 and "mandato" or "mandatos",
            Engine.total_days(s), s.decisions), "cfont", 15))
    group[#group + 1] = VerticalSpan:new{ width = self:scaled(12) }
    group[#group + 1] = self:centered(self:menu_button("Ler a Ata", function()
        self:show_minutes(s, function() self:show_ending(s) end)
    end))
    group[#group + 1] = VerticalSpan:new{ width = self:scaled(8) }
    group[#group + 1] = self:centered(self:menu_button("Novo Jogo", function() self:start_game() end))
    group[#group + 1] = VerticalSpan:new{ width = self:scaled(8) }
    group[#group + 1] = self:centered(self:menu_button("Início", function()
        self.engine.state = nil
        self:show_title()
    end))
    self:set_content(group, "full")
end

function Screen:list_item(item)
    local inner_width = self.text_width - 2 * self:scaled(12) - 2 * self:scaled(2)
    local body = VerticalGroup:new{ align = "left" }
    if item.title then
        body[#body + 1] = TextBoxWidget:new{
            text = item.title,
            face = Font:getFace(SERIF_BOLD, 19),
            width = inner_width,
            bgcolor = item.muted and Blitbuffer.COLOR_LIGHT_GRAY or nil,
        }
    end
    if item.meta then
        body[#body + 1] = TextBoxWidget:new{
            text = item.meta,
            face = Font:getFace(SERIF_ITALIC, 14),
            width = inner_width,
        }
    end
    if item.text then
        if #body > 0 then
            body[#body + 1] = VerticalSpan:new{ width = self:scaled(4) }
        end
        body[#body + 1] = TextBoxWidget:new{
            text = item.text,
            face = Font:getFace(SERIF, 17),
            width = inner_width,
            bgcolor = item.muted and Blitbuffer.COLOR_LIGHT_GRAY or nil,
        }
    end
    return FrameContainer:new{
        width = self.text_width,
        padding = self:scaled(12),
        bordersize = self:scaled(2),
        radius = self:scaled(8),
        background = item.muted and Blitbuffer.COLOR_LIGHT_GRAY or Blitbuffer.COLOR_WHITE,
        body,
    }
end

function Screen:list_pages(items, available)
    local gap = self:scaled(10)
    local pages, page, used = {}, {}, 0
    for _, item in ipairs(items) do
        local widget = self:list_item(item)
        local h = widget:getSize().h
        widget:free()
        if #page > 0 and used + gap + h > available then
            pages[#pages + 1] = page
            page, used = {}, 0
        end
        page[#page + 1] = item
        used = used + (used > 0 and gap or 0) + h
    end
    if #page > 0 then
        pages[#pages + 1] = page
    end
    return pages
end

function Screen:show_list(opts)
    local header_h = self:scaled(opts.summary and 86 or 60)
    local footer_h = self:scaled(70)
    self.list = {
        title = opts.title,
        summary = opts.summary,
        back = opts.back,
        pages = self:list_pages(opts.items, self.height - header_h - footer_h - self:scaled(16)),
        page = 1,
        header_h = header_h,
        footer_h = footer_h,
    }
    self:show_list_page("full")
end

function Screen:show_list_page(refresh)
    self.mode = "list"
    local list = self.list
    local group = VerticalGroup:new{ align = "center" }

    local header = VerticalGroup:new{ align = "center" }
    header[#header + 1] = self:text_line(list.title, SERIF_BOLD, 26)
    if list.summary then
        header[#header + 1] = self:text_line(list.summary, SERIF_ITALIC, 15)
    end
    group[#group + 1] = self:centered(header, list.header_h)

    local body = VerticalGroup:new{ align = "center" }
    for i, item in ipairs(list.pages[list.page] or {}) do
        if i > 1 then
            body[#body + 1] = VerticalSpan:new{ width = self:scaled(10) }
        end
        body[#body + 1] = self:list_item(item)
    end
    local body_h = self.height - list.header_h - list.footer_h
    group[#group + 1] = CenterContainer:new{
        dimen = Geom:new{ w = self.width, h = body_h },
        body,
    }

    local total = math.max(1, #list.pages)
    local third = math.floor(self.text_width / 3)
    local function page_button(text, delta)
        return Button:new{
            text = text,
            width = third - self:scaled(6),
            padding_v = self:scaled(10),
            radius = self:scaled(8),
            bordersize = self:scaled(2),
            text_font_face = "cfont",
            text_font_size = 18,
            enabled = list.page + delta >= 1 and list.page + delta <= total,
            callback = function() self:turn_list_page(delta) end,
        }
    end
    group[#group + 1] = self:centered(HorizontalGroup:new{
        align = "center",
        Button:new{
            text = "Voltar",
            width = third - self:scaled(6),
            padding_v = self:scaled(10),
            radius = self:scaled(8),
            bordersize = self:scaled(2),
            text_font_face = "cfont",
            text_font_size = 18,
            callback = function() list.back() end,
        },
        HorizontalSpan:new{ width = self:scaled(9) },
        page_button("‹", -1),
        HorizontalSpan:new{ width = self:scaled(9) },
        page_button("›", 1),
    }, list.footer_h)
    self:set_content(group, refresh)
end

function Screen:turn_list_page(delta)
    local list = self.list
    local target = list.page + delta
    if target >= 1 and target <= #list.pages then
        list.page = target
        self:show_list_page("ui")
    end
end

function Screen:show_help()
    self:show_list{
        title = "Como Jogar",
        items = self.engine.content.help,
        back = function() self:show_title() end,
    }
end

local function bare_url(url)
    return (url:gsub("^https?://", ""):gsub("/$", ""))
end

function Screen:show_about()
    local meta = self.engine.content.meta
    self:show_list{
        title = "Sobre",
        items = {
            {
                title = meta.fullname,
                meta = "Versão " .. meta.version,
                text = string.format("Um jogo da %s.\n%s\n%s", meta.author, bare_url(meta.website), meta.copyright),
            },
            {
                title = "Código-fonte",
                text = bare_url(meta.homepage),
            },
            {
                title = "Licenças",
                text = "Código: GNU GPL, somente a versão 3. Você pode redistribuir e modificar sob esses termos.\nCartas, personagens, história e arte: CC BY-NC-SA 4.0.\nOs textos completos estão em LICENSE, LICENSE-CONTENT e NOTICE, na pasta do plugin.",
            },
            {
                title = "Sem garantia",
                text = "Este jogo é distribuído sem nenhuma garantia.",
            },
        },
        back = function() self:show_title() end,
    }
end

function Screen:show_minutes(state, back)
    local items = {}
    for _, entry in ipairs(state.minutes or {}) do
        items[#items + 1] = {
            meta = string.format("Mandato %d, mês %d", entry.mandate, entry.month),
            text = entry.text,
        }
    end
    if #items == 0 then
        items[1] = { text = "Nada digno de registro até agora. A ata agradece." }
    end
    self:show_list{
        title = "Ata do Condomínio",
        summary = "As decisões que entraram para a história do prédio",
        items = items,
        back = back,
    }
end

function Screen:show_gallery()
    local items, found, total = {}, 0, 0
    for _, ending in ipairs(self.engine.content.endings) do
        local count = self.stats.endings[ending.id]
        if count or ending.trigger ~= "no_cards" then
            total = total + 1
        end
        if count then
            found = found + 1
            items[#items + 1] = {
                title = ending.title,
                meta = count == 1 and "Visto 1 vez" or string.format("Visto %d vezes", count),
                text = ending.text,
            }
        end
    end
    local missing = total - found
    if missing > 0 then
        items[#items + 1] = {
            muted = true,
            text = missing == 1 and "Falta 1 final para descobrir."
                or string.format("Faltam %d finais para descobrir.", missing),
        }
    end
    self:show_list{
        title = "Galeria de Finais",
        summary = string.format("%d de %d finais, %d partidas, recorde de %d %s",
            found, total, self.stats.games, self.stats.best_mandates,
            self.stats.best_mandates == 1 and "mandato" or "mandatos"),
        items = items,
        back = function() self:show_title() end,
    }
end

function Screen:onSwipe(_, ges)
    if self.mode == "card" then
        if ges.direction == "west" then
            self:decide("left")
            return true
        elseif ges.direction == "east" then
            self:decide("right")
            return true
        end
    elseif self.mode == "list" then
        if ges.direction == "west" then
            self:turn_list_page(1)
            return true
        elseif ges.direction == "east" then
            self:turn_list_page(-1)
            return true
        end
    end
    return false
end

function Screen:close_game()
    UIManager:close(self)
end

function Screen:onSetRotationMode()
    return true
end

function Screen:onCloseWidget()
    if self.restore_rotation then
        Device_screen:setRotationMode(self.restore_rotation)
    end
    UIManager:setDirty(nil, "full")
end

return Screen
