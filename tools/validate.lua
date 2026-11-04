package.path = "./?.lua;" .. package.path
local Content = require("sindico_game/content")
local Engine = require("sindico_game/engine")

local content = Engine.index_content(Content.load("."))
local errors, warnings = {}, {}
local function err(msg) errors[#errors + 1] = msg end
local function warn(msg) warnings[#warnings + 1] = msg end

local meters = {}
for _, m in ipairs(Engine.METERS) do meters[m] = true end
local function ulen(s) return #s:gsub("[\128-\191]", "") end
local TRIGGERS = { election_lost = true, all_mandates = true, no_cards = true }
for _, m in ipairs(Engine.METERS) do TRIGGERS["zero:" .. m] = true end

local seen, flags_set, flags_used, targeted, ending_refs = {}, {}, {}, {}, {}
local function check_meter_table(where, t)
    for k in pairs(t or {}) do
        if not meters[k] then err(where .. ": medidor desconhecido " .. tostring(k)) end
    end
end

for _, card in ipairs(content.cards) do
    local where = "carta " .. tostring(card.id)
    if not card.id or not card.id:match("^[a-z0-9_]+$") then err(where .. ": id inválido") end
    if seen[card.id] then err(where .. ": id repetido") end
    seen[card.id] = true
    if not content.characters[card.char] then err(where .. ": personagem desconhecido " .. tostring(card.char)) end
    if not card.text or ulen(card.text) > 240 then err(where .. ": text ausente ou maior que 240") end
    for _, side in ipairs({ "left", "right" }) do
        local c = card[side]
        if not c then
            err(where .. ": falta " .. side)
        else
            local w = where .. "." .. side
            if not c.label or ulen(c.label) > 22 then err(w .. ": label ausente ou maior que 22") end
            if not c.result or ulen(c.result) > 90 then err(w .. ": result ausente ou maior que 90") end
            if c.minutes and ulen(c.minutes) > 80 then err(w .. ": minutes maior que 80") end
            check_meter_table(w, c.effects)
            for _, f in ipairs(c.set or {}) do flags_set[f] = true end
            if c.next then targeted[c.next] = true end
            if c.schedule then
                targeted[c.schedule.card] = true
                if not c.schedule.days then warn(w .. ": schedule sem days") end
            end
            if c.ending then ending_refs[c.ending] = true end
        end
    end
    local r = card.requires
    if r then
        check_meter_table(where .. ".requires.min", r.min)
        check_meter_table(where .. ".requires.max", r.max)
        for _, f in ipairs(r.flags or {}) do flags_used[f] = true end
        for _, f in ipairs(r.not_flags or {}) do flags_used[f] = true end
    end
end

for _, ending in ipairs(content.endings) do
    local where = "final " .. tostring(ending.id)
    if not ending.title or not ending.text then err(where .. ": falta title ou text") end
    if ulen(ending.text or "") > 420 then err(where .. ": text maior que 420") end
    if ending.trigger and not TRIGGERS[ending.trigger] then err(where .. ": trigger desconhecido") end
    if not ending.trigger and not ending_refs[ending.id] then err(where .. ": nenhuma carta leva a este final") end
    for _, f in ipairs(ending.requires and ending.requires.flags or {}) do flags_used[f] = true end
    for _, f in ipairs(ending.requires and ending.requires.not_flags or {}) do flags_used[f] = true end
end
for id in pairs(ending_refs) do
    if not content.ending_by_id[id] then err("final referenciado não existe: " .. id) end
end
for id in pairs(targeted) do
    if not content.by_id[id] then err("carta referenciada não existe: " .. id) end
end
for _, card in ipairs(content.cards) do
    if card.chain and not targeted[card.id] then err("carta chain sem origem: " .. card.id) end
end
for f in pairs(flags_used) do
    if not flags_set[f] then err("flag exigida, mas nunca ligada: " .. f) end
end
for f in pairs(flags_set) do
    if not flags_used[f] then warn("flag ligada, mas nunca usada: " .. f) end
end
for trigger in pairs(TRIGGERS) do
    local generic = false
    for _, ending in ipairs(content.endings) do
        if ending.trigger == trigger and not ending.requires then generic = true end
    end
    if not generic then err("gatilho sem final genérico: " .. trigger) end
end
local has_election = false
for _, card in ipairs(content.cards) do
    if card.left and card.left.resolve == "election" then has_election = true end
end
if not has_election then err("nenhuma carta de eleição") end

local counts, by_char = 0, {}
for _, card in ipairs(content.cards) do
    counts = counts + 1
    by_char[card.char] = (by_char[card.char] or 0) + 1
end
for id in pairs(content.characters) do
    if not by_char[id] then warn("personagem sem carta: " .. id) end
end
for _, w in ipairs(warnings) do print("aviso: " .. w) end
for _, e in ipairs(errors) do print("ERRO: " .. e) end
print(string.format("%d cartas, %d finais, %d erros, %d avisos", counts, #content.endings, #errors, #warnings))
os.exit(#errors == 0 and 0 or 1)
