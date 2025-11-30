--- === WindowSnap ===
---
--- Windows Snap-style window management with Raycast-style size cycling.
--- Snaps windows to screen edges/corners with configurable size cycling.
---
--- Features:
---  * Two modes: Windows-style (half-screen) and fine-grained (corner snapping)
---  * Cycles through sizes (1/2, 1/3, 2/3) when pressing same direction repeatedly
---  * AeroSpace integration: handles floating windows, passes tiled windows through
---  * Works standalone without AeroSpace
---
--- Quick start:
---   hs.loadSpoon("WindowSnap")
---   spoon.WindowSnap:bindHotkeys()  -- Ctrl+Alt+arrow (Windows-style), Shift+Ctrl+Alt+arrow (fine-grained)
---
--- Custom keys:
---   spoon.WindowSnap:bindHotkeys({ left = "h", right = "l", up = "k", down = "j" })
---
--- Custom modifiers:
---   spoon.WindowSnap:bindHotkeys({
---       windowsMod = {"ctrl", "alt", "cmd"},
---       fineMod = {"shift", "ctrl", "alt", "cmd"}
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
obj.version = "1.0.0"
obj.author = "John Googol <johngoogol@gmail.com>"
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

-- Per-window state: widthIndex, heightIndex, lastH, lastV
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

--- WindowSnap:toggle(direction)
--- Method
--- Toggle between 100% and the current cycle size for an axis.
--- Also moves/snaps the window in the given direction.
---
--- Parameters:
---  * direction - "left", "right", "up", or "down"
---
--- Returns:
---  * None
function obj:toggle(direction)
    local win = hs.window.focusedWindow()
    if not win then return end
    
    local screen = win:screen():frame()
    local winId = win:id()
    local isHorizontal = (direction == "left" or direction == "right")
    
    -- Initialize state for this window
    if not self._windowState[winId] then
        self._windowState[winId] = { widthIndex = 0, heightIndex = 0, lastH = "left", lastV = "up" }
    end
    local state = self._windowState[winId]
    
    -- Update direction
    if isHorizontal then
        state.lastH = direction
        -- Toggle: if at 100% (index 0), restore saved; otherwise save and go to 100%
        if state.widthIndex == 0 then
            if state.savedWidthIndex and state.savedWidthIndex > 0 then
                state.widthIndex = state.savedWidthIndex
            else
                state.widthIndex = 1
            end
        else
            state.savedWidthIndex = state.widthIndex
            state.widthIndex = 0
        end
    else
        state.lastV = direction
        -- Toggle: if at 100% (index 0), restore saved; otherwise save and go to 100%
        if state.heightIndex == 0 then
            if state.savedHeightIndex and state.savedHeightIndex > 0 then
                state.heightIndex = state.savedHeightIndex
            else
                state.heightIndex = 1
            end
        else
            state.savedHeightIndex = state.heightIndex
            state.heightIndex = 0
        end
    end
    
    -- Get sizes (index 0 = full screen)
    local widthRatio = state.widthIndex > 0 and self.sizes[state.widthIndex] or 1
    local heightRatio = state.heightIndex > 0 and self.sizes[state.heightIndex] or 1
    
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
---  * None
function obj:resetState(winId)
    if winId then
        self._windowState[winId] = nil
    else
        self._windowState = {}
    end
end

-- Key code mapping for eventtap
local keyCodes = {
    left = 123, right = 124, up = 126, down = 125,
    h = 4, j = 38, k = 40, l = 37,
}

-- Convert modifier names to eventtap flags
local function modifiersToFlags(mods)
    local flags = {}
    for _, m in ipairs(mods) do
        if m == "ctrl" then flags.ctrl = true
        elseif m == "alt" then flags.alt = true
        elseif m == "cmd" then flags.cmd = true
        elseif m == "shift" then flags.shift = true
        end
    end
    return flags
end

--- WindowSnap:bindHotkeys(mapping)
--- Method
--- Bind hotkeys for window snapping.
--- Uses eventtap for passthrough support with tiling window managers.
---
--- Parameters:
---  * mapping - optional table with:
---    * left, right, up, down - key names (default: arrow keys)
---    * windowsMod - modifiers for Windows-style snapping (default: {"ctrl", "alt"})
---    * fineMod - modifiers for fine-grained corner snapping (default: {"shift", "ctrl", "alt"})
---
--- Returns:
---  * The WindowSnap object
---
--- Notes:
---  * Windows-style mode: Resets to 50% when changing direction, height resets to 100% on horizontal move
---  * Fine-grained mode: Axes are independent, keeps size when changing direction
---  * If AeroSpace is running and window is tiled, key events pass through to AeroSpace
function obj:bindHotkeys(mapping)
    mapping = mapping or {}
    
    local keys = {
        left = mapping.left or "left",
        right = mapping.right or "right",
        up = mapping.up or "up",
        down = mapping.down or "down",
    }
    
    local windowsMod = mapping.windowsMod or {"ctrl", "alt"}
    local fineMod = mapping.fineMod or {"shift", "ctrl", "alt"}
    
    local windowsStyle = { sizes = { 0.5, 1/3, 2/3 }, independentAxes = false, resetOnDirectionChange = true }
    local fineGrained = { sizes = { 0.5, 1/3, 2/3 }, independentAxes = true }
    
    local windowsFlags = modifiersToFlags(windowsMod)
    local fineFlags = modifiersToFlags(fineMod)
    
    -- Build keycode to direction mapping
    local keyToDir = {}
    for dir, key in pairs(keys) do
        keyToDir[keyCodes[key]] = dir
    end
    
    -- Helper to check if all expected flags are set
    local function flagsMatch(current, expected)
        for k, v in pairs(expected) do
            if current[k] ~= v then return false end
        end
        -- Check no extra modifiers (except for fine which includes windows)
        local extraFlags = { ctrl = true, alt = true, cmd = true, shift = true }
        for k in pairs(expected) do extraFlags[k] = nil end
        for k in pairs(extraFlags) do
            if current[k] then return false end
        end
        return true
    end
    
    local aerospacePath = self.aerospacePath
    
    -- Use eventtap for passthrough support
    self._eventtap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
        local keyCode = event:getKeyCode()
        local flags = event:getFlags()
        local direction = keyToDir[keyCode]
        
        if not direction then return false end  -- Not our key, pass through
        
        -- Check if Windows-style modifiers match exactly
        if flagsMatch(flags, windowsFlags) then
            if isAerospaceTiled(aerospacePath) then return false end  -- Pass to AeroSpace
            self:move(direction, windowsStyle)
            return true  -- Consume event
        end
        
        -- Check if fine-grained modifiers match exactly
        if flagsMatch(flags, fineFlags) then
            if isAerospaceTiled(aerospacePath) then return false end  -- Pass to AeroSpace
            self:move(direction, fineGrained)
            return true  -- Consume event
        end
        
        return false  -- Not our modifiers, pass through
    end)
    
    self._eventtap:start()
    return self
end

--- WindowSnap:stop()
--- Method
--- Stop the eventtap (unbind hotkeys).
---
--- Returns:
---  * The WindowSnap object
function obj:stop()
    if self._eventtap then
        self._eventtap:stop()
        self._eventtap = nil
    end
    return self
end

return obj
