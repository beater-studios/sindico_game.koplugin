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
local GameScreen = require("sindico_game/ui/screen")

local function shot(widget, name)
    Screen.bb:fill(require("ffi/blitbuffer").COLOR_WHITE)
    widget:paintTo(Screen.bb, 0, 0)
    local path = out_dir .. "/" .. name .. ".png"
    Screen.bb:writePNG(path)
    print("salvo: " .. path)
end

math.randomseed(7)
local game = GameScreen:new{ plugin_dir = plugin_dir }
shot(game, "title")
game:start_game()
game:decide("left")
shot(game, "card")
game.engine.state.meters.funds = 1
game:decide("left")
game.engine.state.meters.residents = 1
game:decide("left")
if not game.engine.state.ending then
    print("a partida não chegou a um final")
    os.exit(1)
end
shot(game, "ending")
os.exit(0)
