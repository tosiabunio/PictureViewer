import AppKit
import Foundation
import SwiftUI

/// Scans the chosen folder (Pictures by default) for images and provides thumbnail generation.
@MainActor
final class ImageStore: ObservableObject {

  @Published var images: [ImageItem] = []
  @Published var isLoading = false
  @Published var errorMessage: String?
  /// Folder currently being browsed. Persisted across launches.
  @Published private(set) var folderURL: URL
  /// Persisted across launches.
  @Published var sortOrder: ImageSortOrder {
    didSet {
      UserDefaults.standard.set(sortOrder.rawValue, forKey: Self.sortOrderDefaultsKey)
      images.sort(by: sortOrder.areInIncreasingOrder)
    }
  }

  private static nonisolated let supportedExtensions: Set<String> = [
    "jpg", "jpeg", "png", "gif", "webp", "bmp", "tiff", "tif", "heic", "heif",
  ]

  private static let folderDefaultsKey = "imageFolderPath"
  private static let sortOrderDefaultsKey = "imageSortOrder"

  private var thumbnailCache: [URL: NSImage] = [:]

  init() {
    folderURL = Self.savedFolder() ?? URL.picturesDirectory
    sortOrder =
      UserDefaults.standard.string(forKey: Self.sortOrderDefaultsKey)
      .flatMap(ImageSortOrder.init(rawValue:)) ?? .newestFirst
  }

  // MARK: - Public API

  /// Folder name as Finder shows it.
  var folderName: String {
    FileManager.default.displayName(atPath: folderURL.path)
  }

  var isShowingPicturesFolder: Bool {
    folderURL.standardizedFileURL.path == URL.picturesDirectory.standardizedFileURL.path
  }

  func loadImages() async {
    let folder = folderURL
    isLoading = true
    errorMessage = nil

    do {
      try ensureDirectoryExists(folder)
      let items = try await scanDirectory(folder)
      // Another folder was chosen mid-scan; its own load publishes the results.
      guard folder == folderURL else { return }
      images = items.sorted(by: sortOrder.areInIncreasingOrder)
    } catch {
      guard folder == folderURL else { return }
      errorMessage = "Failed to load images: \(error.localizedDescription)"
    }

    isLoading = false
  }

  /// Presents an open panel and switches to the folder the user picks.
  func chooseFolder() {
    let panel = NSOpenPanel()
    panel.title = "Choose a Folder"
    panel.prompt = "Choose"
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.directoryURL = folderURL

    guard panel.runModal() == .OK, let url = panel.url else { return }
    selectFolder(url)
  }

  func usePicturesFolder() {
    selectFolder(URL.picturesDirectory)
  }

  /// Returns a cached thumbnail or generates one on demand.
  func thumbnail(for item: ImageItem, size: CGFloat = DesignSystem.thumbnailSize) -> NSImage? {
    if let cached = thumbnailCache[item.url] {
      return cached
    }

    guard let image = NSImage(contentsOf: item.url) else { return nil }

    let thumb = image.resized(to: NSSize(width: size, height: size))
    thumbnailCache[item.url] = thumb
    return thumb
  }

  /// Loads the full-size image for a given item.
  func fullImage(for item: ImageItem) -> NSImage? {
    NSImage(contentsOf: item.url)
  }

  /// Remove an image from the store (e.g. after trashing).
  ///
  /// Also evicts the thumbnail cache entry so memory is freed.
  func removeImage(_ item: ImageItem) {
    images.removeAll { $0.url == item.url }
    thumbnailCache.removeValue(forKey: item.url)
  }

  // MARK: - Private

  private func selectFolder(_ url: URL) {
    folderURL = url
    if isShowingPicturesFolder {
      UserDefaults.standard.removeObject(forKey: Self.folderDefaultsKey)
    } else {
      UserDefaults.standard.set(url.path, forKey: Self.folderDefaultsKey)
    }

    images = []
    thumbnailCache.removeAll()
    Task { await loadImages() }
  }

  /// The previously chosen folder, if one was saved and still exists.
  private static func savedFolder() -> URL? {
    guard let path = UserDefaults.standard.string(forKey: folderDefaultsKey) else { return nil }
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else { return nil }
    return URL(fileURLWithPath: path, isDirectory: true)
  }

  private func ensureDirectoryExists(_ url: URL) throws {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      throw ImageStoreError.folderNotFound(url)
    }
  }

  private func scanDirectory(_ root: URL) async throws -> [ImageItem] {
    try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        var results: [ImageItem] = []
        let fileManager = FileManager.default

        guard
          let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [
              .fileSizeKey, .contentModificationDateKey, .isRegularFileKey,
            ],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
          )
        else {
          continuation.resume(returning: [])
          return
        }

        for case let fileURL as URL in enumerator {
          let ext = fileURL.pathExtension.lowercased()
          guard Self.supportedExtensions.contains(ext) else { continue }

          do {
            let values = try fileURL.resourceValues(
              forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
            )
            guard values.isRegularFile == true else { continue }

            let item = ImageItem(
              url: fileURL,
              fileSize: Int64(values.fileSize ?? 0),
              modificationDate: values.contentModificationDate ?? .distantPast
            )
            results.append(item)
          } catch {
            // Skip files we can't read metadata for
            continue
          }
        }

        continuation.resume(returning: results)
      }
    }
  }
}

// MARK: - Errors

enum ImageStoreError: LocalizedError {
  case folderNotFound(URL)

  var errorDescription: String? {
    switch self {
    case .folderNotFound(let url):
      return "Could not locate the folder at \(url.path)."
    }
  }
}

// MARK: - NSImage Resize

extension NSImage {
  func resized(to targetSize: NSSize) -> NSImage {
    let aspectWidth = targetSize.width / size.width
    let aspectHeight = targetSize.height / size.height
    let scale = min(aspectWidth, aspectHeight)
    let newSize = NSSize(
      width: size.width * scale,
      height: size.height * scale
    )

    let newImage = NSImage(size: newSize)
    newImage.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    draw(
      in: NSRect(origin: .zero, size: newSize),
      from: NSRect(origin: .zero, size: size),
      operation: .copy,
      fraction: 1.0
    )
    newImage.unlockFocus()
    return newImage
  }
}
