# Tape Strip Positioning

## The Problem

The slideshow displays images in a sketchbook-style frame with two washi-tape strips — one at the top center and one at the bottom right — pinning the image to the page, like a photograph taped into a real sketchbook.

The challenge: images have different aspect ratios. A wide landscape photo fills the container's width but leaves vertical space above and below (letterboxing). A tall portrait fills the height but leaves horizontal space on the sides (pillarboxing). The tape strips must appear at the edges of the **visible image**, not the edges of the container — otherwise a landscape image would have tape floating in empty space above and below it.

```
 Letterboxed (wide image)          Pillarboxed (tall image)
┌─────────────────────┐           ┌─────────────────────┐
│     empty space     │           │   │             │   │
│─ ─ ─ ─ ─ ─ ─ ─ ─ ─│           │   │             │   │
│  [tape]             │           │   │ [tape]      │   │
│  ┌─────────────────┐│           │   │┌───────────┐│   │
│  │                 ││           │ e ││           ││ e │
│  │     IMAGE       ││           │ m ││   IMAGE   ││ m │
│  │                 ││           │ p ││           ││ p │
│  └─────────────────┘│           │ t ││           ││ t │
│             [tape]  │           │ y │└───────────┘│ y │
│─ ─ ─ ─ ─ ─ ─ ─ ─ ─│           │   │      [tape]│   │
│     empty space     │           │   │             │   │
└─────────────────────┘           └─────────────────────┘
```

## Why Fixed Offsets Don't Work

The initial implementation used fixed pixel offsets for tape placement:

```swift
// BROKEN — tape floats in empty space for non-matching aspect ratios
.overlay(alignment: .top) {
    TapeStrip(color: topTapeColor)
        .offset(y: 20)  // 20pt from container top
}
```

This works when the image fills the container (i.e., when the image and container have the same aspect ratio). But for any other ratio, the 20pt offset positions the tape relative to the container edge, not the image edge. A letterboxed image might have 100pt of empty space above it — the tape would land at y=20, which is 80pt above the actual image top.

The same problem occurs horizontally for the bottom-right tape on pillarboxed images.

## The Solution: Aspect-Fit Inset Calculation

The fix has two parts: (1) calculate how much the aspect-fitted image is inset from the container edges, and (2) apply those insets as offsets to the tape strip overlays.

Here the "container" is the page area — the space between the slideshow's top bar and control bar, minus 60pt on each side.

### Part 1: `imageInsets(in:)`

This function computes the empty space between the container edges and the rendered image edges:

```swift
private func imageInsets(in containerSize: CGSize) -> EdgeInsets {
    guard currentImageSize.width > 0, currentImageSize.height > 0,
        containerSize.width > 0, containerSize.height > 0
    else {
        return EdgeInsets()
    }
    let containerAspect = containerSize.width / containerSize.height
    let imageAspect = currentImageSize.width / currentImageSize.height

    if imageAspect > containerAspect {
        // Image is wider — letterboxed top/bottom
        let rendered = containerSize.width / imageAspect
        let inset = (containerSize.height - rendered) / 2
        return EdgeInsets(top: inset, leading: 0, bottom: inset, trailing: 0)
    } else {
        // Image is taller — pillarboxed left/right
        let rendered = containerSize.height * imageAspect
        let inset = (containerSize.width - rendered) / 2
        return EdgeInsets(top: 0, leading: inset, bottom: 0, trailing: inset)
    }
}
```

The logic mirrors what `CALayer` does internally with `contentsGravity = .resizeAspect`:

1. Compare the image's aspect ratio to the container's aspect ratio.
2. If the image is wider (landscape in a squarish container), the image fills the container's width. The rendered height is `width / imageAspect`. The remaining vertical space is split equally top and bottom.
3. If the image is taller (portrait in a wide container), the image fills the container's height. The rendered width is `height * imageAspect`. The remaining horizontal space is split equally left and right.

The returned `EdgeInsets` tells you exactly how many points of empty space exist on each side.

### Part 2: GeometryReader + Offset

The tape strips are SwiftUI overlays on a clear placeholder that fills the page area, positioned using the computed insets:

```swift
private var pageArea: some View {
    GeometryReader { geo in
        let insets = imageInsets(in: geo.size)

        Color.clear
            // Top tape — sits on the actual image top edge
            .overlay(alignment: .top) {
                TapeStrip(color: slideshowTopTape)
                    .scaleEffect(2.4)
                    .rotationEffect(.degrees(-7))
                    .offset(y: insets.top - 10)
            }
            // Bottom-right tape — sits on the actual image corner
            .overlay(alignment: .bottomTrailing) {
                TapeStrip(color: slideshowBottomTape)
                    .scaleEffect(2.4)
                    .rotationEffect(.degrees(11))
                    .offset(
                        x: -(insets.trailing + 40),
                        y: -(insets.bottom - 10)
                    )
            }
            .opacity(zoom.isZoomed ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: zoom.isZoomed)
    }
    .onGeometryChange(for: CGRect.self) { proxy in
        proxy.frame(in: .named(Self.coordinateSpace))
    } action: { frame in
        pageFrame = frame
    }
    .padding(.horizontal, 60)
}
```

The picture itself isn't in here. `SlideshowImageView` spans the whole slideshow behind the bars, so that a zoomed-in picture can spread over all of it, and the page area tells it where the unzoomed picture goes: `onGeometryChange` reports the placeholder's frame in the slideshow's coordinate space, and the image view fits the picture into exactly that rect. While zoomed in, the picture no longer sits in the page, so the tape fades out and comes back when it returns to fit. See [0010](0010_slideshow_zoom_and_pan.md).

### Why GeometryReader Is Necessary

`imageInsets(in:)` needs the page area's dimensions. SwiftUI's layout system doesn't expose parent size to child views without `GeometryReader`, and the page area's size isn't fixed: the spacers around it in the slideshow's `VStack` share the leftover height with it.

`GeometryReader` bridges this gap: it reports `geo.size` — the page area's proposed size — which is exactly what we need to calculate aspect-fit insets. The same measured area, as a frame, is what `SlideshowImageView` fits the picture into.

### Offset Math Explained

**Top tape:**
```swift
.offset(y: insets.top - 10)
```
- `insets.top` moves the tape down past the empty letterbox space to the image's top edge.
- `-10` nudges it 10pt above the edge so the tape visually overlaps the image corner (tape should look like it's holding the image, not sitting on top of it).
- For a non-letterboxed image, `insets.top = 0`, so the tape sits at y=-10 (slightly above the container top, clipped by the parent).

**Bottom-right tape:**
```swift
.offset(
    x: -(insets.trailing + 40),
    y: -(insets.bottom - 10)
)
```
- `-(insets.trailing + 40)`: Move left by the pillarbox inset (to reach the image's right edge) plus 40pt (to sit on the image surface rather than hanging off the edge). The 40pt is an aesthetic choice — the tape should look casually placed, not precisely aligned.
- `-(insets.bottom - 10)`: Move up by the letterbox inset minus 10pt. Same logic as the top tape — the tape overlaps the bottom-right corner by 10pt.
- The minus signs are because `.bottomTrailing` alignment positions from the bottom-right corner, and we're moving inward (negative x = left, negative y = up from bottom).

## Why This Runs on Every Frame (and Why That's OK)

`GeometryReader` re-evaluates its closure whenever the view's size changes (e.g., window resize). `imageInsets(in:)` is called on every layout pass. This is a lightweight computation — two comparisons, a division, and a subtraction — so there's no performance concern.

The alternative (caching insets and invalidating on size change) would add complexity without measurable benefit. SwiftUI's diffing system already ensures the overlays only re-render when the computed offsets actually change.

## Parallel with SlideshowContainerView.fittedImageRect

The `imageInsets(in:)` calculation in SwiftUI mirrors the `fittedImageRect` calculation in the `SlideshowContainerView` (AppKit/Core Animation layer):

```swift
// SlideshowContainerView — used for the CALayer frame
var fittedImageRect: CGRect {
    // Same aspect-fit logic within the page area, but returns a rect instead of insets
    let page = pageRect  // pageFrame, converted to this view's bottom-left origin
    if imageAspect > pageAspect {
        let height = page.width / imageAspect
        return CGRect(x: page.minX, y: page.midY - height / 2, width: page.width, height: height)
    } else {
        let width = page.height * imageAspect
        return CGRect(x: page.midX - width / 2, y: page.minY, width: width, height: page.height)
    }
}
```

Both compute the same aspect-fit geometry, but for different consumers:
- `fittedImageRect` → Core Animation layer frame (AppKit coordinates)
- `imageInsets(in:)` → SwiftUI overlay offsets (SwiftUI coordinates)

They must agree, otherwise the tape strips wouldn't align with the actual rendered image. Both use the same formula on the same rect — the page area that the `GeometryReader` measures and reports as `pageFrame` — so they produce consistent results. Because the image view uses AppKit's bottom-left origin, `pageRect` flips the reported frame vertically before fitting.

## Tape Color Cycling

The tape colors cycle per slide index to add variety:

```swift
private var slideshowTopTape: Color {
    DesignSystem.tapeColors[currentIndex % DesignSystem.tapeColors.count]
}

private var slideshowBottomTape: Color {
    DesignSystem.tapeColors[(currentIndex + 3) % DesignSystem.tapeColors.count]
}
```

The `+3` offset ensures the two tape strips on the same image are never the same color (assuming the palette has more than 3 colors — it has 6). This avoids visual monotony while maintaining the pastel sketchbook aesthetic.

## Edge Cases

- **Image fills container exactly** (aspects match): All insets are 0. Tape sits at fixed positions relative to the container edges, which are also the image edges.
- **Very wide panorama**: Large `insets.top` pushes the top tape far down. The tape still lands on the image edge. If the image is so wide that the rendered height approaches zero, the tapes would overlap — but this is unlikely with real photographs.
- **Very tall portrait**: Large `insets.trailing` pushes the bottom-right tape far left. Same logic applies.
- **Zero-size image** (loading state): The guard clause returns `EdgeInsets()` (all zeros), so tape defaults to container edges. This is visually acceptable during the brief loading moment.

## File References

- `imageInsets(in:)`: `SlideshowView.swift`
- Tape overlay placement and page frame reporting: `pageArea` in `SlideshowView.swift`
- Tape color cycling: `slideshowTopTape`, `slideshowBottomTape` in `SlideshowView.swift`
- Parallel AppKit calculation: `fittedImageRect`, `pageRect` in `SlideshowContainerView.swift`
- Tape color palette: `tapeColors` in `DesignSystem.swift`
