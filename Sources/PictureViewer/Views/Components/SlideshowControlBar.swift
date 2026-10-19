import SwiftUI

/// Capsule-shaped control bar — close, left, play, stop, right, speed, transition, delete.
///
/// All icons are line-only to match the sketchbook aesthetic.
struct SlideshowControlBar: View {
  let filename: String
  let isPlaying: Bool
  let isSpeedy: Bool
  @Binding var transition: SlideTransitionChoice
  let onClose: () -> Void
  let onGoToFirst: () -> Void
  let onPrev: () -> Void
  let onNext: () -> Void
  let onPlay: () -> Void
  let onStop: () -> Void
  let onToggleSpeed: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack(spacing: 24) {
      // Close (back to gallery)
      controlButton(action: onClose) {
        CloseIcon()
          .lineIconStyle(color: DesignSystem.textColor, size: 18)
      }

      // Divider
      Rectangle()
        .fill(DesignSystem.border)
        .frame(width: 1, height: 24)

      // Filename
      Text(filename)
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundColor(DesignSystem.slideshowFilename)
        .lineLimit(1)
        .truncationMode(.middle)
        .frame(maxWidth: 200)

      // Divider
      Rectangle()
        .fill(DesignSystem.border)
        .frame(width: 1, height: 24)

      // Go to first
      controlButton(action: onGoToFirst) {
        SkipToFirstIcon()
          .lineIconStyle(color: DesignSystem.textColor, size: 18)
      }

      // Previous
      controlButton(action: onPrev) {
        ChevronLeftIcon()
          .lineIconStyle(color: DesignSystem.textColor, size: 18)
      }

      // Play
      controlButton(
        action: onPlay,
        isActive: isPlaying,
        activeColor: DesignSystem.accentSurface,
        icon: {
          let color =
            isPlaying
            ? DesignSystem.accent
            : DesignSystem.textColor
          PlayIcon()
            .lineIconStyle(color: color, size: 18)
        }
      )

      // Stop
      controlButton(
        action: onStop,
        isActive: !isPlaying,
        activeColor: DesignSystem.secondary.opacity(0.4),
        icon: {
          let color =
            isPlaying
            ? DesignSystem.textColor
            : DesignSystem.secondary
          StopIcon()
            .lineIconStyle(color: color, size: 18)
        }
      )

      // Next
      controlButton(action: onNext) {
        ChevronRightIcon()
          .lineIconStyle(color: DesignSystem.textColor, size: 18)
      }

      // Divider
      Rectangle()
        .fill(DesignSystem.border)
        .frame(width: 1, height: 24)

      // Speed toggle
      controlButton(
        action: onToggleSpeed,
        isActive: isSpeedy,
        activeColor: DesignSystem.primary.opacity(0.4)
      ) {
        SpeedIcon()
          .lineIconStyle(
            color: isSpeedy ? DesignSystem.slideshowButton : DesignSystem.textColor.opacity(0.4),
            size: 18
          )
      }

      // Transition effect — highlighted when a single effect is chosen
      Menu {
        TransitionPicker(selection: $transition)
          .pickerStyle(.inline)
      } label: {
        PageTurnIcon()
          .lineIconStyle(
            color: transition == .cycle ? DesignSystem.textColor : DesignSystem.slideshowButton,
            size: 18
          )
          .frame(width: 36, height: 36)
          .background(
            Circle()
              .fill(transition == .cycle ? .clear : DesignSystem.primary.opacity(0.4))
              .frame(width: 32, height: 32)
          )
          .contentShape(Circle())
      }
      .menuStyle(.button)
      .buttonStyle(.plain)
      .menuIndicator(.hidden)
      .fixedSize()
      .help("Transition: \(transition.title)")

      // Delete
      controlButton(action: onDelete) {
        TrashIcon()
          .lineIconStyle(color: DesignSystem.secondary, size: 18)
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 10)
    .background(
      Capsule().fill(DesignSystem.controlSurface)
        .shadow(color: DesignSystem.border.opacity(0.4), radius: 6, y: 3)
    )
  }

  /// Consistent circular hit-target for control buttons.
  ///
  /// When `isActive` is true, a filled circle in `activeColor` appears behind the icon
  /// to indicate the button's current state at a glance.
  private func controlButton<Icon: View>(
    action: @escaping () -> Void,
    isActive: Bool = false,
    activeColor: Color = .clear,
    @ViewBuilder icon: () -> Icon
  ) -> some View {
    Button(action: action) {
      icon()
        .frame(width: 36, height: 36)
        .background(
          Circle()
            .fill(isActive ? activeColor : .clear)
            .frame(width: 32, height: 32)
        )
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .animation(.easeInOut(duration: 0.25), value: isActive)
  }
}
