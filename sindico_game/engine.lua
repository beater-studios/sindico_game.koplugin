local SavedState = require("sindico_game/saved_state")

local Engine = {}
Engine.__index = Engine

Engine.METERS = { "residents", "funds", "building", "patience" }
Engine.MANDATE_DAYS = 720
Engine.DEFAULT_CARD_DAYS = 12
Engine.MAX_MANDATES = 5
Engine.START_VALUE = 50
Engine.ELECTION_MIN = 50
Engine.DIFFICULTY_STEP = 0.15
-- How much likelier a card not seen yet in the game is in the draw. Higher values cut repeats further but hold back
-- the hard cards that come back every term, which makes later terms easier (measured with the simulation).
Engine.UNSEEN_WEIGHT = 3
Engine.SAVE_VERSION = 1

local function has_flags(flags, list)
    for _, f in ipairs(list or {}) do
        if not flags[f] then return false end
    end
    return true
end

local function lacks_flags(flags, list)
    for _, f in ipairs(list or {}) do
        if flags[f] then return false end
    end
    return true
end

local function within(meters, min, max)
    for k, v in pairs(min or {}) do
        if meters[k] < v then return false end
    end
    for k, v in pairs(max or {}) do
        if meters[k] > v then return false end
    end
    return true
end

function Engine.index_content(content)
    content.by_id = {}
    for _, card in ipairs(content.cards) do
        content.by_id[card.id] = card
    end
    content.ending_by_id = {}
    for _, ending in ipairs(content.endings) do
        content.ending_by_id[ending.id] = ending
    end
    return content
end

function Engine.new(opts)
    local self = setmetatable({}, Engine)
    self.content = Engine.index_content(opts.content)
    self.random = opts.random or math.random
    self.state = nil
    return self
end

function Engine.new_state()
    local meters = {}
    for _, name in ipairs(Engine.METERS) do
        meters[name] = Engine.START_VALUE
    end
    return {
        meters = meters,
        day = 0,
        mandate = 1,
        used = {},
        used_ever = {},
        flags = {},
        queue = {},
        minutes = {},
        current = nil,
        last = nil,
        last_char = nil,
        decisions = 0,
        ending = nil,
    }
end

function Engine:new_game()
    self.state = Engine.new_state()
    self.state.current = self:draw()
    return self.state
end

-- A copy, so later moves do not change what was handed to the settings.
function Engine:serialize()
    local data = SavedState.copy(self.state)
    data.version = Engine.SAVE_VERSION
    return data
end

local function is_whole(value, min, max)
    return type(value) == "number" and value % 1 == 0 and value >= min and (not max or value <= max)
end

-- The keys of a saved set ({ id = true }) that pass `keep`.
local function saved_set(saved, keep)
    local out = {}
    for key, value in pairs(type(saved) == "table" and saved or {}) do
        if value == true and type(key) == "string" and keep(key) then
            out[key] = true
        end
    end
    return out
end

-- Restores a saved game in progress. Every part is checked before use, ids that left the content are dropped
-- and a missing current card is drawn again. Returns nil when the save does not fit, and the caller starts
-- without it. Saves from 1.0.x have no version and the same format, so they count as version 1.
function Engine:restore(data)
    if type(data) ~= "table" or (data.version or 1) ~= Engine.SAVE_VERSION or data.ending ~= nil then
        return nil
    end
    if type(data.meters) ~= "table" or not is_whole(data.day, 0)
        or not is_whole(data.mandate, 1, Engine.MAX_MANDATES) then
        return nil
    end
    local by_id = self.content.by_id
    local function known(id) return by_id[id] ~= nil end
    local s = Engine.new_state()
    for _, name in ipairs(Engine.METERS) do
        local value = data.meters[name]
        if not is_whole(value, 1, 100) then
            return nil
        end
        s.meters[name] = value
    end
    s.day, s.mandate = data.day, data.mandate
    s.decisions = is_whole(data.decisions, 0) and data.decisions or 0
    s.used = saved_set(data.used, known)
    s.used_ever = saved_set(data.used_ever, known)
    s.flags = saved_set(data.flags, function() return true end)
    -- The saved lists may have holes, and ipairs would stop at the first one.
    local queue = SavedState.list(data.queue)
    for i = 1, table.maxn(queue) do
        local item = queue[i]
        if type(item) == "table" and known(item.card) and is_whole(item.day, 0) then
            s.queue[#s.queue + 1] = { card = item.card, day = item.day }
        end
    end
    -- A minutes entry or the last decision keeps the card and the side when the card still has that text, and
    -- the text it was written with (`text` in the minutes, `result` in the last decision), which is all a save
    -- before 1.1.0 has and what is shown if the card is gone.
    local function kept(item, field, text_key)
        local out = {}
        if self:choice_field(item, field) ~= nil then
            out.card, out.side = item.card, item.side
        end
        if type(item[text_key]) == "string" then
            out[text_key] = item[text_key]
        end
        return (out.card or out[text_key]) and out or nil
    end
    local minutes = SavedState.list(data.minutes)
    for i = 1, table.maxn(minutes) do
        local entry = minutes[i]
        if type(entry) == "table" and is_whole(entry.mandate, 1) and is_whole(entry.month, 1) then
            local item = kept(entry, "minutes", "text")
            if item then
                item.mandate, item.month = entry.mandate, entry.month
                s.minutes[#s.minutes + 1] = item
            end
        end
    end
    local last = type(data.last) == "table" and kept(data.last, "result", "result")
    if last then
        last.deltas = {}
        for _, name in ipairs(Engine.METERS) do
            if type(data.last.deltas) == "table" and is_whole(data.last.deltas[name], -100, 100) then
                last.deltas[name] = data.last.deltas[name]
            end
        end
        last.reelected = data.last.reelected == true or nil
        s.last = last
    end
    if type(data.last_char) == "string" then
        s.last_char = data.last_char
    end
    self.state = s
    if known(data.current) then
        s.current = data.current
    else
        s.current = self:draw()
    end
    if not s.current then
        self.state = nil
        return nil
    end
    return s
end

function Engine:difficulty()
    return 1 + (self.state.mandate - 1) * Engine.DIFFICULTY_STEP
end

Engine.MANDATE_MONTHS = Engine.MANDATE_DAYS / 30

function Engine:month()
    return math.min(Engine.MANDATE_MONTHS, math.floor(self.state.day / 30) + 1)
end

function Engine.completed_mandates(state)
    return state.mandate - 1 + (state.won_all and 1 or 0)
end

function Engine.total_days(state)
    return (state.mandate - 1) * Engine.MANDATE_DAYS + math.min(state.day, Engine.MANDATE_DAYS)
end

function Engine:is_eligible(card)
    local s = self.state
    if s.used[card.id] then return false end
    if card.once_ever and s.used_ever[card.id] then return false end
    local req = card.requires
    if not req then return true end
    if not has_flags(s.flags, req.flags) then return false end
    if not lacks_flags(s.flags, req.not_flags) then return false end
    if not within(s.meters, req.min, req.max) then return false end
    if req.day_min and s.day < req.day_min then return false end
    if req.day_max and s.day > req.day_max then return false end
    if req.mandate_min and s.mandate < req.mandate_min then return false end
    return true
end

function Engine:take_due_scheduled()
    local s = self.state
    for i, item in ipairs(s.queue) do
        if s.day >= item.day then
            local card = self.content.by_id[item.card]
            table.remove(s.queue, i)
            if card and self:is_eligible(card) then
                return card.id
            end
            return self:take_due_scheduled()
        end
    end
end

function Engine:take_at_day()
    local s = self.state
    for _, card in ipairs(self.content.cards) do
        if card.at_day and s.day >= card.at_day and self:is_eligible(card) then
            return card.id
        end
    end
end

-- The cards the draw can pick, with their weights. A card not seen yet in the game weighs UNSEEN_WEIGHT times
-- more, so a new term brings mostly new cards.
function Engine:pool(avoid_char)
    local pool, total = {}, 0
    for _, card in ipairs(self.content.cards) do
        if not card.chain and not card.at_day and self:is_eligible(card)
            and (not avoid_char or card.char ~= avoid_char) then
            local weight = (card.weight or 1) * (self.state.used_ever[card.id] and 1 or Engine.UNSEEN_WEIGHT)
            pool[#pool + 1] = { id = card.id, weight = weight }
            total = total + weight
        end
    end
    return pool, total
end

function Engine:draw()
    local s = self.state
    local id = self:take_due_scheduled() or self:take_at_day()
    if id then return id end
    local pool, total = self:pool(s.last_char)
    if #pool == 0 then
        pool, total = self:pool(nil)
    end
    if #pool == 0 then
        for id in pairs(s.used) do
            local card = self.content.by_id[id]
            if not (card and card.at_day) then s.used[id] = nil end
        end
        pool, total = self:pool(nil)
    end
    if #pool == 0 then return nil end
    local roll = self.random(total)
    for _, item in ipairs(pool) do
        roll = roll - item.weight
        if roll <= 0 then return item.id end
    end
    return pool[#pool].id
end

-- A field of the choice a minutes entry or the last decision points to ({ card, side }), or nil.
function Engine:choice_field(item, field)
    local card = type(item) == "table" and self.content.by_id[item.card]
    local choice = card and (item.side == "left" or item.side == "right") and card[item.side]
    return choice and choice[field]
end

-- The text to show for a minutes entry or the last decision: the card's, in the current language, or the text
-- kept with it when the card is gone.
function Engine:choice_text(item, field, kept)
    return self:choice_field(item, field) or (type(item) == "table" and item[kept]) or nil
end

function Engine:current_card()
    return self.state.current and self.content.by_id[self.state.current]
end

function Engine:apply_effects(effects)
    local s = self.state
    local deltas = {}
    local difficulty = self:difficulty()
    for name, value in pairs(effects or {}) do
        local amount = value
        if amount < 0 then
            amount = math.floor(amount * difficulty + 0.5)
        end
        local before = s.meters[name]
        s.meters[name] = math.max(0, math.min(100, before + amount))
        deltas[name] = s.meters[name] - before
    end
    return deltas
end

function Engine:find_ending_for(trigger)
    local s = self.state
    for _, ending in ipairs(self.content.endings) do
        if ending.trigger == trigger then
            local req = ending.requires
            if not req or (has_flags(s.flags, req.flags) and lacks_flags(s.flags, req.not_flags)) then
                return ending.id
            end
        end
    end
end

function Engine:finish(ending_id)
    self.state.ending = ending_id
    self.state.current = nil
    return ending_id
end

function Engine:zero_ending()
    for _, name in ipairs(Engine.METERS) do
        if self.state.meters[name] <= 0 then
            return self:find_ending_for("zero:" .. name)
        end
    end
end

function Engine:next_mandate()
    local s = self.state
    s.mandate = s.mandate + 1
    s.day = 0
    s.used = {}
    s.queue = {}
    for _, name in ipairs(Engine.METERS) do
        s.meters[name] = math.floor(s.meters[name] + (Engine.START_VALUE - s.meters[name]) / 3 + 0.5)
    end
end

function Engine:resolve_election()
    local s = self.state
    if s.meters.residents < Engine.ELECTION_MIN then
        return self:find_ending_for("election_lost")
    end
    if s.mandate >= Engine.MAX_MANDATES then
        s.won_all = true
        return self:find_ending_for("all_mandates")
    end
    self:next_mandate()
end

function Engine:choose(side)
    local s = self.state
    local card = self:current_card()
    local choice = card and card[side]
    if not choice then return nil end

    local deltas = self:apply_effects(choice.effects)
    for _, f in ipairs(choice.set or {}) do s.flags[f] = true end
    for _, f in ipairs(choice.clear or {}) do s.flags[f] = nil end
    if choice.schedule then
        s.queue[#s.queue + 1] = {
            card = choice.schedule.card,
            day = s.day + (choice.schedule.days or Engine.DEFAULT_CARD_DAYS),
        }
    end
    -- The minutes and the last result keep the card and the side, so they are shown in the current language,
    -- and also the text, for a card a later version removes and for versions before 1.1.0, which only read it.
    if choice.minutes then
        s.minutes[#s.minutes + 1] = {
            mandate = s.mandate, month = self:month(), card = card.id, side = side, text = choice.minutes,
        }
    end
    s.used[card.id] = true
    s.used_ever[card.id] = true
    s.last_char = card.char
    s.decisions = s.decisions + 1
    s.day = s.day + (choice.days or card.days or Engine.DEFAULT_CARD_DAYS)
    s.last = { card = card.id, side = side, result = choice.result, deltas = deltas }

    local ending = choice.ending or self:zero_ending()
    if not ending and choice.resolve == "election" then
        local mandate_before = s.mandate
        ending = self:resolve_election()
        if not ending and s.mandate > mandate_before then
            s.last.reelected = true
        end
    end
    if ending then
        self:finish(ending)
        return s
    end
    s.current = choice.next or self:draw()
    if not s.current then
        self:finish(self:find_ending_for("no_cards"))
    end
    return s
end

function Engine.new_stats()
    return { games = 0, decisions = 0, best_mandates = 0, best_days = 0, endings = {} }
end

-- Saved records, field by field: a field missing from an older save gets its default, and an ending count
-- that is not a whole number is dropped.
function Engine.restore_stats(saved)
    local stats = SavedState.with_defaults(saved, Engine.new_stats())
    for _, field in ipairs({ "games", "decisions", "best_mandates", "best_days" }) do
        if not is_whole(stats[field], 0) then
            stats[field] = 0
        end
    end
    local endings = {}
    for id, count in pairs(stats.endings) do
        if type(id) == "string" and is_whole(count, 1) then
            endings[id] = count
        end
    end
    stats.endings = endings
    if type(stats.newest_ending) ~= "string" or not endings[stats.newest_ending] then
        stats.newest_ending = nil
    end
    return stats
end

function Engine:record_ending(stats)
    local s = self.state
    stats.games = stats.games + 1
    stats.decisions = stats.decisions + s.decisions
    stats.endings[s.ending] = (stats.endings[s.ending] or 0) + 1
    local won = Engine.completed_mandates(s)
    if won > stats.best_mandates then stats.best_mandates = won end
    local days = Engine.total_days(s)
    if days > stats.best_days then stats.best_days = days end
    return stats
end

return Engine
