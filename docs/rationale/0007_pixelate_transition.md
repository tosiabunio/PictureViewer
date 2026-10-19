# Pixelate Transition

## Effect

The old image progressively loses resolution — fine details dissolve into a coarse mosaic of colored squares, as if the image were being downsampled in real time. As the pixelation intensifies, the image simultaneously fades to transparent, revealing the new image underneath. The two phases overlap: pixelation starts first and is well underway before the fade kicks in, creating a "dissolve into abstraction" feel.

## Why This Transition

Pixelate is the most overtly digital effect in the set. Where flip, bend, curl, and book draw from the physical world (cards, paper, books), and blocks straddles physical/digital (shattering tiles), pixelate is unapologetically computational. It references the visual language of image processing — resolution, sampling, pixel grids.

This contrast is intentional. The sketchbook aesthetic is warm and analog, but the medium is a screen. Pixelate acknowledges that duality. It says: "yes, these are digital images, and there's beauty in how they're constructed." Inserting it between page-turn effects creates a moment of visual surprise that keeps the slideshow from feeling too uniform in its metaphors.

The two-phase timing (pixelate first, then fade) also creates a narrative arc within a single transition: the image first becomes abstract, then disappears. This is more interesting than a simultaneous pixelate+fade, which would look like a glitchy crossfade.

## Core Animation Implementation

Pixelate is the only transition that uses a Core Image filter (`CIPixellate`) applied to a `CALayer`'s `filters` array. This leverages macOS's deep integration between Core Animation and Core Image — CI filters applied to a layer run on the GPU as part of the compositing pipeline.

### Snapshot Layer with CIPixellate

```swift
let snapshot = CALayer()
snapshot.name = "pixelSnapshot"
snapshot.frame = rect
snapshot.contents = cgImage
snapshot.contentsRect = oldContentsRect
snapshot.contentsGravity = .resizeAspect
snapshot.masksToBounds = true
host.addSublayer(snapshot)

if let pixellateFilter = CIFilter(name: "CIPixellate") {
    pixellateFilter.setDefaults()
    pixellateFilter.setValue(1.0, forKey: kCIInputScaleKey)
    snapshot.filters = [pixellateFilter]
    // ...
}
```

As with zoom front, `host`, `rect` and `oldContentsRect` are the picture layer and the whole old image when unzoomed, or the viewport layer and the part of the old picture that was on screen while zoomed in ([0010](0010_slideshow_zoom_and_pan.md)).

Setting `inputScale` to 1.0 initially means no visible pixelation — the image looks normal. The animation then drives `inputScale` from 1 to 40, where 40 means each output pixel covers a 40x40 block of source pixels.

### Two-Phase Animation with Overlap

The pixelation and fade are separate `CABasicAnimation` instances within a `CAAnimationGroup`, but they have different `beginTime` and `duration` values:

```swift
// Phase 1: pixelate — first 65% of duration
let pixelAnim = CABasicAnimation(keyPath: "filters.pixellate.inputScale")
pixelAnim.fromValue = 1.0
pixelAnim.toValue = 40.0
pixelAnim.beginTime = 0
pixelAnim.duration = duration * 0.65

// Phase 2: fade — last 60% of duration, starting at 40%
let fade = CABasicAnimation(keyPath: "opacity")
fade.fromValue = 1.0
fade.toValue = 0.0
fade.beginTime = duration * 0.4
fade.duration = duration * 0.6
```

The timeline for a 1.0s duration:

```
0.0s ─── pixelate starts (inputScale: 1)
         ...
0.4s ─── fade starts (opacity: 1.0), pixelation at ~60% progress (inputScale ~24)
         ...
0.65s── pixelate ends (inputScale: 40), fade at ~40% progress (opacity ~0.6)
         ...
1.0s ─── fade ends (opacity: 0.0)
```

The 25% overlap (0.4s to 0.65s) is the sweet spot:
- **No overlap** (fade starts at 0.65s): The image freezes at maximum pixelation for a beat, then fades. This creates a jarring pause.
- **Full overlap** (fade starts at 0.0s): The image fades before it's visibly pixelated. The pixelation effect is wasted.
- **25% overlap**: The fade begins when the pixelation is clearly visible but not yet at its coarsest. The two effects blend during the middle of the transition, creating a smooth "dissolve into noise" rather than two sequential steps.

### Why `inputScale: 40` and Not Higher

At `inputScale: 40`, a 1200px-wide image resolves to about 30 visible blocks across. This is coarse enough to be clearly "pixelated" but fine enough to retain color distribution — the viewer can still sense the image's palette. At `inputScale: 100+`, the image becomes 12 blocks or fewer, which reads as random colored squares with no connection to the original image. The transition should abstract the image, not obliterate it.

### The `filters.pixellate.inputScale` Keypath

Core Animation's keypath system allows animating individual filter parameters by name. The format is `filters.<filterName>.<parameterKey>`. When `CIFilter(name: "CIPixellate")` is assigned to a layer's `filters` array, Core Animation registers it under the filter's name, making `filters.pixellate.inputScale` a valid animation keypath.

This only works because `CIPixellate` is a relatively simple filter — it has one parameter (`inputScale`) and no dependencies on other filters. More complex filter chains would require careful ordering and naming.

### Fallback

If `CIFilter(name: "CIPixellate")` returns nil (which shouldn't happen on macOS 14+ but is handled defensively), the transition falls back to a plain opacity fade:

```swift
} else {
    let fade = CABasicAnimation(keyPath: "opacity")
    fade.fromValue = 1.0
    fade.toValue = 0.0
    fade.duration = duration
    // ...
}
```

This maintains the contract that a transition always occurs — the user never sees a hard cut.

### Duration

1.0s normal, 0.5s speedy. Pixelate needs more time than zoom front (0.8s) because it has two sequential-but-overlapping phases. At shorter durations the pixelation phase is too brief to register before the fade takes over.

## Compositor Thread Execution

`CIFilter` animations on `CALayer.filters` are evaluated by the Core Animation render server, not the main thread. The GPU applies the pixellate kernel per-frame during compositing. This is the same pipeline that handles `CATransition` effects — the only difference is that here we're animating filter parameters rather than transition geometry.

## File References

- Filter setup, two-phase animation and fallback fade: `performPixelateTransition` in `SlideshowTransitions.swift`
- Duration constants: `pixelateDuration`, `speedyPixelateDuration` in `DesignSystem.swift`
