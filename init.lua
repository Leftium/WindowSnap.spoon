--- === WindowSnap ===
---
--- Windows Snap-style window management with Raycast-style size cycling.
--- Snaps windows to screen edges/corners with configurable size cycling.
---
--- Features:
---  * Two modes: Windows-style (half-screen) and fine-grained (corner snapping)
---  * Cycles through sizes (1/2, 1/3, 2/3) when pressing same direction repeatedly
---  * AeroSpace integration: ignores tiled windows (lets AeroSpace handle them)
---  * Works standalone without AeroSpace
---
--- Quick start:
---   hs.loadSpoon("WindowSnap")
---   spoon.WindowSnap:bindHotkeys({
---       snapLeft = {{"ctrl", "alt"}, "left"},
---       snapRight = {{"ctrl", "alt"}, "right"},
---       snapUp = {{"ctrl", "alt"}, "up"},
---       snapDown = {{"ctrl", "alt"}, "down"},
---   })
---
--- With fine-grained control (independent axes):
---   spoon.WindowSnap:bindHotkeys({
---       fineLeft = {{"shift", "ctrl", "alt"}, "left"},
---       fineRight = {{"shift", "ctrl", "alt"}, "right"},
---       fineUp = {{"shift", "ctrl", "alt"}, "up"},
---       fineDown = {{"shift", "ctrl", "alt"}, "down"},
---   })
---
--- Manual usage:
---   spoon.WindowSnap:move("left")
---   spoon.WindowSnap:move("left", { sizes = { 0.5, 1 }, independentAxes = false })
---
--- Download: https://github.com/leftium/WindowSnap.spoon

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "WindowSnap"
obj.version = "2.0.0"
obj.author = "Leftium <john@leftium.com>"
obj.homepage = "https://github.com/leftium/WindowSnap.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- WindowSnap.sizes
--- Variable
--- Default size ratios to cycle through. Default: { 0.5, 1/3, 2/3 }
obj.sizes = { 0.5, 1/3, 2/3 }

--- WindowSnap.independentAxes
--- Variable
--- Default independent axes mode. When true, horizontal and vertical axes are
--- independent (allows corner snapping). When false, Windows-style behavior
--- where horizontal movement resets height to 100%. Default: true
obj.independentAxes = true

--- WindowSnap.aerospacePath
--- Variable
--- Path to aerospace binary. Default: "/opt/homebrew/bin/aerospace"
--- Set to nil to disable AeroSpace integration.
obj.aerospacePath = "/opt/homebrew/bin/aerospace"

-- Private: Per-window state: widthIndex, heightIndex, lastH, lastV
obj._windowState = {}

-- Check if AeroSpace is running and focused window is tiled (not floating)
local function isAerospaceTiled(aerospacePath)
    if not aerospacePath then return false end

    -- Check if aerospace is running
    if not hs.application.find("AeroSpace") then
        return false
    end

    -- Get aerospace's focused window ID
    local aeroWinId, status = hs.execute(aerospacePath .. " list-windows --focused --format '%{window-id}' 2>/dev/null")
    if not status or aeroWinId:gsub("%s+", "") == "" then
        return false  -- aerospace not responding or no focused window
    end
    aeroWinId = aeroWinId:gsub("%s+", "")

    -- Check if window is tiled (treeNodeParent contains "TilingContainer" for tiled windows)
    local output = hs.execute(aerospacePath .. " debug-windows --window-id " .. aeroWinId .. " 2>/dev/null")
    local isTiled = output:find("TilingContainer", 1, true) ~= nil
    return isTiled
end

--- WindowSnap:move(direction, options)
--- Method
--- Move/snap the focused window in the given direction.
--- Repeating the same direction cycles through sizes.
---
--- Parameters:
---  * direction - "left", "right", "up", or "down"
---  * options - optional table with:
---    * sizes - array of size ratios to cycle through (default: WindowSnap.sizes)
---    * independentAxes - boolean, true for corner snapping (default: WindowSnap.independentAxes)
---    * resetOnDirectionChange - boolean, reset to first size when changing direction (default: false)
---
--- Returns:
---  * None
function obj:move(direction, options)
    local win = hs.window.focusedWindow()
    if not win then return end

    -- Skip if AeroSpace is managing this window (tiled)
    if isAerospaceTiled(self.aerospacePath) then return end

    local winId = win:id()

    options = options or {}
    local sizes = options.sizes or self.sizes
    local independentAxes = options.independentAxes
    if independentAxes == nil then independentAxes = self.independentAxes end
    local resetOnDirectionChange = options.resetOnDirectionChange or false

    local screen = win:screen():frame()
    local isHorizontal = (direction == "left" or direction == "right")

    -- Initialize state for this window
    if not self._windowState[winId] then
        self._windowState[winId] = { widthIndex = 0, heightIndex = 0, lastH = "left", lastV = "up" }
    end
    local state = self._windowState[winId]

    -- Cycle size only if same direction, otherwise just move (or reset if option set)
    if isHorizontal then
        if direction == state.lastH then
            state.widthIndex = (state.widthIndex % #sizes) + 1
        elseif resetOnDirectionChange then
            state.widthIndex = 1  -- Reset to first size on direction change
        elseif state.widthIndex == 0 then
            state.widthIndex = 1  -- Initialize on first horizontal move
        end
        state.lastH = direction
        -- Windows-style: horizontal resets vertical to 100%
        if not independentAxes then
            state.heightIndex = 0
        end
    else
        if direction == state.lastV then
            state.heightIndex = (state.heightIndex % #sizes) + 1
        elseif resetOnDirectionChange then
            state.heightIndex = 1  -- Reset to first size on direction change
        elseif state.heightIndex == 0 then
            state.heightIndex = 1  -- Initialize on first vertical move
        end
        state.lastV = direction
        -- Windows-style: vertical does NOT reset horizontal (allows corners)
    end

    -- Get sizes (default to full screen if axis not yet set)
    local widthRatio = state.widthIndex > 0 and sizes[state.widthIndex] or 1
    local heightRatio = state.heightIndex > 0 and sizes[state.heightIndex] or 1

    local f = {
        w = screen.w * widthRatio,
        h = screen.h * heightRatio,
    }
    f.x = screen.x + (state.lastH == "right" and (screen.w - f.w) or 0)
    f.y = screen.y + (state.lastV == "down" and (screen.h - f.h) or 0)

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

-- Windows-style options: resets size on direction change, height resets to 100% on horizontal
local windowsStyle = { sizes = { 0.5, 1/3, 2/3 }, independentAxes = false, resetOnDirectionChange = true }

-- Fine-grained options: independent axes for corner snapping
local fineGrained = { sizes = { 0.5, 1/3, 2/3 }, independentAxes = true }

--- WindowSnap:bindHotkeys(mapping)
--- Method
--- Bind hotkeys for window snapping using standard Hammerspoon format.
---
--- Parameters:
---  * mapping - A table with action names as keys and hotkey specs as values.
---    Each hotkey spec is a table: {{modifiers}, key}
---    Supported actions:
---      * snapLeft, snapRight, snapUp, snapDown - Windows-style snapping
---      * fineLeft, fineRight, fineUp, fineDown - Fine-grained corner snapping
---
--- Returns:
---  * The WindowSnap object
---
--- Notes:
---  * Windows-style (snap*): Resets to 50% when changing direction, height resets to 100% on horizontal
---  * Fine-grained (fine*): Axes are independent, keeps size when changing direction
---  * If AeroSpace is running and window is tiled, hotkeys do nothing (AeroSpace handles it)
---
--- Example:
---  ```lua
---  spoon.WindowSnap:bindHotkeys({
---      snapLeft = {{"ctrl", "alt"}, "left"},
---      snapRight = {{"ctrl", "alt"}, "right"},
---      snapUp = {{"ctrl", "alt"}, "up"},
---      snapDown = {{"ctrl", "alt"}, "down"},
---      fineLeft = {{"shift", "ctrl", "alt"}, "left"},
---      fineRight = {{"shift", "ctrl", "alt"}, "right"},
---      fineUp = {{"shift", "ctrl", "alt"}, "up"},
---      fineDown = {{"shift", "ctrl", "alt"}, "down"},
---  })
---  ```
function obj:bindHotkeys(mapping)
    local spec = {
        snapLeft = hs.fnutils.partial(self.move, self, "left", windowsStyle),
        snapRight = hs.fnutils.partial(self.move, self, "right", windowsStyle),
        snapUp = hs.fnutils.partial(self.move, self, "up", windowsStyle),
        snapDown = hs.fnutils.partial(self.move, self, "down", windowsStyle),
        fineLeft = hs.fnutils.partial(self.move, self, "left", fineGrained),
        fineRight = hs.fnutils.partial(self.move, self, "right", fineGrained),
        fineUp = hs.fnutils.partial(self.move, self, "up", fineGrained),
        fineDown = hs.fnutils.partial(self.move, self, "down", fineGrained),
    }
    hs.spoons.bindHotkeysToSpec(spec, mapping)
    return self
end

return obj
