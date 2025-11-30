--- === WindowSnap ===
---
--- Windows Snap-style window management with size cycling.
--- Snaps windows to screen edges with configurable size cycling.
---
--- Features:
---  * Snap to edges, cycle through sizes (1/2, 1/3, 2/3) on repeat
---  * Hold Shift to prevent height reset (when snapping to the opposite side,
---    height resets to 100% for left↔right, to 50% for up↔down)
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
--- Snap the focused window in the given direction.
--- Repeating the same direction cycles through sizes.
--- Hold Shift to prevent height reset. When snapping to the opposite side,
--- height resets (to 100% for left↔right, to 50% for up↔down).
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
    local isHorizontal = (direction == "left" or direction == "right")

    -- Initialize state for this window
    if not self._windowState[winId] then
        self._windowState[winId] = { widthIndex = 0, heightIndex = 0, lastH = "left", lastV = "up" }
    end
    local state = self._windowState[winId]

    -- Update state based on direction
    if isHorizontal then
        if direction == state.lastH then
            state.widthIndex = (state.widthIndex % #sizes) + 1
        elseif state.widthIndex == 0 then
            state.widthIndex = 1
        end
        state.lastH = direction
        if not preserveSize then
            state.heightIndex = 0
        end
    else
        if direction == state.lastV then
            state.heightIndex = (state.heightIndex % #sizes) + 1
        elseif state.heightIndex == 0 then
            state.heightIndex = 1
        end
        state.lastV = direction
    end

    -- Calculate frame
    local widthRatio = state.widthIndex > 0 and sizes[state.widthIndex] or 1
    local heightRatio = state.heightIndex > 0 and sizes[state.heightIndex] or 1

    local f = {
        w = screen.w * widthRatio,
        h = screen.h * heightRatio,
        x = screen.x + (state.lastH == "right" and (screen.w - screen.w * widthRatio) or 0),
        y = screen.y + (state.lastV == "down" and (screen.h - screen.h * heightRatio) or 0),
    }

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
---  * Hold Shift to prevent height reset. When snapping to the opposite side,
---    height resets (to 100% for left↔right, to 50% for up↔down).
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
