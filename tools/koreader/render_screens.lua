-- Renders the README screenshots in one language (SCREENS_LANG: en by default, pt or es).
-- English, for README.md and the brand art: OUTPUT_DIR=docs/screenshots tools/koreader/run_headless.sh tools/koreader/render_screens.lua
-- Portuguese, for README_pt.md: SCREENS_LANG=pt OUTPUT_DIR=docs/screenshots/pt tools/koreader/run_headless.sh tools/koreader/render_screens.lua
local plugin_dir = assert(os.getenv("PLUGIN_DIR"))
local out_dir = assert(os.getenv("OUTPUT_DIR"))
local lang = os.getenv("SCREENS_LANG") or "en"

require("setupkoenv")
local DataStorage = require("datastorage")
G_defaults = require("luadefaults"):open()
G_reader_settings = require("luasettings"):open(DataStorage:getDataDir() .. "/settings.reader.lua")
G_reader_settings:saveSetting("language", lang)

package.path = plugin_dir .. "/?.lua;" .. package.path

local Device = require("device")
local Screen = Device.screen
-- The same time and battery on every run, so the pictures only change when the game does.
Device.hasBattery = function() return true end
Device.getPowerDevice = function() return { getCapacity = function() return 87 end } end
local real_date = os.date
os.date = function(format, time)
    return real_date(format, time or os.time({ year = 2026, month = 11, day = 12, hour = 14, min = 32 }))
end
require("document/canvascontext"):init(Device)
local UIManager = require("ui/uimanager")
UIManager:init()
local GameScreen = require("sindico_game/ui/screen")

local function shot(widget, name)
    Screen.bb:fill(require("ffi/blitbuffer").COLOR_WHITE)
    widget:paintTo(Screen.bb, 0, 0)
    local path = out_dir .. "/" .. name .. ".png"
    Screen.bb:writePNG(path)
    print("saved: " .. path)
end

math.randomseed(7)
local game = GameScreen:new{ plugin_dir = plugin_dir }
game.result_style = "highlight"
game:start_game()
game:play("left")
game:play("right")
game:show_title()
shot(game, "title")
game:show_card()
shot(game, "card")
game:decide("right")
shot(game, "result")
game:next_card()
game.engine.state.meters.funds = 1
game.engine.state.meters.residents = 1
for _ = 1, 30 do
    if game.engine.state.ending then break end
    game:play("left")
end
if not game.engine.state.ending then
    print("the game did not reach an ending")
    os.exit(1)
end
shot(game, "ending")
os.exit(0)
