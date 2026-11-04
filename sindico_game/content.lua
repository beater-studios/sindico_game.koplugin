local Content = {}

local function load_table(path)
    local chunk, err = loadfile(path)
    if not chunk then error(err) end
    setfenv(chunk, {})
    return chunk()
end

function Content.load(dir)
    local manifest = load_table(dir .. "/data/manifest.lua")
    local content = {
        meta = load_table(dir .. "/_meta.lua"),
        characters = load_table(dir .. "/data/characters.lua"),
        endings = load_table(dir .. "/data/endings.lua"),
        help = load_table(dir .. "/data/help.lua"),
        cards = {},
    }
    for _, name in ipairs(manifest) do
        for _, card in ipairs(load_table(dir .. "/data/decks/" .. name .. ".lua")) do
            card.deck = name
            content.cards[#content.cards + 1] = card
        end
    end
    return content
end

return Content
