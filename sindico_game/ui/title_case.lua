local Letters = require("sindico_game/letters")

local LOWERCASE_WORDS = {}
for word in ("a à ao aos as às até com da das de do dos e em na nas no nos o os ou para por pra que se sem um uma umas uns"):gmatch("%S+") do
    LOWERCASE_WORDS[word] = true
end

local function capitalize(word)
    local chars = Letters.split(word)
    if chars[1] then
        chars[1] = Letters.upper(chars[1])
    end
    return table.concat(chars)
end

local function title_case(text)
    local index = 0
    return (text:gsub("%S+", function(word)
        index = index + 1
        if index > 1 and LOWERCASE_WORDS[word] then
            return word
        end
        return capitalize(word)
    end))
end

return title_case
