import SwiftUI

// MARK: - Line-only icon shapes ported from Icons.tsx
// All icons use a 24x24 coordinate space with 1.5pt stroke,
// rounded caps and joins — matching the Tauri version exactly.

/// 2x2 grid of rounded rectangles.
struct GridIcon: Shape {
  func path(in rect: CGRect) -> Path {
    let scale = scaleFactors(in: rect)
    var path = Path()
    path.addRoundedRect(in: scaledRect(3, 3, 7, 7, scale), cornerSize: .zero)
    path.addRoundedRect(in: scaledRect(14, 3, 7, 7, scale), cornerSize: .zero)
    path.addRoundedRect(in: scaledRect(14, 14, 7, 7, scale), cornerSize: .zero)
    path.addRoundedRect(in: scaledRect(3, 14, 7, 7, scale), cornerSize: .zero)
    return path
  }
}

/// Magnifying glass with a `+` inside.
struct ZoomInIcon: Shape {
  func path(in rect: CGRect) -> Path {
    let scale = scaleFactors(in: rect)
    var path = Path()
    path.addArc(
      center: scaledPoint(11, 11, scale), radius: 8 * scale.scaleX,
      startAngle: .zero, endAngle: .degrees(360), clockwise: false)
    path.move(to: scaledPoint(21, 21, scale))
    path.addLine(to: scaledPoint(16.65, 16.65, scale))
    path.move(to: scaledPoint(11, 8, scale))
    path.addLine(to: scaledPoint(11, 14, scale))
    path.move(to: scaledPoint(8, 11, scale))
    path.addLine(to: scaledPoint(14, 11, scale))
    return path
  }
}

/// Magnifying glass with a `−` inside.
struct ZoomOutIcon: Shape {
  func path(in rect: CGRect) -> Path {
    let scale = scaleFactors(in: rect)
    var path = Path()
    path.addArc(
      center: scaledPoint(11, 11, scale), radius: 8 * scale.scaleX,
      startAngle: .zero, endAngle: .degrees(360), clockwise: false)
    path.move(to: scaledPoint(21, 21, scale))
    path.addLine(to: scaledPoint(16.65, 16.65, scale))
    path.move(to: scaledPoint(8, 11, scale))
    path.addLine(to: scaledPoint(14, 11, scale))
    return path
  }
}

/// X mark — two crossed diagonal lines.
struct CloseIcon: Shape {
  func path(in rect: CGRect) -> Path {
    let scale = scaleFactors(in: rect)
    var path = Path()
    path.move(to: scaledPoint(18, 6, scale))
    path.addLine(to: scaledPoint(6, 18, scale))
    path.move(to: scaledPoint(6, 6, scale))
    path.addLine(to: scaledPoint(18, 18, scale))
    return path
  }
}

/// Left-pointing chevron (`<`).
struct ChevronLeftIcon: Shape {
  func path(in rect: CGRect) -> Path {
    let scale = scaleFactors(in: rect)
    var path = Path()
    path.move(to: scaledPoint(15, 18, scale))
    path.addLine(to: scaledPoint(9, 12, scale))
    path.addLine(to: scaledPoint(15, 6, scale))
    return path
  }
}

/// Right-pointing chevron (`>`).
struct ChevronRightIcon: Shape {
  func path(in rect: CGRect) -> Path {
    let scale = scaleFactors(in: rect)
    var path = Path()
    path.move(to: scaledPoint(9, 18, scale))
    path.addLine(to: scaledPoint(15, 12, scale))
    path.addLine(to: scaledPoint(9, 6, scale))
    return path
  }
}

/// Circular reload arrows.
struct RefreshIcon: Shape {
  func path(in rect: CGRect) -> Path {
    let scale = scaleFactors(in: rect)
    var path = Path()
    // Top-right arrowhead
    path.move(to: scaledPoint(23, 4, scale))
    path.addLine(to: scaledPoint(23, 10, scale))
    path.addLine(to: scaledPoint(17, 10, scale))
    // Bottom-left arrowhead
    path.move(to: scaledPoint(1, 20, scale))
    path.addLine(to: scaledPoint(1, 14, scale))
    path.addLine(to: scaledPoint(7, 14, scale))
    // Upper arc (approximate the SVG arc with a cubic)
    path.move(to: scaledPoint(3.51, 9, scale))
    path.addCurve(
      to: scaledPoint(23, 10, scale),
      control1: scaledPoint(5, 3, scale),
      control2: scaledPoint(14, 2, scale))
    // Lower arc
    path.move(to: scaledPoint(1, 14, scale))
    path.addCurve(
      to: scaledPoint(20.49, 15, scale),
      control1: scaledPoint(3, 21, scale),
      control2: scaledPoint(14, 22, scale))
    return path
  }
}

/// Folder outline.
struct FolderIcon: Shape {
  func path(in rect: CGRect) -> Path {
    let scale = scaleFactors(in: rect)
    var path = Path()
    path.move(to: scaledPoint(22, 19, scale))
    path.addCurve(
      to: scaledPoint(20, 21, scale),
      control1: scaledPoint(22, 20.1, scale),
      control2: scaledPoint(21.1, 21, scale))
    path.addLine(to: scaledPoint(4, 21, scale))
    path.addCurve(
      to: scaledPoint(2, 19, scale),
      control1: scaledPoint(2.9, 21, scale),
      control2: scaledPoint(2, 20.1, scale))
    path.addLine(to: scaledPoint(2, 5, scale))
    path.addCurve(
      to: scaledPoint(4, 3, scale),
      control1: scaledPoint(2, 3.9, scale),
      control2: scaledPoint(2.9, 3, scale))
    path.addLine(to: scaledPoint(9, 3, scale))
    path.addLine(to: scaledPoint(11, 6, scale))
    path.addLine(to: scaledPoint(20, 6, scale))
    path.addCurve(
      to: scaledPoint(22, 8, scale),
      control1: scaledPoint(21.1, 6, scale),
      control2: scaledPoint(22, 6.9, scale))
    path.closeSubpath()
    return path
  }
}

/// Down arrow beside an up arrow — sort order.
struct SortIcon: Shape {
  func path(in rect: CGRect) -> Path {
    let scale = scaleFactors(in: rect)
    var path = Path()
    // Down arrow
    path.move(to: scaledPoint(7, 4, scale))
    path.addLine(to: scaledPoint(7, 20, scale))
    path.move(to: scaledPoint(3, 16, scale))
    path.addLine(to: scaledPoint(7, 20, scale))
    path.addLine(to: scaledPoint(11, 16, scale))
    // Up arrow
    path.move(to: scaledPoint(17, 20, scale))
    path.addLine(to: scaledPoint(17, 4, scale))
    path.move(to: scaledPoint(13, 8, scale))
    path.addLine(to: scaledPoint(17, 4, scale))
    path.addLine(to: scaledPoint(21, 8, scale))
    return path
  }
}

/// Image frame with mountain + sun landscape sketch.
struct ImageIcon: Shape {
  func path(in rect: CGRect) -> Path {
    let scale = scaleFactors(in: rect)
    var path = Path()
    // Frame
    path.addRoundedRect(
      in: scaledRect(3, 3, 18, 18, scale),
      cornerSize: CGSize(width: 2 * scale.scaleX, height: 2 * scale.scaleY))
    // Sun
    path.addArc(
      center: scaledPoint(8.5, 8.5, scale), radius: 1.5 * scale.scaleX,
      startAngle: .zero, endAngle: .degrees(360), clockwise: false)
    // Mountain polyline
    path.move(to: scaledPoint(21, 15, scale))
    path.addLine(to: scaledPoint(16, 10, scale))
    path.addLine(to: scaledPoint(5, 21, scale))
    return path
  }
}

/// Filled play triangle.
struct PlayIcon: Shape {
  func path(in rect: CGRect) -> Path {
    let scale = scaleFactors(in: rect)
    var path = Path()
    path.move(to: scaledPoint(8, 5, scale))
    path.addLine(to: scaledPoint(8, 19, scale))
    path.addLine(to: scaledPoint(19, 12, scale))
    path.closeSubpath()
    return path
  }
}

/// Filled pause bars.
struct PauseIcon: Shape {
  func path(in rect: CGRect) -> Path {
    let scale = scaleFactors(in: rect)
    var path = Path()
    path.addRect(scaledRect(6, 4, 4, 16, scale))
    path.addRect(scaledRect(14, 4, 4, 16, scale))
    return path
  }
}

/// Stop square — line-only outline.
struct StopIcon: Shape {
  func path(in rect: CGRect) -> Path {
    let scale = scaleFactors(in: rect)
    var path = Path()
    path.addRoundedRect(
      in: scaledRect(6, 6, 12, 12, scale),
      cornerSize: CGSize(width: 1.5 * scale.scaleX, height: 1.5 * scale.scaleY))
    return path
  }
}

/// Trash can — line-only with lid, body, and inner lines.
struct TrashIcon: Shape {
  func path(in rect: CGRect) -> Path {
    let scale = scaleFactors(in: rect)
    var path = Path()
    // Lid
    path.move(to: scaledPoint(3, 6, scale))
    path.addLine(to: scaledPoint(21, 6, scale))
    // Handle
    path.move(to: scaledPoint(9, 6, scale))
    path.addLine(to: scaledPoint(9, 4, scale))
    path.addCurve(
      to: scaledPoint(10, 3, scale),
      control1: scaledPoint(9, 3.45, scale),
      control2: scaledPoint(9.45, 3, scale))
    path.addLine(to: scaledPoint(14, 3, scale))
    path.addCurve(
      to: scaledPoint(15, 4, scale),
      control1: scaledPoint(14.55, 3, scale),
      control2: scaledPoint(15, 3.45, scale))
    path.addLine(to: scaledPoint(15, 6, scale))
    // Body
    path.move(to: scaledPoint(5, 6, scale))
    path.addLine(to: scaledPoint(5, 20, scale))
    path.addCurve(
      to: scaledPoint(7, 22, scale),
      control1: scaledPoint(5, 21.1, scale),
      control2: scaledPoint(5.9, 22, scale))
    path.addLine(to: scaledPoint(17, 22, scale))
    path.addCurve(
      to: scaledPoint(19, 20, scale),
      control1: scaledPoint(18.1, 22, scale),
      control2: scaledPoint(19, 21.1, scale))
    path.addLine(to: scaledPoint(19, 6, scale))
    // Inner lines
    path.move(to: scaledPoint(10, 10, scale))
    path.addLine(to: scaledPoint(10, 18, scale))
    path.move(to: scaledPoint(14, 10, scale))
    path.addLine(to: scaledPoint(14, 18, scale))
    return path
  }
}

/// Skip-to-first — vertical bar with a left chevron (⏮).
struct SkipToFirstIcon: Shape {
  func path(in rect: CGRect) -> Path {
    let scale = scaleFactors(in: rect)
    var path = Path()
    // Vertical bar
    path.move(to: scaledPoint(6, 6, scale))
    path.addLine(to: scaledPoint(6, 18, scale))
    // Left chevron
    path.move(to: scaledPoint(18, 6, scale))
    path.addLine(to: scaledPoint(10, 12, scale))
    path.addLine(to: scaledPoint(18, 18, scale))
    return path
  }
}

/// Lightning bolt — speedy mode toggle.
struct SpeedIcon: Shape {
  func path(in rect: CGRect) -> Path {
    let scale = scaleFactors(in: rect)
    var path = Path()
    path.move(to: scaledPoint(13, 2, scale))
    path.addLine(to: scaledPoint(6, 14, scale))
    path.addLine(to: scaledPoint(12, 14, scale))
    path.addLine(to: scaledPoint(11, 22, scale))
    path.addLine(to: scaledPoint(18, 10, scale))
    path.addLine(to: scaledPoint(12, 10, scale))
    path.closeSubpath()
    return path
  }
}

/// Page with a folded corner — slideshow transition picker.
struct PageTurnIcon: Shape {
  func path(in rect: CGRect) -> Path {
    let scale = scaleFactors(in: rect)
    var path = Path()
    // Page outline, bottom-right corner cut off
    path.move(to: scaledPoint(5, 2, scale))
    path.addLine(to: scaledPoint(19, 2, scale))
    path.addLine(to: scaledPoint(19, 15, scale))
    path.addLine(to: scaledPoint(12, 22, scale))
    path.addLine(to: scaledPoint(5, 22, scale))
    path.closeSubpath()
    // Folded-over corner
    path.move(to: scaledPoint(19, 15, scale))
    path.addLine(to: scaledPoint(12, 15, scale))
    path.addLine(to: scaledPoint(12, 22, scale))
    return path
  }
}

// MARK: - Coordinate helpers

/// Scale factors to map from the 24x24 viewBox into the actual rect.
private struct ScaleFactors {
  let scaleX: CGFloat
  let scaleY: CGFloat
  let originX: CGFloat
  let originY: CGFloat
}

private func scaleFactors(in rect: CGRect) -> ScaleFactors {
  let side = min(rect.width, rect.height)
  let factorX = side / 24
  let factorY = side / 24
  let offsetX = rect.minX + (rect.width - side) / 2
  let offsetY = rect.minY + (rect.height - side) / 2
  return ScaleFactors(scaleX: factorX, scaleY: factorY, originX: offsetX, originY: offsetY)
}

private func scaledPoint(
  _ pointX: CGFloat, _ pointY: CGFloat, _ scale: ScaleFactors
) -> CGPoint {
  CGPoint(x: scale.originX + pointX * scale.scaleX, y: scale.originY + pointY * scale.scaleY)
}

private func scaledRect(
  _ rectX: CGFloat, _ rectY: CGFloat, _ width: CGFloat, _ height: CGFloat,
  _ scale: ScaleFactors
) -> CGRect {
  CGRect(
    x: scale.originX + rectX * scale.scaleX, y: scale.originY + rectY * scale.scaleY,
    width: width * scale.scaleX, height: height * scale.scaleY)
}

// MARK: - Convenience view modifier

extension Shape {
  /// Stroke with the line-icon style from the Tauri version.
  func lineIconStyle(
    color: Color = DesignSystem.textColor,
    size: CGFloat = DesignSystem.iconSize
  ) -> some View {
    self
      .stroke(
        color,
        style: StrokeStyle(
          lineWidth: DesignSystem.iconStrokeWidth,
          lineCap: .round,
          lineJoin: .round
        )
      )
      .frame(width: size, height: size)
  }

  /// Fill with the line-icon style (for PlayIcon / PauseIcon).
  func filledIconStyle(
    color: Color = DesignSystem.textColor,
    size: CGFloat = DesignSystem.iconSize
  ) -> some View {
    self
      .fill(color)
      .frame(width: size, height: size)
  }
}
