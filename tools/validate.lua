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

local function key_set(list)
    local set = {}
    for word in list:gmatch("%S+") do set[word] = true end
    return set
end
local CARD_KEYS = key_set("id char text left right requires weight days chain at_day once_ever deck")
local CHOICE_KEYS = key_set("label result effects set clear next schedule minutes ending resolve days")
local REQUIRES_KEYS = key_set("flags not_flags min max day_min day_max mandate_min")
local SCHEDULE_KEYS = key_set("card days")
local ENDING_KEYS = key_set("id trigger requires title text good")
local ENDING_REQUIRES_KEYS = key_set("flags not_flags")
local RESOLVE = { election = true }

local function check_keys(where, t, allowed)
    if type(t) ~= "table" then
        err(where .. ": deveria ser uma tabela")
        return
    end
    for k in pairs(t) do
        if not allowed[k] then err(where .. ": chave desconhecida " .. tostring(k)) end
    end
end
local function check_integer(where, value, min)
    if value ~= nil and (type(value) ~= "number" or value % 1 ~= 0 or value < min) then
        err(where .. ": deveria ser um inteiro a partir de " .. min)
    end
end
local function file_exists(path)
    local f = io.open(path, "rb")
    if f then f:close() end
    return f ~= nil
end

local seen, flags_set, flags_used, targeted, ending_refs = {}, {}, {}, {}, {}
local function check_meter_table(where, t)
    for k, v in pairs(t or {}) do
        if not meters[k] then err(where .. ": medidor desconhecido " .. tostring(k)) end
        if type(v) ~= "number" or v % 1 ~= 0 then err(where .. "." .. tostring(k) .. ": deveria ser um inteiro") end
    end
end

for _, card in ipairs(content.cards) do
    local where = "carta " .. tostring(card.id)
    if not card.id or not card.id:match("^[a-z0-9_]+$") then err(where .. ": id inválido") end
    if seen[card.id] then err(where .. ": id repetido") end
    seen[card.id] = true
    if not content.characters[card.char] then err(where .. ": personagem desconhecido " .. tostring(card.char)) end
    if not card.text or ulen(card.text) > 240 then err(where .. ": text ausente ou maior que 240") end
    check_keys(where, card, CARD_KEYS)
    check_integer(where .. ".weight", card.weight, 1)
    check_integer(where .. ".days", card.days, 1)
    check_integer(where .. ".at_day", card.at_day, 0)
    for _, side in ipairs({ "left", "right" }) do
        local c = card[side]
        if not c then
            err(where .. ": falta " .. side)
        else
            local w = where .. "." .. side
            check_keys(w, c, CHOICE_KEYS)
            check_integer(w .. ".days", c.days, 1)
            if c.resolve and not RESOLVE[c.resolve] then err(w .. ": resolve desconhecido " .. tostring(c.resolve)) end
            if not c.label or ulen(c.label) > 22 then err(w .. ": label ausente ou maior que 22") end
            if not c.result or ulen(c.result) > 90 then err(w .. ": result ausente ou maior que 90") end
            if c.minutes and ulen(c.minutes) > 80 then err(w .. ": minutes maior que 80") end
            check_meter_table(w, c.effects)
            for _, f in ipairs(c.set or {}) do flags_set[f] = true end
            if c.next then targeted[c.next] = true end
            if c.schedule then
                check_keys(w .. ".schedule", c.schedule, SCHEDULE_KEYS)
                check_integer(w .. ".schedule.days", c.schedule.days, 1)
                targeted[c.schedule.card] = true
                if not c.schedule.days then warn(w .. ": schedule sem days") end
            end
            if c.ending then ending_refs[c.ending] = true end
        end
    end
    local r = card.requires
    if r then
        check_keys(where .. ".requires", r, REQUIRES_KEYS)
        check_integer(where .. ".requires.day_min", r.day_min, 0)
        check_integer(where .. ".requires.day_max", r.day_max, 0)
        check_integer(where .. ".requires.mandate_min", r.mandate_min, 1)
        check_meter_table(where .. ".requires.min", r.min)
        check_meter_table(where .. ".requires.max", r.max)
        for _, f in ipairs(r.flags or {}) do flags_used[f] = true end
        for _, f in ipairs(r.not_flags or {}) do flags_used[f] = true end
    end
end

for _, ending in ipairs(content.endings) do
    local where = "final " .. tostring(ending.id)
    if not ending.title or not ending.text then err(where .. ": falta title ou text") end
    check_keys(where, ending, ENDING_KEYS)
    if ending.requires then check_keys(where .. ".requires", ending.requires, ENDING_REQUIRES_KEYS) end
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
    if card.chain and card.at_day then err("carta " .. card.id .. ": chain e at_day ao mesmo tempo") end
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
    local left = card.left and card.left.resolve == "election"
    local right = card.right and card.right.resolve == "election"
    if left or right then has_election = true end
    if left ~= right then err("carta " .. card.id .. ": só um lado resolve a eleição") end
    if card.at_day == Engine.MANDATE_DAYS and not (left and right) then
        err("carta " .. card.id .. ": carta do fim do mandato sem resolve = \"election\"")
    end
end
if not has_election then err("nenhuma carta de eleição") end

local counts, by_char = 0, {}
for _, card in ipairs(content.cards) do
    counts = counts + 1
    by_char[card.char] = (by_char[card.char] or 0) + 1
end
for id in pairs(content.characters) do
    if not by_char[id] then warn("personagem sem carta: " .. id) end
    if not file_exists("assets/portraits/" .. id .. ".png") then err("personagem sem retrato: assets/portraits/" .. id .. ".png") end
end
for _, w in ipairs(warnings) do print("aviso: " .. w) end
for _, e in ipairs(errors) do print("ERRO: " .. e) end
print(string.format("%d cartas, %d finais, %d erros, %d avisos", counts, #content.endings, #errors, #warnings))
os.exit(#errors == 0 and 0 or 1)
