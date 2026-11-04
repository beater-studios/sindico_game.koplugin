local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local Widget = require("ui/widget/widget")

local MeterBar = Widget:extend{
    value = 0,
    width = 0,
    height = 0,
}

function MeterBar:getSize()
    return Geom:new{ w = self.width, h = self.height }
end

function MeterBar:paintTo(bb, x, y)
    bb:paintRect(x, y, self.width, self.height, Blitbuffer.COLOR_WHITE)
    local fill = math.floor((self.width - 4) * self.value / 100 + 0.5)
    local color = self.value <= 20 and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_GRAY_5
    if fill > 0 then
        bb:paintRect(x + 2, y + 2, fill, self.height - 4, color)
    end
    bb:paintBorder(x, y, self.width, self.height, 2, Blitbuffer.COLOR_BLACK)
end

return MeterBar
