-- The language choice and the translated content.
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

check("pt_BR is Portuguese", Content.language_from("pt_BR") == "pt")
check("es_ES is Spanish", Content.language_from("es_ES") == "es")
check("en is English", Content.language_from("en") == "en")
check("another language is English", Content.language_from("fr") == "en")
check("no language is English", Content.language_from(nil) == "en")

local pt, en, es = Content.load(".", "pt"), Content.load(".", "en"), Content.load(".", "es")
check("same cards in every language", #pt.cards == #en.cards and #pt.cards == #es.cards)
-- Everything but the texts, compared level by level: effects, flags, schedules, endings, requirements.
local TEXTS = { text = true, label = true, result = true, minutes = true }
local function same_rules(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return a == b
    end
    for key, value in pairs(a) do
        if not TEXTS[key] and not same_rules(value, b[key]) then return false end
    end
    for key in pairs(b) do
        if not TEXTS[key] and a[key] == nil then return false end
    end
    return true
end
local translated, same = 0, 0
for i, card in ipairs(pt.cards) do
    if en.cards[i].id == card.id and es.cards[i].id == card.id
        and en.cards[i].text ~= card.text and es.cards[i].text ~= card.text then
        translated = translated + 1
    end
    if same_rules(card, en.cards[i]) and same_rules(card, es.cards[i]) then
        same = same + 1
    end
end
check("every card text is translated", translated == #pt.cards)
check("the rules are the same in every language", same == #pt.cards)
check("character names", en.characters.neide.name == "Mrs. Neide" and es.characters.neide.name == "Doña Neide")
check("the cat is Admiral in English", en.characters.almirante.name == "Admiral")
check("help in every language", #en.help == #pt.help and #es.help == #pt.help)
for _, lang in ipairs({ "pt", "en", "es" }) do
    check("interface texts in " .. lang, type(Content.strings(".", lang).new_game) == "string")
end

-- A game played in Portuguese shows its minutes in English after KOReader changes language.
local played = Engine.new({ content = Content.load(".", "pt"), random = function() return 1 end })
played:new_game()
local guard = 0
while #played.state.minutes == 0 and not played.state.ending and guard < 200 do
    guard = guard + 1
    local card = played:current_card()
    played:choose(card.left.minutes and "left" or "right")
end
check("a game with minutes", #played.state.minutes > 0)
local saved = SavedState.copy(played:serialize())
local english = Engine.new({ content = Content.load(".", "en") })
local pt_text = played:choice_text(played.state.minutes[1], "minutes", "text")
if english:restore(SavedState.copy(saved)) then
    local en_text = english:choice_text(english.state.minutes[1], "minutes", "text")
    check("the minutes follow the language", type(en_text) == "string" and en_text ~= pt_text)
else
    check("restored in English", false)
end
-- The saved text is what 1.0.x reads, and what is shown if a later version removes the card.
check("the minutes keep the text for older versions", saved.minutes[1].text == pt_text)
check("the last decision keeps the text for older versions", type(saved.last.result) == "string")
local gone = SavedState.copy(saved)
gone.minutes[1].card = "card_that_left"
local without = Engine.new({ content = Content.load(".", "en") })
if without:restore(gone) then
    check("a removed card keeps its minutes line", #without.state.minutes == #saved.minutes
        and without:choice_text(without.state.minutes[1], "minutes", "text") == pt_text)
else
    check("restored without the card", false)
end

-- Minutes saved by 1.0.2 keep the Portuguese text they were written with.
local chunk = assert(loadfile("tests/saves/1.0.2.lua"))
setfenv(chunk, {})
local old = chunk()
local reopened = Engine.new({ content = Content.load(".", "en") })
if reopened:restore(old.game) then
    check("old minutes are kept", #reopened.state.minutes == #old.game.minutes)
    check("old minutes keep their text", reopened:choice_text(reopened.state.minutes[1], "minutes", "text") == old.game.minutes[1].text)
else
    check("the 1.0.2 save opens", false)
end

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
