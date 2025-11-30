# WindowSnap.spoon

Windows Snap-style window management for [Hammerspoon](https://www.hammerspoon.org/) with size cycling.

## Features

- **Edge snapping**: Snap windows to screen edges, cycle through sizes (1/2, 1/3, 2/3)
- **Shift modifier**: Hold Shift to prevent height reset (when snapping to the opposite side, height resets to 100% for left↔right, to 50% for up↔down)
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
- Press hotkey to snap to edge and cycle sizes (1/2 → 1/3 → 2/3)
- Hold **Shift** to prevent height reset. When snapping to the opposite side, height resets (to 100% for left↔right, to 50% for up↔down).

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
| `move(direction)` | Snap window in direction (detects Shift to prevent height reset) |
| `resetState(winId)` | Reset cycling state for window (or all if nil) |

### Hotkey Actions

| Action | Description |
|--------|-------------|
| `left`, `right`, `up`, `down` | Snap to edge (hold Shift to prevent height reset) |

## License

MIT License - see [LICENSE](LICENSE) for details.

## Author

Leftium <john@leftium.com>
