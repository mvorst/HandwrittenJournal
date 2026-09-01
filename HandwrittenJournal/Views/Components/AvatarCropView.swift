import SwiftUI
import UIKit

/// Drag-and-pinch framing for a profile photo. The window is square because the
/// stored avatar is square (§4.2); the circle is the mask AvatarView will apply,
/// drawn here so the child sees the real result while framing it.
///
/// At scale 1 the photo is aspect-filled to the window, so it can never be pulled
/// small enough to leave a gap — panning is clamped to the same rule.
struct AvatarCropView: View {
    let onDone: (Data) -> Void
    let onCancel: () -> Void

    /// Orientation-baked and size-capped once, at init. Every gesture reads from
    /// this, so it must not be recomputed per frame.
    private let source: UIImage

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private static let maxScale: CGFloat = 6
    private static let outputSide: CGFloat = 512

    init(image: UIImage, onDone: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
        self.source = Self.flattened(image)
        self.onDone = onDone
        self.onCancel = onCancel
    }

    var body: some View {
        GeometryReader { geo in
            let side = window(in: geo.size)
            let display = displaySize(window: side)

            ZStack {
                // The photo rides in an overlay, not as a sibling: zoomed past the
                // screen it would otherwise grow the stack and carry the circle and
                // the buttons off with it.
                Color.black
                    .overlay {
                        Image(uiImage: source)
                            .resizable()
                            .frame(width: display.width, height: display.height)
                            .offset(offset)
                    }
                    .clipped()

                mask(side: side)

                VStack {
                    Spacer()
                    Text("Drag to move · pinch to zoom")
                        .font(.hjCaption)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.bottom, Tokens.Space.s5)
                    HStack(spacing: Tokens.Space.s6) {
                        TextButton(title: "Cancel", tint: .white) { onCancel() }
                        PrimaryButton(title: "Use Photo", systemImage: "checkmark", minWidth: 260) {
                            if let data = render(window: side) { onDone(data) } else { onCancel() }
                        }
                    }
                    .padding(.bottom, Tokens.Space.s7 + Tokens.Layout.homeIndicator)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                SimultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            offset = clamped(CGSize(width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height),
                                             window: side)
                        }
                        .onEnded { _ in lastOffset = offset },
                    MagnifyGesture()
                        .onChanged { value in
                            scale = min(max(lastScale * value.magnification, 1), Self.maxScale)
                            offset = clamped(offset, window: side)
                        }
                        .onEnded { _ in
                            lastScale = scale
                            lastOffset = offset
                        }
                )
            )
        }
        // The whole cropper owns the screen: image, circle and window then share one
        // coordinate space, so what the circle shows is exactly what gets cut.
        .ignoresSafeArea()
        .background(Color.black)
        .statusBarHidden()
    }

    /// Everything outside the circle dimmed, the crop edge drawn on top.
    private func mask(side: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.6))
                .mask {
                    Rectangle()
                        .overlay(Circle().frame(width: side, height: side).blendMode(.destinationOut))
                        .compositingGroup()
                }
            Circle()
                .strokeBorder(Color.white.opacity(0.9), lineWidth: 3)
                .frame(width: side, height: side)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Geometry

    /// The crop window: as large as the screen allows, leaving room for the buttons.
    private func window(in size: CGSize) -> CGFloat {
        min(size.width - Tokens.Layout.screenMargin * 2, size.height - 260, 480)
    }

    private func fitScale(window side: CGFloat) -> CGFloat {
        max(side / source.size.width, side / source.size.height)
    }

    private func displaySize(window side: CGFloat) -> CGSize {
        let total = fitScale(window: side) * scale
        return CGSize(width: source.size.width * total, height: source.size.height * total)
    }

    /// Keeps the photo covering the window — the child can never frame empty space.
    private func clamped(_ proposed: CGSize, window side: CGFloat) -> CGSize {
        let display = displaySize(window: side)
        let slackX = max((display.width - side) / 2, 0)
        let slackY = max((display.height - side) / 2, 0)
        return CGSize(width: min(max(proposed.width, -slackX), slackX),
                      height: min(max(proposed.height, -slackY), slackY))
    }

    // MARK: - Output

    /// Maps the on-screen window back to pixels and writes a 512 × 512 JPEG q0.8 —
    /// roughly 40 KB, the budget the avatar was sized to (§4.2).
    private func render(window side: CGFloat) -> Data? {
        let total = fitScale(window: side) * scale
        let region = side / total
        let centreX = source.size.width / 2 - offset.width / total
        let centreY = source.size.height / 2 - offset.height / total
        let rect = CGRect(x: centreX - region / 2, y: centreY - region / 2, width: region, height: region)
            .integral
            .intersection(CGRect(origin: .zero, size: source.size))

        guard !rect.isNull, let cropped = source.cgImage?.cropping(to: rect) else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let box = CGRect(x: 0, y: 0, width: Self.outputSide, height: Self.outputSide)
        return UIGraphicsImageRenderer(size: box.size, format: format).image { _ in
            UIImage(cgImage: cropped).draw(in: box)
        }.jpegData(compressionQuality: 0.8)
    }

    /// Bakes EXIF orientation into the pixels — `cropping(to:)` works in raw pixel
    /// space and would otherwise cut the wrong corner out of a portrait photo — and
    /// caps the long edge at 2048 so a 12 MP capture doesn't sit in memory whole.
    static func flattened(_ image: UIImage, longEdge: CGFloat = 2048) -> UIImage {
        let ratio = min(longEdge / max(image.size.width, image.size.height), 1)
        let size = CGSize(width: (image.size.width * ratio).rounded(),
                          height: (image.size.height * ratio).rounded())
        if ratio == 1, image.imageOrientation == .up, image.scale == 1 { return image }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
