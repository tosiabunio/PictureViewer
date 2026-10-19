import AppKit
import SwiftUI

/// NSViewRepresentable that uses CATransition for GPU-composited page transitions.
///
/// This is where the magic happens. CATransition types like `pageCurl` and `oglFlip`
/// are rendered entirely by Core Animation on the GPU — no CPU compositing, no jank.
///
/// The `book` animation type uses direction-aware transitions:
/// - Forward: `pageCurl` from the right edge (lifting the current page)
/// - Backward: `pageUnCurl` from the left edge (laying a page back down)
/// This mimics the natural feel of turning a real book page.
struct SlideshowImageView: NSViewRepresentable {
  let image: NSImage?
  let animationType: SlideAnimationType
  /// Length of the transition — shorter in speedy mode.
  let duration: TimeInterval
  let isForward: Bool
  @Binding var isAnimating: Bool

  func makeNSView(context: Context) -> SlideshowContainerView {
    let container = SlideshowContainerView()
    container.wantsLayer = true
    container.layer?.backgroundColor = NSColor.clear.cgColor

    let imageLayer = CALayer()
    imageLayer.name = "imageLayer"
    imageLayer.contentsGravity = .resizeAspect
    imageLayer.backgroundColor = NSColor.clear.cgColor

    // Pastel shadow — soft warm tone matching the sketchbook aesthetic
    imageLayer.shadowColor = NSColor(red: 0.72, green: 0.66, blue: 0.58, alpha: 1.0).cgColor
    imageLayer.shadowOpacity = 0.5
    imageLayer.shadowOffset = CGSize(width: 0, height: -6)
    imageLayer.shadowRadius = 16

    container.layer?.addSublayer(imageLayer)

    return container
  }

  func updateNSView(_ nsView: SlideshowContainerView, context: Context) {
    guard let rootLayer = nsView.layer,
      let imageLayer = rootLayer.sublayers?.first(where: { $0.name == "imageLayer" })
    else { return }

    guard let newImage = image else {
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      nsView.displayedImage = nil
      nsView.currentImageSize = .zero
      imageLayer.frame = rootLayer.bounds
      imageLayer.contents = nil
      CATransaction.commit()
      return
    }

    // SwiftUI also calls this when unrelated slideshow state changes (play, speed,
    // transition setting); only a new image should start a transition.
    guard newImage !== nsView.displayedImage else { return }
    nsView.displayedImage = newImage

    // Store image size so layout() can recalculate on container resize
    nsView.currentImageSize = newImage.size

    // Only animate if there was a previous image (not first load)
    let hadPreviousImage = imageLayer.contents != nil

    switch (animationType, hadPreviousImage) {
    case (.blocks, true), (.zoomFront, true), (.pixelate, true), (.spiral, true):
      // Custom transitions — snapshot old image, set new, then animate overlay
      let oldCGImage = imageLayer.contents
      let fittedRect = nsView.fittedImageRect

      CATransaction.begin()
      CATransaction.setDisableActions(true)
      imageLayer.frame = fittedRect
      imageLayer.contents = newImage.asCGImage
      CATransaction.commit()

      dispatchCustomTransition(
        oldImage: oldCGImage, on: imageLayer, in: fittedRect)

    case (.flip, true), (.bend, true), (.curl, true), (.book, true):
      // CATransition-based transitions
      let transition = CATransition()
      transition.duration = duration
      transition.timingFunction = timingFunction
      transition.type = caTransitionType
      transition.subtype = caTransitionSubtype
      transition.isRemovedOnCompletion = true
      imageLayer.add(transition, forKey: "slideTransition")

      CATransaction.begin()
      CATransaction.setDisableActions(true)
      imageLayer.frame = nsView.fittedImageRect
      CATransaction.commit()
      imageLayer.contents = newImage.asCGImage

    default:
      // First load — no animation, just set the image
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      imageLayer.frame = nsView.fittedImageRect
      CATransaction.commit()
      imageLayer.contents = newImage.asCGImage
    }
  }

  /// Timing curve per animation type.
  ///
  /// The `book` type uses a custom curve tuned for natural page-turn feel:
  /// slow pickup at the corner (0.4), gentle lift (0.0), smooth swing (0.2),
  /// soft settle onto the opposite page (1.0).
  private var timingFunction: CAMediaTimingFunction {
    switch animationType {
    case .book:
      // Natural page turn: slow lift → smooth swing → gentle settle
      return CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)
    case .flip, .bend, .curl, .blocks, .zoomFront, .pixelate, .spiral:
      return CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1.0)
    }
  }

  private var caTransitionType: CATransitionType {
    switch animationType {
    case .flip:
      return CATransitionType(rawValue: "oglFlip")
    case .bend:
      return CATransitionType(rawValue: "pageCurl")
    case .curl:
      return CATransitionType(rawValue: "pageUnCurl")
    case .book:
      return isForward
        ? CATransitionType(rawValue: "pageCurl")
        : CATransitionType(rawValue: "pageUnCurl")
    case .blocks, .zoomFront, .pixelate, .spiral:
      // Not used — custom transitions are handled separately
      return .fade
    }
  }

  /// Direction subtype — book mode flips the subtype for backward navigation
  /// so the curl originates from the correct edge.
  private var caTransitionSubtype: CATransitionSubtype {
    switch animationType {
    case .book:
      return isForward ? .fromRight : .fromLeft
    case .flip, .bend, .curl, .blocks, .zoomFront, .pixelate, .spiral:
      return .fromRight
    }
  }
}

// MARK: - Container view with aspect-fit layout

/// Custom container that keeps the image layer sized to the aspect-fitted rect.
///
/// On window resize, `layout()` recalculates the fitted rect so the image layer
/// (and its curl/flip transitions) always matches the visible image bounds.
class SlideshowContainerView: NSView {
  var currentImageSize: CGSize = .zero
  /// The image on screen, so updates that don't change it skip the transition.
  var displayedImage: NSImage?

  override func layout() {
    super.layout()
    guard let imageLayer = layer?.sublayers?.first(where: { $0.name == "imageLayer" })
    else { return }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    imageLayer.frame = fittedImageRect
    CATransaction.commit()
  }

  /// The aspect-fitted rect for the current image within this view's bounds.
  var fittedImageRect: CGRect {
    guard currentImageSize.width > 0, currentImageSize.height > 0,
      bounds.width > 0, bounds.height > 0
    else { return bounds }

    let imageAspect = currentImageSize.width / currentImageSize.height
    let containerAspect = bounds.width / bounds.height

    if imageAspect > containerAspect {
      // Wider image — letterboxed top/bottom
      let width = bounds.width
      let height = width / imageAspect
      let originY = (bounds.height - height) / 2
      return CGRect(x: 0, y: originY, width: width, height: height)
    } else {
      // Taller image — pillarboxed left/right
      let height = bounds.height
      let width = height * imageAspect
      let originX = (bounds.width - width) / 2
      return CGRect(x: originX, y: 0, width: width, height: height)
    }
  }
}

// MARK: - NSImage CGImage helper

extension NSImage {
  /// Convenience to get a CGImage without needing to manage an inout rect.
  var asCGImage: CGImage? {
    var rect = NSRect(origin: .zero, size: size)
    return cgImage(forProposedRect: &rect, context: nil, hints: nil)
  }
}
