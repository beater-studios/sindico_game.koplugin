-- Checks every screen in a desktop KOReader without a window, at the size given by run_headless.sh: card and
-- ending texts measured with the screen fonts, 40 games played through the screen, the About version, a game
-- resumed in a new screen, the refresh modes, the Back key and saves of earlier versions. With OUTPUT_DIR, it
-- saves screenshots there. Usage: tools/koreader/check_all_sizes.sh
local plugin_dir = assert(os.getenv("PLUGIN_DIR"))
local out_dir = assert(os.getenv("OUTPUT_DIR"))

require("setupkoenv")
local DataStorage = require("datastorage")
G_defaults = require("luadefaults"):open()
G_reader_settings = require("luasettings"):open(DataStorage:getDataDir() .. "/settings.reader.lua")
G_reader_settings:saveSetting("language", "pt_BR")
package.path = plugin_dir .. "/?.lua;" .. package.path

local Device = require("device")
local Screen = Device.screen
require("document/canvascontext"):init(Device)
local UIManager = require("ui/uimanager")
UIManager:init()
local Blitbuffer = require("ffi/blitbuffer")
local Font = require("ui/font")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local Content = require("sindico_game/content")
local GameScreen = require("sindico_game/ui/screen")

local W = Screen:getWidth()
local margin = Screen:scaleBySize(20)
local text_width = W - 2 * margin
local half = math.floor((text_width - Screen:scaleBySize(10)) / 2)
local content = Content.load(plugin_dir)

local function box_height(text, face, size, width)
    local w = TextBoxWidget:new{ text = text, face = Font:getFace(face, size), width = width, alignment = "center" }
    local h = w:getSize().h
    w:free()
    return h
end
local function line_width(text, size)
    local w = TextWidget:new{ text = text, face = Font:getFace("cfont", size), bold = true }
    local width = w:getSize().w
    w:free()
    return width
end

local problems, max_text, max_label, longest_card = 0, 0, 0, nil
for _, card in ipairs(content.cards) do
    local h = box_height(card.text, "noto/NotoSerif-Regular.ttf", 24, text_width)
    if h > max_text then max_text = h; longest_card = card end
    if h > Screen:scaleBySize(218) then
        problems = problems + 1
        print("PROBLEM: card text does not fit: " .. card.id .. " " .. h)
    end
    for _, side in ipairs({ "left", "right" }) do
        local c = card[side]
        local lw = line_width("‹ " .. c.label, 19)
        if lw > max_label then max_label = lw end
        if lw > half - Screen:scaleBySize(16) then
            problems = problems + 1
            print("PROBLEM: choice label does not fit: " .. card.id .. " " .. c.label .. " " .. lw)
        end
        local rh = box_height(c.result, "noto/NotoSerif-Italic.ttf", 16, text_width)
        if rh > Screen:scaleBySize(50) then
            problems = problems + 1
            print("PROBLEM: choice result does not fit: " .. card.id .. " " .. c.result .. " " .. rh)
        end
    end
    local f = io.open(plugin_dir .. "/assets/portraits/" .. card.char .. ".png", "rb")
    if f then f:close() else problems = problems + 1; print("PROBLEM: no portrait: " .. card.char) end
end
for _, ending in ipairs(content.endings) do
    local h = box_height(ending.text, "noto/NotoSerif-Regular.ttf", 20, text_width)
    if h > Screen:scaleBySize(230) then
        problems = problems + 1
        print("PROBLEM: ending text does not fit: " .. ending.id .. " " .. h)
    end
    local th = box_height(ending.title, "noto/NotoSerif-Bold.ttf", 26, text_width)
    if th > Screen:scaleBySize(70) then
        problems = problems + 1
        print("PROBLEM: ending title too long: " .. ending.id .. " " .. th)
    end
end
print(string.format("%d cards; longest text %dpx (limit %d); longest label %dpx (limit %d); %d problems",
    #content.cards, max_text, Screen:scaleBySize(218), max_label, half - Screen:scaleBySize(16), problems))

local function shot(widget, name)
    Screen.bb:fill(Blitbuffer.COLOR_WHITE)
    widget:paintTo(Screen.bb, 0, 0)
    Screen.bb:writePNG(out_dir .. "/" .. name .. ".png")
end

local function check_height(game, name)
    if game.content_height > Screen:getHeight() then
        problems = problems + 1
        print("PROBLEM: screen taller than the display: " .. name .. " " .. game.content_height)
    end
end

math.randomseed(5)
local game = GameScreen:new{ plugin_dir = plugin_dir }
check_height(game, "title without a game")
shot(game, "title_empty")
local games, decisions = 0, 0
for _ = 1, 40 do
    game:start_game()
    local guard = 0
    while not game.engine.state.ending and guard < 400 do
        guard = guard + 1
        game:decide(math.random(2) == 1 and "left" or "right")
        decisions = decisions + 1
        if game.mode == "card" then check_height(game, "card") end
        if guard % 7 == 0 then game:paintTo(Screen.bb, 0, 0) end
    end
    if game.engine.state.ending then
        check_height(game, "ending")
        game:paintTo(Screen.bb, 0, 0)
    end
    games = games + 1
end
print(string.format("%d games and %d decisions through the screen, no error", games, decisions))
shot(game, "ending_real")
local ended = game.engine.state
game:show_minutes(ended, function() end)
check_height(game, "minutes")
shot(game, "ata")

game.engine.state = nil
game:show_gallery()
check_height(game, "gallery")
shot(game, "gallery_1")
print("gallery: " .. #game.list.pages .. " pages")
game:turn_list_page(1)
shot(game, "gallery_2")

game:show_help()
check_height(game, "help")
print("help: " .. #game.list.pages .. " pages")
shot(game, "help_1")

game:show_about()
check_height(game, "about")
print("about: " .. #game.list.pages .. " pages")
shot(game, "about")
local about_version = game.list.pages[1][1].meta
if not about_version:find(game.engine.content.meta.version, 1, true) then
    problems = problems + 1
    print("PROBLEM: version missing on the About screen")
end

game:start_game()
game.engine.state.current = longest_card.id
game:show_card()
shot(game, "longest_card")
game:decide("right")
shot(game, "after_longest")
local expected_decisions = game.engine.state.decisions

local reopened = GameScreen:new{ plugin_dir = plugin_dir }
check_height(reopened, "title with a game")
shot(reopened, "title_with_game")
if not reopened:has_game() or reopened.engine.state.decisions ~= expected_decisions then
    problems = problems + 1
    print("PROBLEM: progress was not saved")
else
    print("progress saved and reloaded: " .. reopened.engine.state.decisions .. " decisions")
end
reopened:show_card()
shot(reopened, "resumed_card")

local function problem(text)
    problems = problems + 1
    print("PROBLEM: " .. text)
end

-- Refresh modes: a new layout flashes, a change inside it does not, and every ninth update in a row flashes.
local Event = require("ui/event")
local real_set_dirty = UIManager.setDirty
local modes = {}
UIManager.setDirty = function(_, _, refresh)
    modes[#modes + 1] = type(refresh) == "function" and (refresh()) or refresh
end
local function safe_side(screen)
    local card = screen.engine:current_card()
    for _, side in ipairs({ "left", "right" }) do
        local choice = card[side]
        if not choice.ending and not choice.resolve then
            return side
        end
    end
    return "left"
end
local function keep_alive(screen)
    for name in pairs(screen.engine.state.meters) do
        screen.engine.state.meters[name] = 90
    end
end
local paint = GameScreen:new{ plugin_dir = plugin_dir }
paint:start_game()
for _ = 1, 9 do
    keep_alive(paint)
    paint:decide(safe_side(paint))
end
paint:show_minutes(paint.engine.state, function() paint:show_card() end)
paint.list.back()
keep_alive(paint)
paint:decide(safe_side(paint))
local real_choose = paint.engine.choose
paint.engine.choose = function(engine, side)
    local state = real_choose(engine, side)
    state.last.reelected = true
    return state
end
keep_alive(paint)
paint:decide(safe_side(paint))
paint.engine.choose = nil
paint:show_title()
paint:show_card()
keep_alive(paint)
paint:decide(safe_side(paint))
paint:handleEvent(Event:new("Resume"))
keep_alive(paint)
paint:decide(safe_side(paint))
UIManager.setDirty = real_set_dirty
-- title, card, 8 changes and a flash, minutes, back to the card, a change, a reelection, title, card, a change,
-- and the first change after waking up.
local expected = "full,full,ui,ui,ui,ui,ui,ui,ui,ui,full,full,full,ui,full,full,full,ui,full"
if table.concat(modes, ",") ~= expected then
    problem("refresh modes " .. table.concat(modes, ",") .. ", expected " .. expected)
else
    print("refresh modes: " .. table.concat(modes, ","))
end

-- The Back key goes back one screen and closes the game from the title; Close from KOReader closes it.
local back = GameScreen:new{ plugin_dir = plugin_dir }
UIManager:show(back)
if Device:hasKeys() and not back.key_events.Back then
    problem("no Back key")
end
back:start_game()
back:handleEvent(Event:new("Back"))
if back.mode ~= "title" then problem("Back on a card did not go to the title: " .. tostring(back.mode)) end
back:show_help()
back:handleEvent(Event:new("Back"))
if back.mode ~= "title" then problem("Back on the help did not go to the title: " .. tostring(back.mode)) end
back:show_card()
back:show_minutes(back.engine.state, function() back:show_card() end)
back:handleEvent(Event:new("Back"))
if back.mode ~= "card" then problem("Back on the minutes did not go back to the card: " .. tostring(back.mode)) end
back:show_card()
back.engine.state.meters.funds = 1
back.engine.state.meters.residents = 1
for _ = 1, 50 do
    if back.engine.state.ending then break end
    back:decide("left")
end
back:handleEvent(Event:new("Back"))
if back.mode ~= "title" or back:has_game() then problem("Back on an ending did not go to the title: " .. tostring(back.mode)) end
back:handleEvent(Event:new("Back"))
if UIManager:isWidgetShown(back) then problem("Back on the title did not close the game") end
local closing = GameScreen:new{ plugin_dir = plugin_dir }
UIManager:show(closing)
closing:handleEvent(Event:new("Close", { keep_screensaver = true }))
if not UIManager:isWidgetShown(closing) then problem("Close with keep_screensaver closed the game") end
closing:handleEvent(Event:new("Close"))
if UIManager:isWidgetShown(closing) then problem("Close did not close the game") end
UIManager:forceRePaint()

-- Saves written by earlier versions open through the screen, and a damaged one is dropped without the records.
local settings_path = GameScreen:settings_path()
local function install_save(text)
    os.remove(settings_path .. ".old")
    local f = assert(io.open(settings_path, "wb"))
    f:write(text)
    f:close()
end
local saves = io.popen('ls "' .. plugin_dir .. '/tests/saves/"*.lua 2>/dev/null')
for path in saves:lines() do
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    install_save(text)
    local data = dofile(path)
    local old = GameScreen:new{ plugin_dir = plugin_dir }
    if data.game and not (old:has_game() and old.engine.state.decisions == data.game.decisions) then
        problem("old save without its game: " .. path)
    end
    if old.stats.games ~= data.stats.games then
        problem("old save without its records: " .. path)
    end
    check_height(old, "title with an old save")
    old:show_card()
    old:decide("left")
    old:show_gallery()
    print("old save opened: " .. path:match("[^/]+$"))
end
saves:close()
install_save('return { ["game"] = { ["meters"] = 5, ["day"] = 12, ["mandate"] = 1 }, ["stats"] = { ["games"] = 7, ["endings"] = {} } }')
local damaged = GameScreen:new{ plugin_dir = plugin_dir }
if damaged:has_game() or damaged.stats.games ~= 7 then
    problem("damaged save: the game should be dropped and the records kept")
end
shot(damaged, "title_damaged_save")

print("problems: " .. problems)
os.exit(problems == 0 and 0 or 1)
