import SwiftUI

/// Root content view — gallery with optional slideshow overlay.
struct ContentView: View {
  @EnvironmentObject var imageStore: ImageStore
  @State private var selectedImage: ImageItem?
  @State private var showSlideshow = false
  @State private var slideshowAutoPlay = false

  var body: some View {
    ZStack {
      DesignSystem.background
        .ignoresSafeArea()

      VStack(spacing: 0) {
        HeaderView(
          imageCount: imageStore.images.count,
          folderName: imageStore.folderName,
          folderPath: imageStore.folderURL.path,
          sortOrder: $imageStore.sortOrder,
          onChooseFolder: { imageStore.chooseFolder() },
          onPlaySlideshow: {
            guard !imageStore.images.isEmpty else { return }
            selectedImage = imageStore.images.first
            slideshowAutoPlay = true
            showSlideshow = true
          }
        )

        if imageStore.isLoading {
          Spacer()
          ProgressView("Scanning \(imageStore.folderName)...")
            .font(DesignSystem.bodyFont)
            .foregroundColor(DesignSystem.textColor)
          Spacer()
        } else if let error = imageStore.errorMessage {
          Spacer()
          VStack(spacing: 12) {
            CloseIcon()
              .lineIconStyle(color: DesignSystem.secondary, size: 40)
            Text(error)
              .font(DesignSystem.bodyFont)
              .foregroundColor(DesignSystem.textColor)
          }
          Spacer()
        } else if imageStore.images.isEmpty {
          Spacer()
          VStack(spacing: 12) {
            ImageIcon()
              .lineIconStyle(color: DesignSystem.primary, size: 40)
            Text("No pictures found in \(imageStore.folderName).")
              .font(DesignSystem.bodyFont)
              .foregroundColor(DesignSystem.textColor)
          }
          Spacer()
        } else {
          GalleryView(
            images: imageStore.images,
            onSelect: { item in
              selectedImage = item
              slideshowAutoPlay = false
              showSlideshow = true
            }
          )
        }
      }

      // Slideshow overlay (macOS has no fullScreenCover)
      if showSlideshow, let selected = selectedImage {
        SlideshowView(
          startingImage: selected,
          autoPlay: slideshowAutoPlay,
          onDismiss: {
            withAnimation(.easeOut(duration: 0.3)) {
              showSlideshow = false
            }
          }
        )
        .ignoresSafeArea()
        .transition(.opacity)
        .zIndex(10)
      }
    }
    .task {
      await imageStore.loadImages()
    }
    .focusedSceneValue(\.isSlideshowShowing, showSlideshow)
  }
}

// MARK: - Focused Values

/// Lets menu commands know whether the focused window is showing a slideshow,
/// so folder changes can't swap the image list out from under it.
struct SlideshowShowingKey: FocusedValueKey {
  typealias Value = Bool
}

extension FocusedValues {
  var isSlideshowShowing: Bool? {
    get { self[SlideshowShowingKey.self] }
    set { self[SlideshowShowingKey.self] = newValue }
  }
}
