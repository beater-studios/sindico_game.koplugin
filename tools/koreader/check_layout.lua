-- Checks every screen in a desktop KOReader without a window, at the size given by run_headless.sh, in the three
-- languages: every card in both result styles and its result, every ending on its screen and in the gallery,
-- and the paged screens. The screens note every text that does not fit its room (ui/canvas.lua), and this
-- script reports them. It also plays games through the screen and checks the About version, a game resumed
-- in a new screen, the refresh modes, the Back key and saves of earlier versions. With OUTPUT_DIR, it saves
-- screenshots there. Usage: tools/koreader/check_all_sizes.sh
local plugin_dir = assert(os.getenv("PLUGIN_DIR"))
local out_dir = assert(os.getenv("OUTPUT_DIR"))

require("setupkoenv")
local DataStorage = require("datastorage")
G_defaults = require("luadefaults"):open()
G_reader_settings = require("luasettings"):open(DataStorage:getDataDir() .. "/settings.reader.lua")
package.path = plugin_dir .. "/?.lua;" .. package.path

local Device = require("device")
Device.hasBattery = function() return true end
Device.getPowerDevice = function() return { getCapacity = function() return 100 end } end
local Screen = Device.screen
require("document/canvascontext"):init(Device)
local UIManager = require("ui/uimanager")
UIManager:init()
local Blitbuffer = require("ffi/blitbuffer")
local Event = require("ui/event")
local GameScreen = require("sindico_game/ui/screen")

local problems = 0
local function problem(text)
    problems = problems + 1
    print("PROBLEM: " .. text)
end

local function shot(game, name)
    Screen.bb:fill(Blitbuffer.COLOR_WHITE)
    game:paintTo(Screen.bb, 0, 0)
    Screen.bb:writePNG(out_dir .. "/" .. name .. ".png")
end

-- The screen fits the display and every text fits its room.
local seen = {}
local function check(game, name)
    if game.content_height > Screen:getHeight() then
        problem("screen taller than the display: " .. name .. " " .. game.content_height)
    end
    for _, text in ipairs(game.layout_problems or {}) do
        local key = name .. "|" .. text
        if not seen[key] then
            seen[key] = true
            problem(name .. ": " .. text)
        end
    end
end

local function set_language(lang)
    G_reader_settings:saveSetting("language", lang == "pt" and "pt_BR" or lang)
end

-- Every minutes line the cards have, as a long minutes book over several terms.
local function every_minutes_line(game)
    local entries = {}
    for _, card in ipairs(game.engine.content.cards) do
        for _, side in ipairs({ "left", "right" }) do
            if card[side].minutes then
                entries[#entries + 1] = { mandate = 1 + math.floor(#entries / 12), month = 1 + #entries % 24, card = card.id, side = side }
            end
        end
    end
    return entries
end

for _, lang in ipairs({ "en", "es", "pt" }) do
    set_language(lang)
    math.randomseed(5)
    local game = GameScreen:new{ plugin_dir = plugin_dir }
    if game.lang ~= lang then
        problem("the screen opened in " .. tostring(game.lang) .. " with KOReader in " .. lang)
    end
    check(game, "title without a game " .. lang)
    shot(game, "title_empty_" .. lang)
    game:start_game()
    local s = game.engine.state
    -- Every card in both styles, and the result of each answer.
    for _, card in ipairs(game.engine.content.cards) do
        for _, style in ipairs({ "highlight", "note" }) do
            game.result_style = style
            s.current = card.id
            s.last = { card = card.id, side = "left", deltas = { residents = 12, funds = -15, building = 5, patience = -3 } }
            game:show_card()
            check(game, "card " .. style .. " " .. lang)
        end
        for _, side in ipairs({ "left", "right" }) do
            s.last = { card = card.id, side = side, deltas = { residents = -12, patience = 10 } }
            game:show_result()
            check(game, "result " .. lang)
        end
    end
    print(string.format("%s: %d cards in both styles and their results", lang, #game.engine.content.cards))
    -- Every ending, with the badge, and in the gallery.
    for _, ending in ipairs(game.engine.content.endings) do
        game.stats.endings[ending.id] = 1
    end
    game.new_ending = true
    local ended = { ending = nil, mandate = 5, day = 720, decisions = 999, won_all = true, minutes = {} }
    for _, ending in ipairs(game.engine.content.endings) do
        ended.ending = ending.id
        game:show_ending(ended)
        check(game, "ending " .. lang)
    end
    game:show_gallery()
    check(game, "gallery " .. lang)
    shot(game, "gallery_" .. lang)
    for page = 2, #game.list.pages do
        game:turn_list_page(1)
        if game.list.page ~= page then problem("the gallery did not turn to page " .. page .. " " .. lang) end
        check(game, "gallery page " .. lang)
    end
    game:show_gallery()
    -- The first tile opens its ending; the pager then goes through every ending found.
    game.canvas:action_at(game.canvas:x(30), game.canvas:y(160))()
    if game.mode ~= "list" or not game.list.pages[1] then problem("a gallery tile did not open its ending " .. lang) end
    for page = 1, #game.list.pages do
        game.list.page = page
        game.list.render(page)
        check(game, "gallery ending " .. lang)
    end
    -- The minutes with every line the cards have, and the paged screens.
    game:show_minutes({ minutes = every_minutes_line(game) }, function() end)
    check(game, "minutes " .. lang)
    shot(game, "minutes_" .. lang)
    for page = 2, #game.list.pages do
        game:turn_list_page(1)
        if game.list.page ~= page then problem("the minutes did not turn to page " .. page .. " " .. lang) end
        check(game, "minutes page " .. lang)
    end
    game:show_help()
    for page = 1, #game.list.pages do
        if page > 1 then game:turn_list_page(1) end
        check(game, "help " .. lang)
        shot(game, "help_" .. page .. "_" .. lang)
    end
    game:show_about()
    check(game, "about " .. lang)
    shot(game, "about_" .. lang)
    local version = game.engine.content.meta.version
    local shows_version = false
    for _, text in ipairs(game:shown_texts()) do
        if text:find(version, 1, true) then shows_version = true end
    end
    if not shows_version then problem("version missing on the About screen " .. lang) end
    for _, style in ipairs({ "highlight", "note" }) do
        game.result_style = style
        game:show_settings()
        check(game, "settings " .. lang)
    end
    shot(game, "settings_" .. lang)
    game:start_game()
    game:show_title()
    check(game, "title with a game " .. lang)
    game:confirm_new_game()
    check(game, "confirm " .. lang)
    shot(game, "confirm_" .. lang)
    -- Games played through the screen, half in each style.
    game.stats.endings = {}
    local games, decisions = 0, 0
    for g = 1, 10 do
        game.result_style = g % 2 == 0 and "note" or "highlight"
        game:start_game()
        local guard = 0
        while not game.engine.state.ending and guard < 400 do
            guard = guard + 1
            game:decide(math.random(2) == 1 and "left" or "right")
            if game.mode == "result" then
                check(game, "result while playing " .. lang)
                game:next_card()
            end
            decisions = decisions + 1
            if game.mode == "card" then check(game, "card while playing " .. lang) end
            if guard % 7 == 0 then game:paintTo(Screen.bb, 0, 0) end
        end
        if game.engine.state.ending then
            check(game, "ending while playing " .. lang)
            game:paintTo(Screen.bb, 0, 0)
        end
        games = games + 1
    end
    print(string.format("%s: %d games and %d decisions through the screen, no error", lang, games, decisions))
    shot(game, "ending_real_" .. lang)
    game:onCloseWidget()
end

-- The rest runs in Portuguese.
set_language("pt")
local game = GameScreen:new{ plugin_dir = plugin_dir }
game:start_game()
game:play("right")
local expected_decisions = game.engine.state.decisions
local reopened = GameScreen:new{ plugin_dir = plugin_dir }
check(reopened, "title with a game")
if not reopened:has_game() or reopened.engine.state.decisions ~= expected_decisions then
    problem("progress was not saved")
else
    print("progress saved and reloaded: " .. reopened.engine.state.decisions .. " decisions")
end
reopened:show_card()
shot(reopened, "resumed_card")

-- Refresh modes: a new layout flashes, a change inside it does not, and every ninth update in a row flashes. A
-- card and its result share one layout kind, so playing in the highlighted style does not flash each time.
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
paint.show_status = false
paint.result_style = "highlight"
paint:start_game()
for _ = 1, 4 do
    keep_alive(paint)
    paint:decide(safe_side(paint))
    paint:next_card()
end
paint:show_minutes(paint.engine.state, function() paint:show_card() end)
paint.list.back()
paint.result_style = "note"
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
-- title, card, 4 decisions with their results (8 updates without a flash), minutes, back to the card, a
-- decision, a reelection, title, card, a decision, and the first decision after waking up.
local expected = "full,full,ui,ui,ui,ui,ui,ui,ui,ui,full,full,ui,full,full,full,ui,full"
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
back.result_style = "highlight"
back:start_game()
back:handleEvent(Event:new("Back"))
if back.mode ~= "title" then problem("Back on a card did not go to the title: " .. tostring(back.mode)) end
back:show_card()
back:decide(safe_side(back))
if back.mode == "result" then
    -- The minutes button of the result footer, and Back from the minutes to the same result.
    local minutes = back.canvas:action_at(back.canvas:x(60), back.canvas:y(740))
    if minutes then minutes() end
    if back.mode ~= "list" then problem("the minutes button of a result did not open the minutes: " .. tostring(back.mode)) end
    back:handleEvent(Event:new("Back"))
    if back.mode ~= "result" then problem("Back on the minutes did not go back to the result: " .. tostring(back.mode)) end
    back:handleEvent(Event:new("Back"))
    if back.mode ~= "card" then problem("Back on a result did not go to the next card: " .. tostring(back.mode)) end
end
back:show_help()
back:handleEvent(Event:new("Back"))
if back.mode ~= "title" then problem("Back on the help did not go to the title: " .. tostring(back.mode)) end
back:show_settings()
back:handleEvent(Event:new("Back"))
if back.mode ~= "title" then problem("Back on the settings did not go to the title: " .. tostring(back.mode)) end
back:show_card()
back:show_minutes(back.engine.state, function() back:show_card() end)
back:handleEvent(Event:new("Back"))
if back.mode ~= "card" then problem("Back on the minutes did not go back to the card: " .. tostring(back.mode)) end
back.engine.state.meters.funds = 1
back.engine.state.meters.residents = 1
for _ = 1, 50 do
    if back.engine.state.ending then break end
    back:play("left")
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

-- The options are saved.
local options = GameScreen:new{ plugin_dir = plugin_dir }
options.result_style, options.show_status = "note", false
options:save_options()
local reread = GameScreen:new{ plugin_dir = plugin_dir }
if reread.result_style ~= "note" or reread.show_status ~= false or reread.status_canvas then
    problem("the settings were not saved")
end
reread.result_style, reread.show_status = "highlight", true
reread:save_options()

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
    check(old, "title with an old save")
    old:show_card()
    old:play("left")
    old:show_gallery()
    old:show_minutes(old.engine.state, function() end)
    check(old, "minutes of an old save")
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
