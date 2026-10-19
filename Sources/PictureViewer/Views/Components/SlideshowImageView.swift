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
  /// Where the unzoomed picture goes, in this view's SwiftUI coordinates.
  let pageFrame: CGRect
  let zoom: SlideshowZoom
  /// Where the next picture starts if the slideshow is zoomed in.
  let zoomedStart: ZoomedPictureStart
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
    imageLayer.shadowOpacity = SlideshowContainerView.imageShadowOpacity
    imageLayer.shadowOffset = CGSize(width: 0, height: -6)
    imageLayer.shadowRadius = 16

    // Clips a zoomed picture to the view; transitions run on it while zoomed.
    let viewportLayer = CALayer()
    viewportLayer.name = "viewportLayer"
    viewportLayer.masksToBounds = true
    viewportLayer.addSublayer(imageLayer)

    container.layer?.addSublayer(viewportLayer)
    zoom.attach(container)

    return container
  }

  func updateNSView(_ nsView: SlideshowContainerView, context: Context) {
    nsView.pageFrame = pageFrame

    guard let imageLayer = nsView.imageLayer, let viewportLayer = nsView.viewportLayer else {
      return
    }

    guard let newImage = image else {
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      nsView.displayedImage = nil
      nsView.currentImageSize = .zero
      imageLayer.frame = nsView.bounds
      imageLayer.contents = nil
      CATransaction.commit()
      return
    }

    // SwiftUI also calls this when unrelated slideshow state changes (play, speed,
    // transition setting); only a new image should start a transition.
    guard newImage !== nsView.displayedImage else { return }
    nsView.displayedImage = newImage

    // Where the old picture showed, for transitions while zoomed.
    let oldVisibleRect = nsView.visibleImageRect
    let oldContentsRect = nsView.visibleContentsRect

    // One transaction, so the new layout, picture and transition land together.
    CATransaction.begin()
    defer { CATransaction.commit() }

    // Store image size so layout() can recalculate on container resize
    nsView.currentImageSize = newImage.size
    let newCGImage = newImage.asCGImage
    nsView.imagePixelSize = newCGImage.map { CGSize(width: $0.width, height: $0.height) } ?? .zero
    // Keeps the zoom; a picture switched to while zoomed starts in reading order.
    nsView.showNewPicture(startingAt: zoomedStart)
    // A zoomed picture layer can be far bigger than the screen, so transitions
    // play on the viewport, over what's visible, instead.
    let isZoomed = nsView.scale > 1

    // Only animate if there was a previous image (not first load)
    let hadPreviousImage = imageLayer.contents != nil

    switch (animationType, hadPreviousImage) {
    case (.blocks, true), (.zoomFront, true), (.pixelate, true), (.spiral, true):
      // Custom transitions — snapshot old image, set new, then animate overlay
      let oldCGImage = imageLayer.contents

      CATransaction.begin()
      CATransaction.setDisableActions(true)
      imageLayer.contents = newCGImage
      CATransaction.commit()

      if isZoomed {
        dispatchCustomTransition(
          oldImage: oldCGImage, showing: oldContentsRect, on: viewportLayer, in: oldVisibleRect)
      } else {
        dispatchCustomTransition(
          oldImage: oldCGImage, showing: CGRect(x: 0, y: 0, width: 1, height: 1),
          on: imageLayer, in: imageLayer.bounds)
      }

    case (.flip, true), (.bend, true), (.curl, true), (.book, true):
      // CATransition-based transitions
      let transition = CATransition()
      transition.duration = duration
      transition.timingFunction = timingFunction
      transition.type = caTransitionType
      transition.subtype = caTransitionSubtype
      transition.isRemovedOnCompletion = true
      (isZoomed ? viewportLayer : imageLayer).add(transition, forKey: "slideTransition")
      imageLayer.contents = newCGImage

    default:
      // First load — no animation, just set the image
      imageLayer.contents = newCGImage
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

// MARK: - NSImage CGImage helper

extension NSImage {
  /// Convenience to get a CGImage without needing to manage an inout rect.
  var asCGImage: CGImage? {
    var rect = NSRect(origin: .zero, size: size)
    return cgImage(forProposedRect: &rect, context: nil, hints: nil)
  }
}
