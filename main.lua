local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")

local GameScreensaver = require("sindico_game/screensaver")
local Screen = require("sindico_game/ui/screen")

local PLUGIN_DIR = debug.getinfo(1, "S").source:gsub("^@", ""):match("(.*)/") or "."

GameScreensaver.install(PLUGIN_DIR, "sindico_game")

local SindicoGame = WidgetContainer:extend{
    name = "sindico_game",
    is_doc_only = false,
}

function SindicoGame:init()
    self.ui.menu:registerToMainMenu(self)
end

function SindicoGame:addToMainMenu(menu_items)
    menu_items.sindico_game = {
        text = "O Síndico",
        sorting_hint = "tools",
        callback = function()
            -- An error while opening would otherwise reach the KOReader loop and close it.
            local ok, screen = pcall(Screen.new, Screen, { plugin_dir = PLUGIN_DIR })
            if ok then
                UIManager:show(screen)
            else
                logger.warn("sindico_game: could not open", screen)
                UIManager:show(InfoMessage:new{ text = "Não foi possível abrir O Síndico. Tente reiniciar o KOReader." })
            end
        end,
    }
end

return SindicoGame
