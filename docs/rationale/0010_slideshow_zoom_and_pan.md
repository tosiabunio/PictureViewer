# Slideshow Zoom and Pan

## Effect

Pinching the trackpad, double-clicking the picture (or double-tapping with two fingers), or pressing **+** zooms into the slideshow picture, and the slideshow switches to zoom mode on its own. A zoomed picture spreads over the whole slideshow, behind the counter and the control bar; scrolling, dragging or the arrow keys pan it. Switching pictures keeps the zoom, starting each picture in reading order.

## Why Zoom Over the Whole Slideshow

Two designs were considered:

1. **Zoom inside the page frame.** Set the picture layer's `contentsRect` to a sub-rectangle of the image: the frame, shadow and tape strips stay put and only the content inside magnifies. A quick prototype confirmed it works and costs almost nothing.
2. **Let the zoomed picture grow over the whole slideshow.** The frame disappears, but far more of the picture fits on screen.

The point of zooming is to see detail — reading the small lettering of a scanned comic page, for example — so the second design won. The sketchbook frame returns as soon as the picture is back to fit: the tape strips and the picture's shadow fade out while zoomed in and back in at fit.

Zoom moves the picture layer's `frame` rather than its `contentsRect`. Animating the frame alone scales the picture uniformly; animating a clipped frame and a `contentsRect` together would stretch the picture slightly mid-animation, because the two interpolate independently.

## Layout: One Image View for the Whole Slideshow

`SlideshowImageView` used to sit in the page area between the bars. It now fills the slideshow's `ZStack` behind them, and the page area is a clear placeholder that carries the tape strips and reports its frame:

```swift
.onGeometryChange(for: CGRect.self) { proxy in
  proxy.frame(in: .named(Self.coordinateSpace))
} action: { frame in
  pageFrame = frame
}
```

The coordinate space is attached to the `ZStack`, whose bounds are the image view's bounds, so the frame is already in the image view's (top-left-origin) coordinates. `SlideshowContainerView` flips it to its own bottom-left origin (`pageRect`) and fits the unzoomed picture into it (`fittedImageRect`), so unzoomed the slideshow looks exactly as before. See [0009](0009_tape_strip_positioning.md).

The empty parts of the bars' `VStack` (spacers, `Color.clear`) aren't hit-testable, so clicks, scrolls and pinches reach the image view everywhere except over the counter and the control bar.

## Zoom State Lives in the AppKit View

Trackpad gestures arrive as `NSEvent`s many times per second. `SlideshowContainerView` owns the zoom — `scale` (1 means fit) and `offset` (how far the picture's center is from its fitted center) — and moves the image layer directly, without a SwiftUI round trip per event.

SwiftUI drives it through `SlideshowZoom`, a small `ObservableObject` holding a weak reference to the view: `zoomIn()`, `zoomOut()`, `fit()` and `pan(x:y:)` for the control bar and the keys. The view reports the scale back for the control bar's zoom label and the tape-strip fade. It reports only scale changes, not every pan, and defers the report with `Task { @MainActor in ... }`, because the view can change scale while SwiftUI is updating it (a new picture arrives in `updateNSView`), and publishing an `ObservableObject` change during a view update isn't allowed.

Gestures are `NSView` overrides — `magnify(with:)`, `smartMagnify(with:)`, `scrollWheel(with:)`, `mouseDown(with:)`/`mouseDragged(with:)` — rather than SwiftUI gestures: SwiftUI on macOS 14 has no scroll-wheel gesture, and the native events carry precise scrolling deltas and the cursor position for zooming around it.

## Geometry

- **Picture rect**: the fitted size times `scale`, centered at the fitted center plus `offset`.
- **Zooming in** keeps the picture point under the focus (the cursor or fingers, or the middle of the view for keys and buttons) in place: `newCenter = focus + (center − focus) × newScale / scale`.
- **Zooming out** eases the picture back toward its fitted place: `newOffset = offset × (newScale − 1) / (scale − 1)`. It arrives exactly at the fitted position at 1×, with no jump at the end of a pinch.
- **Clamping**, per axis: a picture larger than the view must cover it, with no gaps at the edges. A picture still smaller than the view along an axis — a portrait page at 2× is usually narrower than the screen — ignores the offset on that axis and stays as close to its fitted place as the view allows, because there is nothing to pan to. Both rules give the same position when the picture exactly fills the view, so growing past that point doesn't jump.
- **Maximum zoom**: two screen pixels per picture pixel, but never less than 4× (`maxScale`). It uses the bitmap's pixel size, not `NSImage.size`, which is in points: a 300 dpi scan reports 288×396 points for a 1200×1650-pixel image.
- **Animation**: buttons, keys and double-click animate over 0.25s; pinch, scroll and drag follow the fingers directly.
- **Shadow**: fades out by 1.25×. A picture spread over the slideshow needs no shadow, and a shadow on a layer several screens large would cost an offscreen rendering pass.

## Zoom Mode

The control bar swaps first/play/stop and the speed, transition and trash buttons for previous, zoom out, the zoom level, zoom in, fit and next, plus the highlighted magnifier, and auto-play pauses so pictures don't change mid-zoom. Any zoom-in enters zoom mode on its own (`onChange(of: zoom.isZoomed)`). Pinching back down to 1× stays in zoom mode; leaving is deliberate — Esc, Z or the magnifier — and animates the picture back to fit. The first Esc leaves zoom mode; only the next one closes the slideshow.

## Switching Pictures While Zoomed

**Reading order.** The new picture keeps the zoom level and starts where you would start reading it: the next picture at its top-left, the previous one at its bottom-right (where you finished it), and Home/End at the top-left. The navigation functions set `zoomedStart` alongside `navigatingForward`, and `showNewPicture(startingAt:)` places the picture's corner at the matching corner of the view.

**Keys.** Page Up/Page Down and Shift+arrows switch pictures. Plain arrows pan, but `pan(x:y:)` reports whether the picture actually moved; a fresh press (`KeyPress.phase == .down`) that can't move it switches pictures, while key repeats don't, so holding ↓ scrolls to the bottom of a comic page and stops, and the next press turns the page.

**Transitions.** A zoomed picture layer can be many times the size of the screen. A `CATransition` on it would play mostly off screen and snapshot a huge texture, and the tile-based transitions would slice it into hundreds of tiles. So `imageLayer` lives inside a screen-sized `viewportLayer` with `masksToBounds`:

- Unzoomed, transitions run on `imageLayer` exactly as before.
- While zoomed, `CATransition`s are added to `viewportLayer`, so a flip or curl turns what is on screen.
- The custom transitions take a host layer, a rect and the part of the old image to show. While zoomed, they put their snapshots on `viewportLayer` over the rect where the old picture was visible, cropped with `contentsRect` to that visible part (`visibleImageRect`, `visibleContentsRect`), so the mosaic or pixelation dissolves exactly the view you were looking at.

The new layout, the new picture and its transition are set inside one `CATransaction`, so they reach the screen together. Zooming and keyboard panning are ignored while a transition runs (`canZoom`), since moving the picture would shift it under the transition's snapshots.

## Only a New Picture Starts a Transition

SwiftUI calls `updateNSView` whenever the slideshow body re-renders: Play, Stop, the speed toggle, the transition picker, and every zoom step. Earlier, each call started a transition and replayed the current picture's effect. Now `updateNSView` returns early unless the `NSImage` instance changed (`displayedImage`). `ImageStore.fullImage(for:)` creates a new `NSImage` on every call, so a new instance always means a real picture change.

For the same reason, `SlideshowView` picks the effect and its duration per slide, in `advanceSlide(to:)`, rather than computing them in `body`: a changed setting or speed applies from the next picture instead of re-animating the current one.

## File References

- Zoom state, geometry and gestures: `SlideshowContainerView` in `SlideshowContainerView.swift` — `apply(scale:offset:animated:)`, `zoom(by:around:animated:)`, `pan(byFractionX:y:)`, `showNewPicture(startingAt:)`, `maxScale`, `canZoom`
- SwiftUI bridge and reading-order start: `SlideshowZoom`, `ZoomedPictureStart` in `SlideshowContainerView.swift`
- Picture switching and transition host: `updateNSView` in `SlideshowImageView.swift`
- Cropped custom transitions: `dispatchCustomTransition`, `tileContentsRect` in `SlideshowTransitions.swift`
- Page area, zoom mode and keys: `pageArea`, `enterZoomMode()`, `handleArrow(_:navigate:)` in `SlideshowView.swift`
- Zoom-mode controls: `zoomControls` in `SlideshowControlBar.swift`
