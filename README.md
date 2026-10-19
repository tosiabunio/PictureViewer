# Picture Viewer

A native macOS application for browsing pictures in a sketchbook-style interface with GPU-composited page-turn animations.

Built with Swift, SwiftUI, and Core Animation. Reads images from the user's Pictures folder — or any folder you choose — and displays them in a pastel-toned gallery with a fullscreen slideshow featuring eight transition effects — all rendered on the compositor thread with zero jank.

## Screenshots

| Gallery | Slideshow |
|---------|-----------|
| ![Gallery View](screenshots/gallery_view.png) | ![Slideshow](screenshots/slideshow.png) |

## Choosing a Folder

The gallery starts in your Pictures folder. Click the folder button in the header, or use **File ▸ Open Folder…** (⌘O), to browse any other folder; subfolders are scanned recursively. The choice is remembered across launches. **File ▸ Show Pictures Folder** switches back.

## Sorting

Use the sort menu in the header, or **View ▸ Sort By**, to order pictures by name (A–Z or Z–A) or by modification date (newest or oldest first). Names sort the way Finder does, so `page2` comes before `page10`, and pictures in subfolders stay grouped together. Pictures with the same modification date are ordered by name. The choice is remembered across launches.

## Slideshow Keyboard Shortcuts

| Key | Action |
|-----|--------|
| ← / ↑ | Previous picture |
| → / ↓ | Next picture |
| Home / End | First / last picture |
| Space | Play / pause |
| Esc | Close slideshow |

## Transition Effects

The slideshow cycles through eight GPU-composited transition effects:

### Flip

Hardware-accelerated 3D page flip via `oglFlip`. The image rotates around its vertical axis like a card being flipped over.

```swift
let transition = CATransition()
transition.type = CATransitionType(rawValue: "oglFlip")
transition.subtype = .fromRight
```

### Bend

A page-curl lift using `pageCurl`. The current image peels up from the corner, revealing the next image underneath — like lifting a sticky note.

```swift
transition.type = CATransitionType(rawValue: "pageCurl")
```

### Curl

The reverse of bend — `pageUnCurl` lays a page back down. A smooth uncurling motion from one corner.

```swift
transition.type = CATransitionType(rawValue: "pageUnCurl")
```

### Book

Direction-aware page turn that mimics a real book. Forward navigation uses `pageCurl` from the right edge; backward uses `pageUnCurl` from the left. A custom cubic-bezier timing curve `(0.4, 0.0, 0.2, 1.0)` gives a natural slow-lift, smooth-swing, gentle-settle feel.

```swift
transition.type = isForward
  ? CATransitionType(rawValue: "pageCurl")
  : CATransitionType(rawValue: "pageUnCurl")
transition.subtype = isForward ? .fromRight : .fromLeft
transition.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)
```

### Blocks

Mosaic dissolve — the old image breaks into a grid of `CALayer` tiles, each showing its portion via `contentsRect`. Tiles fade out with staggered random delays, revealing the new image underneath.

```swift
let tile = CALayer()
tile.contentsRect = CGRect(
  x: CGFloat(col) / CGFloat(cols),
  y: CGFloat(row) / CGFloat(rows),
  width: 1.0 / CGFloat(cols),
  height: 1.0 / CGFloat(rows))

let fade = CABasicAnimation(keyPath: "opacity")
fade.beginTime = CACurrentMediaTime() + Double.random(in: 0...maxDelay)
```

### Zoom Front

The old image scales up toward the viewer (1.0 to 1.4x) while fading out, creating a sense of depth as the new image is revealed behind it. Uses a `CAAnimationGroup` combining `transform.scale` and `opacity` animations.

```swift
let scale = CABasicAnimation(keyPath: "transform.scale")
scale.fromValue = 1.0
scale.toValue = 1.4

let fade = CABasicAnimation(keyPath: "opacity")
fade.fromValue = 1.0
fade.toValue = 0.0

let group = CAAnimationGroup()
group.animations = [scale, fade]
```

### Pixelate

The old image progressively pixelates via `CIPixellate` filter (inputScale 1 to 40), then dissolves with an overlapping opacity fade. Two-phase animation: pixelation occupies the first 65% of duration, fade-out starts at 40% and runs through the end.

```swift
let pixellateFilter = CIFilter(name: "CIPixellate")
snapshot.filters = [pixellateFilter]

let pixelAnim = CABasicAnimation(keyPath: "filters.pixellate.inputScale")
pixelAnim.fromValue = 1.0
pixelAnim.toValue = 40.0
pixelAnim.duration = duration * 0.65

let fade = CABasicAnimation(keyPath: "opacity")
fade.beginTime = duration * 0.4
fade.duration = duration * 0.6
```

### Spiral

Tiles reveal in clockwise spiral order from the outer edge inward — like blocks, but with deterministic ordering instead of random delays. A `spiralOrder(rows:cols:)` helper generates the traversal sequence (right, down, left, up, repeat inward), and each tile's delay is proportional to its position in the spiral.

```swift
let order = spiralOrder(rows: rows, cols: cols)
for (spiralIndex, pos) in order.enumerated() {
  let delay = (Double(spiralIndex) / Double(totalTiles - 1)) * maxDelay
  fade.beginTime = CACurrentMediaTime() + delay
}
```

## Requirements

- macOS 14+ (Sonoma)
- Swift 5.9+
- [Task](https://taskfile.dev) (optional, for `task dev:run` commands)

## Build & Run

```sh
# Build
swift build

# Run as .app bundle (requires task runner)
task dev:run
```

## License

MIT
