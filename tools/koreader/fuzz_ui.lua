-- Random touches through every part of the game. Usage, from the plugin folder:
--   KOREADER_DIR=<desktop KOReader> tools/koreader/run_headless.sh tools/koreader/fuzz_ui.lua
-- ACTIONS, SEED, ONLY and MAX_ERRORS work as in tools/koreader/fuzz.lua.
local Fuzz = dofile(os.getenv("PLUGIN_DIR") .. "/tools/koreader/fuzz.lua")
local UIManager = require("ui/uimanager")
local GameScreen = require("sindico_game/ui/screen")
local SavedState = require("sindico_game/saved_state")

-- What the touches reached: the screens shown and the decisions made, to see that the runs got somewhere.
local shown, decisions = {}, 0
local real_set_content, real_decide = GameScreen.set_content, GameScreen.decide
GameScreen.set_content = function(screen, widget, kind)
    shown[kind] = (shown[kind] or 0) + 1
    return real_set_content(screen, widget, kind)
end
GameScreen.decide = function(screen, side)
    if screen.mode == "card" then
        decisions = decisions + 1
    end
    return real_decide(screen, side)
end

local current
-- A new screen without anything saved, with the card draws tied to the fuzz seed.
local function fresh(f)
    if current and UIManager:isWidgetShown(current) then
        UIManager:close(current)
    end
    SavedState.remove_file(GameScreen:settings_path())
    math.randomseed(f.random(1, 1000000000))
    current = GameScreen:new{ plugin_dir = Fuzz.plugin_dir }
    UIManager:show(current)
    return current
end

local function finish_games(screen, count)
    for _ = 1, count do
        screen:start_game()
        while not screen.engine.state.ending do
            screen:decide(math.random(2) == 1 and "left" or "right")
        end
    end
end

local function in_list(f)
    return f.screen.mode ~= "list"
end

SavedState.remove_file(GameScreen:settings_path())
current = GameScreen:new{ plugin_dir = Fuzz.plugin_dir }
local fuzz = Fuzz.new{ screen = current }

fuzz:run{
    label = "title",
    setup = function(f) return fresh(f) end,
}

fuzz:run{
    label = "title with a game",
    setup = function(f)
        local screen = fresh(f)
        screen:start_game()
        for _ = 1, 5 do
            screen:decide("left")
        end
        screen:show_title()
        return screen
    end,
}

-- A swipe decides, as a finger would, once in three steps; the rest are random touches.
fuzz:run{
    label = "card",
    setup = function(f)
        local screen = fresh(f)
        screen:start_game()
        return screen
    end,
    again = function(f) return f.screen.mode ~= "card" and f.screen.mode ~= "list" end,
    step = function(f)
        if f.random(1, 3) == 1 then
            f:swipe(math.floor(f.width / 2), math.floor(f.height / 2), f.random(1, 2) == 1 and "west" or "east",
                math.floor(f.width / 3))
        else
            f:touch()
        end
    end,
}

fuzz:run{
    label = "ending",
    setup = function(f)
        local screen = fresh(f)
        screen:start_game()
        screen.engine.state.meters.funds = 1
        screen.engine.state.meters.residents = 1
        while not screen.engine.state.ending do
            screen:decide("left")
        end
        return screen
    end,
    again = function(f) return f.screen.mode == "title" end,
}

fuzz:run{
    label = "gallery",
    setup = function(f)
        local screen = fresh(f)
        finish_games(screen, 4)
        screen:show_gallery()
        return screen
    end,
    again = in_list,
}

fuzz:run{
    label = "minutes",
    setup = function(f)
        local screen = fresh(f)
        screen:start_game()
        while #screen.engine.state.minutes < 6 and not screen.engine.state.ending do
            screen:decide("right")
        end
        local state = screen.engine.state
        screen:show_minutes(state, function() screen:show_title() end)
        return screen
    end,
    again = in_list,
}

fuzz:run{
    label = "help",
    setup = function(f)
        local screen = fresh(f)
        screen:show_help()
        return screen
    end,
    again = in_list,
}

fuzz:run{
    label = "about",
    setup = function(f)
        local screen = fresh(f)
        screen:show_about()
        return screen
    end,
    again = in_list,
}

local kinds = {}
for kind, count in pairs(shown) do
    kinds[#kinds + 1] = kind .. " " .. count
end
table.sort(kinds)
print("screens shown: " .. table.concat(kinds, ", ") .. "; decisions: " .. decisions)
fuzz:finish()
