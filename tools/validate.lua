-- Checks the hand-written data in data/. Usage: luajit tools/validate.lua
package.path = "./?.lua;./tools/?.lua;" .. package.path
local Content = require("sindico_game/content")
local DataCheck = require("data_check")
local Engine = require("sindico_game/engine")

local loaded, content = pcall(Content.load, ".")
if not loaded then
    print("ERROR: " .. tostring(content))
    os.exit(1)
end
content = Engine.index_content(content)
local c = DataCheck.new()

local CARD = DataCheck.set("id char text left right requires weight days chain at_day once_ever deck")
local CHOICE = DataCheck.set("label result effects set clear next schedule minutes ending resolve days")
local REQUIRES = DataCheck.set("flags not_flags min max day_min day_max mandate_min")
local SCHEDULE = DataCheck.set("card days")
local ENDING = DataCheck.set("id trigger requires title text good")
local ENDING_REQUIRES = DataCheck.set("flags not_flags")
local CHARACTER = DataCheck.set("name role")
local HELP = DataCheck.set("title text")
local METERS = DataCheck.set(Engine.METERS)
local RESOLVE = DataCheck.set("election")
local TRIGGERS = DataCheck.set("election_lost all_mandates no_cards")
for _, meter in ipairs(Engine.METERS) do
    TRIGGERS["zero:" .. meter] = true
end

local function meter_table(where, t)
    if t ~= nil and c:table(where, t, METERS) then
        for meter, amount in pairs(t) do
            c:integer(where .. "." .. tostring(meter), amount, nil, nil, true)
        end
    end
end

local function flag_list(where, list, into)
    if list == nil then
        return
    end
    if type(list) ~= "table" then
        c:error(where .. ": should be a list")
        return
    end
    for i, flag in ipairs(list) do
        c:text(where .. "[" .. i .. "]", flag, nil, true)
        if type(flag) == "string" and into[flag] == nil then
            into[flag] = where
        end
    end
end

local known_chars = {}
for id, character in pairs(content.characters) do
    known_chars[id] = true
    local where = "character " .. tostring(id)
    if c:table(where, character, CHARACTER) then
        c:text(where .. ".name", character.name, nil, true)
        c:text(where .. ".role", character.role, nil, true)
    end
    c:file(where, "assets/portraits/" .. tostring(id) .. ".png")
end

for i, item in ipairs(content.help) do
    local where = "help " .. i
    if c:table(where, item, HELP) then
        c:text(where .. ".title", item.title, nil, true)
        c:text(where .. ".text", item.text, nil, true)
    end
end

local defined, card_uses, char_uses, ending_uses, flags_set, flags_read = {}, {}, {}, {}, {}, {}
local valid_cards = {}
for i, card in ipairs(content.cards) do
    local where = "card " .. tostring(type(card) == "table" and card.id or i)
    if c:table(where, card, CARD) then
        valid_cards[#valid_cards + 1] = card
        if type(card.id) ~= "string" or not card.id:match("^[a-z0-9_]+$") then
            c:error(where .. ": invalid id")
        elseif defined[card.id] then
            c:error(where .. ": repeated id")
        else
            defined[card.id] = true
        end
        c:text(where .. ".char", card.char, nil, true)
        if type(card.char) == "string" and char_uses[card.char] == nil then
            char_uses[card.char] = where
        end
        c:text(where .. ".text", card.text, 240, true)
        c:integer(where .. ".weight", card.weight, 1)
        c:integer(where .. ".days", card.days, 1)
        c:integer(where .. ".at_day", card.at_day, 0)
        for _, side in ipairs({ "left", "right" }) do
            local choice = card[side]
            local w = where .. "." .. side
            if c:table(w, choice, CHOICE) then
                c:text(w .. ".label", choice.label, 22, true)
                c:text(w .. ".result", choice.result, 90, true)
                c:text(w .. ".minutes", choice.minutes, 80)
                c:integer(w .. ".days", choice.days, 1)
                c:one_of(w .. ".resolve", choice.resolve, RESOLVE)
                meter_table(w .. ".effects", choice.effects)
                flag_list(w .. ".set", choice.set, flags_set)
                flag_list(w .. ".clear", choice.clear, {})
                if choice.next ~= nil then
                    c:text(w .. ".next", choice.next, nil, true)
                    card_uses[choice.next] = w .. ".next"
                end
                if choice.schedule ~= nil and c:table(w .. ".schedule", choice.schedule, SCHEDULE) then
                    c:text(w .. ".schedule.card", choice.schedule.card, nil, true)
                    c:integer(w .. ".schedule.days", choice.schedule.days, 1)
                    if choice.schedule.card ~= nil then
                        card_uses[choice.schedule.card] = w .. ".schedule"
                    end
                    if choice.schedule.days == nil then
                        c:warn(w .. ": schedule without days")
                    end
                end
                if choice.ending ~= nil then
                    c:text(w .. ".ending", choice.ending, nil, true)
                    ending_uses[choice.ending] = w .. ".ending"
                end
            end
        end
        local r = card.requires
        if r ~= nil and c:table(where .. ".requires", r, REQUIRES) then
            c:integer(where .. ".requires.day_min", r.day_min, 0)
            c:integer(where .. ".requires.day_max", r.day_max, 0)
            c:integer(where .. ".requires.mandate_min", r.mandate_min, 1)
            meter_table(where .. ".requires.min", r.min)
            meter_table(where .. ".requires.max", r.max)
            flag_list(where .. ".requires.flags", r.flags, flags_read)
            flag_list(where .. ".requires.not_flags", r.not_flags, flags_read)
        end
    end
end

local valid_endings = {}
for i, ending in ipairs(content.endings) do
    local where = "ending " .. tostring(type(ending) == "table" and ending.id or i)
    if c:table(where, ending, ENDING) then
        valid_endings[#valid_endings + 1] = ending
        c:text(where .. ".id", ending.id, nil, true)
        c:text(where .. ".title", ending.title, nil, true)
        c:text(where .. ".text", ending.text, 420, true)
        c:one_of(where .. ".trigger", ending.trigger, TRIGGERS)
        if ending.good ~= nil and type(ending.good) ~= "boolean" then
            c:error(where .. ".good: should be true or false")
        end
        if ending.requires ~= nil and c:table(where .. ".requires", ending.requires, ENDING_REQUIRES) then
            flag_list(where .. ".requires.flags", ending.requires.flags, flags_read)
            flag_list(where .. ".requires.not_flags", ending.requires.not_flags, flags_read)
        end
        if ending.trigger == nil and ending_uses[ending.id] == nil then
            c:error(where .. ": no card leads to this ending")
        end
    end
end

c:references("card", card_uses, defined)
c:references("ending", ending_uses, content.ending_by_id)
c:references("character", char_uses, known_chars, true)
c:references("flag", flags_read, flags_set)
local flags_used = {}
for flag in pairs(flags_read) do
    flags_used[flag] = true
end
for flag in pairs(flags_set) do
    if not flags_used[flag] then
        c:warn("flag set but never read: " .. flag)
    end
end

-- Rules of the game itself.
local has_election = false
for _, card in ipairs(valid_cards) do
    if card.chain and card_uses[card.id] == nil then
        c:error("card " .. tostring(card.id) .. ": chain card with no way in")
    end
    if card.chain and card.at_day then
        c:error("card " .. tostring(card.id) .. ": chain and at_day together")
    end
    local left = type(card.left) == "table" and card.left.resolve == "election"
    local right = type(card.right) == "table" and card.right.resolve == "election"
    if left or right then
        has_election = true
    end
    if left ~= right then
        c:error("card " .. tostring(card.id) .. ": only one side resolves the election")
    end
    if card.at_day == Engine.MANDATE_DAYS and not (left and right) then
        c:error("card " .. tostring(card.id) .. ": end of mandate card without resolve = \"election\"")
    end
end
if not has_election then
    c:error("no election card")
end
for trigger in pairs(TRIGGERS) do
    local generic = false
    for _, ending in ipairs(valid_endings) do
        if ending.trigger == trigger and ending.requires == nil then
            generic = true
        end
    end
    if not generic then
        c:error("trigger without a generic ending: " .. trigger)
    end
end

c:finish(string.format("%d cards, %d endings", #content.cards, #content.endings))
