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

/// Order of images in the gallery and slideshow.
enum ImageSortOrder: String, CaseIterable, Identifiable {
  case nameAscending
  case nameDescending
  case newestFirst
  case oldestFirst

  var id: Self { self }

  var title: String {
    switch self {
    case .nameAscending: return "Name (A–Z)"
    case .nameDescending: return "Name (Z–A)"
    case .newestFirst: return "Newest First"
    case .oldestFirst: return "Oldest First"
    }
  }

  /// Names compare like Finder ("page2" before "page10") and by full path, so
  /// images in subfolders stay grouped. Date ties fall back to name, since
  /// files extracted from an archive often share one modification time.
  func areInIncreasingOrder(_ lhs: ImageItem, _ rhs: ImageItem) -> Bool {
    switch self {
    case .nameAscending:
      return Self.compareNames(lhs, rhs) == .orderedAscending
    case .nameDescending:
      return Self.compareNames(lhs, rhs) == .orderedDescending
    case .newestFirst where lhs.modificationDate != rhs.modificationDate:
      return lhs.modificationDate > rhs.modificationDate
    case .oldestFirst where lhs.modificationDate != rhs.modificationDate:
      return lhs.modificationDate < rhs.modificationDate
    case .newestFirst, .oldestFirst:
      return Self.compareNames(lhs, rhs) == .orderedAscending
    }
  }

  private static func compareNames(_ lhs: ImageItem, _ rhs: ImageItem) -> ComparisonResult {
    lhs.url.path.localizedStandardCompare(rhs.url.path)
  }
}

/// The slideshow's transition effects; see `SlideTransitionChoice` for which one is used.
///
/// `flip`, `bend`, and `curl` are single-effect transitions.
/// `book` is a realistic page turn — `pageCurl` going forward, `pageUnCurl` going
/// backward — with a natural timing curve that mimics lifting a real page corner.
/// `blocks` is a mosaic dissolve — the old image breaks into a grid of tiles that
/// fade out with staggered delays, revealing the new image underneath.
/// `zoomFront` scales the old image toward the viewer while fading out.
/// `pixelate` progressively pixelates the old image then dissolves it.
/// `spiral` reveals tiles in clockwise spiral order from outer edge inward.
enum SlideAnimationType: String, CaseIterable, Identifiable {
  case flip
  case bend
  case curl
  case book
  case blocks
  case zoomFront
  case pixelate
  case spiral

  var id: Self { self }

  /// Name shown in the transition menus.
  var title: String {
    switch self {
    case .flip: return "Flip"
    case .bend: return "Bend"
    case .curl: return "Curl"
    case .book: return "Book"
    case .blocks: return "Blocks"
    case .zoomFront: return "Zoom"
    case .pixelate: return "Pixelate"
    case .spiral: return "Spiral"
    }
  }
}

/// Which transition the slideshow uses: every effect in turn, or always the same one.
///
/// Stored in UserDefaults as its raw value — `cycle`, or the effect's raw value.
enum SlideTransitionChoice: Hashable {
  case cycle
  case fixed(SlideAnimationType)

  static let defaultsKey = "slideTransition"

  var title: String {
    switch self {
    case .cycle: return "Cycle Through All"
    case .fixed(let type): return type.title
    }
  }

  /// The effect for the slideshow's `index`-th transition.
  func animationType(forTransition index: Int) -> SlideAnimationType {
    switch self {
    case .cycle:
      let allTypes = SlideAnimationType.allCases
      return allTypes[index % allTypes.count]
    case .fixed(let type):
      return type
    }
  }
}

extension SlideTransitionChoice: RawRepresentable {
  init?(rawValue: String) {
    if rawValue == "cycle" {
      self = .cycle
    } else if let type = SlideAnimationType(rawValue: rawValue) {
      self = .fixed(type)
    } else {
      return nil
    }
  }

  var rawValue: String {
    switch self {
    case .cycle: return "cycle"
    case .fixed(let type): return type.rawValue
    }
  }
}
