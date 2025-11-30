# WindowSnap.spoon

Windows Snap-style window management for [Hammerspoon](https://www.hammerspoon.org/) with size cycling.

## Features

- **Slot-based movement**: Left/right moves between slots, cycles width at edges
- **Size cycling**: Tiling sizes (1/2, 1/3) have multiple slots; non-tiling (2/3) snaps to edges
- **Height behavior**: Left/right resets height to 100%; up/down preserves width
- **Shift modifier**: Hold Shift to preserve height on left/right
- **AeroSpace integration**: Automatically detects floating vs tiled windows, ignores tiled windows
- **Simple API**: Just 4 hotkeys (left/right/up/down), Shift variants auto-bound

## Installation

### Manual

```bash
git clone https://github.com/leftium/WindowSnap.spoon ~/.hammerspoon/Spoons/WindowSnap.spoon
```

### Download

Download the [latest release](https://github.com/leftium/WindowSnap.spoon/releases), unzip, and double-click `WindowSnap.spoon` to install.

## Usage

### Quick Start

```lua
hs.loadSpoon("WindowSnap")
spoon.WindowSnap:bindHotkeys({
    left  = {{"ctrl", "alt"}, "left"},
    right = {{"ctrl", "alt"}, "right"},
    up    = {{"ctrl", "alt"}, "up"},
    down  = {{"ctrl", "alt"}, "down"},
})
```

**Usage:**
- **Left/Right**: Move between slots (left/middle/right for 1/3 width), cycle width at edges, reset height to 100%
- **Up/Down**: Move between slots, cycle height at edges, preserve width
- Hold **Shift** to preserve height on left/right movement

### Vim-Style Keys

```lua
spoon.WindowSnap:bindHotkeys({
    left  = {{"ctrl", "alt"}, "h"},
    right = {{"ctrl", "alt"}, "l"},
    up    = {{"ctrl", "alt"}, "k"},
    down  = {{"ctrl", "alt"}, "j"},
})
```

### Manual Control

```lua
spoon.WindowSnap:move("left")   -- Snap left
spoon.WindowSnap:move("right")  -- Snap right
```

## AeroSpace Integration

WindowSnap automatically detects if [AeroSpace](https://github.com/nikitabobko/AeroSpace) is running:

- **Floating windows**: WindowSnap handles directly
- **Tiled windows**: WindowSnap does nothing (lets AeroSpace handle via its own bindings)

To disable AeroSpace integration:

```lua
spoon.WindowSnap.aerospacePath = nil
```

To use a custom AeroSpace path:

```lua
spoon.WindowSnap.aerospacePath = "/usr/local/bin/aerospace"
```

## API

### Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `sizes` | `{0.5, 1/3, 2/3}` | Size ratios to cycle through |
| `aerospacePath` | `"/opt/homebrew/bin/aerospace"` | Path to aerospace binary, or nil to disable |

### Methods

| Method | Description |
|--------|-------------|
| `bindHotkeys(mapping)` | Bind hotkeys for left/right/up/down (auto-binds Shift variants) |
| `move(direction)` | Move window between slots, cycle size at edges |
| `resetState(winId)` | Reset cycling state for window (or all if nil) |

### Hotkey Actions

| Action | Description |
|--------|-------------|
| `left`, `right` | Move between slots, cycle width at edge, reset height (Shift preserves) |
| `up`, `down` | Move between slots, cycle height at edge, preserve width |

## License

MIT License - see [LICENSE](LICENSE) for details.

## Author

Leftium <john@leftium.com>
