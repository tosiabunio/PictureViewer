import SwiftUI

// MARK: - Navigation, Auto-play & Delete

extension SlideshowView {
  /// Arrow-key pan distance, as a fraction of the visible area.
  private static let keyPanStep: CGFloat = 0.15

  // MARK: Navigation

  func navigateToFirst() {
    guard !isAnimating, currentIndex != 0 else { return }
    navigatingForward = false
    zoomedStart = .topLeading
    advanceSlide(to: 0)
    if isPlaying {
      restartAutoPlayTimer()
    }
  }

  func navigateToLast() {
    let lastIndex = imageStore.images.count - 1
    guard !isAnimating, currentIndex < lastIndex else { return }
    navigatingForward = true
    zoomedStart = .topLeading
    advanceSlide(to: lastIndex)
    if isPlaying {
      restartAutoPlayTimer()
    }
  }

  func navigateNext() {
    guard !isAnimating else { return }
    navigatingForward = true
    zoomedStart = .topLeading
    let nextIndex = (currentIndex + 1) % imageStore.images.count
    advanceSlide(to: nextIndex)
    if isPlaying {
      restartAutoPlayTimer()
    }
  }

  func navigatePrev() {
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
    let (normal, speedy): (TimeInterval, TimeInterval) =
      switch type {
      case .flip: (DesignSystem.flipDuration, DesignSystem.speedyFlipDuration)
      case .bend: (DesignSystem.bendDuration, DesignSystem.speedyBendDuration)
      case .curl: (DesignSystem.curlDuration, DesignSystem.speedyCurlDuration)
      case .book: (DesignSystem.bookDuration, DesignSystem.speedyBookDuration)
      case .blocks: (DesignSystem.blocksDuration, DesignSystem.speedyBlocksDuration)
      case .zoomFront: (DesignSystem.zoomFrontDuration, DesignSystem.speedyZoomFrontDuration)
      case .pixelate: (DesignSystem.pixelateDuration, DesignSystem.speedyPixelateDuration)
      case .spiral: (DesignSystem.spiralDuration, DesignSystem.speedySpiralDuration)
      }
    return isSpeedy ? speedy : normal
  }

  // MARK: Zoom mode

  /// Stops auto-play, which would otherwise switch pictures mid-zoom.
  func enterZoomMode() {
    guard !isZoomMode else { return }
    isZoomMode = true
    stopAutoPlay()
  }

  func exitZoomMode() {
    isZoomMode = false
    zoom.fit()
  }

  func toggleZoomMode() {
    if isZoomMode { exitZoomMode() } else { enterZoomMode() }
  }

  /// Arrows switch pictures, except in zoom mode, where they pan. There,
  /// Shift+arrow switches pictures, and so does a fresh press once the picture
  /// can't pan any further that way; a held key stops at the edge.
  func handleArrow(_ press: KeyPress, navigate: () -> Void) -> KeyPress.Result {
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

  func togglePlayPause() {
    if isPlaying {
      stopAutoPlay()
    } else {
      startAutoPlay()
    }
  }

  func startAutoPlay() {
    isPlaying = true
    restartAutoPlayTimer()
  }

  func stopAutoPlay() {
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

  func toggleSpeedyMode() {
    isSpeedy.toggle()
    if isPlaying {
      restartAutoPlayTimer()
    }
  }

  // MARK: Delete

  func requestTrash() {
    guard !isAnimating, !imageStore.images.isEmpty else { return }
    resumesPlayAfterTrashPrompt = isPlaying
    stopAutoPlay()
    isConfirmingTrash = true
  }

  /// Resumes auto-play if the prompt paused it, and takes keyboard focus back from the alert.
  func finishTrashPrompt() {
    if resumesPlayAfterTrashPrompt, !imageStore.images.isEmpty {
      startAutoPlay()
    }
    resumesPlayAfterTrashPrompt = false
    isFocused = true
  }

  /// Move the current image to Trash via FileManager and advance to the next slide.
  func deleteCurrentImage() {
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
