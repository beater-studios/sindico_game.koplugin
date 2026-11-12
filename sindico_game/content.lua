local Content = {}

Content.LANGUAGES = { pt = true, en = true, es = true }
-- The cards, endings, characters and help are written in Portuguese in data/; the other languages are layers in
-- data/i18n/<language>/ with the same ids, which replace only the texts.
Content.SOURCE_LANGUAGE = "pt"

-- Data files run in an empty environment and can only return a table, as tools/data_check.lua loads them.
local function load_table(path)
    local chunk, err = loadfile(path)
    if not chunk then
        error(err, 0)
    end
    setfenv(chunk, {})
    local ok, result = pcall(chunk)
    if not ok then
        error(tostring(result), 0)
    end
    if type(result) ~= "table" then
        error(path .. ": should return a table, returned " .. type(result), 0)
    end
    return result
end
Content.load_table = load_table

-- The first two letters of KOReader's language (pt_BR is pt), and English for any language the game does not have.
function Content.language_from(setting)
    local prefix = tostring(setting or ""):sub(1, 2):lower()
    return Content.LANGUAGES[prefix] and prefix or "en"
end

-- The interface texts of one language.
function Content.strings(dir, lang)
    return load_table(dir .. "/data/i18n.lua")[lang or Content.SOURCE_LANGUAGE]
end

local TEXT_FIELDS = { "label", "result", "minutes" }

local function translate_card(card, layer)
    if type(layer) ~= "table" then
        return
    end
    card.text = layer.text or card.text
    for _, side in ipairs({ "left", "right" }) do
        local choice, translated = card[side], layer[side]
        if type(choice) == "table" and type(translated) == "table" then
            for _, field in ipairs(TEXT_FIELDS) do
                if choice[field] ~= nil and translated[field] ~= nil then
                    choice[field] = translated[field]
                end
            end
        end
    end
end

-- Everything the game shows, in `lang` (Portuguese by default). A text missing from a layer stays in Portuguese;
-- tools/validate.lua makes sure none is missing.
function Content.load(dir, lang)
    lang = lang or Content.SOURCE_LANGUAGE
    local manifest = load_table(dir .. "/data/manifest.lua")
    local content = {
        lang = lang,
        meta = load_table(dir .. "/_meta.lua"),
        characters = load_table(dir .. "/data/characters.lua"),
        endings = load_table(dir .. "/data/endings.lua"),
        help = load_table(dir .. "/data/help.lua"),
        cards = {},
    }
    local layers = lang ~= Content.SOURCE_LANGUAGE and (dir .. "/data/i18n/" .. lang)
    for _, name in ipairs(manifest) do
        local translated = layers and load_table(layers .. "/decks/" .. name .. ".lua") or {}
        for _, card in ipairs(load_table(dir .. "/data/decks/" .. name .. ".lua")) do
            card.deck = name
            translate_card(card, translated[card.id])
            content.cards[#content.cards + 1] = card
        end
    end
    if layers then
        for id, character in pairs(load_table(layers .. "/characters.lua")) do
            local target = content.characters[id]
            if target then
                target.name = character.name or target.name
                target.role = character.role or target.role
            end
        end
        local endings = load_table(layers .. "/endings.lua")
        for _, ending in ipairs(content.endings) do
            local translated = endings[ending.id]
            if translated then
                ending.title = translated.title or ending.title
                ending.text = translated.text or ending.text
            end
        end
        -- The layer has the texts; the illustration of each item comes from the Portuguese help.
        for i, item in ipairs(load_table(layers .. "/help.lua")) do
            local target = content.help[i]
            if target then
                target.title = item.title or target.title
                target.text = item.text or target.text
            end
        end
    end
    return content
end

return Content
