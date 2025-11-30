# WindowSnap.spoon

Windows Snap-style window management for [Hammerspoon](https://www.hammerspoon.org/) with Raycast-style size cycling.

## Features

- **Windows-style snapping**: Snap windows to left/right half, cycle through sizes (1/2, 1/3, 2/3)
- **Fine-grained control**: Independent horizontal/vertical axes for precise corner positioning
- **Size cycling**: Press the same direction repeatedly to cycle through sizes
- **AeroSpace integration**: Automatically detects floating vs tiled windows, passes tiled windows through to AeroSpace
- **Works standalone**: No dependencies required (AeroSpace integration is optional)

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
spoon.WindowSnap:bindHotkeys()
```

Default hotkeys:
- `Ctrl+Alt+Arrow` - Windows-style snapping (resets to 50% on direction change)
- `Shift+Ctrl+Alt+Arrow` - Fine-grained control (independent axes)

### Custom Modifiers

```lua
hs.loadSpoon("WindowSnap")
spoon.WindowSnap:bindHotkeys({
    windowsMod = {"ctrl", "alt", "cmd"},           -- Mega modifier
    fineMod = {"shift", "ctrl", "alt", "cmd"},     -- Giga modifier
})
```

### Custom Keys

```lua
spoon.WindowSnap:bindHotkeys({
    left = "h", right = "l", up = "k", down = "j"
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

### Windows-style (default modifier)

Mimics Windows 10/11 Snap behavior:
- Snaps to half screen, cycles through 1/2 → 1/3 → 2/3
- Changing horizontal direction resets to 50% width
- Height resets to 100% on horizontal move
- Press up/down after left/right for corner positioning

### Fine-grained (shift + default modifier)

For precise corner positioning:
- Horizontal and vertical axes are independent
- Size is preserved when changing direction
- Allows arbitrary combinations like 1/3 wide × 2/3 tall

## AeroSpace Integration

WindowSnap automatically detects if [AeroSpace](https://github.com/nikitabobko/AeroSpace) is running:

- **Floating windows**: WindowSnap handles directly
- **Tiled windows**: Key events pass through to AeroSpace

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
| `bindHotkeys(mapping)` | Bind hotkeys with optional custom keys/modifiers |
| `move(direction, options)` | Move window in direction with optional settings |
| `toggle(direction)` | Toggle between 100% and current size |
| `resetState(winId)` | Reset cycling state for window (or all if nil) |
| `stop()` | Stop the eventtap (unbind hotkeys) |

## License

MIT License - see [LICENSE](LICENSE) for details.

## Author

John Googol <johngoogol@gmail.com>
