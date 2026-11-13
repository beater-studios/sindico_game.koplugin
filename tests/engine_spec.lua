package.path = "./?.lua;" .. package.path
local Engine = require("sindico_game/engine")

local passed, failed = 0, 0
local function check(name, condition)
    if condition then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAILED: " .. name)
    end
end

local function choice(extra)
    local c = { label = "x", result = "r", effects = {} }
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
end
local function card(id, extra)
    local c = { id = id, char = "a", text = "t", left = choice(), right = choice() }
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
end
local function make(cards, random)
    local endings = {
        { id = "z_residents", trigger = "zero:residents", title = "t", text = "t" },
        { id = "z_funds_flag", trigger = "zero:funds", title = "t", text = "t", requires = { flags = { "f" } } },
        { id = "z_funds", trigger = "zero:funds", title = "t", text = "t" },
        { id = "z_building", trigger = "zero:building", title = "t", text = "t" },
        { id = "z_patience", trigger = "zero:patience", title = "t", text = "t" },
        { id = "lost", trigger = "election_lost", title = "t", text = "t" },
        { id = "all", trigger = "all_mandates", title = "t", text = "t" },
        { id = "none", trigger = "no_cards", title = "t", text = "t" },
        { id = "special", title = "t", text = "t" },
    }
    local e = Engine.new({ content = { cards = cards, endings = endings, characters = {} }, random = random or function() return 1 end })
    e:new_game()
    return e
end

do
    local e = make({ card("a", { left = choice({ effects = { funds = 10, residents = -5 } }) }), card("b") })
    check("first card", e.state.current == "a")
    e:choose("left")
    check("positive effect", e.state.meters.funds == 60)
    check("negative effect", e.state.meters.residents == 45)
    check("deltas", e.state.last.deltas.funds == 10 and e.state.last.deltas.residents == -5)
    check("days go by", e.state.day == Engine.DEFAULT_CARD_DAYS)
    check("does not repeat a card", e.state.current == "b")
end

do
    local e = make({ card("a", { left = choice({ effects = { funds = 90 } }) }), card("b") })
    e:choose("left")
    check("limit 100", e.state.meters.funds == 100)
end

do
    local e = make({ card("a", { left = choice({ effects = { funds = -60 } }) }), card("b") })
    e:choose("left")
    check("zero ends the game", e.state.ending == "z_funds")
    check("no current card", e.state.current == nil)
end

do
    local e = make({ card("a", { left = choice({ effects = { funds = -60 }, set = { "f" } }) }) })
    e:choose("left")
    check("specific ending comes first", e.state.ending == "z_funds_flag")
end

do
    local e = make({ card("a", { left = choice({ ending = "special" }) }), card("b") })
    e:choose("left")
    check("ending by choice", e.state.ending == "special")
end

do
    local e = make({
        card("a", { left = choice({ next = "c" }) }),
        card("b"),
        card("c", { chain = true }),
    })
    e:choose("left")
    check("next", e.state.current == "c")
end

do
    local cards = { card("a"), card("c", { chain = true }) }
    local e = make(cards)
    e:choose("left")
    check("chain card out of the draw", e.state.current ~= "c")
end

do
    local e = make({
        card("a", { left = choice({ schedule = { card = "s", days = 24 } }) }),
        card("b"), card("b2"), card("b3"),
        card("s", { chain = true }),
    })
    e:choose("left")
    check("scheduled card not before its day", e.state.current ~= "s")
    e:choose("left")
    check("scheduled card on its day", e.state.current == "s")
end

do
    local e = make({
        card("a", { left = choice({ set = { "x" } }), right = choice() }),
        card("b", { requires = { flags = { "x" } } }),
        card("c", { requires = { not_flags = { "x" } } }),
    })
    e:choose("left")
    check("requires flags", e.state.current == "b")
end

do
    local e = make({ card("a"), card("rich", { requires = { min = { funds = 70 } } }), card("b") })
    e:choose("left")
    check("requires min blocks", e.state.current == "b")
end

do
    local e = make({ card("a"), card("election", { at_day = 12, left = choice({ resolve = "election" }), right = choice({ resolve = "election" }) }), card("b") })
    e:choose("left")
    check("at_day card is mandatory", e.state.current == "election")
    e.state.meters.residents = 80
    e.state.meters.funds = 20
    e:choose("left")
    check("reelected", e.state.mandate == 2 and e.state.day == 0 and not e.state.ending)
    check("marks the reelection", e.state.last.reelected == true)
    check("meter goes back a third", e.state.meters.residents == 70 and e.state.meters.funds == 30)
    check("difficulty goes up", e:difficulty() > 1)
end

do
    local e = make({ card("election", { at_day = 0, left = choice({ resolve = "election" }), right = choice({ resolve = "election" }) }) })
    e.state.meters.residents = 30
    e:choose("left")
    check("loses the election", e.state.ending == "lost")
end

do
    local e = make({ card("election", { at_day = 0, left = choice({ resolve = "election" }), right = choice({ resolve = "election" }) }) })
    e.state.mandate = Engine.MAX_MANDATES
    e.state.meters.residents = 90
    e:choose("left")
    check("wins every mandate", e.state.ending == "all")
    check("counts the last mandate", Engine.completed_mandates(e.state) == Engine.MAX_MANDATES)
    local stats = e:record_ending(Engine.new_stats())
    check("record with every mandate", stats.best_mandates == Engine.MAX_MANDATES)
end

do
    local e = make({ card("election", { at_day = 0, left = choice({ resolve = "election" }), right = choice({ resolve = "election" }) }) })
    e.state.mandate = 3
    e.state.day = Engine.MANDATE_DAYS
    e.state.meters.residents = 30
    e:choose("left")
    check("a defeat does not count the mandate", Engine.completed_mandates(e.state) == 2)
    check("days stop at the end of the mandate", Engine.total_days(e.state) == 3 * Engine.MANDATE_DAYS)
    check("month capped by the mandate", e:month() == Engine.MANDATE_MONTHS)
end

do
    local e = make({ card("a", { days = 20, left = choice({ days = 30 }) }), card("b"), card("c") })
    e:choose("left")
    check("days of the choice", e.state.day == 30)
    e.state.current = "a"
    e.state.used.a = nil
    e:choose("right")
    check("days of the card", e.state.day == 50)
end

do
    local e = make({ card("a"), card("fixed", { at_day = 12 }) })
    e:choose("left")
    check("at_day card shows up", e.state.current == "fixed")
    e:choose("left")
    e:choose("left")
    check("without cards, at_day does not repeat", e.state.current == "a")
end

do
    local e = make({ card("a", { left = choice({ effects = { funds = -10 } }) }), card("b") })
    e.state.mandate = 3
    e:choose("left")
    check("negative effect scales", e.state.meters.funds == 37)
end

do
    local e = make({ card("a", { left = choice({ minutes = "Fez algo." }) }), card("b") })
    e:choose("left")
    check("minutes", #e.state.minutes == 1 and e:choice_text(e.state.minutes[1], "minutes", "text") == "Fez algo.")
    check("last result by card", e:choice_text(e.state.last, "result", "result") == "r")
end

do
    local e = make({ card("a"), card("b") })
    local saved = e:serialize()
    local e2 = make({ card("a"), card("b") })
    e2:restore(saved)
    check("restores the state", e2.state.current == saved.current)
    check("save has a version", saved.version == Engine.SAVE_VERSION)
    e:choose("left")
    check("save is a copy", saved.decisions == 0)
end

do
    local e = make({ card("a", { left = choice({ effects = { funds = -60 } }) }) })
    e:choose("left")
    local stats = e:record_ending(Engine.new_stats())
    check("records", stats.games == 1 and stats.endings.z_funds == 1 and stats.decisions == 1)
end

do
    -- A card not seen yet in the game weighs more in the draw than one seen in an earlier term.
    local e = make({ card("a", { char = "a" }), card("b", { char = "b", weight = 2 }) })
    e.state.used_ever.a = true
    local pool, total = e:pool(nil)
    local weights = {}
    for _, item in ipairs(pool) do weights[item.id] = item.weight end
    check("unseen card weighs more", weights.a == 1 and weights.b == 2 * Engine.UNSEEN_WEIGHT
        and total == 1 + 2 * Engine.UNSEEN_WEIGHT)
end

local sentence_case = require("sindico_game/ui/sentence_case")
check("sentence case keeps the rest as written", sentence_case("falar com Kleber") == "Falar com Kleber")
check("sentence case accent", sentence_case("só horário comercial") == "Só horário comercial")
check("sentence case after an opening sign", sentence_case("¿por qué no?") == "¿Por qué no?")
check("sentence case number", sentence_case("18h em ponto") == "18h em ponto")

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
