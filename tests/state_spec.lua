-- Reading saves back: the game in progress, the records and saves from published versions.
package.path = "./?.lua;" .. package.path
local Content = require("sindico_game/content")
local Engine = require("sindico_game/engine")
local SavedState = require("sindico_game/saved_state")

local passed, failed = 0, 0
local function check(name, condition)
    if condition then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAILED: " .. name)
    end
end

local content = Content.load(".")
local function seeded(seed)
    local state = seed
    return function(n)
        state = state * 48271 % 2147483647
        return state % n + 1
    end
end
local function engine(seed)
    return Engine.new({ content = content, random = seeded(seed or 7) })
end
local function play(e, decisions)
    for _ = 1, decisions do
        if e.state.ending then return end
        -- The side that leaves the lowest meter highest and does not end the game, so the game lasts whatever
        -- the draws.
        local card = e:current_card()
        local best, side = nil, "left"
        for _, option in ipairs({ "left", "right" }) do
            local low = card[option].ending and -math.huge or math.huge
            for _, name in ipairs(Engine.METERS) do
                low = math.min(low, e.state.meters[name] + ((card[option].effects or {})[name] or 0))
            end
            if not best or low > best then best, side = low, option end
        end
        e:choose(side)
    end
end
local function load_save(path)
    local chunk = assert(loadfile(path))
    setfenv(chunk, {})
    return chunk()
end

-- Round trip: what the screen shows and what the engine uses come back equal, and the game goes on.
do
    local e = engine(7)
    e:new_game()
    play(e, 30)
    check("round trip: game in progress", not e.state.ending and e.state.decisions == 30)
    local saved = SavedState.copy(e:serialize())
    local back = engine(7)
    check("round trip: restores", back:restore(saved) ~= nil)
    local a, b = e.state, back.state
    check("round trip: current card", a.current == b.current)
    check("round trip: day, mandate and decisions", a.day == b.day and a.mandate == b.mandate and a.decisions == b.decisions)
    local same_meters = true
    for _, name in ipairs(Engine.METERS) do
        if a.meters[name] ~= b.meters[name] then same_meters = false end
    end
    check("round trip: meters", same_meters)
    check("round trip: minutes", #a.minutes == #b.minutes)
    check("round trip: queue", #a.queue == #b.queue)
    local same_flags = true
    for flag in pairs(a.flags) do
        if not b.flags[flag] then same_flags = false end
    end
    check("round trip: flags", same_flags)
    -- The same draws from here on, so both games take the same path.
    e.random, back.random = seeded(99), seeded(99)
    play(e, 40)
    play(back, 40)
    check("round trip: goes on the same", e.state.decisions == back.state.decisions and e.state.current == back.state.current
        and e.state.ending == back.state.ending)
end

-- Content that left: the current card and queued cards that no longer exist.
do
    local e = engine(3)
    e:new_game()
    play(e, 5)
    local saved = SavedState.copy(e:serialize())
    saved.current = "card_that_left"
    saved.queue = { { card = "card_that_left", day = 10 }, { card = content.cards[1].id, day = saved.day + 500 } }
    saved.used.card_that_left = true
    local back = engine(3)
    check("content that left: opens", back:restore(saved) ~= nil)
    check("content that left: another current card", back.state.current ~= "card_that_left" and back:current_card() ~= nil)
    check("content that left: queue without the card", #back.state.queue == 1)
    check("content that left: used without the card", back.state.used.card_that_left == nil)
end

-- Damaged saves: a part of another type drops the game, and the records stay.
do
    local function restored(change)
        local e = engine(5)
        e:new_game()
        play(e, 3)
        local saved = SavedState.copy(e:serialize())
        change(saved)
        return SavedState.restore(function(data) return engine(5):restore(data) end, saved, nil)
    end
    check("damaged save: meters", restored(function(s) s.meters = 5 end) == nil)
    check("damaged save: meter at zero", restored(function(s) s.meters.funds = 0 end) == nil)
    check("damaged save: day", restored(function(s) s.day = "300" end) == nil)
    check("damaged save: mandate", restored(function(s) s.mandate = 9 end) == nil)
    check("damaged save: future version", restored(function(s) s.version = 2 end) == nil)
    check("damaged save: finished game", restored(function(s) s.ending = "bankruptcy" end) == nil)
    check("damaged save: queue and minutes", restored(function(s)
        s.queue = { "x", { card = 3 } }
        s.minutes = { { text = 4 }, false }
        s.last = { result = 1 }
    end) ~= nil)
    do
        local e = engine(5)
        e:new_game()
        local saved = SavedState.copy(e:serialize())
        local card = content.cards[1].id
        saved.queue = { [1] = { card = card, day = saved.day + 500 }, [3] = { card = card, day = saved.day + 600 } }
        saved.minutes = { [1] = { mandate = 1, month = 1, text = "a" }, [3] = { mandate = 1, month = 2, text = "b" } }
        local back = engine(5)
        back:restore(saved)
        check("damaged save: entries after a hole in the queue stay", back.state and #back.state.queue == 2)
        check("damaged save: entries after a hole in the minutes stay", back.state and #back.state.minutes == 2)
        local untouched = SavedState.copy(e:serialize())
        untouched.version = nil
        engine(5):restore(untouched)
        check("restore leaves the saved table as it was", untouched.version == nil)
    end
    check("damaged save: an error gives nil", SavedState.restore(function() error("boom") end, {}, nil) == nil)
    local stats = Engine.restore_stats({ games = "3", decisions = 10.5, endings = { bankruptcy = 2, broken = "x" } })
    check("damaged records: fields", stats.games == 0 and stats.decisions == 0 and stats.best_days == 0)
    check("damaged records: endings", stats.endings.bankruptcy == 2 and stats.endings.broken == nil)
end

-- Records from an older save, without a field added later.
do
    local stats = Engine.restore_stats({ games = 4, best_mandates = 2, endings = { bankruptcy = 1 } })
    check("old records: new field", stats.decisions == 0 and stats.best_days == 0)
    check("old records: the others stay", stats.games == 4 and stats.best_mandates == 2 and stats.endings.bankruptcy == 1)
    check("empty records", Engine.restore_stats(nil).games == 0)
end

-- Saves from published versions, in tests/saves/<version>.lua.
do
    local files = {}
    local list = io.popen("ls tests/saves/*.lua 2>/dev/null")
    for path in list:lines() do
        files[#files + 1] = path
    end
    list:close()
    check("old saves: there are some", #files > 0)
    for _, path in ipairs(files) do
        local data = load_save(path)
        local stats = Engine.restore_stats(data.stats)
        check(path .. ": records", stats.games > 0 and next(stats.endings) ~= nil)
        if data.game then
            local e = engine(9)
            local decisions = data.game.decisions
            check(path .. ": game", e:restore(data.game) ~= nil and e.state.decisions == decisions)
            check(path .. ": current card", e:current_card() ~= nil)
            play(e, 20)
            check(path .. ": game goes on", e.state.decisions > decisions)
        end
    end
end

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
