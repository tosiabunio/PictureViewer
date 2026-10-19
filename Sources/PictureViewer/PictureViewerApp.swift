import AppKit
import CoreText
import SwiftUI

@main
struct PictureViewerApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @StateObject private var imageStore = ImageStore()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(imageStore)
    }
    .windowStyle(.hiddenTitleBar)
    .defaultSize(width: 1440, height: 900)
    .commands {
      GalleryCommands(imageStore: imageStore)
    }
  }
}

// MARK: - Commands

/// Menu commands for choosing the gallery's folder, sort order, and slideshow transition.
///
/// Folder and sort commands are disabled while a slideshow is open, since it
/// indexes into the image list.
struct GalleryCommands: Commands {
  @ObservedObject var imageStore: ImageStore
  @FocusedValue(\.isSlideshowShowing) private var isSlideshowShowing
  @AppStorage(SlideTransitionChoice.defaultsKey)
  private var transitionChoice = SlideTransitionChoice.cycle

  var body: some Commands {
    CommandGroup(after: .newItem) {
      Button("Open Folder…") { imageStore.chooseFolder() }
        .keyboardShortcut("o")
        .disabled(isSlideshowShowing == true)

      Button("Show Pictures Folder") { imageStore.usePicturesFolder() }
        .disabled(isSlideshowShowing == true || imageStore.isShowingPicturesFolder)
    }

    CommandGroup(before: .toolbar) {
      Picker("Sort By", selection: $imageStore.sortOrder) {
        ForEach(ImageSortOrder.allCases) { order in
          Text(order.title).tag(order)
        }
      }
      .disabled(isSlideshowShowing == true)

      TransitionPicker(title: "Slideshow Transition", selection: $transitionChoice)
    }
  }
}

// MARK: - App Delegate

/// Registers bundled fonts and enters full screen on launch.
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var didEnterFullScreen = false
  private var isFullScreenPending = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    registerBundledFonts()
    registerAppIcon()

    // Count full screen as done only once a window actually starts entering it,
    // so an attempt that never takes effect is retried when the window is next key.
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowWillEnterFullScreen),
      name: NSWindow.willEnterFullScreenNotification,
      object: nil
    )

    // SwiftUI usually creates and keys the window before this runs, so its
    // didBecomeKey notification has already fired by the time we observe.
    if let window = NSApp.keyWindow {
      enterFullScreenOnce(window)
    }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidBecomeKey),
      name: NSWindow.didBecomeKeyNotification,
      object: nil
    )
  }

  @objc @MainActor private func windowDidBecomeKey(_ notification: Notification) {
    guard let window = notification.object as? NSWindow else { return }
    enterFullScreenOnce(window)
  }

  @objc @MainActor private func windowWillEnterFullScreen(_ notification: Notification) {
    didEnterFullScreen = true
  }

  /// Enters full screen the first time a gallery window becomes key.
  ///
  /// Panels such as the folder picker are skipped: full-screening one moves it
  /// into its own Space, which is left empty (black) once the panel closes.
  @MainActor private func enterFullScreenOnce(_ window: NSWindow) {
    guard !didEnterFullScreen, !isFullScreenPending, !(window is NSPanel) else { return }
    isFullScreenPending = true
    // Ensure the window supports full screen, then enter after a short layout delay.
    window.collectionBehavior.insert(.fullScreenPrimary)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      self.isFullScreenPending = false
      guard !self.didEnterFullScreen else { return }
      // toggleFullScreen on a window that is already full screen would exit it.
      if window.styleMask.contains(.fullScreen) {
        self.didEnterFullScreen = true
      } else {
        window.toggleFullScreen(nil)
      }
    }
  }

  /// Registers all .ttf fonts found in the bundled Fonts resource directory.
  private func registerBundledFonts() {
    guard let fontsURL = Bundle.module.url(forResource: "Fonts", withExtension: nil) else {
      return
    }
    guard
      let enumerator = FileManager.default.enumerator(
        at: fontsURL,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
    else { return }

    for case let fileURL as URL in enumerator where fileURL.pathExtension == "ttf" {
      CTFontManagerRegisterFontsForURL(fileURL as CFURL, .process, nil)
    }
  }

  /// Sets the Dock icon from the bundled .icns file.
  @MainActor private func registerAppIcon() {
    guard
      let iconURL = Bundle.module.url(
        forResource: "icon", withExtension: "icns", subdirectory: "Icons")
    else { return }
    NSApplication.shared.applicationIconImage = NSImage(contentsOf: iconURL)
  }
}
