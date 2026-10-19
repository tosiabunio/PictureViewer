# Blocks Transition

## Effect

The old image shatters into a grid of rectangular tiles. Each tile holds its exact slice of the old image (not a scaled-down copy). The tiles then fade out individually with random staggered delays, creating a mosaic dissolve that gradually reveals the new image underneath — like pieces of a puzzle disappearing one by one.

## Why This Transition

Blocks breaks the pattern of page-based transitions (flip, bend, curl, book). After several page turns in a row, the viewer's attention starts to slide past the transitions — they become wallpaper. Blocks is visually distinct enough to re-engage attention: it's not a page turning, it's the image itself coming apart.

The randomized per-tile timing adds organic unpredictability. Unlike flip (which is perfectly mechanical) or book (which follows a deterministic curve), blocks has a different visual rhythm every time it plays. This makes the slideshow feel more alive during long auto-play sessions.

## Core Animation Implementation

Blocks is the first "custom" transition — it doesn't use `CATransition` at all. Instead, it builds the effect from scratch using `CALayer` tiles and `CABasicAnimation`.

### The Tile Grid

The grid adapts to the image dimensions. Given a target tile edge size (`blocksEdge = 100pt`), the number of columns and rows is computed:

```swift
let edge = DesignSystem.blocksEdge  // 100pt
let cols = max(1, Int(ceil(rect.width / edge)))
let rows = max(1, Int(ceil(rect.height / edge)))
let tileW = rect.width / CGFloat(cols)
let tileH = rect.height / CGFloat(rows)
```

This means tile dimensions are not exactly 100x100 — they're whatever size evenly divides the image rect. A 1200x800 image produces 12x8 tiles of 100x100, but a 1300x800 image produces 13x8 tiles of 100x100 (since 1300/100 = 13 exactly). A 1250x800 image produces 13x8 tiles of ~96x100.

The `max(1, ...)` guard prevents division by zero on degenerate rects.

### Slice-Based Rendering via `contentsRect`

Each tile's `contents` is set to the same `CGImage` as the full old image, but `contentsRect` crops it to the tile's portion of `oldContentsRect` — the part of the old image being dissolved:

```swift
tile.frame = CGRect(
  x: rect.minX + CGFloat(col) * tileW,
  y: rect.minY + CGFloat(row) * tileH,
  width: tileW,
  height: tileH)
tile.contentsRect = tileContentsRect(
  col: col, row: row, cols: cols, rows: rows, in: oldContentsRect)

// tileContentsRect:
CGRect(
  x: contentsRect.minX + contentsRect.width * CGFloat(col) / CGFloat(cols),
  y: contentsRect.minY + contentsRect.height * CGFloat(row) / CGFloat(rows),
  width: contentsRect.width / CGFloat(cols),
  height: contentsRect.height / CGFloat(rows))
```

`contentsRect` is normalized (0.0 to 1.0). Unzoomed, `oldContentsRect` is the whole image, so `x: 2/12` means "start at 16.7% from the left edge of the image." This is a GPU-side crop — no CPU image slicing happens. The full `CGImage` texture is uploaded once, and each tile just samples a different region.

### While Zoomed

Unzoomed, the tiles go on `imageLayer` and cover its bounds. While zoomed in, the picture layer can be several screens large, so the tiles go on the screen-sized viewport layer instead, covering only the part of the old picture that was on screen, and `oldContentsRect` is that visible part. The mosaic then dissolves exactly the view you were looking at, and the grid is never bigger than the screen divided into 100pt tiles (18×11 on a 1728×1084pt slideshow), however far you zoom in. See [0010](0010_slideshow_zoom_and_pan.md).

### Staggered Random Fade

Each tile gets a `CABasicAnimation` on `opacity` from 1.0 to 0.0, with a random `beginTime`:

```swift
let fadeDuration = DesignSystem.blocksBlockFade * duration / DesignSystem.blocksDuration  // 0.35s at normal speed
let maxDelay = totalDuration - fadeDuration  // e.g., 1.2 - 0.35 = 0.85s
let delay = Double.random(in: 0...maxDelay)

fade.beginTime = CACurrentMediaTime() + delay
fade.duration = fadeDuration  // 0.35s
```

The math ensures no tile's fade extends past `totalDuration`:
- Earliest start: `now + 0` — tile fades from 0.0s to 0.35s
- Latest start: `now + 0.85s` — tile fades from 0.85s to 1.2s
- Total wall-clock time: exactly `blocksDuration` (1.2s)

`CACurrentMediaTime()` is critical here — it returns the compositor's media time, not `Date().timeIntervalSinceReferenceDate`. Using wall-clock time would cause drift between the animation system and the cleanup timer.

### Why Not `CATransition(type: .fade)` with Masks

An alternative approach: apply a single `CATransition` of type `.fade` with a grid mask that dissolves in patches. This would be simpler but has two drawbacks:

1. `CATransition.fade` is a uniform crossfade — there's no built-in way to make different regions fade at different times.
2. Animating a mask layer's contents (e.g., drawing black/white patches) would require either a `CADisplayLink` callback (main-thread work) or a pre-rendered image sequence (memory-heavy).

The tile approach is more explicit but gives per-tile timing control while keeping everything on the compositor thread.

### Cleanup

After the total duration plus a 50ms buffer, all tiles are removed:

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration + 0.05) {
    self.removeTransitionSublayers(named: "blockTile", from: host)
}
```

The 50ms buffer prevents tiles from being removed while their last fade frame is still being composited. Without it, the last few tiles would visually snap to invisible rather than fading smoothly to zero.

Leftover tiles from a previous blocks transition are also cleaned up at the start of each invocation, in case the user navigates faster than the cleanup timer.

## Speedy Mode

Normal: 1.2s total, 0.35s per-tile fade, up to 0.85s of stagger.
Speedy: 0.6s total. The per-tile fade scales with the total to 0.175s, leaving 0.425s of stagger — the same mosaic at twice the speed.

Keeping the fade at 0.35s would leave only 0.25s of stagger in speedy mode, so the tiles would fade out almost together and the mosaic would read as a crossfade.

## File References

- Tile grid construction and random delays: `performBlocksTransition` in `SlideshowTransitions.swift`
- Tile cropping: `tileContentsRect` in `SlideshowTransitions.swift`
- Constants: `blocksDuration`, `speedyBlocksDuration`, `blocksBlockFade`, `blocksEdge` in `DesignSystem.swift`
- Cleanup: `removeTransitionSublayers(named:from:)` in `SlideshowTransitions.swift`
