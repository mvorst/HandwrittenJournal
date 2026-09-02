import SwiftUI

/// `Sheet / Badge` (§10.8, v3.2) — what a badge is for, on a tap from the home strip.
///
/// A centred card on the scrim, in the family of the PIN pad and the formation-help
/// modal: the badge at tile size, its name, whether it is earned, and one line saying
/// what earned it or what will. Closable three ways — the button, the ✕, and the scrim —
/// because a six-year-old should never be stuck behind a card.
struct BadgeDetailOverlay: View {
    let badge: BadgeDefinition
    let earned: Bool
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Tokens.Colour.overlayScrim.ignoresSafeArea()
                .onTapGesture(perform: onClose)
                .accessibilityHidden(true)
            card
                .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onClose)
    }

    private var card: some View {
        VStack(spacing: 0) {
            BadgeTile(badge: badge, earned: earned, diameter: 88)
                .padding(.top, Tokens.Space.s7)
            Text(badge.name)
                .font(.hjTitle2)
                .foregroundStyle(Tokens.Colour.textPrimary)
                .padding(.top, Tokens.Space.s5)
            HStack(spacing: Tokens.Space.s1) {
                Image(systemName: earned ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 15, weight: .semibold))
                Text(earned ? "Earned" : "Not earned yet")
                    .font(.hjCaption)
            }
            .foregroundStyle(earned ? Tokens.Colour.success : Tokens.Colour.textSecondary)
            .padding(.top, Tokens.Space.s2)
            Text(earned ? badge.detail : badge.hint)
                .font(.hjBody)
                .foregroundStyle(Tokens.Colour.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, Tokens.Space.s4)
                .padding(.horizontal, Tokens.Space.s6)
            PrimaryButton(title: "Got it", action: onClose)
                .padding(.top, Tokens.Space.s6)
                .padding(.bottom, Tokens.Space.s6)
        }
        .frame(width: 480)
        .background(RoundedRectangle(cornerRadius: Tokens.Radius.sheet)
            .fill(Tokens.Colour.paperRaised)
            .hjShadow(Tokens.Elevation.modal))
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Tokens.Colour.textSecondary)
                    .frame(width: Tokens.Target.minimum, height: Tokens.Target.minimum)
                    .background(Tokens.Colour.paperSunk, in: Circle())
            }
            .buttonStyle(PressableStyle())
            .padding(Tokens.Space.s4)
            .accessibilityLabel("Close")
        }
        .padding(Tokens.Space.s6)
    }
}

/// `Badge / Tile` (§10.7): the disc alone — an earned tile floats on the page, an
/// unearned one sinks into it. 64 pt on the home strip, 88 pt on its card.
struct BadgeTile: View {
    let badge: BadgeDefinition
    let earned: Bool
    var diameter: CGFloat = 64

    var body: some View {
        Image(systemName: badge.systemImage)
            .font(.system(size: (diameter * 0.44).rounded()))
            .foregroundStyle(earned ? Tokens.Colour.starOn : Tokens.Colour.starOff)
            .frame(width: diameter, height: diameter)
            .background(Circle()
                .fill(earned ? Tokens.Colour.paperRaised : Tokens.Colour.paperSunk)
                .hjShadow(earned ? Tokens.Elevation.card : Tokens.ShadowSpec(radius: 0, y: 0, opacity: 0)))
    }
}
