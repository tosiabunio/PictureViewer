import SwiftUI

/// Picker for the slideshow transition — cycle through every effect, or always use one.
///
/// Shared by the View menu and the slideshow control bar.
struct TransitionPicker: View {
  var title = "Transition"
  @Binding var selection: SlideTransitionChoice

  var body: some View {
    Picker(title, selection: $selection) {
      Text(SlideTransitionChoice.cycle.title)
        .tag(SlideTransitionChoice.cycle)

      Divider()

      ForEach(SlideAnimationType.allCases) { type in
        Text(type.title)
          .tag(SlideTransitionChoice.fixed(type))
      }
    }
  }
}
