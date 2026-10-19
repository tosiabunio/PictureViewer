import AppKit
import SwiftUI

// MARK: - Zoom bridge

/// Connects the slideshow's SwiftUI controls to the zoom in `SlideshowContainerView`.
///
/// The view owns the live zoom so trackpad gestures never wait on SwiftUI;
/// it reports the scale back here for the control bar.
@MainActor
final class SlideshowZoom: ObservableObject {
  /// Zoom relative to the fitted picture; 1 means the whole picture fits the page.
  @Published private(set) var scale: CGFloat = 1

  private weak var view: SlideshowContainerView?

  var isZoomed: Bool { scale > 1 }

  func attach(_ view: SlideshowContainerView) {
    self.view = view
    // Deferred, since the view can change scale while SwiftUI is updating it.
    view.onScaleChange = { [weak self] scale in
      Task { @MainActor in self?.scale = scale }
    }
  }

  func zoomIn() { view?.zoom(by: SlideshowContainerView.zoomStep, animated: true) }
  func zoomOut() { view?.zoom(by: 1 / SlideshowContainerView.zoomStep, animated: true) }
  func fit() { view?.fit(animated: true) }

  /// Pans by fractions of the visible area; positive values reveal more to the
  /// right and further down. Returns false when the picture can't move that way.
  @discardableResult
  func pan(x: CGFloat, y: CGFloat) -> Bool { view?.pan(byFractionX: x, y: y) ?? false }
}

/// Where a picture switched to while zoomed starts, in reading order: the next
/// picture at its top-left, the previous one at its bottom-right.
enum ZoomedPictureStart {
  case topLeading
  case bottomTrailing
}

// MARK: - Container view with zoom and pan

/// Hosts the slideshow picture layer, spanning the whole slideshow.
///
/// Unzoomed, the picture is aspect-fitted into `pageFrame`, the area between the
/// top bar and the control bar. Zoomed, it grows over the whole view and pans
/// within it: pinch or double-click to zoom, scroll or drag to pan. Switching
/// pictures keeps the zoom.
///
/// The picture layer sits in a view-sized viewport layer that clips it; while
/// zoomed, transitions run on the viewport so they play over what's on screen.
///
/// On window resize, `layout()` recalculates the picture rect so the image layer
/// (and its curl/flip transitions) always matches the visible image bounds.
class SlideshowContainerView: NSView {
  /// Two steps double the size.
  static let zoomStep: CGFloat = 2.squareRoot()
  static let imageShadowOpacity: Float = 0.5
  private static let minimumMaxScale: CGFloat = 4
  private static let zoomAnimationDuration: CFTimeInterval = 0.25
  /// Points per line for mouse wheels that scroll in lines.
  private static let lineScrollDistance: CGFloat = 10

  var currentImageSize: CGSize = .zero
  /// Pixel size of the picture's bitmap, which sets the maximum zoom.
  var imagePixelSize: CGSize = .zero
  /// The image on screen, so updates that don't change it skip the transition.
  var displayedImage: NSImage?
  /// The page area, in SwiftUI's top-left-origin coordinates of this view.
  var pageFrame: CGRect = .zero {
    didSet {
      if pageFrame != oldValue { needsLayout = true }
    }
  }
  /// Called whenever the zoom scale changes.
  var onScaleChange: ((CGFloat) -> Void)?

  private(set) var scale: CGFloat = 1
  /// How far the zoomed picture's center is from its fitted center.
  private var offset: CGPoint = .zero
  private var lastDragLocation: CGPoint?

  var viewportLayer: CALayer? {
    layer?.sublayers?.first { $0.name == "viewportLayer" }
  }

  var imageLayer: CALayer? {
    viewportLayer?.sublayers?.first { $0.name == "imageLayer" }
  }

  override func layout() {
    super.layout()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    viewportLayer?.frame = bounds
    CATransaction.commit()
    // Re-clamp, since the visible area or the page may have changed size.
    apply(scale: scale, offset: offset, animated: false)
  }

  // MARK: Geometry

  /// `pageFrame` in this view's bottom-left-origin coordinates; the whole view
  /// until SwiftUI reports the page.
  private var pageRect: CGRect {
    guard pageFrame.width > 0, pageFrame.height > 0 else { return bounds }
    return CGRect(
      x: pageFrame.minX, y: bounds.height - pageFrame.maxY,
      width: pageFrame.width, height: pageFrame.height)
  }

  /// The aspect-fitted rect for the current image within the page area.
  var fittedImageRect: CGRect {
    let page = pageRect
    guard currentImageSize.width > 0, currentImageSize.height > 0,
      page.width > 0, page.height > 0
    else { return page }

    let imageAspect = currentImageSize.width / currentImageSize.height
    let pageAspect = page.width / page.height

    if imageAspect > pageAspect {
      // Wider image — letterboxed top/bottom
      let height = page.width / imageAspect
      return CGRect(x: page.minX, y: page.midY - height / 2, width: page.width, height: height)
    } else {
      // Taller image — pillarboxed left/right
      let width = page.height * imageAspect
      return CGRect(x: page.midX - width / 2, y: page.minY, width: width, height: page.height)
    }
  }

  /// The picture's rect at the current zoom and pan.
  private var zoomedImageRect: CGRect {
    let fitted = fittedImageRect
    let width = fitted.width * scale
    let height = fitted.height * scale
    return CGRect(
      x: fitted.midX + offset.x - width / 2, y: fitted.midY + offset.y - height / 2,
      width: width, height: height)
  }

  /// The on-screen part of the picture, in viewport coordinates.
  var visibleImageRect: CGRect {
    zoomedImageRect.intersection(bounds)
  }

  /// The on-screen part of the picture in the image's unit coordinates
  /// (origin bottom-left), as `contentsRect` takes them.
  var visibleContentsRect: CGRect {
    let frame = zoomedImageRect
    let visible = frame.intersection(bounds)
    guard frame.width > 0, frame.height > 0, !visible.isNull else {
      return CGRect(x: 0, y: 0, width: 1, height: 1)
    }
    return CGRect(
      x: (visible.minX - frame.minX) / frame.width, y: (visible.minY - frame.minY) / frame.height,
      width: visible.width / frame.width, height: visible.height / frame.height)
  }

  /// Up to two screen pixels per picture pixel, and never less than 4×.
  private var maxScale: CGFloat {
    let fittedPixels = fittedImageRect.width * (window?.backingScaleFactor ?? 2)
    guard fittedPixels > 0, imagePixelSize.width > 0 else { return Self.minimumMaxScale }
    return max(Self.minimumMaxScale, 2 * imagePixelSize.width / fittedPixels)
  }

  /// Zooming or panning mid-transition would shift the picture under the
  /// transition's snapshot layers.
  private var canZoom: Bool {
    guard let imageLayer, let viewportLayer, imageLayer.contents != nil else { return false }
    let hasSnapshots =
      !(imageLayer.sublayers ?? []).isEmpty
      || (viewportLayer.sublayers ?? []).contains { $0 !== imageLayer }
    return imageLayer.animation(forKey: "slideTransition") == nil
      && viewportLayer.animation(forKey: "slideTransition") == nil
      && !hasSnapshots
  }

  // MARK: Zoom

  /// Zooms by `factor`, keeping the picture point under `focus` (the middle of
  /// the view if nil) in place.
  func zoom(by factor: CGFloat, around focus: CGPoint? = nil, animated: Bool) {
    guard canZoom else { return }
    let newScale = min(max(scale * factor, 1), maxScale)
    guard newScale != scale else { return }

    let newOffset: CGPoint
    if newScale > scale {
      let fitted = fittedImageRect
      let focus = focus ?? CGPoint(x: bounds.midX, y: bounds.midY)
      let ratio = newScale / scale
      let centerX = focus.x + (fitted.midX + offset.x - focus.x) * ratio
      let centerY = focus.y + (fitted.midY + offset.y - focus.y) * ratio
      newOffset = CGPoint(x: centerX - fitted.midX, y: centerY - fitted.midY)
    } else {
      // Ease the picture back toward its fitted place, arriving there at 1×.
      let ratio = (newScale - 1) / (scale - 1)
      newOffset = CGPoint(x: offset.x * ratio, y: offset.y * ratio)
    }
    apply(scale: newScale, offset: newOffset, animated: animated)
  }

  func fit(animated: Bool) {
    apply(scale: 1, offset: .zero, animated: animated)
  }

  /// Pans by fractions of the visible area; positive values reveal more to the
  /// right and further down. Returns false when the picture can't move that way.
  @discardableResult
  func pan(byFractionX fractionX: CGFloat, y fractionY: CGFloat) -> Bool {
    guard scale > 1, canZoom else { return false }
    let oldOffset = offset
    let newOffset = CGPoint(
      x: offset.x - fractionX * bounds.width, y: offset.y + fractionY * bounds.height)
    apply(scale: scale, offset: newOffset, animated: true)
    return abs(offset.x - oldOffset.x) > 0.5 || abs(offset.y - oldOffset.y) > 0.5
  }

  /// Lays out a newly shown picture without animation, keeping the zoom and
  /// placing it at `start`. Call after updating `currentImageSize`.
  func showNewPicture(startingAt start: ZoomedPictureStart) {
    imageLayer?.removeAllAnimations()
    let fitted = fittedImageRect
    let halfWidth = fitted.width * scale / 2
    let halfHeight = fitted.height * scale / 2
    // Aim the picture's corner at the matching view corner; apply() clamps it there.
    let center =
      start == .topLeading
      ? CGPoint(x: bounds.minX + halfWidth, y: bounds.maxY - halfHeight)
      : CGPoint(x: bounds.maxX - halfWidth, y: bounds.minY + halfHeight)
    apply(
      scale: scale, offset: CGPoint(x: center.x - fitted.midX, y: center.y - fitted.midY),
      animated: false)
  }

  /// Clamps and stores the zoom, then moves the image layer to match.
  private func apply(scale newScale: CGFloat, offset newOffset: CGPoint, animated: Bool) {
    let oldScale = scale
    scale = min(max(newScale, 1), max(maxScale, 1))
    if scale > 1 {
      // Along an axis where the picture still fits on screen there is nothing to
      // pan to, so it stays as close to its fitted place as it can.
      let fitted = fittedImageRect
      let width = fitted.width * scale
      let height = fitted.height * scale
      let centerX = Self.clamp(
        fitted.midX + (width > bounds.width ? newOffset.x : 0), length: width,
        within: bounds.minX, bounds.maxX)
      let centerY = Self.clamp(
        fitted.midY + (height > bounds.height ? newOffset.y : 0), length: height,
        within: bounds.minY, bounds.maxY)
      offset = CGPoint(x: centerX - fitted.midX, y: centerY - fitted.midY)
    } else {
      offset = .zero
    }

    if let imageLayer {
      CATransaction.begin()
      if animated {
        CATransaction.setAnimationDuration(Self.zoomAnimationDuration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
      } else {
        CATransaction.setDisableActions(true)
      }
      imageLayer.frame = zoomedImageRect
      // Fade the shadow out by 1.25×: a picture spread over the slideshow needs none.
      let shadowFade = Float(max(0, 1 - (scale - 1) * 4))
      imageLayer.shadowOpacity = Self.imageShadowOpacity * shadowFade
      CATransaction.commit()
    }

    if scale != oldScale { onScaleChange?(scale) }
  }

  /// Keeps a picture span inside `[low, high]` when it is shorter than that
  /// range, and covering it when longer.
  private static func clamp(
    _ center: CGFloat, length: CGFloat, within low: CGFloat, _ high: CGFloat
  ) -> CGFloat {
    let lowest = min(low + length / 2, high - length / 2)
    let highest = max(low + length / 2, high - length / 2)
    return min(max(center, lowest), highest)
  }

  // MARK: Gestures

  override func magnify(with event: NSEvent) {
    zoom(by: 1 + event.magnification, around: location(of: event), animated: false)
  }

  /// Two-finger double-tap on a trackpad.
  override func smartMagnify(with event: NSEvent) {
    toggleZoom(at: location(of: event))
  }

  override func scrollWheel(with event: NSEvent) {
    guard scale > 1 else {
      super.scrollWheel(with: event)
      return
    }
    let distance = event.hasPreciseScrollingDeltas ? 1 : Self.lineScrollDistance
    // The picture follows the fingers; positive deltas move content right and down.
    let newOffset = CGPoint(
      x: offset.x + event.scrollingDeltaX * distance,
      y: offset.y - event.scrollingDeltaY * distance)
    apply(scale: scale, offset: newOffset, animated: false)
  }

  override func mouseDown(with event: NSEvent) {
    if event.clickCount == 2 {
      toggleZoom(at: location(of: event))
    } else if scale > 1 {
      lastDragLocation = location(of: event)
    } else {
      super.mouseDown(with: event)
    }
  }

  override func mouseDragged(with event: NSEvent) {
    guard let last = lastDragLocation else {
      super.mouseDragged(with: event)
      return
    }
    let point = location(of: event)
    lastDragLocation = point
    let newOffset = CGPoint(x: offset.x + point.x - last.x, y: offset.y + point.y - last.y)
    apply(scale: scale, offset: newOffset, animated: false)
  }

  override func mouseUp(with event: NSEvent) {
    guard lastDragLocation != nil else {
      super.mouseUp(with: event)
      return
    }
    lastDragLocation = nil
  }

  /// Fits a zoomed picture; otherwise zooms to 2× at `point`.
  private func toggleZoom(at point: CGPoint) {
    if scale > 1 {
      fit(animated: true)
    } else {
      zoom(by: 2, around: point, animated: true)
    }
  }

  private func location(of event: NSEvent) -> CGPoint {
    convert(event.locationInWindow, from: nil)
  }
}
