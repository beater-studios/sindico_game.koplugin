package.path = "./?.lua;" .. package.path
local Engine = require("sindico_game/engine")

local passed, failed = 0, 0
local function check(name, condition)
    if condition then
        passed = passed + 1
    else
        failed = failed + 1
        print("FALHOU: " .. name)
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
    check("primeira carta", e.state.current == "a")
    e:choose("left")
    check("efeito positivo", e.state.meters.funds == 60)
    check("efeito negativo", e.state.meters.residents == 45)
    check("deltas", e.state.last.deltas.funds == 10 and e.state.last.deltas.residents == -5)
    check("avança dias", e.state.day == Engine.DEFAULT_CARD_DAYS)
    check("não repete carta", e.state.current == "b")
end

do
    local e = make({ card("a", { left = choice({ effects = { funds = 90 } }) }), card("b") })
    e:choose("left")
    check("limite 100", e.state.meters.funds == 100)
end

do
    local e = make({ card("a", { left = choice({ effects = { funds = -60 } }) }), card("b") })
    e:choose("left")
    check("zero encerra", e.state.ending == "z_funds")
    check("sem carta atual", e.state.current == nil)
end

do
    local e = make({ card("a", { left = choice({ effects = { funds = -60 }, set = { "f" } }) }) })
    e:choose("left")
    check("final específico vem primeiro", e.state.ending == "z_funds_flag")
end

do
    local e = make({ card("a", { left = choice({ ending = "special" }) }), card("b") })
    e:choose("left")
    check("final por escolha", e.state.ending == "special")
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
    check("chain fora do sorteio", e.state.current ~= "c")
end

do
    local e = make({
        card("a", { left = choice({ schedule = { card = "s", days = 24 } }) }),
        card("b"), card("b2"), card("b3"),
        card("s", { chain = true }),
    })
    e:choose("left")
    check("agendada não vem antes", e.state.current ~= "s")
    e:choose("left")
    check("agendada vem no prazo", e.state.current == "s")
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
    check("requires min bloqueia", e.state.current == "b")
end

do
    local e = make({ card("a"), card("election", { at_day = 12, left = choice({ resolve = "election" }), right = choice({ resolve = "election" }) }), card("b") })
    e:choose("left")
    check("at_day obrigatório", e.state.current == "election")
    e.state.meters.residents = 80
    e.state.meters.funds = 20
    e:choose("left")
    check("reeleito", e.state.mandate == 2 and e.state.day == 0 and not e.state.ending)
    check("marca reeleição", e.state.last.reelected == true)
    check("medidor volta um terço", e.state.meters.residents == 70 and e.state.meters.funds == 30)
    check("dificuldade sobe", e:difficulty() > 1)
end

do
    local e = make({ card("election", { at_day = 0, left = choice({ resolve = "election" }), right = choice({ resolve = "election" }) }) })
    e.state.meters.residents = 30
    e:choose("left")
    check("perde eleição", e.state.ending == "lost")
end

do
    local e = make({ card("election", { at_day = 0, left = choice({ resolve = "election" }), right = choice({ resolve = "election" }) }) })
    e.state.mandate = Engine.MAX_MANDATES
    e.state.meters.residents = 90
    e:choose("left")
    check("vence todos os mandatos", e.state.ending == "all")
end

do
    local e = make({ card("a", { left = choice({ effects = { funds = -10 } }) }), card("b") })
    e.state.mandate = 3
    e:choose("left")
    check("efeito negativo escala", e.state.meters.funds == 37)
end

do
    local e = make({ card("a", { left = choice({ minutes = "Fez algo." }) }), card("b") })
    e:choose("left")
    check("ata", #e.state.minutes == 1 and e.state.minutes[1].text == "Fez algo.")
end

do
    local e = make({ card("a"), card("b") })
    local saved = e:serialize()
    local e2 = make({ card("a"), card("b") })
    e2:load(saved)
    check("carrega estado", e2.state.current == saved.current)
end

do
    local e = make({ card("a", { left = choice({ effects = { funds = -60 } }) }) })
    e:choose("left")
    local stats = e:record_ending(Engine.new_stats())
    check("estatísticas", stats.games == 1 and stats.endings.z_funds == 1 and stats.decisions == 1)
end

local title_case = require("sindico_game/ui/title_case")
check("title case comum", title_case("dar a folga") == "Dar a Folga")
check("title case acento", title_case("só horário comercial") == "Só Horário Comercial")
check("title case primeira palavra", title_case("a reforma") == "A Reforma")

print(string.format("%d passaram, %d falharam", passed, failed))
os.exit(failed == 0 and 0 or 1)
