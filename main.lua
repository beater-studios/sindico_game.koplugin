local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local Screen = require("sindico_game/ui/screen")

local PLUGIN_DIR = debug.getinfo(1, "S").source:gsub("^@", ""):match("(.*)/") or "."

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
            UIManager:show(Screen:new{ plugin_dir = PLUGIN_DIR })
        end,
    }
end

return SindicoGame
