import SwiftUI
import SwiftData

/// The main screen (v3.1): the header, the action deck, the points card, badges, then
/// every entry newest first with the search field directly above them.
///
/// There is no navigation bar any more. The export button left — an entry's ⋯ menu still
/// reaches *Share as PDF*, including the whole journal — and search moved down to sit by
/// the list it filters, so nothing was left to put in one. There is no resume card and no
/// separate journal list either: an entry is not a task with a state, it is a page you
/// either open or don't. Tapping one opens it to read (§4.7); the same page carries on
/// writing it.
struct JournalHomeView: View {
    @Environment(\.modelContext) private var context
    @Bindable var profile: UserProfile
    @Binding var selected: UserProfile?

    @State private var writing = false
    @State private var practicing = false
    @State private var opened: WritingSession?
    @State private var showSettings = false
    @State private var showProgress = false
    @State private var query = ""
    /// The badge whose card is open (§4.3, v3.2).
    @State private var shownBadge: BadgeDefinition?

    /// Newest first. `orderedSessions` already sorts by `startedAt` descending.
    private var entries: [WritingSession] {
        let all = profile.orderedSessions
        guard !query.isEmpty else { return all }
        let needle = query.lowercased()
        // Search matches what the child said, not how they wrote it.
        return all.filter { $0.transcript.lowercased().contains(needle) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    actionDeck
                    pointsCard
                    badgesSection
                    entriesSection
                }
                .padding(.horizontal, Tokens.Layout.screenMargin)
                .padding(.bottom, Tokens.Space.s8)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Tokens.Colour.paper)
            // Nothing lives in the bar (v3.1) — the pushed practice sheet keeps its own.
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $practicing) { PracticeView(profile: profile) }
        }
        // A new entry opens on the writing surface; one from the journal opens as
        // something to read. Same screen either way (§4.4).
        .fullScreenCover(isPresented: $writing) {
            EntryPageView(profile: profile, context: context, mode: .edit)
        }
        .fullScreenCover(item: $opened) { session in
            EntryPageView(profile: profile, context: context, resuming: session, mode: .view)
        }
        .sheet(isPresented: $showSettings) {
            ProfileSettingsView(profile: profile, selected: $selected).presentationDetents([.large])
        }
        .sheet(isPresented: $showProgress) {
            ProgressReportView(profile: profile).presentationDetents([.large])
        }
        // A badge's card sits over everything, in the family of the PIN pad (v3.2).
        .overlay {
            if let badge = shownBadge {
                BadgeDetailOverlay(badge: badge, earned: profile.earnedBadgeIDs.contains(badge.id)) {
                    shownBadge = nil
                }
            }
        }
        .animation(Tokens.Motion.spring, value: shownBadge)
        .task {
            #if DEBUG
            switch DemoData.screen {
            case "trace":    opened = profile.orderedSessions.first
            case "progress": showProgress = true
            case "settings": showSettings = true
            case "write":    writing = true
            case "practice": practicing = true
            default: break
            }
            #endif
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: Tokens.Space.s4) {
            Button { selected = nil } label: {
                AvatarView(image: profile.avatarImageData, initial: profile.initial, diameter: 56)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Tokens.Colour.action)
                            .frame(width: 22, height: 22)
                            .background(Tokens.Colour.paperRaised, in: Circle())
                            .hjShadow(Tokens.Elevation.card)
                    }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name).font(.hjDisplay).foregroundStyle(Tokens.Colour.textPrimary)
                HStack(spacing: Tokens.Space.s2) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(profile.currentStreak > 0 ? Tokens.Colour.streakFlame : Tokens.Colour.starOff)
                    Text(streakText)
                        .font(.hjBody)
                        .foregroundStyle(profile.currentStreak > 0 ? Tokens.Colour.streakFlame : Tokens.Colour.textSecondary)
                }
            }
            Spacer()
            ToolbarIconButton(systemImage: "chart.line.uptrend.xyaxis") { showProgress = true }
            ToolbarIconButton(systemImage: "gearshape.fill") { showSettings = true }
        }
        .padding(.top, Tokens.Space.s5)
    }

    /// Streak language is only ever positive: when it lapses, say nothing about losing it.
    private var streakText: String {
        switch profile.currentStreak {
        case 0: return "Write today to start a streak"
        case 1: return "1-day streak"
        default: return "\(profile.currentStreak)-day streak"
        }
    }

    // MARK: - Action deck (§4.3)

    /// The two ways to earn, side by side on the content grid: New Entry stays the
    /// primary; Practice is its outlined partner, a real button rather than a text link.
    private var actionDeck: some View {
        HStack(spacing: Tokens.Space.s4) {
            ActionTile(style: .primary,
                       title: "New Entry",
                       subtitle: "Tell me about your day",
                       systemImage: "pencil.line",
                       chip: "up to +\(ScoringEngine.maxEntryPoints) points") { writing = true }
            ActionTile(style: .secondary,
                       title: "Practice my letters",
                       systemImage: "textformat.abc",
                       chip: "+\(PracticePoints.full) points a letter") { practicing = true }
                .frame(width: 284)
        }
        .padding(.top, Tokens.Space.s5)
    }

    // MARK: - Points (§4.3, §8.3)

    /// The running total, what today added, and a bar for each of the last seven days.
    /// The card is a button: it opens Progress, like the chart icon above it.
    private var pointsCard: some View {
        let summary = profile.pointsSummary()
        return Button { showProgress = true } label: {
            HStack(spacing: Tokens.Space.s4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(summary.total > 0 ? Tokens.Colour.starOn : Tokens.Colour.starOff)
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s2) {
                        Text(summary.total.formatted())
                            .font(.hjNumeralL)
                            .foregroundStyle(Tokens.Colour.textPrimary)
                            .monospacedDigit()
                        Text("points").font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                    }
                    Text(pointsDelta(summary))
                        .font(summary.today > 0 ? .hjBodyEm : .hjBody)
                        .foregroundStyle(summary.today > 0 ? Tokens.Colour.success : Tokens.Colour.textSecondary)
                }
                Spacer(minLength: Tokens.Space.s4)
                PointsTracker(days: summary.days)
                Spacer(minLength: Tokens.Space.s4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Tokens.Colour.textSecondary)
            }
            .padding(.horizontal, Tokens.Space.s5)
            .frame(height: 128)
            .frame(maxWidth: .infinity)
            .card()
        }
        .buttonStyle(PressableStyle())
        .padding(.top, Tokens.Space.s4)
        .accessibilityLabel("\(summary.total) points, \(pointsDelta(summary)). Opens progress.")
    }

    private func pointsDelta(_ summary: PointsSummary) -> String {
        if summary.today > 0 { return "+\(summary.today) today" }
        return summary.total == 0 ? "Your first entry starts the count." : "Nothing yet today"
    }

    // MARK: - Badges

    private var badgesSection: some View {
        let earned = BadgeEngine.all.filter { profile.earnedBadgeIDs.contains($0.id) }.count
        return VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            SectionHeader(title: "Badges", trailing: AnyView(
                Text("\(earned) of \(BadgeEngine.all.count)")
                    .font(.hjCaption)
                    .foregroundStyle(Tokens.Colour.textSecondary)
            ))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(BadgeEngine.all) { badge in
                        let earned = profile.earnedBadgeIDs.contains(badge.id)
                        // Every tile is a button: a tap opens the badge's card (v3.2).
                        Button { shownBadge = badge } label: {
                            BadgeTile(badge: badge, earned: earned)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel(earned ? "\(badge.name), earned" : "\(badge.name), not earned yet")
                        .accessibilityHint("Shows what this badge is for")
                    }
                }
                .padding(.vertical, Tokens.Space.s1)
            }
        }
        .padding(.top, Tokens.Space.s6)
    }

    // MARK: - Entries

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            SectionHeader(title: query.isEmpty ? "My Journal" : resultsTitle)
            SearchField(text: $query)
            if entries.isEmpty {
                emptyState
            } else {
                ForEach(entries) { session in
                    Button { opened = session } label: { EntryRow(session: session) }
                        .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, Tokens.Space.s8)
    }

    private var resultsTitle: String {
        entries.isEmpty ? "No results" : "\(entries.count) result\(entries.count == 1 ? "" : "s")"
    }

    @ViewBuilder
    private var emptyState: some View {
        if query.isEmpty {
            EmptyStateView(systemImage: "book.closed",
                           heading: "Your journal is empty",
                           message: "Tap New Entry and tell me about your day.")
                .padding(.vertical, Tokens.Space.s9)
        } else {
            EmptyStateView(systemImage: "magnifyingglass",
                           heading: "Nothing found",
                           message: "Search looks at what you said, not how you wrote it.")
                .padding(.vertical, Tokens.Space.s8)
        }
    }
}

/// One entry, one row. The handwriting thumbnail leads — the journal should look like a
/// journal at a glance, not like a list of scores — and the points the entry earned sit
/// quietly under its stars, so the list reads as the ledger of a number that only goes up.
struct EntryRow: View {
    let session: WritingSession

    var body: some View {
        HStack(spacing: Tokens.Space.s4) {
            thumbnail
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Text("\(session.shortDate)  ·  \(session.timeOfDay)")
                    .font(.hjBodyEm).foregroundStyle(Tokens.Colour.textPrimary)
                Text("\u{201C}\(session.firstLine)\u{201D}")
                    .font(.hjBody).foregroundStyle(Tokens.Colour.textPrimary)
                    .lineLimit(1)
                Text(metadata)
                    .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
            }
            Spacer()
            VStack(spacing: Tokens.Space.s2) {
                StarsView(earned: session.stars, size: StarsView.row.size, gap: StarsView.row.gap)
                if session.points > 0 {
                    Text("+\(session.points) points")
                        .font(.hjCaption.weight(.semibold))
                        .foregroundStyle(Tokens.Colour.success)
                        .monospacedDigit()
                }
            }
        }
        .padding(Tokens.Space.s4)
        .frame(height: 132)
        .card()
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Tokens.Radius.chip).fill(Tokens.Colour.paper)
            if let data = session.thumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().padding(Tokens.Space.s2)
            } else {
                Text(session.firstLine).font(.hjCaptionSm)
                    .foregroundStyle(Tokens.Colour.textSecondary)
                    .padding(Tokens.Space.s2)
            }
        }
        .frame(width: 160, height: 100)
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.chip).stroke(Tokens.Colour.divider, lineWidth: 1))
    }

    private var metadata: String {
        let words = session.totalWords == 1 ? "1 word" : "\(session.totalWords) words"
        guard session.hasWriting else { return "\(words) · not written yet" }
        return "\(words)  ·  \(session.accuracyPercent)%  ·  \(session.setup.shortSummary)"
    }
}
