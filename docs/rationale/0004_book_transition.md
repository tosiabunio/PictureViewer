# Book Transition

## Effect

A realistic page turn that changes behavior based on navigation direction. Going forward: the right page lifts from its edge and swings left, curling as it goes — like turning to the next page of a book. Going backward: a page uncurls from the left edge and settles back down — like flipping back to re-read a previous page.

The motion has a distinctive three-phase feel: slow corner lift, smooth swing through the middle, and gentle settle onto the opposite side.

## Why This Transition

Book is the most physically grounded transition in the set. While bend and curl use the same Core Animation primitives, they're one-directional effects that don't respond to navigation context. Book is the only transition that knows which way you're going and adjusts accordingly.

This direction-awareness matters for usability. When a user presses the left arrow and sees a page uncurl from the left, it reinforces the spatial metaphor: "I'm going back." When they press right and the page curls away to the left, it says "I'm moving forward." The transition becomes a form of feedback, not just decoration.

## Core Animation Implementation

Book dynamically selects both the transition type and subtype based on the `isForward` flag:

```swift
// Type: pageCurl for forward, pageUnCurl for backward
transition.type = isForward
  ? CATransitionType(rawValue: "pageCurl")
  : CATransitionType(rawValue: "pageUnCurl")

// Subtype: from right edge going forward, from left edge going backward
transition.subtype = isForward ? .fromRight : .fromLeft
```

### The Custom Timing Curve

Book is the only transition that uses a non-standard timing function:

```swift
transition.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)
```

This curve was tuned specifically for the page-turn metaphor:

| Control Point | Value | Physical Meaning |
|---------------|-------|------------------|
| x1 | 0.4 | Slow start — the page corner lifts gradually, like pinching a real page |
| y1 | 0.0 | No early velocity — the page doesn't jump off the surface |
| x2 | 0.2 | Early deceleration onset — the swing starts slowing well before the end |
| y2 | 1.0 | Full arrival — the page settles completely, no bounce or overshoot |

Compare this to the standard curve used by other transitions `(0.25, 0.1, 0.25, 1.0)`:
- Standard starts faster (x1=0.25 vs 0.4), which suits mechanical effects like flip
- Standard has a small initial velocity (y1=0.1), giving a slight "push" feel
- Book's slower start + zero initial velocity creates the sensation of overcoming static friction (the page sticking to the surface before lifting)

### Duration

1.0s — the same as flip. Despite being a more complex visual effect, the custom timing curve makes book feel unhurried at 1.0s because the slow start occupies the first ~300ms as anticipation. A longer duration (like bend's 1.2s) would make the middle swing phase feel floaty.

Speedy mode: 0.5s. At this speed the slow-start phase compresses to ~150ms, which still reads as a page turn but feels appropriately brisk.

### Why Direction Matters Here but Not Elsewhere

Flip is symmetric — rotating left-to-right vs right-to-left doesn't carry meaning because both look like "flipping." Bend and curl have inherent directionality in their names (peel up vs lay down), so adding navigation-based direction would create a confusing matrix of options (bend-forward-from-right, bend-backward-from-left, etc.).

Book is the natural home for direction because it references a physical object where direction is meaningful. A book has a spine, a left page, and a right page. Forward and backward map unambiguously to these physical directions. Making book direction-aware while keeping the others fixed gives each transition a distinct personality without overcomplicating the system.

## The `isForward` Flag

The `isForward` state is set in `SlideshowView` before the image change:

```swift
private func navigateNext() {
    navigatingForward = true
    // ...
}

private func navigatePrev() {
    navigatingForward = false
    // ...
}
```

This is passed through to `SlideshowImageView` as a property. The flag is only consumed by the `book` case — all other transitions ignore it. This means adding direction-awareness to another transition in the future only requires reading the existing `isForward` property; no plumbing changes needed.

The same navigation functions also set `zoomedStart`, which decides where a picture switched to while zoomed in begins (top-left going forward, bottom-right going back). It is kept separate from `isForward` because Home counts as backward for the page turn but still starts the first picture at its top. See [0010](0010_slideshow_zoom_and_pan.md).

## File References

- Type/subtype selection: `caTransitionType`, `caTransitionSubtype` in `SlideshowImageView.swift`
- Timing function: `timingFunction` in `SlideshowImageView.swift`
- Duration constants: `bookDuration`, `speedyBookDuration` in `DesignSystem.swift`
- Forward/backward state: `navigateNext()`, `navigatePrev()` in `SlideshowView.swift`
