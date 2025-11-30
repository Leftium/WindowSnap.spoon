--- === WindowSnap ===
---
--- Windows Snap-style window management with size cycling.
--- Snaps windows to screen edges with configurable size cycling.
---
--- Features:
---  * Left/right snaps to edge, cycles width at edge (resets to 50% width, 100% height)
---  * Up/down snaps to edge, cycles height at edge (resets to 50% height, preserves width)
---  * Tiling sizes (1/2, 1/3) have multiple slots; non-tiling (2/3) snaps to edges
---  * Hold Shift to preserve size and move between slots
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

--- WindowSnap.sizes
--- Variable
--- Size ratios to cycle through. Default: { 0.5, 1/3, 2/3 }
obj.sizes = { 0.5, 1/3, 2/3 }

--- WindowSnap.aerospacePath
--- Variable
--- Path to aerospace binary. Default: "/opt/homebrew/bin/aerospace"
--- Set to nil to disable AeroSpace integration.
obj.aerospacePath = "/opt/homebrew/bin/aerospace"

-- Private: Per-window state
obj._windowState = {}

-- Check if AeroSpace is running and focused window is tiled
local function isAerospaceTiled(aerospacePath)
    if not aerospacePath then return false end
    if not hs.application.find("AeroSpace") then return false end

    local aeroWinId, status = hs.execute(aerospacePath .. " list-windows --focused --format '%{window-id}' 2>/dev/null")
    if not status or aeroWinId:gsub("%s+", "") == "" then return false end
    aeroWinId = aeroWinId:gsub("%s+", "")

    local output = hs.execute(aerospacePath .. " debug-windows --window-id " .. aeroWinId .. " 2>/dev/null")
    return output:find("TilingContainer", 1, true) ~= nil
end

--- WindowSnap:move(direction)
--- Method
--- Move window in the given direction between slots; cycle size at edges.
--- Left/right resets height to 100% (hold Shift to preserve).
--- Up/down preserves width.
---
--- Parameters:
---  * direction - "left", "right", "up", or "down"
---
--- Returns:
---  * None
function obj:move(direction)
    local win = hs.window.focusedWindow()
    if not win then return end
    if isAerospaceTiled(self.aerospacePath) then return end

    local winId = win:id()
    local sizes = self.sizes
    local preserveSize = hs.eventtap.checkKeyboardModifiers().shift
    local screen = win:screen():frame()
    local currentFrame = win:frame()
    local isHorizontal = (direction == "left" or direction == "right")

    -- Initialize state for this window (only tracks size indices now)
    if not self._windowState[winId] then
        self._windowState[winId] = { widthIndex = 1, heightIndex = 0 }
    end
    local state = self._windowState[winId]

    -- Get current size ratios
    local widthRatio = state.widthIndex > 0 and sizes[state.widthIndex] or 1
    local heightRatio = state.heightIndex > 0 and sizes[state.heightIndex] or 1

    if isHorizontal then
        local slotWidth = screen.w * widthRatio
        -- Only allow multiple slots for sizes that tile evenly (1/n where n is integer)
        local tilesEvenly = math.abs(widthRatio - 1/math.floor(1/widthRatio + 0.5)) < 0.01
        local maxSlot = tilesEvenly and (math.floor(1 / widthRatio + 0.5) - 1) or 0
        local currentSlot = math.floor((currentFrame.x - screen.x) / slotWidth + 0.5)
        currentSlot = math.max(0, math.min(maxSlot, currentSlot))  -- clamp

        -- For non-tiling sizes, detect actual edge position
        local atLeftEdge = currentFrame.x <= screen.x + 10
        local atRightEdge = currentFrame.x + currentFrame.w >= screen.x + screen.w - 10

        local cycling = false
        if direction == "left" then
            if atLeftEdge then
                -- At left edge: cycle width
                state.widthIndex = (state.widthIndex % #sizes) + 1
                widthRatio = sizes[state.widthIndex]
                currentSlot = 0
                cycling = true
            elseif preserveSize and tilesEvenly and currentSlot > 0 then
                -- Shift held: move between slots
                currentSlot = currentSlot - 1
            else
                -- Snap to left edge
                currentSlot = 0
            end
        else -- right
            if atRightEdge then
                -- At right edge: cycle width, stay on right edge
                state.widthIndex = (state.widthIndex % #sizes) + 1
                widthRatio = sizes[state.widthIndex]
                currentSlot = -1  -- flag: right edge
                cycling = true
            elseif preserveSize and tilesEvenly and currentSlot < maxSlot then
                -- Shift held: move between slots
                currentSlot = currentSlot + 1
            else
                -- Snap to right edge
                currentSlot = -1
            end
        end

        -- Reset when snapping (not cycling), unless Shift held
        if not cycling and not preserveSize then
            state.widthIndex = 1  -- Reset width to 50%
            widthRatio = sizes[1]
            state.heightIndex = 0  -- Reset height to 100%
            heightRatio = 1
            -- Snap to edge in direction of movement
            currentSlot = (direction == "left") and 0 or -1
        end

        local f = {
            w = screen.w * widthRatio,
            h = screen.h * heightRatio,
            x = currentSlot == -1
                and (screen.x + screen.w - screen.w * widthRatio)
                or (screen.x + currentSlot * screen.w * widthRatio),
            y = preserveSize and currentFrame.y or screen.y,
        }
        win:setFrame(f, 0)
    else
        local slotHeight = screen.h * heightRatio
        -- Only allow multiple slots for sizes that tile evenly (1/n where n is integer)
        local tilesEvenly = math.abs(heightRatio - 1/math.floor(1/heightRatio + 0.5)) < 0.01
        local maxSlot = tilesEvenly and (math.floor(1 / heightRatio + 0.5) - 1) or 0
        local currentSlot = math.floor((currentFrame.y - screen.y) / slotHeight + 0.5)
        currentSlot = math.max(0, math.min(maxSlot, currentSlot))  -- clamp

        -- For non-tiling sizes, detect actual edge position
        local atTopEdge = currentFrame.y <= screen.y + 10
        local atBottomEdge = currentFrame.y + currentFrame.h >= screen.y + screen.h - 10

        local cycling = false
        if direction == "up" then
            if atTopEdge then
                -- At top edge: cycle height
                state.heightIndex = (state.heightIndex % #sizes) + 1
                heightRatio = sizes[state.heightIndex]
                currentSlot = 0
                cycling = true
            elseif preserveSize and tilesEvenly and currentSlot > 0 then
                -- Shift held: move between slots
                currentSlot = currentSlot - 1
            else
                -- Snap to top edge
                currentSlot = 0
            end
        else -- down
            if atBottomEdge then
                -- At bottom edge: cycle height, stay at bottom
                state.heightIndex = (state.heightIndex % #sizes) + 1
                heightRatio = sizes[state.heightIndex]
                currentSlot = -1  -- flag: bottom edge
                cycling = true
            elseif preserveSize and tilesEvenly and currentSlot < maxSlot then
                -- Shift held: move between slots
                currentSlot = currentSlot + 1
            else
                -- Snap to bottom edge
                currentSlot = -1
            end
        end

        -- Reset height to 50% when snapping (not cycling), unless Shift held
        if not cycling and not preserveSize then
            state.heightIndex = 1  -- Reset to first size (50%)
            heightRatio = sizes[1]
            -- Snap to edge in direction of movement
            currentSlot = (direction == "up") and 0 or -1
        end

        -- Preserve current x position and width
        local f = {
            w = currentFrame.w,
            h = screen.h * heightRatio,
            x = currentFrame.x,
            y = currentSlot == -1
                and (screen.y + screen.h - screen.h * heightRatio)
                or (screen.y + currentSlot * screen.h * heightRatio),
        }
        win:setFrame(f, 0)
    end
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
---  * Left/right moves between slots, cycles width at edges (resets height to 100%)
---  * Up/down moves between slots, cycles height at edges (preserves width)
---  * Hold Shift to preserve height on left/right
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
