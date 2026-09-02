import SwiftUI

// MARK: - Buttons (§10.1)

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var minWidth: CGFloat = Tokens.Target.childPrimaryW
    var height: CGFloat = Tokens.Target.childPrimaryH
    var enabled: Bool = true
    /// Stretches to the width offered — a column's, in the landscape rail (v3.3).
    var fillsWidth = false
    /// The label's side padding. The rail uses a tighter one so the control still fits
    /// beside the scroll chevron on a 13-inch iPad's 344 pt rail.
    var horizontalPadding: CGFloat = Tokens.Space.s6
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.s3) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 28, weight: .medium)) }
                Text(title).font(.hjButton).lineLimit(1)
            }
            .foregroundStyle(Tokens.Colour.textOnAction)
            .frame(minWidth: minWidth, minHeight: height)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .padding(.horizontal, horizontalPadding)
            // §8 v2.8: primary buttons sit on the page like cut paper; disabled ones lie flat.
            // The shadow is the shape's, not the label's — cast from the composed view it
            // would ghost the text as well.
            .background(RoundedRectangle(cornerRadius: Tokens.Radius.button)
                .fill(enabled ? Tokens.Colour.action : Tokens.Colour.actionDisabled)
                .hjShadow(enabled ? Tokens.Elevation.card : Tokens.ShadowSpec(radius: 0, y: 0, opacity: 0)))
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
    /// Stretches to the width offered (v3.3).
    var fillsWidth = false
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
            .frame(maxWidth: fillsWidth ? .infinity : nil)
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

/// `Button / Tile` (§10.1, v3.1) — the action deck on Journal Home: a big primary tile and
/// its outlined partner, each saying what it earns. Replaces the centred primary button
/// and the text link that used to hang beneath it.
struct ActionTile: View {
    enum Style { case primary, secondary }

    let style: Style
    let title: String
    var subtitle: String? = nil
    let systemImage: String
    var chip: String? = nil
    var height: CGFloat = 128
    let action: () -> Void

    private var isPrimary: Bool { style == .primary }
    private var tint: Color { isPrimary ? Tokens.Colour.textOnAction : Tokens.Colour.action }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.s4) {
                Image(systemName: systemImage)
                    .font(.system(size: isPrimary ? 40 : 36, weight: .medium))
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                    Text(title).font(isPrimary ? .hjButton : .hjHeadline)
                    if let subtitle {
                        Text(subtitle).font(.hjBody).opacity(0.85)
                    }
                    if !isPrimary, let chip {
                        PointsChip(text: chip, tint: Tokens.Colour.action, onAction: false)
                            .padding(.top, Tokens.Space.s1)
                    }
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, Tokens.Space.s5)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .background(isPrimary ? Tokens.Colour.action : Tokens.Colour.paperRaised,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.card))
            .overlay {
                if !isPrimary {
                    RoundedRectangle(cornerRadius: Tokens.Radius.card)
                        .strokeBorder(Tokens.Colour.action, lineWidth: Tokens.Stroke.emphasis)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isPrimary, let chip {
                    PointsChip(text: chip, tint: Tokens.Colour.textOnAction, onAction: true)
                        .padding(Tokens.Space.s4)
                }
            }
            // The primary tile sits on the page like cut paper; the outlined one lies flat.
            .hjShadow(isPrimary ? Tokens.Elevation.card : Tokens.ShadowSpec(radius: 0, y: 0, opacity: 0))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(chip.map { "\(title). \($0)" } ?? title)
    }
}

/// "up to +230 points" / "+2 points a letter" — a caption capsule on a tile.
struct PointsChip: View {
    let text: String
    var tint: Color = Tokens.Colour.action
    /// On the action-blue tile the capsule is a white wash; elsewhere a tint wash.
    var onAction = false

    var body: some View {
        Text(text)
            .font(.hjCaption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, Tokens.Space.s3)
            .frame(height: 28)
            .background(tint.opacity(onAction ? 0.2 : 0.1), in: Capsule())
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

// MARK: - Points tracker (§10.5, v3.1 — Tracker / last 7 days)

/// One bar per day for the last week, today in `action`, the other days in
/// `action-disabled`, a 4 pt `paper-sunk` stub for a day with nothing. Bars scale to the
/// week's best day, so a quiet week still reads.
struct PointsTracker: View {
    let days: [PointsSummary.Day]
    var barWidth: CGFloat = 24
    var gap: CGFloat = 12
    var maxHeight: CGFloat = 38

    private var peak: Int { max(1, days.map(\.points).max() ?? 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
            Text("Last 7 days").font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
            HStack(alignment: .bottom, spacing: gap) {
                ForEach(days, id: \.date) { day in
                    VStack(spacing: Tokens.Space.s1) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(fill(for: day))
                            .frame(width: barWidth, height: height(for: day))
                        Text(day.date.formatted(.dateTime.weekday(.narrow)))
                            .font(day.isToday ? .hjCaptionSm.weight(.bold) : .hjCaptionSm)
                            .foregroundStyle(day.isToday ? Tokens.Colour.textPrimary : Tokens.Colour.textSecondary)
                            .lineLimit(1)
                            .fixedSize()
                            .frame(width: barWidth)
                    }
                }
            }
            .frame(height: maxHeight + Tokens.Space.s1 + LineHeight.captionSm, alignment: .bottom)
        }
        // The week is a fixed 240 pt; a card that proposes less would squeeze the last
        // labels to nothing, so insist on the ideal width.
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Last 7 days: " + days.map {
            "\($0.date.formatted(.dateTime.weekday(.wide))) \($0.points)"
        }.joined(separator: ", "))
    }

    private func fill(for day: PointsSummary.Day) -> Color {
        if day.points == 0 { return Tokens.Colour.paperSunk }
        return day.isToday ? Tokens.Colour.action : Tokens.Colour.actionDisabled
    }

    private func height(for day: PointsSummary.Day) -> CGFloat {
        guard day.points > 0 else { return 4 }
        return max(6, (maxHeight * CGFloat(day.points) / CGFloat(peak)).rounded())
    }
}

// MARK: - Chrome

/// The journal search (§10.8, v3.1): a plain field that sits directly above the entries
/// it filters, now that Journal Home has no navigation bar to put it in.
struct SearchField: View {
    @Binding var text: String
    var prompt = "Search what you said"

    var body: some View {
        HStack(spacing: Tokens.Space.s3) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Tokens.Colour.textSecondary)
            TextField(prompt, text: $text)
                .font(.hjBody)
                .foregroundStyle(Tokens.Colour.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Tokens.Colour.starOff)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Tokens.Space.s4)
        .frame(height: Tokens.Target.minimum)
        .background(Tokens.Colour.paperSunk, in: Capsule())
    }
}

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
        // The shadow belongs to the shape; cast from the composed view it ghosts the content.
        background(RoundedRectangle(cornerRadius: radius).fill(fill).hjShadow(shadow))
    }

    func sunkCard(radius: CGFloat = Tokens.Radius.card) -> some View {
        background(Tokens.Colour.paperSunk, in: RoundedRectangle(cornerRadius: radius))
    }
}
