local Engine = {}
Engine.__index = Engine

Engine.METERS = { "residents", "funds", "building", "patience" }
Engine.MANDATE_DAYS = 720
Engine.DEFAULT_CARD_DAYS = 12
Engine.MAX_MANDATES = 5
Engine.START_VALUE = 50
Engine.ELECTION_MIN = 50
Engine.DIFFICULTY_STEP = 0.15

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

function Engine:new_game()
    local meters = {}
    for _, name in ipairs(Engine.METERS) do
        meters[name] = Engine.START_VALUE
    end
    self.state = {
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
    self.state.current = self:draw()
    return self.state
end

function Engine:load(state)
    self.state = state
    if state and state.current and not self.content.by_id[state.current] then
        state.current = self:draw()
    end
    return state
end

function Engine:serialize()
    return self.state
end

function Engine:difficulty()
    return 1 + (self.state.mandate - 1) * Engine.DIFFICULTY_STEP
end

Engine.MANDATE_MONTHS = Engine.MANDATE_DAYS / 30

function Engine:month()
    return math.min(Engine.MANDATE_MONTHS, math.floor(self.state.day / 30) + 1)
end

-- Mandates fully served. Winning the last election ends the game without
-- starting a new mandate, so that one is counted through `won_all`.
function Engine.completed_mandates(state)
    return state.mandate - 1 + (state.won_all and 1 or 0)
end

-- Days in office. The election card may push the day past the end of the
-- mandate, so each mandate counts at most MANDATE_DAYS.
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

function Engine:pool(avoid_char)
    local pool, total = {}, 0
    for _, card in ipairs(self.content.cards) do
        if not card.chain and not card.at_day and self:is_eligible(card)
            and (not avoid_char or card.char ~= avoid_char) then
            local weight = card.weight or 1
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
        -- Out of cards: let regular cards repeat, but never the mandatory ones.
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
    if choice.minutes then
        s.minutes[#s.minutes + 1] = { mandate = s.mandate, month = self:month(), text = choice.minutes }
    end
    s.used[card.id] = true
    s.used_ever[card.id] = true
    s.last_char = card.char
    s.decisions = s.decisions + 1
    s.day = s.day + (choice.days or card.days or Engine.DEFAULT_CARD_DAYS)
    s.last = { result = choice.result, deltas = deltas }

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
