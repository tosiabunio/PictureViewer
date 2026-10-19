import AppKit
import Foundation

/// A single image discovered in the browsed folder.
struct ImageItem: Identifiable, Hashable {
  let id: UUID
  let url: URL
  let filename: String
  let fileSize: Int64
  let modificationDate: Date

  init(url: URL, fileSize: Int64 = 0, modificationDate: Date = .now) {
    self.id = UUID()
    self.url = url
    self.filename = url.lastPathComponent
    self.fileSize = fileSize
    self.modificationDate = modificationDate
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(url)
  }

  static func == (lhs: ImageItem, rhs: ImageItem) -> Bool {
    lhs.url == rhs.url
  }
}

/// The animation types that cycle during slideshow transitions.
///
/// `flip`, `bend`, and `curl` are single-effect transitions.
/// `book` is a realistic page turn — `pageCurl` going forward, `pageUnCurl` going
/// backward — with a natural timing curve that mimics lifting a real page corner.
/// `blocks` is a mosaic dissolve — the old image breaks into a grid of tiles that
/// fade out with staggered delays, revealing the new image underneath.
/// `zoomFront` scales the old image toward the viewer while fading out.
/// `pixelate` progressively pixelates the old image then dissolves it.
/// `spiral` reveals tiles in clockwise spiral order from outer edge inward.
enum SlideAnimationType: CaseIterable {
  case flip
  case bend
  case curl
  case book
  case blocks
  case zoomFront
  case pixelate
  case spiral
}
