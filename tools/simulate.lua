-- Plays many games with random and careful choices and reports how long they last, the endings reached and
-- the cards never seen. Usage: luajit tools/simulate.lua [games]
package.path = "./?.lua;" .. package.path
local Content = require("sindico_game/content")
local Engine = require("sindico_game/engine")

local GAMES = tonumber(arg and arg[1]) or 5000
math.randomseed(42)
local engine = Engine.new({ content = Content.load(".") })
local endings, seen, decisions, mandates, stuck = {}, {}, {}, {}, 0
local smart_endings, smart_decisions, smart_mandates = {}, {}, {}

local function play(pick)
    engine:new_game()
    local guard = 0
    while not engine.state.ending do
        guard = guard + 1
        if guard > 5000 then stuck = stuck + 1; return nil end
        local card = engine:current_card()
        seen[card.id] = true
        engine:choose(pick(card))
    end
    return engine.state
end

local function random_pick() return math.random(2) == 1 and "left" or "right" end

local function score(choice, meters)
    local total = 0
    for name, value in pairs(meters) do
        local delta = (choice.effects or {})[name] or 0
        local after = math.max(1, value + delta)
        total = total + math.log(after)
    end
    return total
end
local function careful_pick(card)
    local meters = engine.state.meters
    return score(card.left, meters) >= score(card.right, meters) and "left" or "right"
end

for _ = 1, GAMES do
    local s = play(random_pick)
    if s then
        endings[s.ending] = (endings[s.ending] or 0) + 1
        decisions[#decisions + 1] = s.decisions
        mandates[#mandates + 1] = s.mandate
    end
    s = play(careful_pick)
    if s then
        smart_endings[s.ending] = (smart_endings[s.ending] or 0) + 1
        smart_decisions[#smart_decisions + 1] = s.decisions
        smart_mandates[#smart_mandates + 1] = s.mandate
    end
end

local function stats(list)
    table.sort(list)
    local sum = 0
    for _, v in ipairs(list) do sum = sum + v end
    return string.format("mean %.1f, median %d, min %d, max %d", sum / #list, list[math.ceil(#list / 2)], list[1], list[#list])
end
local function show(title, map, n)
    print(title)
    local keys = {}
    for k in pairs(map) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return map[a] > map[b] end)
    for _, k in ipairs(keys) do print(string.format("  %-28s %6.1f%%", k, map[k] * 100 / n)) end
end

print("Random player: decisions " .. stats(decisions) .. "; mandates " .. stats(mandates))
show("Endings (random):", endings, GAMES)
print("Careful player: decisions " .. stats(smart_decisions) .. "; mandates " .. stats(smart_mandates))
show("Endings (careful):", smart_endings, GAMES)
local never = {}
for _, card in ipairs(engine.content.cards) do
    if not seen[card.id] then never[#never + 1] = card.id end
end
print("Cards never seen: " .. #never .. (#never > 0 and (" -> " .. table.concat(never, ", ")) or ""))
for _, ending in ipairs(engine.content.endings) do
    if not endings[ending.id] and not smart_endings[ending.id] then
        print("Ending never reached: " .. ending.id)
    end
end
print("Stuck games: " .. stuck)
