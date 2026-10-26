import SwiftUI

/// Grid gallery displaying image thumbnails in a scrollable grid.
///
/// 60:30:10 — gallery background is **60 %** (warm cream, inherited),
/// placeholder fills + card borders are **30 %**, hover glow is **10 %**.
/// Each card has a sketchbook-style shadow frame and washi-tape corner strips.
struct GalleryView: View {
  let images: [ImageItem]
  let onSelect: (ImageItem) -> Void

  @EnvironmentObject private var imageStore: ImageStore
  @State private var hoveredItem: ImageItem?

  private let columns = [
    GridItem(
      .adaptive(minimum: DesignSystem.thumbnailSize + 24, maximum: DesignSystem.thumbnailSize + 64),
      spacing: DesignSystem.gridSpacing + 8)
  ]

  var body: some View {
    ScrollView {
      LazyVGrid(columns: columns, spacing: DesignSystem.gridSpacing + 12) {
        ForEach(Array(images.enumerated()), id: \.element.id) { index, item in
          ThumbnailCard(
            item: item,
            cardIndex: index,
            isHovered: hoveredItem == item,
            thumbnail: imageStore.thumbnail(for: item)
          )
          .onTapGesture { onSelect(item) }
          .onHover { isHovered in
            withAnimation(.easeInOut(duration: 0.25)) {
              hoveredItem = isHovered ? item : nil
            }
          }
        }
      }
      .padding(28)
    }
  }
}

// MARK: - Thumbnail Card

struct ThumbnailCard: View {
  let item: ImageItem
  let cardIndex: Int
  let isHovered: Bool
  let thumbnail: NSImage?

  /// Slight random-looking rotation per card for a hand-placed sketchbook feel.
  private var cardRotation: Double {
    let seed = Double(cardIndex)
    // Deterministic pseudo-random rotation: -1.5° to +1.5°
    return sin(seed * 2.654) * 1.5
  }

  /// Pick tape colors deterministically per card so each feels unique.
  private var topTapeColor: Color {
    DesignSystem.tapeColors[cardIndex % DesignSystem.tapeColors.count]
  }

  private var bottomTapeColor: Color {
    DesignSystem.tapeColors[(cardIndex + 3) % DesignSystem.tapeColors.count]
  }

  var body: some View {
    VStack(spacing: 8) {
      // Photo frame with tape
      ZStack {
        // Shadow frame — white card with soft drop shadow (60 % surface)
        RoundedRectangle(cornerRadius: 3)
          .fill(Color.white)
          .frame(
            width: DesignSystem.thumbnailSize + 16,
            height: DesignSystem.thumbnailSize + 16
          )
          .shadow(
            color: isHovered
              ? DesignSystem.accent.opacity(0.35)
              : DesignSystem.textColor.opacity(0.12),
            radius: isHovered ? 12 : 5,
            x: isHovered ? 0 : 1,
            y: isHovered ? 8 : 3
          )

        // 30 % — placeholder fill (soft blue tint)
        RoundedRectangle(cornerRadius: 2)
          .fill(DesignSystem.primary.opacity(0.12))
          .frame(
            width: DesignSystem.thumbnailSize,
            height: DesignSystem.thumbnailSize
          )

        // Actual thumbnail image
        if let thumb = thumbnail {
          Image(nsImage: thumb)
            .resizable()
            .scaledToFill()
            .frame(
              width: DesignSystem.thumbnailSize,
              height: DesignSystem.thumbnailSize
            )
            .clipped()
        } else {
          ImageIcon()
            .lineIconStyle(color: DesignSystem.primary.opacity(0.5), size: 30)
        }

        // Tape strip — top center, slightly rotated
        TapeStrip(color: topTapeColor)
          .rotationEffect(.degrees(-8 + cardRotation))
          .offset(y: -(DesignSystem.thumbnailSize / 2 + 6))

        // Tape strip — bottom right, slightly rotated the other way
        TapeStrip(color: bottomTapeColor)
          .rotationEffect(.degrees(12 - cardRotation))
          .offset(
            x: DesignSystem.thumbnailSize * 0.2,
            y: DesignSystem.thumbnailSize / 2 + 4
          )
      }
      .frame(
        width: DesignSystem.thumbnailSize + 24,
        height: DesignSystem.thumbnailSize + 24
      )
      // 10 % — accent border on hover
      .overlay(
        RoundedRectangle(cornerRadius: 3)
          .stroke(
            isHovered ? DesignSystem.accent.opacity(0.6) : Color.clear,
            lineWidth: 2
          )
          .padding(3)
      )
      .rotationEffect(.degrees(cardRotation))
      .scaleEffect(isHovered ? 1.05 : 1.0)
      .offset(y: isHovered ? -4 : 0)

      // Filename
      Text(item.filename)
        .font(DesignSystem.captionSemiboldFont)
        .foregroundColor(DesignSystem.textColor)
        .lineLimit(1)
        .truncationMode(.middle)
        .frame(width: DesignSystem.thumbnailSize)
    }
    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isHovered)
  }
}

// MARK: - Tape Strip

/// A small semi-transparent rectangle that mimics washi tape stuck over a photo edge.
struct TapeStrip: View {
  let color: Color

  var body: some View {
    RoundedRectangle(cornerRadius: 1.5)
      .fill(color)
      .frame(width: 40, height: 12)
      .overlay(
        // Subtle texture lines inside the tape
        VStack(spacing: 2.5) {
          ForEach(0..<3, id: \.self) { _ in
            Rectangle()
              .fill(Color.white.opacity(0.25))
              .frame(height: 0.5)
          }
        }
        .padding(.horizontal, 3)
      )
  }
}
