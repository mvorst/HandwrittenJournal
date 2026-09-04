import SwiftUI
import SwiftData

/// The main screen (v3.1): the header, the action deck, the points card, badges, then
/// every entry newest first with the search field directly above them. Since v3.3 the
/// dashboard stays put and only the entries scroll, and in landscape the two stand side
/// by side — the dashboard a column on the left, the journal the rest.
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

    /// The home greeting has been said for this visit (v3.7).
    @State private var greeted = false
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
            GeometryReader { geo in
                let layout = ScreenLayout(geo)
                let stack = layout.isLandscape
                    ? AnyLayout(HStackLayout(alignment: .top, spacing: Tokens.Space.s5))
                    : AnyLayout(VStackLayout(spacing: 0))
                stack {
                    dashboard(layout)
                        .frame(width: layout.isLandscape ? layout.dashboardWidth : nil)
                    entriesColumn(layout)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, Tokens.Layout.screenMargin)
            }
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
        .onAppear {
            Telemetry.screen(.journal)
            // Once per visit from the picker, not on every return from a page (§4.12, v3.7).
            if !greeted { greeted = true; Voice.say(.home) }
        }
        .task {
            #if DEBUG
            switch DemoData.screen {
            case "trace":    opened = profile.orderedSessions.first
            case "progress": showProgress = true
            case "settings": showSettings = true
            case "write":    writing = true
            case "practice": practicing = true
            // v3.8 — the sheet with *How to trace a letter* owed, as on a first visit.
            case "practice-tutorial":
                profile.practiceTutorialSeen = false
                practicing = true
            default: break
            }
            #endif
        }
    }

    // MARK: - Dashboard

    /// Everything above the journal: the header, the action deck, the points card and
    /// the badges. Only the badges scroll, and only in landscape, where they wrap (v3.3).
    private func dashboard(_ layout: ScreenLayout) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(showsButtons: !layout.isLandscape)
            actionDeck(layout)
            pointsCard(layout)
            badgesSection(layout)
        }
    }

    // MARK: - Header

    private func header(showsButtons: Bool) -> some View {
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
            if showsButtons { screenButtons }
        }
        .padding(.top, Tokens.Space.s5)
    }

    /// Settings. In the header in portrait; in landscape it moves to the journal
    /// column's header, so it keeps the top-right corner either way (v3.3).
    /// Progress has no icon of its own: the points card below opens it.
    private var screenButtons: some View {
        ToolbarIconButton(systemImage: "gearshape.fill") { showSettings = true }
    }

    /// Streak language is only ever positive: when it lapses, say nothing about losing it.
    private var streakText: String {
        switch profile.currentStreak {
        case 0: return String(localized: "Write today to start a streak")
        case 1: return String(localized: "1-day streak")
        default: return String(localized: "\(profile.currentStreak)-day streak")
        }
    }

    // MARK: - Action deck (§4.3)

    /// The two ways to earn, side by side on the content grid: New Entry stays the
    /// primary; Practice is its outlined partner, a real button rather than a text link.
    private func actionDeck(_ layout: ScreenLayout) -> some View {
        // Side by side on the content grid in portrait; stacked in the dashboard column
        // in landscape, each the column's width (v3.3).
        let deck = layout.isLandscape
            ? AnyLayout(VStackLayout(spacing: Tokens.Space.s4))
            : AnyLayout(HStackLayout(spacing: Tokens.Space.s4))
        return deck {
            ActionTile(style: .primary,
                       title: "New Entry",
                       subtitle: "Tell me about your day",
                       systemImage: "pencil.line") { writing = true }
            ActionTile(style: .secondary,
                       title: "Practice my letters",
                       systemImage: "textformat.abc",
                       chip: "+\(PracticePoints.full) points a letter") { practicing = true }
                .frame(width: layout.isLandscape ? nil : 284)
        }
        .padding(.top, Tokens.Space.s5)
    }

    // MARK: - Points (§4.3, §8.3)

    /// The running total, what today added, and a bar for each of the last seven days.
    /// The card is a button, and the only way in to Progress from this screen.
    private func pointsCard(_ layout: ScreenLayout) -> some View {
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
                            .lineLimit(1)
                            .fixedSize()
                        Text("points").font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                    }
                    // The total and its unit never wrap, whatever the column squeezes (v3.3).
                    .fixedSize()
                    Text(pointsDelta(summary))
                        .font(summary.today > 0 ? .hjBodyEm : .hjBody)
                        .foregroundStyle(summary.today > 0 ? Tokens.Colour.success : Tokens.Colour.textSecondary)
                }
                Spacer(minLength: Tokens.Space.s4)
                // Narrower bars in the dashboard column (v3.3), so a four-figure total
                // beside the tracker never wraps.
                PointsTracker(days: summary.days,
                              barWidth: layout.isLandscape ? 20 : 24,
                              gap: layout.isLandscape ? 10 : 12)
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
        if summary.today > 0 { return String(localized: "+\(summary.today) today") }
        return summary.total == 0 ? String(localized: "Your first entry starts the count.") : String(localized: "Nothing yet today")
    }

    // MARK: - Badges

    /// In portrait the tiles are one strip that scrolls sideways. In landscape the
    /// dashboard column is narrow and tall, so the tiles wrap into rows and the section
    /// scrolls up and down instead — the only part of the dashboard that scrolls.
    private func badgesSection(_ layout: ScreenLayout) -> some View {
        let earned = BadgeEngine.all.filter { profile.earnedBadgeIDs.contains($0.id) }.count
        return VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            SectionHeader(title: "Badges", trailing: AnyView(
                Text("\(earned) of \(BadgeEngine.all.count)")
                    .font(.hjCaption)
                    .foregroundStyle(Tokens.Colour.textSecondary)
            ))
            if layout.isLandscape {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 20)], spacing: 20) {
                        badgeTiles
                    }
                    .padding(.vertical, Tokens.Space.s1)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) { badgeTiles }
                        .padding(.vertical, Tokens.Space.s1)
                }
            }
        }
        .padding(.top, Tokens.Space.s6)
    }

    private var badgeTiles: some View {
        ForEach(BadgeEngine.all) { badge in
            let earned = profile.earnedBadgeIDs.contains(badge.id)
            // Every tile is a button: a tap opens the badge's card (v3.2).
            Button { shownBadge = badge } label: {
                BadgeTile(badge: badge, earned: earned)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(earned ? Text("\(badge.name), earned") : Text("\(badge.name), not earned yet"))
            .accessibilityHint("Shows what this badge is for")
        }
    }

    // MARK: - Entries

    /// The journal: its header and the search field stay put; only the rows scroll (v3.3).
    private func entriesColumn(_ layout: ScreenLayout) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            SectionHeader(title: query.isEmpty ? "My Journal" : resultsTitle,
                          trailing: layout.isLandscape ? AnyView(screenButtons) : nil)
            SearchField(text: $query)
            ScrollView {
                LazyVStack(spacing: Tokens.Space.s4) {
                    if entries.isEmpty {
                        emptyState
                    } else {
                        ForEach(entries) { session in
                            Button { opened = session } label: { EntryRow(session: session) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                // Room for the first row's edge, and for the last to clear the home indicator.
                .padding(.top, Tokens.Space.s1)
                .padding(.bottom, Tokens.Space.s8)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(.top, layout.isLandscape ? Tokens.Space.s6 : Tokens.Space.s8)
    }

    /// "1 result" is the catalog's plural form of the second key.
    private var resultsTitle: LocalizedStringKey {
        entries.isEmpty ? "No results" : "\(entries.count) results"
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
        let words = String(localized: "\(session.totalWords) words")   // "1 word" via the catalog
        guard session.hasWriting else { return String(localized: "\(words) · not written yet") }
        return String(localized: "\(words)  ·  \(session.accuracyPercent)%  ·  \(session.setup.shortSummary)")
    }
}
