# WindowSnap.spoon - Agent Guidelines

WindowSnap is a Hammerspoon Spoon. Read `README.md` for setup and controls; check `init.lua` before changing behavior or documenting it.

## Movement model

Both axes use the same rules and preserve the other axis:

- Unshifted, before the requested edge: snap to that edge with the complementary fraction (1/3 <-> 2/3, 1/2 stays 1/2, other sizes default to 1/2).
- Unshifted, at the requested edge: cycle from the measured size. Left/Up use 1/2 -> 2/3 -> 1/3; Right/Down use 1/2 -> 1/3 -> 2/3. Full and unmatched sizes start at half.
- Shifted, before the requested edge: preserve both dimensions. Move one slot for evenly tiling fractions, or directly to the edge otherwise.
- Shifted, at the requested edge: expand any non-full movement-axis size to full; full returns to half.

Mega means unshifted direction and Giga means Shift + direction in the author's dotfiles. Slot movement belongs to Giga. Neither mode resets the other axis.

## Implementation details

`init.lua` owns movement, configuration, AeroSpace detection, and hotkey binding.

- `cycleSizes` is local, not a public setting. `getNextCycleSize()` matches the measured ratio and steps forward for Left/Up or backward for Right/Down. There is no remembered cycle state; manual resizing takes effect on the next command.
- Edge detection runs before slot movement on both axes, with a 10-pixel tolerance. Size matching uses a ratio tolerance of 0.01.
- Shifted slot movement uses `math.abs(ratio - 1/math.floor(1/ratio + 0.5)) < 0.01` to recognize evenly tiling fractions. A 2/3-size window moves directly to the requested edge.
- `bindHotkeys()` registers the supplied mapping and adds Shift variants. `move()` reads Shift at runtime, including when called directly.
- `resetState()` is a compatibility no-op and returns the Spoon. It does not clear the AeroSpace cache.

Keep horizontal and vertical branches consistent. Remove obsolete descriptions when changing behavior; do not restore the former height-reset or unshifted-slot model.

## AeroSpace boundary

Standalone snapping needs no AeroSpace. Set `aerospacePath = nil` when using TrellisWM or another setup without the external helpers.

With integration enabled, detection first checks for the running AeroSpace app. Tiled windows delegate: unshifted commands invoke the external `~/.config/bin/aerospace-move-or-cycle-size`; shifted commands invoke `aerospace focus`. The helper is not shipped in this repo. A failed layout query is treated as non-tiled; delegated failures have no movement fallback.

`_tiledCache` holds the most recently queried window's layout with an infinite TTL. No cache invalidation hook is provided here. External integrations must clear it after layout changes, or reload Hammerspoon. Do not describe `resetState()` as clearing this cache.

## Documentation and verification

Keep `README.md`, source docstrings, and generated `docs.json` consistent. Generate API docs from the corrected source where tooling is available; do not edit executable Lua for a documentation-only change.

Run `lua tests/move.lua` with Lua 5.3+, or `hs -c 'dofile("/absolute/path/to/WindowSnap.spoon/tests/move.lua")'`. The suite mocks frames and modifiers; it does not move desktop windows or test keyboard delivery.

After behavior changes, reload Hammerspoon and check:

1. Unshifted complementary snaps in all four directions, including an arbitrary starting size.
2. Both unshifted cycle orders, including manual resizing and full or unmatched sizes entering at half.
3. Shifted slot movement at 1/2 and 1/3, edge movement at 2/3, and full/half toggles at each edge.
4. Preservation of the other axis in both modes.
5. Standalone snapping with AeroSpace disabled; delegation and cache invalidation separately if that integration is available.

Report live checks separately from source inspection. Do not imply keyboard delivery or TrellisWM workspace behavior was tested by a source-only check.
