# Bend Transition

## Effect

The current image peels up from its bottom-right corner, curling away from the surface like a page being lifted from a book or a sticky note being peeled off a desk. The curl reveals the new image underneath. The paper appears to have physical thickness and casts a subtle shadow as it lifts.

## Why This Transition

Bend reinforces the sketchbook metaphor that defines the app's visual identity. A sketchbook is a physical object — pages curl, paper bends, corners lift. By using `pageCurl` as a one-directional effect (always peeling up), bend feels like casually lifting a page to peek at the next drawing underneath. It's less formal than `book` (which simulates deliberate page-turning with direction awareness) and more playful.

The name "bend" (rather than "curl") distinguishes it from the reverse effect (`curl`, which uses `pageUnCurl`). Together they form a complementary pair: bend lifts up, curl lays down.

## Core Animation Implementation

Bend uses `pageCurl`, another private-but-stable `CATransitionType`. Like `oglFlip`, this is a GPU-native effect — Core Animation renders the curling paper geometry, the shadow underneath, and the perspective foreshortening entirely in the compositor process.

```swift
let transition = CATransition()
transition.type = CATransitionType(rawValue: "pageCurl")
transition.subtype = .fromRight
transition.duration = duration  // 1.2s, or 0.6s in speedy mode
transition.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1.0)
(isZoomed ? viewportLayer : imageLayer).add(transition, forKey: "slideTransition")
```

### Why `pageCurl` Runs on the GPU

`pageCurl` involves deforming a 2D texture (the layer's `contents`) along a cylindrical surface, which requires per-pixel displacement mapping. On the CPU this would mean re-rendering the entire image every frame — hundreds of thousands of pixels at 60 fps. Core Animation offloads this to the GPU's texture sampling hardware, where the deformation is essentially free (it's just a different UV coordinate lookup per fragment).

This is the core reason the app was rewritten from Tauri to Swift. The web platform has no equivalent of `pageCurl`. CSS `transform: rotateY()` can fake a flat card flip, but it cannot deform a surface into a cylinder. JavaScript libraries that simulate page curls (like turn.js) do it by slicing the image into strips and transforming each one — which is CPU-bound, produces visible seams, and can't match the shadow/lighting fidelity of the native effect.

### Duration and Timing

Bend is the longest of the simple transitions at 1.2s (vs 1.0s for flip and 1.1s for curl). The extra 200ms gives the curl time to develop — `pageCurl` involves a multi-phase motion (corner lift, curl tightening, swing away) that looks rushed at shorter durations. The standard ease curve `(0.25, 0.1, 0.25, 1.0)` works well here because the curl's built-in physics already provides visual interest; a more aggressive curve would fight against the effect's natural rhythm.

Speedy mode drops to 0.6s, which is fast enough to feel snappy but still allows the curl shape to register visually before the page is gone.

### Fixed Direction

Bend always curls from the right (`.fromRight`), regardless of navigation direction. This is intentional — bend is a casual "peek" effect, not a directional metaphor. Making it direction-aware would step on `book`'s territory, where direction carries meaning (forward = turn right page, backward = turn left page).

## Layer Sizing

Same as flip — the transition is applied to the aspect-fitted `imageLayer`, so the curl originates from the visible image's corner rather than the container's corner. Without this, a tall portrait image in a wide container would have its curl start from empty space to the right of the image, breaking the illusion.

While zoomed in, it goes on the screen-sized `viewportLayer` instead, so the curl starts from the corner of the screen and peels away what you were looking at. See [0010](0010_slideshow_zoom_and_pan.md).

## File References

- Transition type selection: `caTransitionType` in `SlideshowImageView.swift`
- Duration constants: `bendDuration`, `speedyBendDuration` in `DesignSystem.swift`
- Aspect-fit sizing: `fittedImageRect` in `SlideshowContainerView.swift`
