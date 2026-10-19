# Zoom Front Transition

## Effect

The old image scales up toward the viewer (growing from 1.0x to 1.4x its size) while simultaneously fading to transparent. The combination creates a sense of depth — the old image appears to rush past the camera into the foreground, becoming a ghostly enlargement before vanishing entirely. The new image sits still underneath, revealed as the old one dissipates.

## Why This Transition

Zoom front introduces a z-axis metaphor that no other transition in the set uses. Flip, bend, curl, and book all operate on the x/y plane (rotating, curling, peeling). Blocks and spiral disassemble the image in-place. Zoom front is the only transition that moves content toward the viewer along the z-axis.

This depth-based motion serves a perceptual purpose: it makes the old image feel "dismissed" rather than "removed." The scaling-up-and-fading pattern is a well-established UI idiom (iOS uses it for app launch animations, macOS uses it for window minimization). Users intuitively read it as "this thing is leaving, making room for the next thing."

In the slideshow cycle, zoom front provides a moment of cinematic drama between the more tactile page-turn effects.

## Core Animation Implementation

Zoom front uses a snapshot `CALayer` with a `CAAnimationGroup` combining scale and opacity animations.

### Snapshot Layer

```swift
let snapshot = CALayer()
snapshot.name = "zoomSnapshot"
snapshot.frame = rect
snapshot.contents = cgImage           // Old image
snapshot.contentsRect = oldContentsRect
snapshot.contentsGravity = .resizeAspect
snapshot.masksToBounds = true
host.addSublayer(snapshot)
```

The snapshot is placed over the new image: on `imageLayer` itself (covering its bounds, showing the whole old image) when unzoomed, or on the screen-sized viewport layer (covering the part of the old picture that was on screen, cropped to it) while zoomed in. As the snapshot scales up and fades, the static new image is progressively revealed. See [0010](0010_slideshow_zoom_and_pan.md).

`masksToBounds = true` is essential — without it, the scaling snapshot would visually overflow the image area, overlapping tape strips and other UI elements. Clipping ensures the zoom effect stays contained within the image bounds.

### Combined Animation

```swift
let scale = CABasicAnimation(keyPath: "transform.scale")
scale.fromValue = 1.0
scale.toValue = 1.4

let fade = CABasicAnimation(keyPath: "opacity")
fade.fromValue = 1.0
fade.toValue = 0.0

let group = CAAnimationGroup()
group.animations = [scale, fade]
group.duration = duration  // 0.8s, or 0.4s in speedy mode
group.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1.0)
```

### Why 1.4x and Not More

The scale factor of 1.4 was chosen for perceptual balance:

- **1.0x to 1.2x**: Too subtle — the zoom is barely visible before the fade completes. Feels like a plain crossfade with a slight wobble.
- **1.0x to 1.4x**: The sweet spot. Enough magnification to clearly communicate "zooming toward you" without the image becoming a blurry mess (since the image is being displayed at larger-than-native resolution, pixel artifacts would show at higher scales).
- **1.0x to 2.0x+**: Too aggressive. The image blows up past recognizability, and the GPU has to sample well beyond the texture's native resolution, causing visible pixelation on the enlarged snapshot even before the fade completes.

### Why a Group, Not Sequential Animations

Both animations start at time 0 and run for the full duration. They could be added as separate animations on the layer, but `CAAnimationGroup` has two advantages:

1. **Single timing function**: The group's `timingFunction` applies uniformly to both children. Adding them separately would require setting the timing function on each, and if they ever needed to drift apart (e.g., different durations), the group makes it explicit that they're coupled.
2. **Single `isRemovedOnCompletion` and `fillMode`**: The group's fill mode governs both children. Without the group, one animation being removed before the other could cause a visual flash (e.g., scale resets to 1.0 while opacity is still at 0.3).

### Duration

0.8s normal, 0.4s speedy. Zoom front is faster than the page-turn transitions because its motion is simpler — there's no multi-phase geometry deformation, just a linear scale + fade. At 1.0s+ the effect would overstay its welcome; the "depth rush" reads best as a quick punch.

## Cleanup

Same pattern as blocks — `DispatchQueue.main.asyncAfter` removes the snapshot layer after duration + 50ms buffer.

## File References

- Snapshot + animation: `performZoomFrontTransition` in `SlideshowTransitions.swift`
- Duration constants: `zoomFrontDuration`, `speedyZoomFrontDuration` in `DesignSystem.swift`
- Dispatch routing: `dispatchCustomTransition` in `SlideshowTransitions.swift`
