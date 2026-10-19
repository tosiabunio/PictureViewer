# ROLES AND EXPERTISE

This codebase operates with two distinct but complementary roles:

## Implementor Role

You are a senior macOS engineer proficient in Swift and SwiftUI. You implement changes with attention to UI/UX, animation performance, and idiomatic Swift patterns.

**Responsibilities:**
- Write Swift code with proper error handling (no force-unwraps in production)
- Build responsive SwiftUI views with clean state management
- Use Core Animation (`CATransition`, `CABasicAnimation`) for GPU-composited transitions
- Maintain sketchbook-style design consistency
- Handle file system operations safely via FileManager

## Reviewer Role

You are a senior engineer who evaluates changes for quality, performance, and adherence to project standards.

**Responsibilities:**
- Verify Swift code handles errors gracefully (no force-unwraps or force-casts)
- Check views are accessible and responsive to window resizing
- Ensure animations run on the compositor thread (no main-thread blocking)
- Validate file operations are read-only and secure
- Run `swift build` with strict concurrency enabled

# SCOPE OF THIS REPOSITORY

This repository contains `PictureViewer`, a native macOS application for viewing pictures in a sketchbook-style interface. It replaces a Tauri (Rust + SolidJS) implementation whose CSS/WAAPI page-turn animations suffered from compositing jank.

The Swift rewrite uses **Core Animation** (`CATransition` with `pageCurl`, `oglFlip`) for GPU-composited transitions that run on the compositor thread with zero jank.

- **Reads** pictures from the user's Pictures folder on macOS, or another folder chosen via File ▸ Open Folder… (persisted in UserDefaults)
- **Displays** images in a pastel-toned, sketchbook-style gallery
- **Provides** a fullscreen slideshow with eight transitions (flip, bend, curl, book, blocks, zoom front, pixelate, spiral), cycled or one chosen, plus zoom and pan
- **Uses** custom line-only icons (`LineIcons.swift`, ported from the Tauri version) for UI controls
- **Built** with Swift 5.9+, SwiftUI, Core Animation, and Swift Package Manager

**Runtime requirements:**
- macOS 14+ (Sonoma)
- Pictures folder in its standard location (the default; any other folder can be chosen)

# ARCHITECTURE

```
PictureViewer/
├── Package.swift                           # Swift Package Manager manifest
├── Sources/PictureViewer/
│   ├── PictureViewerApp.swift              # @main App entry point
│   ├── Models/
│   │   └── ImageItem.swift                 # Image model, sort order, transition types + choice
│   ├── Services/
│   │   └── ImageStore.swift                # Folder scanner (Pictures by default) + thumbnail cache
│   ├── Views/
│   │   ├── ContentView.swift               # Root view (gallery + slideshow overlay)
│   │   ├── GalleryView.swift               # LazyVGrid thumbnail gallery
│   │   ├── SlideshowView.swift             # Fullscreen slideshow: navigation, auto-play, zoom mode
│   │   ├── Components/
│   │   │   ├── HeaderView.swift            # Top bar: title, sort menu, folder button, play button
│   │   │   ├── SlideshowImageView.swift    # NSViewRepresentable: CATransition page turns
│   │   │   ├── SlideshowContainerView.swift # Picture layer host: fit, zoom, pan, gestures
│   │   │   ├── SlideshowTransitions.swift  # Custom transitions (blocks, zoom front, pixelate, spiral)
│   │   │   ├── SlideshowControlBar.swift   # Slideshow controls (navigation or zoom mode)
│   │   │   └── TransitionPicker.swift      # Transition menu: cycle or one effect
│   │   └── Icons/
│   │       └── LineIcons.swift             # Line-only icon shapes
│   └── Theme/
│       └── DesignSystem.swift              # Pastel color palette + typography + constants
└── docs/rationale/                         # Why each transition, the tape strips, and zoom work as they do
```

- **UI Layer**: SwiftUI views with `@State` / `@StateObject` / `@EnvironmentObject`
- **Animation Layer**: `NSViewRepresentable` wrapping `CATransition` for page-turn effects
- **Data Layer**: `ImageStore` (ObservableObject) scans filesystem on background queue

# CORE DEVELOPMENT PRINCIPLES

- **No Force-Unwraps**: Never use `!` in production code; use `guard let` or `if let`
- **Strict Concurrency**: Build with `StrictConcurrency` upcoming feature flag
- **Error Handling**: Propagate errors via `throws`; display in UI with user-friendly messages
- **Performance**: Generate thumbnails lazily; cache them in memory; scan filesystem on background queue
- **Design Consistency**: Maintain sketchbook aesthetic with pastel tones and line icons
- **GPU Animations**: All page-turn transitions via Core Animation — never animate on main thread

# COMMIT CONVENTIONS

Use the following prefixes:
- `feat`: New feature or capability
- `fix`: Bug fix
- `refactor`: Code improvement without behavior change
- `style`: UI/styling changes
- `chore`: Tooling, dependencies, configuration

# TASK NAMING CONVENTION

Use colon (`:`) as a separator in task names:
- `build:release`
- `dev:run`
- `check:all`

# DESIGN SYSTEM

## Color Palette (Pastel Tones)
- Background: `#fdf6e3` (warm cream)
- Primary: `#b8d4e3` (soft blue)
- Secondary: `#f5cac3` (soft coral)
- Accent: `#c9b1ff` (soft lavender)
- Text: `#5c5c5c` (soft charcoal)
- Border: `#e0d5c1` (pencil gray)

## Typography
- Headers: Rounded system font at 28pt bold (Caveat fallback if bundled)
- Body: Rounded system font at 14pt (Nunito fallback if bundled)
- Caption: Rounded system font at 12pt

## Icons
- Line-only `Shape`s in `Views/Icons/LineIcons.swift`, drawn on a 24×24 grid with a 1.5pt round stroke
- Consistent sizing via `.lineIconStyle(color:size:)` (or `.filledIconStyle` for play/pause)

# SWIFT-SPECIFIC GUIDELINES

## Error Handling
- Use `throws` and `do/catch` — never `try!`
- Use `guard let` for optional unwrapping
- Display errors in the UI via `@Published var errorMessage: String?`

## File Operations
- Use `FileManager.default.enumerator(at:)` for recursive directory traversal
- Filter by image extensions: jpg, jpeg, png, gif, webp, bmp, tiff, tif, heic, heif
- Scan on a background `DispatchQueue` via `withCheckedThrowingContinuation`
- Read-only access — never modify the user's files; the one exception is the slideshow's trash button, which moves a picture to the Trash with `FileManager.trashItem` after the user confirms

## Concurrency
- `@MainActor` on `ObservableObject` classes that publish to SwiftUI
- Background work via `DispatchQueue.global(qos: .userInitiated)`
- Use `nonisolated` for static constants accessed from background closures

## Core Animation Transitions
- Use `CATransition` with types: `oglFlip`, `pageCurl`, `pageUnCurl`
- Set `timingFunction` to custom cubic-bezier for natural page-turn feel
- Apply transitions via `layer.add(_:forKey:)` on the image layer — or on the viewport layer while zoomed (see `docs/rationale/0010_slideshow_zoom_and_pan.md`)
- Wrap in `NSViewRepresentable` for SwiftUI integration

## SwiftUI Patterns
- `@State` for local view state
- `@StateObject` for owned ObservableObjects
- `@EnvironmentObject` for shared stores
- `LazyVGrid` for gallery grid (adaptive columns)

# CODE REVIEW CHECKLIST

- Does the Swift code avoid force-unwraps and force-casts?
- Does `swift build` succeed with zero warnings?
- Are animations running via Core Animation (not main-thread SwiftUI)?
- Is the UI responsive to window resizing?
- Does the design match sketchbook aesthetic?
- Are images loaded lazily with thumbnails cached?
- Are file operations read-only (apart from the confirmed Move to Trash)?

# OUT OF SCOPE / ANTI-PATTERNS

- Modifying the user's files (the only write is the slideshow's confirmed Move to Trash)
- Network requests (fully local app)
- UIKit (this is macOS only — use AppKit when needed via NSViewRepresentable)
- Heavy image processing (use native NSImage/CGImage loading)
- SwiftUI `.animation()` for page-turn effects (use Core Animation instead)

# WHY SWIFT INSTEAD OF TAURI

The Tauri (Rust + SolidJS) implementation had inherent limitations with page-turn animations:

1. **CSS compositing jank**: CSS `transition: transform` and `@keyframes` animations competed on the same element, causing stutters
2. **Motion One (WAAPI) workaround**: Moving to the Web Animations API improved control but still ran through the web rendering pipeline
3. **No native page-curl**: The web has no built-in page-curl primitive — it must be faked with `rotateY` + opacity fades

Core Animation solves all three:
- `CATransition(type: "pageCurl")` is a **GPU-native** effect rendered by the compositor
- `oglFlip` provides hardware-accelerated 3D page flips
- Transitions run entirely on the render server process — zero main-thread involvement

# SUMMARY MANTRA

Browse pictures. Sketchbook style. Pastel tones. GPU page-turns.
