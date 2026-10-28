# WindowSnap.spoon

Window snapping and size cycling for [Hammerspoon](https://www.hammerspoon.org/). Use arrows to snap with a complementary size, or hold Shift to move without resizing until you reach an edge.

Works on its own, including alongside TrellisWM. AeroSpace integration is optional.

## Install and configure

Install Hammerspoon, then clone the Spoon:

```sh
mkdir -p ~/.hammerspoon/Spoons
git clone https://github.com/leftium/WindowSnap.spoon ~/.hammerspoon/Spoons/WindowSnap.spoon
```

Add this to `~/.hammerspoon/init.lua`:

```lua
hs.loadSpoon("WindowSnap")
spoon.WindowSnap.aerospacePath = nil -- Use WindowSnap directly, including with TrellisWM
spoon.WindowSnap:bindHotkeys({
    left  = {{"ctrl", "alt", "cmd"}, "left"},
    right = {{"ctrl", "alt", "cmd"}, "right"},
    up    = {{"ctrl", "alt", "cmd"}, "up"},
    down  = {{"ctrl", "alt", "cmd"}, "down"},
})
```

Reload Hammerspoon's configuration and grant Accessibility access when prompted. Shift variants are bound automatically. You can change the modifiers or use `h`, `j`, `k`, and `l` instead of arrows.

## Controls

The example uses Ctrl+Alt+Cmd, called Mega in the author's dotfiles. Adding Shift gives Giga. Both modes preserve the other axis: horizontal commands keep height and vertical position; vertical commands keep width and horizontal position.

| Control | Before the requested edge | Already at the requested edge |
| --- | --- | --- |
| Mega: direction | Snap to that edge with complementary size | Cycle size through 1/2, 1/3, and 2/3 using remembered state |
| Giga: Shift + direction | Move one slot at evenly tiling sizes such as 1/3 or 1/2; otherwise move to the edge, keeping size | Toggle the movement-axis size between full and half |

Complementary snapping swaps 1/3 and 2/3. Half stays half; other sizes snap to half.

For a window in the left third, Giga+Right moves it to the middle third without resizing. Mega+Right snaps it to the right edge at 2/3 width. Another Mega+Right cycles it to half width. The same rules apply vertically.

Cycling remembers an index per window and axis; it does not infer the next size from the current frame. A newly tracked window already at the requested edge first cycles to 1/3. Manual resizing does not update that index. At an edge, Giga expands any non-full size to full; the next press returns it to half.

## API

| Interface | Behavior |
| --- | --- |
| `bindHotkeys(mapping)` | Bind directional hotkeys and their Shift variants; returns the Spoon |
| `move(direction)` | Act on the focused window; accepts `"left"`, `"right"`, `"up"`, or `"down"` and reads the current Shift state |
| `resetState(winId)` | Clear one window's cycling state, or all cycling state if omitted; returns the Spoon |
| `aerospacePath` | AeroSpace executable path; defaults to `"/opt/homebrew/bin/aerospace"`. Set to `nil` to disable integration |

The size cycle is fixed in the implementation. There is no public `sizes` setting. `resetState()` does not clear the AeroSpace layout cache.

## Optional AeroSpace integration

To enable integration, omit the `aerospacePath = nil` line above, or set the path to your AeroSpace executable. When AeroSpace is running and reports the focused window as tiled:

- Mega invokes `~/.config/bin/aerospace-move-or-cycle-size` asynchronously.
- Giga invokes `aerospace focus` in the requested direction.

The helper is external and is not included here. You must supply it for Mega commands on tiled windows. Floating windows use WindowSnap's own movement logic.

Detection checks for the running AeroSpace application before querying its CLI. A failed layout query is treated as non-tiled. Delegated command failures do not fall back to WindowSnap movement.

Layout results are cached for the most recently queried window with no expiry. This Spoon provides no automatic invalidation on float/tile changes; external integration must clear the cache, or you can reload Hammerspoon. Keep integration disabled when using TrellisWM or after removing the helper scripts.

## License

[MIT](LICENSE). By Leftium <john@leftium.com>.
