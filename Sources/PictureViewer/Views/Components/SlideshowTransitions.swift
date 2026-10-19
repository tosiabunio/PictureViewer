import AppKit
import QuartzCore

// MARK: - Custom Transitions (compositor-thread animations)

/// All custom slideshow transitions — blocks, zoomFront, pixelate, spiral.
///
/// Each method creates snapshot layers of the old image, applies Core Animation
/// effects, and cleans up after the transition completes. All animations run
/// entirely on the GPU compositor thread — zero main-thread blocking.
///
/// Snapshots go on `host` and cover `rect` (in host coordinates), showing the
/// `oldContentsRect` part of the old image: the whole image on the picture layer
/// when unzoomed, or just the part that was on screen on the viewport when zoomed.
extension SlideshowImageView {

  /// Route to the correct custom transition based on the current animation type.
  func dispatchCustomTransition(
    oldImage: Any?, showing oldContentsRect: CGRect, on host: CALayer, in rect: CGRect
  ) {
    switch animationType {
    case .blocks:
      performBlocksTransition(
        oldImage: oldImage, showing: oldContentsRect, on: host, in: rect)
    case .zoomFront:
      performZoomFrontTransition(
        oldImage: oldImage, showing: oldContentsRect, on: host, in: rect)
    case .pixelate:
      performPixelateTransition(
        oldImage: oldImage, showing: oldContentsRect, on: host, in: rect)
    case .spiral:
      performSpiralTransition(
        oldImage: oldImage, showing: oldContentsRect, on: host, in: rect)
    case .flip, .bend, .curl, .book:
      break  // Handled via CATransition in updateNSView
    }
  }

  /// The part of `contentsRect` shown by the tile at `col`, `row` of a grid.
  private func tileContentsRect(
    col: Int, row: Int, cols: Int, rows: Int, in contentsRect: CGRect
  ) -> CGRect {
    CGRect(
      x: contentsRect.minX + contentsRect.width * CGFloat(col) / CGFloat(cols),
      y: contentsRect.minY + contentsRect.height * CGFloat(row) / CGFloat(rows),
      width: contentsRect.width / CGFloat(cols),
      height: contentsRect.height / CGFloat(rows)
    )
  }

  /// Remove all sublayers with a given name from the host layer.
  private func removeTransitionSublayers(named name: String, from layer: CALayer) {
    guard let sublayers = layer.sublayers else { return }
    for sub in sublayers where sub.name == name {
      sub.removeFromSuperlayer()
    }
  }

  // MARK: - Blocks (mosaic dissolve)

  /// Overlay a grid of tiles showing the old image, then fade each tile out
  /// with staggered random delays to reveal the new image underneath.
  func performBlocksTransition(
    oldImage: Any?, showing oldContentsRect: CGRect, on host: CALayer, in rect: CGRect
  ) {
    removeTransitionSublayers(named: "blockTile", from: host)
    guard let cgImage = oldImage else { return }

    let edge = DesignSystem.blocksEdge
    let cols = max(1, Int(ceil(rect.width / edge)))
    let rows = max(1, Int(ceil(rect.height / edge)))
    let tileW = rect.width / CGFloat(cols)
    let tileH = rect.height / CGFloat(rows)

    let totalDuration = duration
    // Scaled with the total, so speedy mode plays the same stagger faster.
    let fadeDuration = DesignSystem.blocksBlockFade * duration / DesignSystem.blocksDuration
    let maxDelay = totalDuration - fadeDuration

    for row in 0..<rows {
      for col in 0..<cols {
        let tile = CALayer()
        tile.name = "blockTile"
        tile.frame = CGRect(
          x: rect.minX + CGFloat(col) * tileW,
          y: rect.minY + CGFloat(row) * tileH,
          width: tileW,
          height: tileH
        )
        tile.contents = cgImage
        tile.contentsGravity = .resizeAspect
        tile.contentsRect = tileContentsRect(
          col: col, row: row, cols: cols, rows: rows, in: oldContentsRect)
        tile.masksToBounds = true
        host.addSublayer(tile)

        let delay = Double.random(in: 0...maxDelay)
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1.0
        fade.toValue = 0.0
        fade.beginTime = CACurrentMediaTime() + delay
        fade.duration = fadeDuration
        fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        tile.add(fade, forKey: "blockFade")
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration + 0.05) {
      self.removeTransitionSublayers(named: "blockTile", from: host)
    }
  }

  // MARK: - Zoom Front

  /// Old image scales up toward the viewer while fading out, revealing the new image.
  ///
  /// Creates a snapshot layer of the old image, then applies a grouped animation:
  /// `transform.scale` (1.0 → 1.4) + `opacity` (1.0 → 0.0).
  func performZoomFrontTransition(
    oldImage: Any?, showing oldContentsRect: CGRect, on host: CALayer, in rect: CGRect
  ) {
    removeTransitionSublayers(named: "zoomSnapshot", from: host)
    guard let cgImage = oldImage else { return }

    let snapshot = CALayer()
    snapshot.name = "zoomSnapshot"
    snapshot.frame = rect
    snapshot.contents = cgImage
    snapshot.contentsRect = oldContentsRect
    snapshot.contentsGravity = .resizeAspect
    snapshot.masksToBounds = true
    host.addSublayer(snapshot)

    // Scale up toward the viewer
    let scale = CABasicAnimation(keyPath: "transform.scale")
    scale.fromValue = 1.0
    scale.toValue = 1.4

    // Fade out
    let fade = CABasicAnimation(keyPath: "opacity")
    fade.fromValue = 1.0
    fade.toValue = 0.0

    let group = CAAnimationGroup()
    group.animations = [scale, fade]
    group.duration = duration
    group.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1.0)
    group.fillMode = .forwards
    group.isRemovedOnCompletion = false
    snapshot.add(group, forKey: "zoomFront")

    DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) {
      self.removeTransitionSublayers(named: "zoomSnapshot", from: host)
    }
  }

  // MARK: - Pixelate

  /// Old image progressively pixelates then dissolves to reveal the new image.
  ///
  /// Uses CIPixellate filter on a snapshot layer. Phase 1 (65% of duration):
  /// pixel scale animates from 1 → 40. Phase 2 (last 60%): opacity fades out.
  /// Falls back to a simple fade if CIFilter is unavailable.
  func performPixelateTransition(
    oldImage: Any?, showing oldContentsRect: CGRect, on host: CALayer, in rect: CGRect
  ) {
    removeTransitionSublayers(named: "pixelSnapshot", from: host)
    guard let cgImage = oldImage else { return }

    let snapshot = CALayer()
    snapshot.name = "pixelSnapshot"
    snapshot.frame = rect
    snapshot.contents = cgImage
    snapshot.contentsRect = oldContentsRect
    snapshot.contentsGravity = .resizeAspect
    snapshot.masksToBounds = true
    host.addSublayer(snapshot)

    // Apply CIPixellate filter
    if let pixellateFilter = CIFilter(name: "CIPixellate") {
      pixellateFilter.setDefaults()
      pixellateFilter.setValue(1.0, forKey: kCIInputScaleKey)
      snapshot.filters = [pixellateFilter]

      // Phase 1: pixelate — animate inputScale from 1 to 40
      let pixelAnim = CABasicAnimation(keyPath: "filters.pixellate.inputScale")
      pixelAnim.fromValue = 1.0
      pixelAnim.toValue = 40.0
      pixelAnim.beginTime = 0
      pixelAnim.duration = duration * 0.65
      pixelAnim.timingFunction = CAMediaTimingFunction(name: .easeIn)
      pixelAnim.fillMode = .forwards
      pixelAnim.isRemovedOnCompletion = false

      // Phase 2: fade out — overlaps with pixelation
      let fade = CABasicAnimation(keyPath: "opacity")
      fade.fromValue = 1.0
      fade.toValue = 0.0
      fade.beginTime = duration * 0.4
      fade.duration = duration * 0.6
      fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
      fade.fillMode = .forwards
      fade.isRemovedOnCompletion = false

      let group = CAAnimationGroup()
      group.animations = [pixelAnim, fade]
      group.duration = duration
      group.fillMode = .forwards
      group.isRemovedOnCompletion = false
      snapshot.add(group, forKey: "pixelate")
    } else {
      // Fallback: simple fade
      let fade = CABasicAnimation(keyPath: "opacity")
      fade.fromValue = 1.0
      fade.toValue = 0.0
      fade.duration = duration
      fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
      fade.fillMode = .forwards
      fade.isRemovedOnCompletion = false
      snapshot.add(fade, forKey: "pixelateFallback")
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) {
      self.removeTransitionSublayers(named: "pixelSnapshot", from: host)
    }
  }

  // MARK: - Spiral

  /// Tiles reveal in clockwise spiral order from the outer edge inward.
  ///
  /// Same grid structure as blocks, but tile fade-out delays follow a spiral
  /// traversal pattern instead of random ordering.
  func performSpiralTransition(
    oldImage: Any?, showing oldContentsRect: CGRect, on host: CALayer, in rect: CGRect
  ) {
    removeTransitionSublayers(named: "spiralTile", from: host)
    guard let cgImage = oldImage else { return }

    let edge = DesignSystem.blocksEdge
    let cols = max(1, Int(ceil(rect.width / edge)))
    let rows = max(1, Int(ceil(rect.height / edge)))
    let tileW = rect.width / CGFloat(cols)
    let tileH = rect.height / CGFloat(rows)

    let totalDuration = duration
    // Scaled with the total, so speedy mode plays the same stagger faster.
    let fadeDuration = DesignSystem.blocksBlockFade * duration / DesignSystem.spiralDuration
    let maxDelay = totalDuration - fadeDuration

    let order = spiralOrder(rows: rows, cols: cols)
    let totalTiles = order.count

    for (spiralIndex, pos) in order.enumerated() {
      let tile = CALayer()
      tile.name = "spiralTile"
      tile.frame = CGRect(
        x: rect.minX + CGFloat(pos.col) * tileW,
        y: rect.minY + CGFloat(pos.row) * tileH,
        width: tileW,
        height: tileH
      )
      tile.contents = cgImage
      tile.contentsGravity = .resizeAspect
      tile.contentsRect = tileContentsRect(
        col: pos.col, row: pos.row, cols: cols, rows: rows, in: oldContentsRect)
      tile.masksToBounds = true
      host.addSublayer(tile)

      let delay: Double
      if totalTiles > 1 {
        delay = (Double(spiralIndex) / Double(totalTiles - 1)) * maxDelay
      } else {
        delay = 0.0
      }
      let fade = CABasicAnimation(keyPath: "opacity")
      fade.fromValue = 1.0
      fade.toValue = 0.0
      fade.beginTime = CACurrentMediaTime() + delay
      fade.duration = fadeDuration
      fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
      fade.fillMode = .forwards
      fade.isRemovedOnCompletion = false
      tile.add(fade, forKey: "spiralFade")
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration + 0.05) {
      self.removeTransitionSublayers(named: "spiralTile", from: host)
    }
  }

  // MARK: - Spiral Order Helper

  /// Generate a clockwise spiral traversal of grid positions, from outer edge inward.
  ///
  /// Returns an array of `(row, col)` tuples in the order they should be visited.
  /// The spiral starts at the top-left corner and proceeds: right → down → left → up.
  private func spiralOrder(rows: Int, cols: Int) -> [(row: Int, col: Int)] {
    var result: [(row: Int, col: Int)] = []
    result.reserveCapacity(rows * cols)

    var top = 0
    var bottom = rows - 1
    var left = 0
    var right = cols - 1

    while top <= bottom, left <= right {
      // Move right across top row
      for col in left...right {
        result.append((row: top, col: col))
      }
      top += 1

      // Move down along right column
      if top <= bottom {
        for row in top...bottom {
          result.append((row: row, col: right))
        }
      }
      right -= 1

      // Move left across bottom row
      if top <= bottom, left <= right {
        for col in stride(from: right, through: left, by: -1) {
          result.append((row: bottom, col: col))
        }
      }
      bottom -= 1

      // Move up along left column
      if top <= bottom, left <= right {
        for row in stride(from: bottom, through: top, by: -1) {
          result.append((row: row, col: left))
        }
      }
      left += 1
    }

    return result
  }
}
