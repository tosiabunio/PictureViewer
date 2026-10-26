import SwiftUI

// MARK: - Slideshow control icons
// Drawn on the same 24x24 grid as `LineIcons.swift`, using its coordinate helpers.

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

/// Plain magnifying glass — slideshow zoom mode.
struct MagnifierIcon: Shape {
  func path(in rect: CGRect) -> Path {
    let scale = scaleFactors(in: rect)
    var path = Path()
    path.addArc(
      center: scaledPoint(11, 11, scale), radius: 8 * scale.scaleX,
      startAngle: .zero, endAngle: .degrees(360), clockwise: false)
    path.move(to: scaledPoint(21, 21, scale))
    path.addLine(to: scaledPoint(16.65, 16.65, scale))
    return path
  }
}

/// Four corner brackets — fit the picture to the page.
struct FitIcon: Shape {
  func path(in rect: CGRect) -> Path {
    let scale = scaleFactors(in: rect)
    var path = Path()
    path.move(to: scaledPoint(4, 9, scale))
    path.addLine(to: scaledPoint(4, 4, scale))
    path.addLine(to: scaledPoint(9, 4, scale))
    path.move(to: scaledPoint(15, 4, scale))
    path.addLine(to: scaledPoint(20, 4, scale))
    path.addLine(to: scaledPoint(20, 9, scale))
    path.move(to: scaledPoint(20, 15, scale))
    path.addLine(to: scaledPoint(20, 20, scale))
    path.addLine(to: scaledPoint(15, 20, scale))
    path.move(to: scaledPoint(9, 20, scale))
    path.addLine(to: scaledPoint(4, 20, scale))
    path.addLine(to: scaledPoint(4, 15, scale))
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
