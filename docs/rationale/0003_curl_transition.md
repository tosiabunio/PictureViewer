# Curl Transition

## Effect

The new image appears to be laid down onto the surface, uncurling from a rolled-up state and settling flat — the reverse of a page being peeled up. The paper unfurls from the right edge and presses down, with the shadow shrinking as the page makes contact with the surface beneath.

## Why This Transition

Curl is the inverse of bend. Where bend lifts a page away (revealing something underneath), curl lays a page down (covering what was there before). This inversion gives the slideshow a sense of rhythmic variety — lift, lay, lift, lay — even before other transitions enter the cycle.

The metaphor is different from bend's: instead of "peeking at the next sketch," curl feels like "placing a new print on top of the stack." Both are physically grounded in the sketchbook world, but they imply different relationships between the viewer and the content.

## Core Animation Implementation

Curl uses `pageUnCurl`, the complementary counterpart to `pageCurl`. The same GPU-native geometry deformation applies, just in reverse — the cylindrical surface unrolls rather than rolling up.

```swift
let transition = CATransition()
transition.type = CATransitionType(rawValue: "pageUnCurl")
transition.subtype = .fromRight
transition.duration = duration  // 1.1s, or 0.55s in speedy mode
transition.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1.0)
(isZoomed ? viewportLayer : imageLayer).add(transition, forKey: "slideTransition")
```

### Relationship to `pageCurl`

`pageCurl` and `pageUnCurl` are not simply time-reversed versions of each other. `pageCurl` shows the old content curling away; `pageUnCurl` shows the new content being placed. The shadow behavior differs: `pageCurl`'s shadow grows as the page lifts, while `pageUnCurl`'s shadow shrinks as the page settles. This matters for visual coherence — if you time-reversed `pageCurl`, the shadow would grow as the page came down, which looks wrong physically.

### Duration

1.1s — slightly shorter than bend (1.2s) because the uncurl motion is perceptually faster. The page settling down accelerates under "gravity" (the ease curve's deceleration phase coincides with the page's final press-down), so the animation feels complete sooner. A full 1.2s would make the last 100ms feel like dead air.

Speedy mode: 0.55s.

### Fixed Direction

Like bend, curl always operates from the right. The directional pair (curl vs uncurl) is expressed through the transition type, not the subtype. This keeps curl as a distinct visual identity rather than a parameterized variant.

## Distinction from Book's Backward Navigation

`book` also uses `pageUnCurl` — but only when navigating backward, and it applies from the left edge (`.fromLeft`). Curl always uses `.fromRight`. The visual difference is significant: book-backward feels like turning a page back in a left-to-right book, while curl feels like a fresh sheet being pressed down from the right. Same Core Animation type, different spatial semantics.

## File References

- Transition type selection: `caTransitionType` in `SlideshowImageView.swift`
- Duration constants: `curlDuration`, `speedyCurlDuration` in `DesignSystem.swift`
- Contrast with book: the `.book` cases of `caTransitionType` and `caTransitionSubtype` in `SlideshowImageView.swift`
