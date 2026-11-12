-- A screen laid out in the units of the mockups (600x800), scaled to the real screen and centered. Laying out
-- builds a list of things to paint and of tap areas; painting only replays the list. Every text that does not
-- fit the room it was given is noted in `problems`, which tools/koreader/check_layout.lua reads.
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local ImageWidget = require("ui/widget/imagewidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")

local Canvas = {}
Canvas.__index = Canvas

Canvas.UNITS_W, Canvas.UNITS_H = 600, 800

-- The 16 grays of the screen, by brightness.
Canvas.BLACK, Canvas.DARK, Canvas.MID, Canvas.LIGHT, Canvas.PALE, Canvas.PAPER, Canvas.WHITE = 0, 68, 136, 187, 221, 238, 255

Canvas.SANS = "noto/NotoSans-Regular.ttf"
Canvas.SANS_BOLD = "noto/NotoSans-Bold.ttf"
Canvas.SERIF = "noto/NotoSerif-Regular.ttf"
Canvas.SERIF_BOLD = "noto/NotoSerif-Bold.ttf"
Canvas.SERIF_ITALIC = "noto/NotoSerif-Italic.ttf"

local function color(value)
    return Blitbuffer.Color8(value)
end

function Canvas.new(width, height)
    local self = setmetatable({}, Canvas)
    self.width, self.height = width, height
    self.s = math.min(width / Canvas.UNITS_W, height / Canvas.UNITS_H)
    self.ox = math.floor((width - Canvas.UNITS_W * self.s) / 2)
    self.oy = math.floor((height - Canvas.UNITS_H * self.s) / 2)
    self.items, self.hits, self.problems, self.bottom = {}, {}, {}, 0
    return self
end

function Canvas:px(v)
    return math.floor(v * self.s + 0.5)
end

function Canvas:x(v)
    return self.ox + self:px(v)
end

function Canvas:y(v)
    return self.oy + self:px(v)
end

-- Font:getFace multiplies the size by the screen scale; sizes here are already in pixels.
function Canvas:face(name, size)
    local factor = Device.screen:scaleBySize(1000) / 1000
    return Font:getFace(name, math.max(6, size * self.s / factor))
end

function Canvas:reach(y)
    if y > self.bottom then
        self.bottom = y
    end
end

function Canvas:problem(text)
    self.problems[#self.problems + 1] = text
end

-- A rectangle with rounded corners: fill and border are grays (nil for none), width and radius in units.
function Canvas:box(x0, y0, x1, y1, opts)
    opts = opts or {}
    self.items[#self.items + 1] = {
        kind = "box", x = self:x(x0), y = self:y(y0), w = self:px(x1 - x0), h = self:px(y1 - y0),
        fill = opts.fill, border = opts.border, bw = math.max(1, self:px(opts.width or 2)), r = self:px(opts.radius or 0),
    }
    self:reach(y1)
end

-- A straight line, horizontal or vertical.
function Canvas:line(x0, y0, x1, y1, value, width)
    local bw = math.max(1, self:px(width or 2))
    local x, y = self:x(math.min(x0, x1)), self:y(math.min(y0, y1))
    local w = x0 == x1 and bw or self:px(math.abs(x1 - x0))
    local h = y0 == y1 and bw or self:px(math.abs(y1 - y0))
    self.items[#self.items + 1] = { kind = "rect", x = x, y = y, w = w, h = h, fill = value or Canvas.BLACK }
    self:reach(math.max(y0, y1))
end

-- The width, in units, of a text on one line.
function Canvas:measure(text, font, size)
    local widget = TextWidget:new{ text = text, face = self:face(font, size) }
    local w = widget:getSize().w
    widget:free()
    return w / self.s
end

-- One line of text. anchor: left (default), center or right of x; middle: y is the vertical center instead of
-- the top. With room, a text wider than that is a problem. Returns the width in units.
function Canvas:text(x, y, text, font, size, opts)
    opts = opts or {}
    local widget = TextWidget:new{
        text = text, face = self:face(font, size), fgcolor = color(opts.color or Canvas.BLACK),
        max_width = opts.room and self:px(opts.room) or nil,
    }
    local w, h = self:measure(text, font, size), widget:getSize().h / self.s
    if opts.room and w > opts.room then
        self:problem(string.format("text does not fit in %s: %s", opts.name or "a line", text))
    end
    local shown = math.min(w, opts.room or w)
    local left = x
    if opts.anchor == "center" then
        left = x - shown / 2
    elseif opts.anchor == "right" then
        left = x - shown
    end
    local top = opts.middle and y - h / 2 or y
    self.items[#self.items + 1] = { kind = "widget", widget = widget, x = self:x(left), y = self:y(top) }
    self:reach(top + h)
    return w
end

-- The height, in units, of a wrapped text.
function Canvas:measure_paragraph(text, font, size, width)
    local widget = TextBoxWidget:new{ text = text, face = self:face(font, size), width = self:px(width) }
    local h = widget:getSize().h
    widget:free()
    return h / self.s
end

-- A wrapped text. align: left, center (default) or right; background: the gray behind it. With room (a
-- height), a taller text is a problem. Returns the bottom, in units.
function Canvas:paragraph(x, y, width, text, font, size, opts)
    opts = opts or {}
    local widget = TextBoxWidget:new{
        text = text, face = self:face(font, size), width = self:px(width), alignment = opts.align or "center",
        fgcolor = color(opts.color or Canvas.BLACK), bgcolor = color(opts.background or Canvas.WHITE),
    }
    local h = widget:getSize().h / self.s
    if opts.room and h > opts.room + 0.5 then
        self:problem(string.format("text taller than its room in %s: %s", opts.name or "a paragraph", text))
    end
    self.items[#self.items + 1] = { kind = "widget", widget = widget, x = self:x(x), y = self:y(y) }
    self:reach(y + h)
    return y + h
end

-- An image file (PNG or SVG), stretched to w x h units, with an optional frame.
function Canvas:image(file, x, y, w, h, opts)
    opts = opts or {}
    local widget = ImageWidget:new{ file = file, width = self:px(w), height = self:px(h or w), alpha = opts.alpha }
    self.items[#self.items + 1] = { kind = "widget", widget = widget, x = self:x(x), y = self:y(y) }
    if opts.frame then
        self:box(x, y, x + w, y + (h or w), { border = Canvas.BLACK, width = opts.frame })
    end
    self:reach(y + (h or w))
end

-- A tap area, in units, and what it does.
function Canvas:hit(x0, y0, x1, y1, action)
    self.hits[#self.hits + 1] = {
        rect = Geom:new{ x = self:x(x0), y = self:y(y0), w = self:px(x1 - x0), h = self:px(y1 - y0) },
        action = action,
    }
end

-- The action of the topmost tap area under a screen point, or nil.
function Canvas:action_at(x, y)
    for i = #self.hits, 1, -1 do
        local rect = self.hits[i].rect
        if x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h then
            return self.hits[i].action
        end
    end
end

-- The bottom of everything laid out, in screen pixels.
function Canvas:content_height()
    return self:y(self.bottom)
end

function Canvas:paint(bb, x, y)
    for _, item in ipairs(self.items) do
        if item.kind == "box" then
            if item.fill then
                if item.r > 0 then
                    bb:paintRoundedRect(x + item.x, y + item.y, item.w, item.h, color(item.fill), item.r)
                else
                    bb:paintRect(x + item.x, y + item.y, item.w, item.h, color(item.fill))
                end
            end
            if item.border then
                bb:paintBorder(x + item.x, y + item.y, item.w, item.h, item.bw, color(item.border), item.r)
            end
        elseif item.kind == "rect" then
            bb:paintRect(x + item.x, y + item.y, item.w, item.h, color(item.fill))
        elseif item.kind == "lighten" then
            bb:lightenRect(x + item.x, y + item.y, item.w, item.h, item.by)
        else
            item.widget:paintTo(bb, x + item.x, y + item.y)
        end
    end
end

-- Everything painted so far, faded: for a dialog over a screen.
function Canvas:fade(by)
    self.items[#self.items + 1] = { kind = "lighten", x = 0, y = 0, w = self.width, h = self.height, by = by }
end

function Canvas:free()
    for _, item in ipairs(self.items) do
        if item.widget then
            item.widget:free()
        end
    end
    self.items, self.hits = {}, {}
end

return Canvas
