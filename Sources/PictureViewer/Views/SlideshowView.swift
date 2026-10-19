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

  @EnvironmentObject private var imageStore: ImageStore
  @State private var currentIndex: Int = 0
  @State private var isPlaying = false
  @State private var isAnimating = false
  @State private var animCycleIdx = 0
  @State private var currentAnimationType = SlideAnimationType.flip
  @State private var currentTransitionDuration = DesignSystem.flipDuration
  @State private var glowCycleIdx = 0
  @State private var navigatingForward = true
  @State private var currentNSImage: NSImage?
  @State private var currentImageSize: CGSize = .zero
  @State private var isSpeedy = false
  @AppStorage(SlideTransitionChoice.defaultsKey)
  private var transitionChoice = SlideTransitionChoice.cycle
  @StateObject private var zoom = SlideshowZoom()
  /// In zoom mode the controls and arrow keys zoom and pan instead of switching pictures.
  @State private var isZoomMode = false
  /// The area between the bars where the unzoomed picture sits.
  @State private var pageFrame: CGRect = .zero
  /// Where the next picture starts while zoomed: reading order by direction.
  @State private var zoomedStart = ZoomedPictureStart.topLeading

  nonisolated private static let coordinateSpace = "slideshow"
  /// Arrow-key pan distance, as a fraction of the visible area.
  private static let keyPanStep: CGFloat = 0.15

  // Timer for auto-advance
  @State private var slideTimer: Timer?

  /// `onKeyPress` only fires for a focused view, so the slideshow takes focus on appear.
  @FocusState private var isFocused: Bool

  /// Trashing asks first; auto-play pauses meanwhile so the picture can't change under the prompt.
  @State private var isConfirmingTrash = false
  @State private var resumesPlayAfterTrashPrompt = false

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

// MARK: - Navigation, Auto-play & Delete

extension SlideshowView {

  // MARK: Navigation

  private func navigateToFirst() {
    guard !isAnimating, currentIndex != 0 else { return }
    navigatingForward = false
    zoomedStart = .topLeading
    advanceSlide(to: 0)
    if isPlaying {
      restartAutoPlayTimer()
    }
  }

  private func navigateToLast() {
    let lastIndex = imageStore.images.count - 1
    guard !isAnimating, currentIndex < lastIndex else { return }
    navigatingForward = true
    zoomedStart = .topLeading
    advanceSlide(to: lastIndex)
    if isPlaying {
      restartAutoPlayTimer()
    }
  }

  private func navigateNext() {
    guard !isAnimating else { return }
    navigatingForward = true
    zoomedStart = .topLeading
    let nextIndex = (currentIndex + 1) % imageStore.images.count
    advanceSlide(to: nextIndex)
    if isPlaying {
      restartAutoPlayTimer()
    }
  }

  private func navigatePrev() {
    guard !isAnimating else { return }
    navigatingForward = false
    zoomedStart = .bottomTrailing
    let prevIndex = (currentIndex - 1 + imageStore.images.count) % imageStore.images.count
    advanceSlide(to: prevIndex)
    if isPlaying {
      restartAutoPlayTimer()
    }
  }

  private func advanceSlide(to targetIndex: Int) {
    guard !isAnimating else { return }
    isAnimating = true

    // Preload the target image
    let targetImage = imageStore.fullImage(for: imageStore.images[targetIndex])

    // The SlideshowImageView handles the Core Animation transition.
    // We update state which triggers the CA transition in the NSView.
    currentIndex = targetIndex
    currentNSImage = targetImage
    currentImageSize = targetImage?.size ?? .zero
    animCycleIdx += 1
    // Picked per slide, so a change of setting or speed applies from the next slide.
    currentAnimationType = transitionChoice.animationType(forTransition: animCycleIdx)
    currentTransitionDuration = transitionDuration(for: currentAnimationType)
    glowCycleIdx += 1

    // Reset animation flag after transition completes
    DispatchQueue.main.asyncAfter(deadline: .now() + currentTransitionDuration) {
      isAnimating = false
    }
  }

  private func transitionDuration(for type: SlideAnimationType) -> TimeInterval {
    if isSpeedy {
      switch type {
      case .flip: return DesignSystem.speedyFlipDuration
      case .bend: return DesignSystem.speedyBendDuration
      case .curl: return DesignSystem.speedyCurlDuration
      case .book: return DesignSystem.speedyBookDuration
      case .blocks: return DesignSystem.speedyBlocksDuration
      case .zoomFront: return DesignSystem.speedyZoomFrontDuration
      case .pixelate: return DesignSystem.speedyPixelateDuration
      case .spiral: return DesignSystem.speedySpiralDuration
      }
    } else {
      switch type {
      case .flip: return DesignSystem.flipDuration
      case .bend: return DesignSystem.bendDuration
      case .curl: return DesignSystem.curlDuration
      case .book: return DesignSystem.bookDuration
      case .blocks: return DesignSystem.blocksDuration
      case .zoomFront: return DesignSystem.zoomFrontDuration
      case .pixelate: return DesignSystem.pixelateDuration
      case .spiral: return DesignSystem.spiralDuration
      }
    }
  }

  // MARK: Zoom mode

  /// Stops auto-play, which would otherwise switch pictures mid-zoom.
  private func enterZoomMode() {
    guard !isZoomMode else { return }
    isZoomMode = true
    stopAutoPlay()
  }

  private func exitZoomMode() {
    isZoomMode = false
    zoom.fit()
  }

  private func toggleZoomMode() {
    if isZoomMode { exitZoomMode() } else { enterZoomMode() }
  }

  /// Arrows switch pictures, except in zoom mode, where they pan. There,
  /// Shift+arrow switches pictures, and so does a fresh press once the picture
  /// can't pan any further that way; a held key stops at the edge.
  private func handleArrow(_ press: KeyPress, navigate: () -> Void) -> KeyPress.Result {
    if !isZoomMode || press.modifiers.contains(.shift) {
      navigate()
    } else if !pan(toward: press.key), press.phase == .down {
      navigate()
    }
    return .handled
  }

  /// Returns false when the picture can't move that way.
  private func pan(toward key: KeyEquivalent) -> Bool {
    switch key {
    case .leftArrow: return zoom.pan(x: -Self.keyPanStep, y: 0)
    case .rightArrow: return zoom.pan(x: Self.keyPanStep, y: 0)
    case .upArrow: return zoom.pan(x: 0, y: -Self.keyPanStep)
    case .downArrow: return zoom.pan(x: 0, y: Self.keyPanStep)
    default: return false
    }
  }

  // MARK: Auto-play

  private func togglePlayPause() {
    if isPlaying {
      stopAutoPlay()
    } else {
      startAutoPlay()
    }
  }

  private func startAutoPlay() {
    isPlaying = true
    restartAutoPlayTimer()
  }

  private func stopAutoPlay() {
    isPlaying = false
    slideTimer?.invalidate()
    slideTimer = nil
  }

  private func restartAutoPlayTimer() {
    slideTimer?.invalidate()
    let interval =
      isSpeedy
      ? DesignSystem.speedySlideshowInterval
      : DesignSystem.slideshowInterval
    slideTimer = Timer.scheduledTimer(
      withTimeInterval: interval,
      repeats: true
    ) { _ in
      Task { @MainActor in
        navigateNext()
      }
    }
  }

  private func toggleSpeedyMode() {
    isSpeedy.toggle()
    if isPlaying {
      restartAutoPlayTimer()
    }
  }

  // MARK: Delete

  private func requestTrash() {
    guard !isAnimating, !imageStore.images.isEmpty else { return }
    resumesPlayAfterTrashPrompt = isPlaying
    stopAutoPlay()
    isConfirmingTrash = true
  }

  /// Resumes auto-play if the prompt paused it, and takes keyboard focus back from the alert.
  private func finishTrashPrompt() {
    if resumesPlayAfterTrashPrompt, !imageStore.images.isEmpty {
      startAutoPlay()
    }
    resumesPlayAfterTrashPrompt = false
    isFocused = true
  }

  /// Move the current image to Trash via FileManager and advance to the next slide.
  private func deleteCurrentImage() {
    guard !isAnimating, !imageStore.images.isEmpty else { return }
    let item = imageStore.images[currentIndex]

    // Attempt to trash — FileManager.trashItem moves to Trash safely.
    do {
      var resultingURL: NSURL?
      try FileManager.default.trashItem(at: item.url, resultingItemURL: &resultingURL)
    } catch {
      // Silently fail — the app is read-oriented; show nothing disruptive.
      return
    }

    // Remove from store so gallery also updates
    imageStore.removeImage(item)

    // If no images left, dismiss slideshow
    let remaining = imageStore.images
    if remaining.isEmpty {
      onDismiss()
      return
    }

    // Clamp index and load the next image
    if currentIndex >= remaining.count {
      currentIndex = 0
    }
    currentNSImage = imageStore.fullImage(for: remaining[currentIndex])
    currentImageSize = currentNSImage?.size ?? .zero
  }
}
