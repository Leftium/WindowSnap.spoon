# WindowSnap.spoon - AI Agent Guidelines

This document provides context for AI coding assistants working on WindowSnap.

## Overview

WindowSnap is a Hammerspoon Spoon that provides Windows Snap-style window management with slot-based positioning and size cycling.

## Architecture

### Core Concepts

1. **Slots**: Screen positions where windows can snap. Tiling sizes (1/2, 1/3) divide the screen into multiple slots; non-tiling sizes (2/3) only snap to edges.

2. **Tiling vs Non-Tiling Sizes**:
   - **Tiling**: Sizes like 1/2, 1/3 that divide evenly into the screen (multiple slots)
   - **Non-Tiling**: Sizes like 2/3 that don't tile evenly (only left/right or top/bottom edges)
   - Detection: `tilesEvenly = math.abs(ratio - 1/math.floor(1/ratio + 0.5)) < 0.01`

3. **Edge Detection**: For non-tiling sizes, we detect edges by pixel position (within 10px tolerance) rather than slot calculation.

4. **State Tracking**: `_windowState[winId]` tracks `widthIndex` and `heightIndex` into the `sizes` array.

### Movement Logic

Both horizontal (left/right) and vertical (up/down) follow the same pattern:

```
if tiling and can move between slots:
    move to adjacent slot
elseif at edge:
    cycle size, stay at edge
else:
    move to edge
```

### Shift Modifier Behavior

- **Left/Right + Shift**: Preserves height (doesn't reset to 100%)
- **Up/Down + Shift**: Same as without Shift (both preserve width)

## Common Issues & Fixes

### Issue: Non-tiling sizes have incorrect slot behavior

**Symptom**: Window at 2/3 width tries to move to a "middle slot" that doesn't exist.

**Cause**: Missing `tilesEvenly` check - code assumes all sizes have multiple slots.

**Fix**: Add `tilesEvenly` check and only allow slot movement for tiling sizes. Use edge detection for non-tiling sizes.

### Issue: Shift + move at non-tiling size causes unexpected resize

**Symptom**: Pressing Shift + Left at 2/3 width resizes to 1/2 instead of preserving size.

**Cause**: Edge detection fails because non-tiling sizes can be at edges without `currentSlot` being at min/max.

**Fix**: Use pixel-based edge detection (`atLeftEdge`, `atRightEdge`, etc.) instead of relying solely on slot position.

### Issue: Shift hotkeys don't work

**Symptom**: Holding Shift while pressing the hotkey does nothing.

**Cause**: Hammerspoon treats Shift as a modifier, so `ctrl+alt+left` and `ctrl+alt+shift+left` are different hotkeys.

**Fix**: `bindHotkeys()` automatically registers both normal and Shift variants, both calling the same `move()` function which checks Shift state at runtime via `hs.eventtap.checkKeyboardModifiers().shift`.

## Code Structure

```
init.lua
├── Metadata (name, version, etc.)
├── Configuration (sizes, aerospacePath)
├── Private state (_windowState)
├── isAerospaceTiled() - AeroSpace integration
├── move(direction) - Main movement logic
│   ├── Horizontal (left/right) branch
│   │   ├── tilesEvenly check
│   │   ├── Edge detection (atLeftEdge, atRightEdge)
│   │   ├── Slot movement or edge cycling
│   │   └── Height reset (unless Shift)
│   └── Vertical (up/down) branch
│       ├── tilesEvenly check
│       ├── Edge detection (atTopEdge, atBottomEdge)
│       ├── Slot movement or edge cycling
│       └── Width preservation
├── resetState(winId) - Clear window state
└── bindHotkeys(mapping) - Hotkey registration
```

## Testing

After changes, reload Hammerspoon config and test:

1. **Tiling sizes (1/2, 1/3)**: Should move between slots, cycle at edges
2. **Non-tiling sizes (2/3)**: Should only snap to edges, cycle at edges
3. **Shift + Left/Right**: Should preserve height
4. **Shift + Up/Down**: Should behave same as without Shift
5. **AeroSpace integration**: Should ignore tiled windows

## Symmetry Principle

The horizontal and vertical logic should be symmetrical. When fixing issues in one, check if the same fix is needed in the other:

- Both need `tilesEvenly` check
- Both need edge detection for non-tiling sizes
- Both use `-1` as a flag for "snap to far edge" (right/bottom)
