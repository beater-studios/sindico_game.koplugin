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
        print("TEXTO NÃO CABE: " .. card.id .. " " .. h)
    end
    for _, side in ipairs({ "left", "right" }) do
        local c = card[side]
        local lw = line_width("‹ " .. c.label, 19)
        if lw > max_label then max_label = lw end
        if lw > half - Screen:scaleBySize(16) then
            problems = problems + 1
            print("RÓTULO NÃO CABE: " .. card.id .. " " .. c.label .. " " .. lw)
        end
        local rh = box_height(c.result, "noto/NotoSerif-Italic.ttf", 16, text_width)
        if rh > Screen:scaleBySize(50) then
            problems = problems + 1
            print("RESULTADO NÃO CABE: " .. card.id .. " " .. c.result .. " " .. rh)
        end
    end
    local f = io.open(plugin_dir .. "/assets/portraits/" .. card.char .. ".png", "rb")
    if f then f:close() else problems = problems + 1; print("SEM RETRATO: " .. card.char) end
end
for _, ending in ipairs(content.endings) do
    local h = box_height(ending.text, "noto/NotoSerif-Regular.ttf", 20, text_width)
    if h > Screen:scaleBySize(230) then
        problems = problems + 1
        print("FINAL NÃO CABE: " .. ending.id .. " " .. h)
    end
    local th = box_height(ending.title, "noto/NotoSerif-Bold.ttf", 26, text_width)
    if th > Screen:scaleBySize(70) then
        problems = problems + 1
        print("TÍTULO LONGO: " .. ending.id .. " " .. th)
    end
end
print(string.format("%d cartas; maior texto %dpx (limite %d); maior rótulo %dpx (limite %d); %d problemas",
    #content.cards, max_text, Screen:scaleBySize(218), max_label, half - Screen:scaleBySize(16), problems))

local function shot(widget, name)
    Screen.bb:fill(Blitbuffer.COLOR_WHITE)
    widget:paintTo(Screen.bb, 0, 0)
    Screen.bb:writePNG(out_dir .. "/" .. name .. ".png")
end

local function check_height(game, name)
    if game.content_height > Screen:getHeight() then
        problems = problems + 1
        print("TELA ESTOURA: " .. name .. " " .. game.content_height)
    end
end

math.randomseed(5)
local game = GameScreen:new{ plugin_dir = plugin_dir }
check_height(game, "título sem jogo")
shot(game, "title_empty")
local games, decisions = 0, 0
for _ = 1, 40 do
    game:start_game()
    local guard = 0
    while not game.engine.state.ending and guard < 400 do
        guard = guard + 1
        game:decide(math.random(2) == 1 and "left" or "right")
        decisions = decisions + 1
        if game.mode == "card" then check_height(game, "carta") end
        if guard % 7 == 0 then game:paintTo(Screen.bb, 0, 0) end
    end
    if game.engine.state.ending then
        check_height(game, "final")
        game:paintTo(Screen.bb, 0, 0)
    end
    games = games + 1
end
print(string.format("%d partidas e %d decisões pela interface, sem erro", games, decisions))
shot(game, "ending_real")
local ended = game.engine.state
game:show_minutes(ended, function() end)
check_height(game, "ata")
shot(game, "ata")

game.engine.state = nil
game:show_gallery()
check_height(game, "galeria")
shot(game, "gallery_1")
print("galeria: " .. #game.list.pages .. " páginas")
game:turn_list_page(1)
shot(game, "gallery_2")

game:show_help()
check_height(game, "ajuda")
print("ajuda: " .. #game.list.pages .. " páginas")
shot(game, "help_1")

game:show_about()
check_height(game, "sobre")
print("sobre: " .. #game.list.pages .. " páginas")
shot(game, "about")
local about_version = game.list.pages[1][1].meta
if not about_version:find(game.engine.content.meta.version, 1, true) then
    problems = problems + 1
    print("VERSÃO AUSENTE NA TELA SOBRE")
end

game:start_game()
game.engine.state.current = longest_card.id
game:show_card()
shot(game, "longest_card")
game:decide("right")
shot(game, "after_longest")
local expected_decisions = game.engine.state.decisions

local reopened = GameScreen:new{ plugin_dir = plugin_dir }
check_height(reopened, "título com jogo")
shot(reopened, "title_with_game")
if not reopened:has_game() or reopened.engine.state.decisions ~= expected_decisions then
    problems = problems + 1
    print("PROGRESSO NÃO FOI SALVO")
else
    print("progresso salvo e recarregado: " .. reopened.engine.state.decisions .. " decisões")
end
reopened:show_card("full")
shot(reopened, "resumed_card")

local initial_rotation = Screen:getRotationMode()
Screen:setRotationMode(Screen.DEVICE_ROTATED_CLOCKWISE)
local rotated = GameScreen:new{ plugin_dir = plugin_dir }
rotated:show_card("full")
check_height(rotated, "carta aberta em paisagem")
shot(rotated, "opened_in_landscape")
if Screen:getWidth() > Screen:getHeight() then
    problems = problems + 1
    print("JOGO ABERTO EM PAISAGEM NÃO VOLTOU PARA RETRATO")
end
if not rotated:onSetRotationMode(Screen.DEVICE_ROTATED_CLOCKWISE) or Screen:getWidth() > Screen:getHeight() then
    problems = problems + 1
    print("ROTAÇÃO DURANTE O JOGO NÃO FOI IGNORADA")
end
rotated:onCloseWidget()
if Screen:getRotationMode() ~= Screen.DEVICE_ROTATED_CLOCKWISE then
    problems = problems + 1
    print("ROTAÇÃO ORIGINAL NÃO FOI RESTAURADA")
else
    print("aberto em paisagem: jogou em retrato e restaurou a rotação ao fechar")
end
Screen:setRotationMode(initial_rotation)

print("problemas: " .. problems)
os.exit(problems == 0 and 0 or 1)
