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
      FolderCommands(imageStore: imageStore)
    }
  }
}

// MARK: - Commands

/// File-menu commands for choosing which folder the gallery browses.
struct FolderCommands: Commands {
  @ObservedObject var imageStore: ImageStore
  @FocusedValue(\.isSlideshowShowing) private var isSlideshowShowing

  var body: some Commands {
    CommandGroup(after: .newItem) {
      Button("Open Folder…") { imageStore.chooseFolder() }
        .keyboardShortcut("o")
        .disabled(isSlideshowShowing == true)

      Button("Show Pictures Folder") { imageStore.usePicturesFolder() }
        .disabled(isSlideshowShowing == true || imageStore.isShowingPicturesFolder)
    }
  }
}

// MARK: - App Delegate

/// Registers bundled fonts and enters full screen on launch.
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var didEnterFullScreen = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    registerBundledFonts()
    registerAppIcon()

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

  /// Enters full screen the first time a gallery window becomes key.
  ///
  /// Panels such as the folder picker are skipped: full-screening one moves it
  /// into its own Space, which is left empty (black) once the panel closes.
  @MainActor private func enterFullScreenOnce(_ window: NSWindow) {
    guard !didEnterFullScreen, !(window is NSPanel) else { return }
    didEnterFullScreen = true
    // Ensure the window supports full screen, then enter after a short layout delay.
    window.collectionBehavior.insert(.fullScreenPrimary)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      window.toggleFullScreen(nil)
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
