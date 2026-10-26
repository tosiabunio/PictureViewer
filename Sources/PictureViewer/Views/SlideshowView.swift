import AppKit
import SwiftUI

/// Fullscreen slideshow with Core Animation page-turn transitions.
///
/// Uses `CATransition` for GPU-composited flip, curl, and bend effects.
/// This is the primary motivation for the Swift rewrite — these transitions
/// run on the Core Animation compositor thread with zero jank, unlike the
/// web-based CSS/WAAPI approach in the Tauri version.
struct SlideshowView: View {
  let startingImage: ImageItem
  let autoPlay: Bool
  let onDismiss: () -> Void

  // Not private: the navigation in `SlideshowView+Navigation.swift` drives this state.
  @EnvironmentObject var imageStore: ImageStore
  @State var currentIndex: Int = 0
  @State var isPlaying = false
  @State var isAnimating = false
  @State var animCycleIdx = 0
  @State var currentAnimationType = SlideAnimationType.flip
  @State var currentTransitionDuration = DesignSystem.flipDuration
  @State var glowCycleIdx = 0
  @State var navigatingForward = true
  @State var currentNSImage: NSImage?
  @State var currentImageSize: CGSize = .zero
  @State var isSpeedy = false
  @AppStorage(SlideTransitionChoice.defaultsKey)
  var transitionChoice = SlideTransitionChoice.cycle
  @StateObject var zoom = SlideshowZoom()
  /// In zoom mode the controls and arrow keys zoom and pan instead of switching pictures.
  @State var isZoomMode = false
  /// The area between the bars where the unzoomed picture sits.
  @State private var pageFrame: CGRect = .zero
  /// Where the next picture starts while zoomed: reading order by direction.
  @State var zoomedStart = ZoomedPictureStart.topLeading

  nonisolated private static let coordinateSpace = "slideshow"

  // Timer for auto-advance
  @State var slideTimer: Timer?

  /// `onKeyPress` only fires for a focused view, so the slideshow takes focus on appear.
  @FocusState var isFocused: Bool

  /// Trashing asks first; auto-play pauses meanwhile so the picture can't change under the prompt.
  @State var isConfirmingTrash = false
  @State var resumesPlayAfterTrashPrompt = false

  var body: some View {
    ZStack {
      // Glow background
      glowBackground
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1.2), value: glowCycleIdx)

      // Image — spans the whole slideshow so a zoomed picture can use all of it;
      // unzoomed, the picture is fitted into the page area between the bars.
      SlideshowImageView(
        image: currentNSImage,
        animationType: currentAnimationType,
        duration: currentTransitionDuration,
        isForward: navigatingForward,
        pageFrame: pageFrame,
        zoom: zoom,
        zoomedStart: zoomedStart,
        isAnimating: $isAnimating
      )

      // Main content — counter, page area, controls
      VStack(spacing: 0) {
        // Top bar — close and counter
        topBar

        Spacer(minLength: 8)

        // Page — sketchbook frame with tape strips
        pageArea

        Spacer(minLength: 32)

        // Bottom control bar
        controlBar
          .padding(.bottom, 20)
      }
      .padding(.vertical, 12)
    }
    .coordinateSpace(.named(Self.coordinateSpace))
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
      LinearGradient(
        stops: DesignSystem.slideshowGradientStops,
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .onAppear {
      setupInitialState()
      isFocused = true
    }
    .onDisappear {
      stopAutoPlay()
    }
    // Pinching or double-clicking the picture switches to zoom mode by itself.
    .onChange(of: zoom.isZoomed) { _, isZoomed in
      if isZoomed { enterZoomMode() }
    }
    .alert("Move “\(currentFilename)” to the Trash?", isPresented: $isConfirmingTrash) {
      Button("Move to Trash", role: .destructive) {
        deleteCurrentImage()
        finishTrashPrompt()
      }
      .keyboardShortcut(.defaultAction)
      Button("Cancel", role: .cancel) {
        finishTrashPrompt()
      }
    } message: {
      Text("You can restore it from the Trash until you empty it.")
    }
    .focusable()
    .focusEffectDisabled()
    .focused($isFocused)
    // Keyboard navigation
    .onKeyPress(keys: [.leftArrow, .upArrow]) { press in
      handleArrow(press, navigate: navigatePrev)
    }
    .onKeyPress(keys: [.rightArrow, .downArrow]) { press in
      handleArrow(press, navigate: navigateNext)
    }
    .onKeyPress(.pageUp) {
      navigatePrev()
      return .handled
    }
    .onKeyPress(.pageDown) {
      navigateNext()
      return .handled
    }
    .onKeyPress(.home) {
      navigateToFirst()
      return .handled
    }
    .onKeyPress(.end) {
      navigateToLast()
      return .handled
    }
    .onKeyPress(.space) {
      if !isZoomMode { togglePlayPause() }
      return .handled
    }
    .onKeyPress(characters: CharacterSet(charactersIn: "zZ"), phases: .down) { _ in
      toggleZoomMode()
      return .handled
    }
    .onKeyPress(characters: CharacterSet(charactersIn: "+=")) { _ in
      enterZoomMode()
      zoom.zoomIn()
      return .handled
    }
    .onKeyPress(characters: CharacterSet(charactersIn: "-_")) { _ in
      if isZoomMode { zoom.zoomOut() }
      return .handled
    }
    .onKeyPress(characters: CharacterSet(charactersIn: "0")) { _ in
      if isZoomMode { zoom.fit() }
      return .handled
    }
    .onKeyPress(.escape) {
      if isZoomMode { exitZoomMode() } else { onDismiss() }
      return .handled
    }
  }

  // MARK: - Subviews

  private var glowBackground: some View {
    let idx = glowCycleIdx % DesignSystem.glowMoods.count
    return Rectangle()
      .fill(
        RadialGradient(
          colors: [DesignSystem.glowMoods[idx], Color.clear],
          center: .center,
          startRadius: 100,
          endRadius: 600
        )
      )
  }

  /// Sketchbook-style page — washi-tape strips positioned at the actual image edges.
  ///
  /// The picture itself is drawn by `SlideshowImageView` behind the bars; this
  /// reports where it should sit and hides the tape while zoomed.
  private var pageArea: some View {
    GeometryReader { geo in
      let insets = imageInsets(in: geo.size)

      Color.clear
        // Tape strip — top center, on actual image edge
        .overlay(alignment: .top) {
          TapeStrip(color: slideshowTopTape)
            .scaleEffect(2.4)
            .rotationEffect(.degrees(-7))
            .offset(y: insets.top - 10)
        }
        // Tape strip — bottom right, on actual image corner
        .overlay(alignment: .bottomTrailing) {
          TapeStrip(color: slideshowBottomTape)
            .scaleEffect(2.4)
            .rotationEffect(.degrees(11))
            .offset(
              x: -(insets.trailing + 40),
              y: -(insets.bottom - 10)
            )
        }
        .opacity(zoom.isZoomed ? 0 : 1)
        .animation(.easeInOut(duration: 0.2), value: zoom.isZoomed)
    }
    .onGeometryChange(for: CGRect.self) { proxy in
      proxy.frame(in: .named(Self.coordinateSpace))
    } action: { frame in
      pageFrame = frame
    }
    .padding(.horizontal, 60)
  }

  /// Calculate how much the aspect-fitted image is inset from the container edges.
  private func imageInsets(in containerSize: CGSize) -> EdgeInsets {
    guard currentImageSize.width > 0, currentImageSize.height > 0,
      containerSize.width > 0, containerSize.height > 0
    else {
      return EdgeInsets()
    }
    let containerAspect = containerSize.width / containerSize.height
    let imageAspect = currentImageSize.width / currentImageSize.height

    if imageAspect > containerAspect {
      // Image is wider — letterboxed top/bottom
      let rendered = containerSize.width / imageAspect
      let inset = (containerSize.height - rendered) / 2
      return EdgeInsets(top: inset, leading: 0, bottom: inset, trailing: 0)
    } else {
      // Image is taller — pillarboxed left/right
      let rendered = containerSize.height * imageAspect
      let inset = (containerSize.width - rendered) / 2
      return EdgeInsets(top: 0, leading: inset, bottom: 0, trailing: inset)
    }
  }

  /// Tape color cycling per slide for variety.
  private var slideshowTopTape: Color {
    DesignSystem.tapeColors[currentIndex % DesignSystem.tapeColors.count]
  }

  private var slideshowBottomTape: Color {
    DesignSystem.tapeColors[(currentIndex + 3) % DesignSystem.tapeColors.count]
  }

  /// Top bar — counter pill (right-aligned).
  private var topBar: some View {
    HStack {
      Spacer()

      Text("\(currentIndex + 1) / \(imageStore.images.count)")
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundColor(DesignSystem.slideshowButton)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
          Capsule().fill(DesignSystem.controlSurface)
            .shadow(color: DesignSystem.border.opacity(0.3), radius: 3, y: 1)
        )
    }
    .padding(.horizontal, 20)
  }

  /// Bottom control bar — close, left, play, stop, right, speed, delete.
  private var controlBar: some View {
    SlideshowControlBar(
      filename: currentFilename,
      isPlaying: isPlaying,
      isSpeedy: isSpeedy,
      transition: $transitionChoice,
      isZoomMode: isZoomMode,
      zoomScale: zoom.scale,
      onClose: onDismiss,
      onGoToFirst: navigateToFirst,
      onPrev: navigatePrev,
      onNext: navigateNext,
      onPlay: { if !isPlaying { startAutoPlay() } },
      onStop: { if isPlaying { stopAutoPlay() } },
      onToggleSpeed: toggleSpeedyMode,
      onToggleZoomMode: toggleZoomMode,
      onZoomIn: { zoom.zoomIn() },
      onZoomOut: { zoom.zoomOut() },
      onFit: { zoom.fit() },
      onDelete: requestTrash
    )
  }

  // MARK: - State

  /// Current image filename for display.
  private var currentFilename: String {
    guard currentIndex >= 0, currentIndex < imageStore.images.count else { return "" }
    return imageStore.images[currentIndex].filename
  }

  private func setupInitialState() {
    if let idx = imageStore.images.firstIndex(where: { $0.id == startingImage.id }) {
      currentIndex = idx
    }
    currentNSImage = imageStore.fullImage(for: imageStore.images[currentIndex])
    currentImageSize = currentNSImage?.size ?? .zero

    if autoPlay {
      startAutoPlay()
    }
  }

}
