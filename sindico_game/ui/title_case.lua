local LOWERCASE_WORDS = {}
for word in ("a à ao aos as às até com da das de do dos e em na nas no nos o os ou para por pra que se sem um uma umas uns"):gmatch("%S+") do
    LOWERCASE_WORDS[word] = true
end

local ACCENTED_UPPER = {
    ["á"] = "Á", ["à"] = "À", ["â"] = "Â", ["ã"] = "Ã", ["é"] = "É", ["ê"] = "Ê",
    ["í"] = "Í", ["ó"] = "Ó", ["ô"] = "Ô", ["õ"] = "Õ", ["ú"] = "Ú", ["ç"] = "Ç",
}

local function capitalize(word)
    local first = word:sub(1, 2)
    if ACCENTED_UPPER[first] then
        return ACCENTED_UPPER[first] .. word:sub(3)
    end
    return word:sub(1, 1):upper() .. word:sub(2)
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
