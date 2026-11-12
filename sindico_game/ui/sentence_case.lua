local Letters = require("sindico_game/letters")

-- A choice label as written in the cards, in sentence case: only the first letter is made uppercase, after any
-- opening sign (¿, ¡, a quote), and the rest stays as written, so names keep their capitals and short words such
-- as "de" stay in lowercase. A label that starts with a number, such as 18h, stays as it is.
local function sentence_case(text)
    local chars = Letters.split(text)
    for i, char in ipairs(chars) do
        if char:match("^%d$") then
            break
        elseif Letters.upper(char) ~= Letters.lower(char) then
            chars[i] = Letters.upper(char)
            break
        end
    end
    return table.concat(chars)
end

return sentence_case
