-- Run with Lua 5.3+ or: hs -c 'dofile("/path/to/WindowSnap.spoon/tests/move.lua")'
-- Window frames and modifiers are mocked; no desktop windows are moved.
local source = debug.getinfo(1, "S").source:sub(2)
local root = assert(source:match("^(.*)tests[/]move.lua$"))
local screen = { x = -1600, y = 70, w = 1200, h = 900 }
local current, shiftHeld
local checks = 0

local function copy(frame)
    return { x = frame.x, y = frame.y, w = frame.w, h = frame.h }
end

local environment = setmetatable({ hs = {
    window = { focusedWindow = function() return current end },
    eventtap = { checkKeyboardModifiers = function() return { shift = shiftHeld } end },
} }, { __index = _G })
local snap = assert(loadfile(root .. "init.lua", "t", environment))()
snap.aerospacePath = nil

local function near(actual, expected, label)
    assert(math.abs(actual - expected) < 0.000001,
        label .. ": expected " .. expected .. ", got " .. actual)
    checks = checks + 1
end

local function horizontal(direction)
    return direction == "left" or direction == "right"
end

local function frameAt(direction, ratio)
    local f = { x = screen.x + 120, y = screen.y + 90, w = 420, h = 360 }
    if horizontal(direction) then
        f.w = screen.w * ratio
        f.x = direction == "left" and screen.x or screen.x + screen.w - f.w
    else
        f.h = screen.h * ratio
        f.y = direction == "up" and screen.y or screen.y + screen.h - f.h
    end
    return f
end

local function use(frame)
    current = {
        value = copy(frame),
        id = function() return 42 end,
        screen = function() return { frame = function() return copy(screen) end } end,
        frame = function(self) return copy(self.value) end,
        setFrame = function(self, f) self.value = copy(f) end,
    }
    shiftHeld = false
end

local function expect(direction, ratio, before)
    local expected = frameAt(direction, ratio)
    if horizontal(direction) then
        expected.y, expected.h = before.y, before.h
    else
        expected.x, expected.w = before.x, before.w
    end
    for _, key in ipairs({ "x", "y", "w", "h" }) do
        near(current.value[key], expected[key], direction .. " " .. key)
    end
end

local opposite = { left = "right", right = "left", up = "down", down = "up" }
for _, direction in ipairs({ "left", "right", "up", "down" }) do
    local first = (direction == "left" or direction == "up") and 2/3 or 1/3
    local second = 1 - first
    use(frameAt(direction, 0.5))
    for _, ratio in ipairs({ first, second, 0.5, first, second, 0.5 }) do
        local before = current:frame()
        snap:move(direction)
        expect(direction, ratio, before)
    end

    -- Manual resizing after earlier commands must replace any prior cycle position.
    for _, ratio in ipairs({ 1/3, 2/3, 0.5, 0.505 }) do
        current.value = frameAt(direction, ratio)
        local expected = ratio > 0.49 and ratio < 0.51 and first
            or (math.abs(ratio - first) < 0.01 and second or 0.5)
        local before = current:frame()
        snap:move(direction)
        expect(direction, expected, before)
    end

    for _, ratio in ipairs({ 1, 0.42, 0.25 }) do
        use(frameAt(direction, ratio))
        local before = current:frame()
        snap:move(direction)
        expect(direction, 0.5, before)
    end

    -- Moving to the opposite edge still takes the complementary size.
    for _, sizes in ipairs({ {1/3, 2/3}, {2/3, 1/3}, {0.5, 0.5}, {0.42, 0.5} }) do
        use(frameAt(opposite[direction], sizes[1]))
        local before = current:frame()
        snap:move(direction)
        expect(direction, sizes[2], before)
        before = current:frame()
        snap:move(direction)
        local expected = sizes[2] == 0.5 and first
            or (math.abs(sizes[2] - first) < 0.01 and second or 0.5)
        expect(direction, expected, before)
    end

    -- Shift toggles any non-full edge size to full, then half.
    for _, ratio in ipairs({ 0.5, 1/3, 2/3, 0.42 }) do
        use(frameAt(direction, ratio))
        shiftHeld = true
        for _, nextRatio in ipairs({ 1, 0.5 }) do
            local before = current:frame()
            snap:move(direction)
            expect(direction, nextRatio, before)
        end
        shiftHeld = false
        local before = current:frame()
        snap:move(direction)
        expect(direction, first, before)
    end

    -- Shift moves thirds one slot at a time; other sizes go straight to the edge.
    for _, ratio in ipairs({ 1/3, 0.5, 2/3, 0.42 }) do
        use(frameAt(opposite[direction], ratio))
        shiftHeld = true
        local before = current:frame()
        snap:move(direction)
        if ratio == 1/3 then
            local key, dimension = horizontal(direction) and "x" or "y",
                horizontal(direction) and "w" or "h"
            near(current.value[key], screen[key] + screen[dimension] / 3, "middle slot")
            near(current.value.w, before.w, "slot width")
            near(current.value.h, before.h, "slot height")
            local other = horizontal(direction) and "y" or "x"
            near(current.value[other], before[other], "slot other position")
            snap:move(direction)
        end
        expect(direction, ratio, before)
    end
end

-- Real window frames can round fractional sizes and positions to whole pixels.
screen.w, screen.h = 1199, 901
for _, direction in ipairs({ "left", "right", "up", "down" }) do
    local order = (direction == "left" or direction == "up")
        and { 0.5, 2/3, 1/3 } or { 0.5, 1/3, 2/3 }
    for index, ratio in ipairs(order) do
        local rounded = frameAt(direction, ratio)
        for key, value in pairs(rounded) do
            rounded[key] = math.floor(value + 0.5)
        end
        use(rounded)
        local before = current:frame()
        snap:move(direction)
        expect(direction, order[index % #order + 1], before)
    end
end

assert(snap:resetState(42) == snap and snap:resetState() == snap)
current = nil
snap:move("left") -- No focused window.
print("PASS: " .. checks .. " frame assertions; all four directions, resize, complements, and Shift")
