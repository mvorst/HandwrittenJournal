import SwiftUI

// MARK: - Buttons (§10.1)

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var minWidth: CGFloat = Tokens.Target.childPrimaryW
    var height: CGFloat = Tokens.Target.childPrimaryH
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.s3) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 28, weight: .medium)) }
                Text(title).font(.hjButton)
            }
            .foregroundStyle(Tokens.Colour.textOnAction)
            .frame(minWidth: minWidth, minHeight: height)
            .padding(.horizontal, Tokens.Space.s6)
            .background(enabled ? Tokens.Colour.action : Tokens.Colour.actionDisabled,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.button))
            // §8 v2.8: primary buttons sit on the page like cut paper; disabled ones lie flat.
            .hjShadow(enabled ? Tokens.Elevation.card : Tokens.ShadowSpec(radius: 0, y: 0, opacity: 0))
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }
}

struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    var minWidth: CGFloat = 220
    var destructive = false
    let action: () -> Void

    private var tint: Color { destructive ? Tokens.Colour.danger : Tokens.Colour.action }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.s3) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 22, weight: .medium)) }
                Text(title).font(.hjButtonSm)
            }
            .foregroundStyle(tint)
            .frame(minWidth: minWidth, minHeight: 56)
            .padding(.horizontal, Tokens.Space.s5)
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.button)
                .stroke(tint, lineWidth: Tokens.Stroke.emphasis))
        }
        .buttonStyle(PressableStyle())
    }
}

struct TextButton: View {
    let title: String
    var systemImage: String? = nil
    var trailingImage: String? = nil
    var tint: Color = Tokens.Colour.action
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.s3) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 20, weight: .medium)) }
                Text(title).font(.hjButtonSm)
                if let trailingImage { Image(systemName: trailingImage).font(.system(size: 20, weight: .medium)) }
            }
            .foregroundStyle(tint)
            .frame(minHeight: Tokens.Target.minimum)
        }
        .buttonStyle(PressableStyle())
    }
}

struct ToolbarIconButton: View {
    let systemImage: String
    var enabled = true
    var active = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(active ? Tokens.Colour.textOnAction
                                 : (enabled ? Tokens.Colour.action : Tokens.Colour.actionDisabled))
                .frame(width: Tokens.Target.minimum, height: Tokens.Target.minimum)
                .background(active ? Tokens.Colour.action : .clear,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.button - 2))
        }
        .disabled(!enabled)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Avatars (§10.2)

struct AvatarView: View {
    var image: Data?
    var initial: String?
    var diameter: CGFloat
    var locked = false
    var isAddTile = false

    private var ringWidth: CGFloat { diameter >= 140 ? 4 : (diameter >= 56 ? 2 : 0) }

    var body: some View {
        ZStack {
            if isAddTile {
                Circle()
                    .fill(Tokens.Colour.paperSunk)
                    .overlay(Circle().strokeBorder(Tokens.Colour.starOff,
                                                   style: StrokeStyle(lineWidth: 2, dash: [8, 6])))
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: diameter * 0.34, weight: .regular))
                    .foregroundStyle(Tokens.Colour.starOff)
            } else if let image, let ui = UIImage(data: image) {
                Image(uiImage: ui).resizable().scaledToFill()
                    .frame(width: diameter, height: diameter)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Tokens.Colour.paperRaised, lineWidth: ringWidth))
            } else {
                // A profile with no photo shows its initial — never the add-tile
                // treatment, or the two become indistinguishable (§10.2).
                Circle()
                    .fill(Tokens.Colour.paperSunk)
                    .overlay(Circle().strokeBorder(Tokens.Colour.paperRaised, lineWidth: ringWidth))
                Text(initial ?? "?")
                    .font(.system(size: diameter * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(Tokens.Colour.textSecondary)
            }
        }
        .frame(width: diameter, height: diameter)
        .hjShadow(diameter >= 56 ? Tokens.Elevation.card : Tokens.ShadowSpec(radius: 0, y: 0, opacity: 0))
        .overlay(alignment: .bottomTrailing) {
            if locked && diameter >= 140 {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.Colour.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Tokens.Colour.paperRaised, in: Circle())
                    .hjShadow(Tokens.Elevation.card)
                    .offset(x: 2, y: 2)
            }
        }
    }
}

// MARK: - Stars (§10.4)

struct StarsView: View {
    let earned: Int
    var total = 3
    var size: CGFloat = 28
    var gap: CGFloat = 8

    var body: some View {
        HStack(spacing: gap) {
            ForEach(0..<total, id: \.self) { i in
                Image(systemName: "star.fill")
                    .font(.system(size: size))
                    .foregroundStyle(i < earned ? Tokens.Colour.starOn : Tokens.Colour.starOff)
            }
        }
    }

    static let results = (size: CGFloat(44), gap: CGFloat(16))
    static let row     = (size: CGFloat(28), gap: CGFloat(8))
    static let compact = (size: CGFloat(20), gap: CGFloat(6))
}

// MARK: - Progress ring (§10.5)

struct AccuracyRing: View {
    let accuracy: Double            // 0…1
    var diameter: CGFloat = 220
    var lineWidth: CGFloat = 18
    var label: String? = "Accuracy"
    var tint: Color = Tokens.Colour.action

    var body: some View {
        ZStack {
            Circle().stroke(Tokens.Colour.paperSunk, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, accuracy)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: Tokens.Space.s2) {
                Text("\(Int((accuracy * 100).rounded()))%")
                    .font(diameter >= 180 ? .hjNumeralXL : .hjNumeralL)
                    .foregroundStyle(Tokens.Colour.textPrimary)
                    .monospacedDigit()
                if let label, diameter >= 180 {
                    Text(label).font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .padding(lineWidth / 2)
    }
}

// MARK: - Segmented control (§10.5)

struct SegmentedControl<T: Hashable>: View {
    let options: [(value: T, label: String)]
    @Binding var selection: T
    var height: CGFloat = 56

    var body: some View {
        GeometryReader { geo in
            let segment = geo.size.width / CGFloat(max(1, options.count))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2).fill(Tokens.Colour.paperSunk)
                if let index = options.firstIndex(where: { $0.value == selection }) {
                    RoundedRectangle(cornerRadius: (height - 8) / 2)
                        .fill(Tokens.Colour.paperRaised)
                        .hjShadow(Tokens.Elevation.card)
                        .padding(4)
                        .frame(width: segment)
                        .offset(x: segment * CGFloat(index))
                        .animation(.easeOut(duration: Tokens.Motion.standard), value: selection)
                }
                HStack(spacing: 0) {
                    ForEach(options, id: \.value) { option in
                        Text(option.label)
                            .font(.hjButtonSm)
                            .foregroundStyle(option.value == selection ? Tokens.Colour.textPrimary : Tokens.Colour.textSecondary)
                            .frame(width: segment, height: height)
                            .contentShape(Rectangle())
                            .onTapGesture { selection = option.value }
                    }
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Chrome

struct SectionHeader: View {
    let title: String
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: Tokens.Space.s4) {
            Text(title).font(.hjTitle2).foregroundStyle(Tokens.Colour.textPrimary)
            Rectangle().fill(Tokens.Colour.divider).frame(height: 1)
            if let trailing { trailing }
        }
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let heading: String
    let message: String
    var actionTitle: String? = nil
    var actionImage: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: systemImage)
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(Tokens.Colour.starOff)
                .padding(.bottom, Tokens.Space.s5)
            Text(heading).font(.hjTitle2).foregroundStyle(Tokens.Colour.textPrimary)
                .padding(.bottom, Tokens.Space.s3)
            Text(message).font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, systemImage: actionImage, action: action)
                    .padding(.top, Tokens.Space.s6)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct SettingRow<Control: View>: View {
    let title: String
    var subtitle: String? = nil
    var disabled = false
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack(spacing: Tokens.Space.s4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.hjBody).foregroundStyle(Tokens.Colour.textPrimary)
                if let subtitle {
                    Text(subtitle).font(.hjCaptionSm).foregroundStyle(Tokens.Colour.textSecondary)
                }
            }
            Spacer()
            control()
        }
        .frame(minHeight: 64)
        .padding(.horizontal, Tokens.Space.s4)
        .opacity(disabled ? 0.4 : 1)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Tokens.Colour.divider).frame(height: 1).padding(.leading, Tokens.Space.s4)
        }
    }
}

extension View {
    func card(radius: CGFloat = Tokens.Radius.card,
              fill: Color = Tokens.Colour.paperRaised,
              shadow: Tokens.ShadowSpec = Tokens.Elevation.card) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: radius)).hjShadow(shadow)
    }

    func sunkCard(radius: CGFloat = Tokens.Radius.card) -> some View {
        background(Tokens.Colour.paperSunk, in: RoundedRectangle(cornerRadius: radius))
    }
}
