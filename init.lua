--- === WindowSnap ===
---
--- Windows Snap-style window management with complement-based snapping.
---
--- Features:
---  * Unshifted: Snap to edge with complement size (1/3<->2/3, 1/2<->1/2), preserve other axis
---  * Unshifted at edge: Toggle 100% <-> 50%
---  * Shifted: Move between slots (for tiling sizes 1/2, 1/3), preserving size
---  * Shifted at edge: Cycle 1/2 -> 1/3 -> 2/3
---  * AeroSpace integration: ignores tiled windows
---
--- Quick start:
---   hs.loadSpoon("WindowSnap")
---   spoon.WindowSnap:bindHotkeys({
---       left  = {{"ctrl", "alt"}, "left"},
---       right = {{"ctrl", "alt"}, "right"},
---       up    = {{"ctrl", "alt"}, "up"},
---       down  = {{"ctrl", "alt"}, "down"},
---   })
---
--- Download: https://github.com/leftium/WindowSnap.spoon

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "WindowSnap"
obj.version = "3.0.0"
obj.author = "Leftium <john@leftium.com>"
obj.homepage = "https://github.com/leftium/WindowSnap.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- WindowSnap.aerospacePath
--- Variable
--- Path to aerospace binary. Default: "/opt/homebrew/bin/aerospace"
--- Set to nil to disable AeroSpace integration.
obj.aerospacePath = "/opt/homebrew/bin/aerospace"

-- Private: Per-window state
obj._windowState = {}

-- Private: Cache for tiled status {windowId, isTiled, timestamp}
obj._tiledCache = {windowId = nil, isTiled = false, timestamp = 0}
obj._tiledCacheTTL = 2  -- seconds

-- Tiling sizes for cycling
local cycleSizes = { 0.5, 1/3, 2/3 }

-- Helper: Get complement size (1/3 <-> 2/3, 1/2 <-> 1/2)
local function getComplementSize(ratio)
    local tolerance = 0.01
    if math.abs(ratio - 1/3) < tolerance then return 2/3 end
    if math.abs(ratio - 2/3) < tolerance then return 1/3 end
    if math.abs(ratio - 0.5) < tolerance then return 0.5 end
    return 0.5  -- non-tiling sizes default to 50%
end

-- Helper: Get index in cycleSizes, or 0 if not found
local function getCycleSizeIndex(ratio)
    local tolerance = 0.01
    for i, size in ipairs(cycleSizes) do
        if math.abs(ratio - size) < tolerance then return i end
    end
    return 0
end

-- Check if AeroSpace is running and focused window is tiled (with caching)
local function isAerospaceTiled(self)
    if not self.aerospacePath then return false end
    if not hs.application.find("AeroSpace") then return false end

    local aeroWinId, status = hs.execute(self.aerospacePath .. " list-windows --focused --format '%{window-id}' 2>/dev/null")
    if not status or aeroWinId:gsub("%s+", "") == "" then return false end
    aeroWinId = aeroWinId:gsub("%s+", "")

    -- Check cache
    local cache = self._tiledCache
    local now = os.time()
    if cache.windowId == aeroWinId and (now - cache.timestamp) < self._tiledCacheTTL then
        return cache.isTiled
    end

    -- Cache miss - check if tiled
    local output = hs.execute(self.aerospacePath .. " debug-windows --window-id " .. aeroWinId .. " 2>/dev/null")
    local isTiled = output:find("TilingContainer", 1, true) ~= nil

    -- Update cache
    self._tiledCache = {windowId = aeroWinId, isTiled = isTiled, timestamp = now}
    return isTiled
end

--- WindowSnap:move(direction)
--- Method
--- Move window in the given direction.
---
--- Unshifted behavior:
---  * Not at target edge: Snap to target edge with complement size, preserve other axis
---  * At target edge: Toggle 100% <-> 50%
---
--- Shifted behavior:
---  * Tiling size (1/2, 1/3): Move between slots, preserve size
---  * At target edge: Cycle 1/2 -> 1/3 -> 2/3
---  * Non-tiling size: Move to target edge, preserve size
---
--- Parameters:
---  * direction - "left", "right", "up", or "down"
---
--- Returns:
---  * None
function obj:move(direction)
    local win = hs.window.focusedWindow()
    if not win then return end

    local winId = win:id()
    local shiftHeld = hs.eventtap.checkKeyboardModifiers().shift

    -- For tiled windows, delegate to AeroSpace if available
    if isAerospaceTiled(self) then
        if shiftHeld then
            -- Giga-arrow: focus in direction
            hs.execute(self.aerospacePath .. " focus " .. direction)
        else
            -- Mega-arrow: move or cycle size
            local binDir = self.aerospacePath:gsub("/[^/]+$", "")
            local scriptPath = os.getenv("HOME") .. "/.config/bin/aerospace-move-or-cycle-size"
            hs.execute("PATH=" .. binDir .. ":/usr/bin:/bin " .. scriptPath .. " " .. direction)
        end
        return
    end
    local screen = win:screen():frame()
    local f = win:frame()
    local isHorizontal = (direction == "left" or direction == "right")
    local tolerance = 10

    -- Initialize state for this window
    if not self._windowState[winId] then
        self._windowState[winId] = { widthIndex = 1, heightIndex = 1 }
    end
    local state = self._windowState[winId]

    -- Detect current position and size
    local atLeftEdge = f.x <= screen.x + tolerance
    local atRightEdge = f.x + f.w >= screen.x + screen.w - tolerance
    local atTopEdge = f.y <= screen.y + tolerance
    local atBottomEdge = f.y + f.h >= screen.y + screen.h - tolerance

    local widthRatio = f.w / screen.w
    local heightRatio = f.h / screen.h
    local isFullWidth = math.abs(widthRatio - 1) < 0.01
    local isFullHeight = math.abs(heightRatio - 1) < 0.01

    if isHorizontal then
        local targetEdge = (direction == "left") and "left" or "right"
        local atTargetEdge
        if direction == "left" then
            atTargetEdge = atLeftEdge
        else
            atTargetEdge = atRightEdge
        end

        if atTargetEdge then
            -- AT TARGET EDGE: Cycle or maximize
            if shiftHeld then
                -- Shifted cycling: 1/2 -> 1/3 -> 2/3 -> 1/2...
                state.widthIndex = (state.widthIndex % #cycleSizes) + 1
                widthRatio = cycleSizes[state.widthIndex]
            else
                -- Unshifted at edge: toggle 100% <-> 50%
                if isFullWidth then
                    widthRatio = 0.5
                    state.widthIndex = 1
                else
                    widthRatio = 1
                    state.widthIndex = 0  -- 0 means 100%
                end
            end
            -- Stay at target edge
            f.w = screen.w * widthRatio
            f.x = (targetEdge == "left") and screen.x or (screen.x + screen.w - f.w)
            -- Preserve height and y when cycling
        else
            -- NOT AT TARGET EDGE: Snap or move
            if shiftHeld then
                -- Shifted: Move between slots (for tiling sizes) or to edge
                -- Check if width tiles evenly (1/n where n is integer)
                local tilesEvenly = math.abs(widthRatio - 1/math.floor(1/widthRatio + 0.5)) < 0.01
                if tilesEvenly then
                    local slotWidth = screen.w * widthRatio
                    local maxSlot = math.floor(1 / widthRatio + 0.5) - 1
                    local currentSlot = math.floor((f.x - screen.x) / slotWidth + 0.5)
                    currentSlot = math.max(0, math.min(maxSlot, currentSlot))

                    if direction == "left" and currentSlot > 0 then
                        currentSlot = currentSlot - 1
                        f.x = screen.x + currentSlot * slotWidth
                    elseif direction == "right" and currentSlot < maxSlot then
                        currentSlot = currentSlot + 1
                        f.x = screen.x + currentSlot * slotWidth
                    else
                        -- At edge already, snap to edge
                        f.x = (targetEdge == "left") and screen.x or (screen.x + screen.w - f.w)
                    end
                else
                    -- Non-tiling size: just move to edge
                    f.x = (targetEdge == "left") and screen.x or (screen.x + screen.w - f.w)
                end
                -- Preserve width and height
            else
                -- Unshifted: Snap with complement width, preserve height
                local complementWidth = getComplementSize(widthRatio)
                state.widthIndex = getCycleSizeIndex(complementWidth)
                f.w = screen.w * complementWidth
                f.x = (targetEdge == "left") and screen.x or (screen.x + screen.w - f.w)
                -- Preserve height and y
            end
        end
    else
        -- Vertical (up/down)
        local targetEdge = (direction == "up") and "top" or "bottom"
        local atTargetEdge
        if direction == "up" then
            atTargetEdge = atTopEdge
        else
            atTargetEdge = atBottomEdge
        end

        if atTargetEdge then
            -- AT TARGET EDGE: Cycle or maximize
            if shiftHeld then
                -- Shifted cycling: 1/2 -> 1/3 -> 2/3 -> 1/2...
                state.heightIndex = (state.heightIndex % #cycleSizes) + 1
                heightRatio = cycleSizes[state.heightIndex]
            else
                -- Unshifted at edge: toggle 100% <-> 50%
                if isFullHeight then
                    heightRatio = 0.5
                    state.heightIndex = 1
                else
                    heightRatio = 1
                    state.heightIndex = 0  -- 0 means 100%
                end
            end
            -- Stay at target edge
            f.h = screen.h * heightRatio
            f.y = (targetEdge == "top") and screen.y or (screen.y + screen.h - f.h)
            -- Preserve width and x when cycling
        else
            -- NOT AT TARGET EDGE: Snap or move
            if shiftHeld then
                -- Shifted: Move between slots (for tiling sizes) or to edge
                -- Check if height tiles evenly (1/n where n is integer)
                local tilesEvenly = math.abs(heightRatio - 1/math.floor(1/heightRatio + 0.5)) < 0.01
                if tilesEvenly then
                    local slotHeight = screen.h * heightRatio
                    local maxSlot = math.floor(1 / heightRatio + 0.5) - 1
                    local currentSlot = math.floor((f.y - screen.y) / slotHeight + 0.5)
                    currentSlot = math.max(0, math.min(maxSlot, currentSlot))

                    if direction == "up" and currentSlot > 0 then
                        currentSlot = currentSlot - 1
                        f.y = screen.y + currentSlot * slotHeight
                    elseif direction == "down" and currentSlot < maxSlot then
                        currentSlot = currentSlot + 1
                        f.y = screen.y + currentSlot * slotHeight
                    else
                        -- At edge already, snap to edge
                        f.y = (targetEdge == "top") and screen.y or (screen.y + screen.h - f.h)
                    end
                else
                    -- Non-tiling size: just move to edge
                    f.y = (targetEdge == "top") and screen.y or (screen.y + screen.h - f.h)
                end
                -- Preserve width and height
            else
                -- Unshifted: Snap with complement height, preserve width
                local complementHeight = getComplementSize(heightRatio)
                state.heightIndex = getCycleSizeIndex(complementHeight)
                f.h = screen.h * complementHeight
                f.y = (targetEdge == "top") and screen.y or (screen.y + screen.h - f.h)
                -- Preserve width and x
            end
        end
    end

    win:setFrame(f, 0)
end

--- WindowSnap:resetState(winId)
--- Method
--- Reset the cycling state for a specific window (or all windows if nil).
---
--- Parameters:
---  * winId - window ID to reset, or nil to reset all
---
--- Returns:
---  * The WindowSnap object
function obj:resetState(winId)
    if winId then
        self._windowState[winId] = nil
    else
        self._windowState = {}
    end
    return self
end

--- WindowSnap:bindHotkeys(mapping)
--- Method
--- Bind hotkeys for window snapping.
--- Automatically binds both normal and Shift variants for runtime Shift detection.
---
--- Parameters:
---  * mapping - A table with action names as keys and hotkey specs as values.
---    Each hotkey spec is a table: {modifiers, key}
---    Supported actions: left, right, up, down
---
--- Returns:
---  * The WindowSnap object
---
--- Notes:
---  * Unshifted: Snap to edge with complement size (1/3<->2/3), preserve other axis
---  * Unshifted at edge: Toggle 100% <-> 50%
---  * Shifted: Move between slots (for tiling sizes), preserving size
---  * Shifted at edge: Cycle 1/2 -> 1/3 -> 2/3
---  * If AeroSpace is running and window is tiled, hotkeys do nothing
---
--- Example:
---  ```lua
---  spoon.WindowSnap:bindHotkeys({
---      left  = {{"ctrl", "alt"}, "left"},
---      right = {{"ctrl", "alt"}, "right"},
---      up    = {{"ctrl", "alt"}, "up"},
---      down  = {{"ctrl", "alt"}, "down"},
---  })
---  ```
function obj:bindHotkeys(mapping)
    local spec = {
        left  = hs.fnutils.partial(self.move, self, "left"),
        right = hs.fnutils.partial(self.move, self, "right"),
        up    = hs.fnutils.partial(self.move, self, "up"),
        down  = hs.fnutils.partial(self.move, self, "down"),
    }
    hs.spoons.bindHotkeysToSpec(spec, mapping)

    -- Also bind with Shift added (for runtime Shift detection)
    for action, hotkeySpec in pairs(mapping) do
        local mods = hotkeySpec[1]
        local key = hotkeySpec[2]
        local modsWithShift = {table.unpack(mods)}
        table.insert(modsWithShift, "shift")
        hs.hotkey.bind(modsWithShift, key, function() self:move(action) end)
    end

    return self
end

return obj
