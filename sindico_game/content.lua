local Content = {}

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
