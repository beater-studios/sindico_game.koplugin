local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")

local Content = require("sindico_game/content")
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
                -- The texts may be what failed to load, so there is a fallback in English.
                local lang = Content.language_from(G_reader_settings and G_reader_settings:readSetting("language"))
                local ok_strings, strings = pcall(Content.strings, PLUGIN_DIR, lang)
                local text = ok_strings and strings and strings.open_failed
                UIManager:show(InfoMessage:new{ text = text or "O Síndico could not open. Try restarting KOReader." })
            end
        end,
    }
end

return SindicoGame
