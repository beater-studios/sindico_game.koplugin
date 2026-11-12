-- Random touches through every part of the game. Usage, from the plugin folder:
--   KOREADER_DIR=<desktop KOReader> tools/koreader/run_headless.sh tools/koreader/fuzz_ui.lua
-- ACTIONS, SEED, ONLY and MAX_ERRORS work as in tools/koreader/fuzz.lua.
local Fuzz = dofile(os.getenv("PLUGIN_DIR") .. "/tools/koreader/fuzz.lua")
local UIManager = require("ui/uimanager")
local GameScreen = require("sindico_game/ui/screen")
local SavedState = require("sindico_game/saved_state")

-- What the touches reached: the screens shown and the decisions made, to see that the runs got somewhere.
local shown, decisions = {}, 0
local real_present, real_decide = GameScreen.present, GameScreen.decide
GameScreen.present = function(screen, canvas, mode, kind)
    shown[mode] = (shown[mode] or 0) + 1
    return real_present(screen, canvas, mode, kind)
end
GameScreen.decide = function(screen, side)
    if screen.mode == "card" then
        decisions = decisions + 1
    end
    return real_decide(screen, side)
end

local current
local lang = "pt"
-- A new screen without anything saved, in the language of the run, with the card draws tied to the fuzz seed.
local function fresh(f)
    G_reader_settings:saveSetting("language", lang)
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
            screen:play(math.random(2) == 1 and "left" or "right")
        end
    end
end

local function in_list(f)
    return f.screen.mode ~= "list"
end

SavedState.remove_file(GameScreen:settings_path())
current = GameScreen:new{ plugin_dir = Fuzz.plugin_dir }
local fuzz = Fuzz.new{ screen = current }

-- Every part of the game in each language.
for _, code in ipairs({ "pt", "en", "es" }) do
    fuzz:run{
        label = "title " .. code,
        setup = function(f)
            lang = code
            return fresh(f)
        end,
    }

    fuzz:run{
        label = "title with a game " .. code,
        setup = function(f)
            lang = code
            local screen = fresh(f)
            screen:start_game()
            for _ = 1, 5 do
                screen:play("left")
            end
            screen:show_title()
            return screen
        end,
    }

    for _, style in ipairs({ "highlight", "note" }) do
        -- A swipe decides, as a finger would, once in three steps; the rest are random touches.
        fuzz:run{
            label = "card " .. style .. " " .. code,
            setup = function(f)
                lang = code
                local screen = fresh(f)
                screen.result_style = style
                screen:start_game()
                return screen
            end,
            again = function(f) return f.screen.mode ~= "card" and f.screen.mode ~= "result" and f.screen.mode ~= "list" end,
            step = function(f)
                if f.random(1, 3) == 1 then
                    f:swipe(math.floor(f.width / 2), math.floor(f.height / 2), f.random(1, 2) == 1 and "west" or "east",
                        math.floor(f.width / 3))
                else
                    f:touch()
                end
            end,
        }
    end

    fuzz:run{
        label = "ending " .. code,
        setup = function(f)
            lang = code
            local screen = fresh(f)
            screen:start_game()
            screen.engine.state.meters.funds = 1
            screen.engine.state.meters.residents = 1
            while not screen.engine.state.ending do
                screen:play("left")
            end
            return screen
        end,
        again = function(f) return f.screen.mode == "title" end,
    }

    fuzz:run{
        label = "gallery " .. code,
        setup = function(f)
            lang = code
            local screen = fresh(f)
            finish_games(screen, 4)
            screen:show_gallery()
            return screen
        end,
        again = in_list,
    }

    fuzz:run{
        label = "minutes " .. code,
        setup = function(f)
            lang = code
            local screen = fresh(f)
            screen:start_game()
            while #screen.engine.state.minutes < 6 and not screen.engine.state.ending do
                screen:play("right")
            end
            local state = screen.engine.state
            screen:show_minutes(state, function() screen:show_title() end)
            return screen
        end,
        again = in_list,
    }

    fuzz:run{
        label = "help " .. code,
        setup = function(f)
            lang = code
            local screen = fresh(f)
            screen:show_help()
            return screen
        end,
        again = in_list,
    }

    fuzz:run{
        label = "settings " .. code,
        setup = function(f)
            lang = code
            local screen = fresh(f)
            screen:show_settings()
            return screen
        end,
        again = function(f) return f.screen.mode ~= "settings" end,
    }

    fuzz:run{
        label = "about " .. code,
        setup = function(f)
            lang = code
            local screen = fresh(f)
            screen:show_about()
            return screen
        end,
        again = in_list,
    }
end

local kinds = {}
for kind, count in pairs(shown) do
    kinds[#kinds + 1] = kind .. " " .. count
end
table.sort(kinds)
print("screens shown: " .. table.concat(kinds, ", ") .. "; decisions: " .. decisions)
fuzz:finish()
