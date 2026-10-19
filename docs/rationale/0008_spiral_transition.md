# Spiral Transition

## Effect

The old image is divided into a grid of tiles (same as blocks), but instead of fading out in random order, the tiles disappear in a clockwise spiral pattern — starting from the outer edge and working inward. The outer corners vanish first, then the edges, then the interior, until the last central tile fades away and the new image is fully revealed.

The visual impression is of the old image being "unwound" from its frame, like peeling tape off a gift or unraveling thread from a spool.

## Why This Transition

Spiral is blocks' deterministic counterpart. Where blocks uses random per-tile delays (creating a different pattern every time), spiral follows a fixed, predictable path. This contrast is valuable in the transition cycle:

1. **Blocks** feels chaotic and organic — tiles disappear unpredictably, like rain hitting a window.
2. **Spiral** feels orderly and deliberate — there's a clear visual path the eye can follow.

By placing them in the same cycle, the slideshow alternates between randomness and structure, keeping the viewer engaged without requiring them to understand or notice the difference consciously.

The spiral pattern specifically was chosen because it draws the eye inward. Most other transitions are centrifugal — flip rotates outward, zoom front pushes toward the viewer, blocks scatter randomly. Spiral is centripetal: it contracts from the periphery to the center. This creates a natural focal point in the middle of the image, which is where the subject typically is in a well-composed photograph.

## Core Animation Implementation

Spiral reuses the tile grid architecture from blocks but replaces the random delay function with a spiral-order delay function.

### Tile Grid (Shared with Blocks)

```swift
let edge = DesignSystem.blocksEdge  // 100pt
let cols = max(1, Int(ceil(rect.width / edge)))
let rows = max(1, Int(ceil(rect.height / edge)))
let tileW = rect.width / CGFloat(cols)
let tileH = rect.height / CGFloat(rows)
```

Tiles are constructed identically to blocks — same `contentsRect` slicing (including the crop to the visible part while zoomed in), same `masksToBounds`, same `contentsGravity`. The only difference is when each tile starts its fade.

### Spiral Order Algorithm

The `spiralOrder(rows:cols:)` function generates a list of `(row, col)` positions in clockwise spiral traversal order:

```swift
private func spiralOrder(rows: Int, cols: Int) -> [(row: Int, col: Int)] {
    var result: [(row: Int, col: Int)] = []
    var top = 0, bottom = rows - 1, left = 0, right = cols - 1

    while top <= bottom, left <= right {
        // Right across top row
        for col in left...right { result.append((row: top, col: col)) }
        top += 1
        // Down along right column
        if top <= bottom {
            for row in top...bottom { result.append((row: row, col: right)) }
        }
        right -= 1
        // Left across bottom row
        if top <= bottom, left <= right {
            for col in stride(from: right, through: left, by: -1) {
                result.append((row: bottom, col: col))
            }
        }
        bottom -= 1
        // Up along left column
        if top <= bottom, left <= right {
            for row in stride(from: bottom, through: top, by: -1) {
                result.append((row: row, col: left))
            }
        }
        left += 1
    }
    return result
}
```

This is the standard spiral matrix traversal algorithm. For a 4x5 grid, it produces:

```
 1  2  3  4  5
14 15 16 17  6
13 20 19 18  7
12 11 10  9  8
```

The boundary variables (`top`, `bottom`, `left`, `right`) shrink inward after each pass, ensuring every cell is visited exactly once. The `if` guards prevent double-visiting cells when the remaining area is a single row or column.

### Delay Mapping

Each tile's fade delay is proportional to its position in the spiral:

```swift
let delay: Double
if totalTiles > 1 {
    delay = (Double(spiralIndex) / Double(totalTiles - 1)) * maxDelay
} else {
    delay = 0.0
}
```

For a 4x5 grid (20 tiles) with `maxDelay = 1.05s`:
- Tile 0 (top-left corner): delay = 0.0s
- Tile 10 (middle of bottom row): delay = 0.525s
- Tile 19 (center): delay = 1.05s

This linear mapping means tiles fade at a constant rate around the spiral. An alternative would be to use an ease-in curve (slow at the edges, fast toward the center) but the linear rate already looks natural because the spiral path itself accelerates perceptually — each ring has fewer tiles than the one outside it, so the "front" of the disappearing wave appears to speed up as it approaches the center.

### Duration

1.4s normal, 0.7s speedy. Spiral is the longest transition because the eye needs time to track the pattern. If the spiral completed in 0.8s, the viewer would see tiles disappearing but wouldn't have time to perceive the spiral order — it would look like a slightly-less-random version of blocks, defeating the purpose.

The per-tile fade starts from the same `blocksBlockFade` (0.35s) as blocks and scales with the duration, so at normal speed `maxDelay = 1.4 - 0.35 = 1.05s`, giving the outermost tile a full second head start over the innermost tile. That's enough temporal spread for the spiral pattern to be clearly visible. In speedy mode (0.7s) the fade shrinks to 0.175s and the spread to 0.525s, keeping the same proportions.

### Why Clockwise, Outside-In

**Clockwise**: Matches the reading direction for most users (left-to-right, top-to-bottom). The spiral starts at the top-left and initially moves right, which is where the eye naturally begins scanning. Counter-clockwise would feel slightly "off" for LTR readers.

**Outside-in**: Creates the centripetal focus effect described above. Inside-out would disperse attention outward, which conflicts with the goal of directing the eye to the image center.

These could be made configurable in the future, but the current fixed pattern serves the design intent.

## Relationship to Blocks

Spiral and blocks share significant code: same tile construction, same `contentsRect` slicing, same fade animation setup, same cleanup pattern. The only difference is the delay calculation:

| | Blocks | Spiral |
|---|--------|--------|
| Delay source | `Double.random(in: 0...maxDelay)` | `(spiralIndex / totalTiles) * maxDelay` |
| Visual pattern | Random scatter | Clockwise inward spiral |
| Repeatability | Different every time | Same pattern every time |
| Duration | 1.2s | 1.4s |

Both methods live in `SlideshowTransitions.swift` as separate functions rather than a shared parameterized function because the clarity of having distinct, readable implementations outweighs the small amount of code duplication. A shared `performTileTransition(delayFor:)` with a closure parameter would save ~20 lines but make each transition harder to understand in isolation.

## File References

- Spiral transition: `performSpiralTransition` in `SlideshowTransitions.swift`
- Spiral order algorithm: `spiralOrder(rows:cols:)` in `SlideshowTransitions.swift`
- Duration constants: `spiralDuration`, `speedySpiralDuration` in `DesignSystem.swift`
- Shared tile edge size: `blocksEdge` in `DesignSystem.swift`
