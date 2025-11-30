# WindowSnap.spoon

Windows Snap-style window management for [Hammerspoon](https://www.hammerspoon.org/) with Raycast-style size cycling.

## Features

- **Windows-style snapping**: Snap windows to left/right half, cycle through sizes (1/2, 1/3, 2/3)
- **Fine-grained control**: Independent horizontal/vertical axes for precise corner positioning
- **Size cycling**: Press the same direction repeatedly to cycle through sizes
- **AeroSpace integration**: Automatically detects floating vs tiled windows, ignores tiled windows (lets AeroSpace handle them)
- **Works standalone**: No dependencies required (AeroSpace integration is optional)
- **Standard Spoon API**: Follows Hammerspoon Spoon conventions

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
    snapLeft = {{"ctrl", "alt"}, "left"},
    snapRight = {{"ctrl", "alt"}, "right"},
    snapUp = {{"ctrl", "alt"}, "up"},
    snapDown = {{"ctrl", "alt"}, "down"},
})
```

### With Fine-Grained Control

```lua
hs.loadSpoon("WindowSnap")
spoon.WindowSnap:bindHotkeys({
    -- Windows-style snapping
    snapLeft = {{"ctrl", "alt"}, "left"},
    snapRight = {{"ctrl", "alt"}, "right"},
    snapUp = {{"ctrl", "alt"}, "up"},
    snapDown = {{"ctrl", "alt"}, "down"},
    -- Fine-grained corner snapping
    fineLeft = {{"shift", "ctrl", "alt"}, "left"},
    fineRight = {{"shift", "ctrl", "alt"}, "right"},
    fineUp = {{"shift", "ctrl", "alt"}, "up"},
    fineDown = {{"shift", "ctrl", "alt"}, "down"},
})
```

### Vim-Style Keys

```lua
spoon.WindowSnap:bindHotkeys({
    snapLeft = {{"ctrl", "alt"}, "h"},
    snapRight = {{"ctrl", "alt"}, "l"},
    snapUp = {{"ctrl", "alt"}, "k"},
    snapDown = {{"ctrl", "alt"}, "j"},
})
```

### Manual Control

```lua
-- Basic usage
spoon.WindowSnap:move("left")
spoon.WindowSnap:move("right")

-- With options
spoon.WindowSnap:move("left", {
    sizes = { 0.5, 0.25, 0.75 },
    independentAxes = false,
    resetOnDirectionChange = true
})
```

## Modes

### Windows-style (snap*)

Mimics Windows 10/11 Snap behavior:
- Snaps to half screen, cycles through 1/2 → 1/3 → 2/3
- Changing horizontal direction resets to 50% width
- Height resets to 100% on horizontal move
- Press up/down after left/right for corner positioning

### Fine-grained (fine*)

For precise corner positioning:
- Horizontal and vertical axes are independent
- Size is preserved when changing direction
- Allows arbitrary combinations like 1/3 wide × 2/3 tall

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
| `independentAxes` | `true` | Whether axes are independent (corner snapping) |
| `aerospacePath` | `"/opt/homebrew/bin/aerospace"` | Path to aerospace binary, or nil to disable |

### Methods

| Method | Description |
|--------|-------------|
| `bindHotkeys(mapping)` | Bind hotkeys using standard Spoon format |
| `move(direction, options)` | Move window in direction with optional settings |
| `resetState(winId)` | Reset cycling state for window (or all if nil) |

### Hotkey Actions

| Action | Description |
|--------|-------------|
| `snapLeft`, `snapRight`, `snapUp`, `snapDown` | Windows-style snapping |
| `fineLeft`, `fineRight`, `fineUp`, `fineDown` | Fine-grained corner snapping |

## License

MIT License - see [LICENSE](LICENSE) for details.

## Author

Leftium <john@leftium.com>
