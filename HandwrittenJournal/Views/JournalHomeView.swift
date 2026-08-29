import SwiftUI
import SwiftData

/// The main screen (v2.6): badges, then every entry newest first.
///
/// There is no resume card and no separate journal list. An entry is not a task with a
/// state — it is a page you either open or don't. Tapping one opens it to read, and the
/// Edit button on that page carries on writing it.
struct JournalHomeView: View {
    @Environment(\.modelContext) private var context
    @Bindable var profile: UserProfile
    @Binding var selected: UserProfile?

    @State private var writing = false
    @State private var practicing = false
    @State private var editing: WritingSession?
    @State private var showSettings = false
    @State private var showProgress = false
    @State private var showExport = false
    @State private var query = ""

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
                    newEntryButton
                    badgesSection
                    entriesSection
                }
                .padding(.horizontal, Tokens.Layout.screenMargin)
                .padding(.bottom, Tokens.Space.s8)
            }
            .background(Tokens.Colour.paper)
            .navigationDestination(isPresented: $practicing) { PracticeView(profile: profile) }
            .searchable(text: $query, prompt: "Search what you said")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showExport = true } label: { Image(systemName: "square.and.arrow.up") }
                        .disabled(profile.orderedSessions.isEmpty)
                }
            }
        }
        .fullScreenCover(isPresented: $writing) {
            WriteSessionView(profile: profile, context: context)
        }
        .fullScreenCover(item: $editing) { session in
            WriteSessionView(profile: profile, context: context, resuming: session)
        }
        .sheet(isPresented: $showSettings) {
            ProfileSettingsView(profile: profile, selected: $selected).presentationDetents([.large])
        }
        .sheet(isPresented: $showProgress) {
            ProgressReportView(profile: profile).presentationDetents([.large])
        }
        .sheet(isPresented: $showExport) {
            ExportView(profile: profile, session: nil).presentationDetents([.large])
        }
        .task {
            #if DEBUG
            switch DemoData.screen {
            case "trace":    editing = profile.orderedSessions.first
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

    // MARK: - Primary action

    private var newEntryButton: some View {
        VStack(spacing: Tokens.Space.s3) {
            PrimaryButton(title: "New Entry", systemImage: "pencil.line", minWidth: 320, height: 72) {
                writing = true
            }
            TextButton(title: "Practice my letters", systemImage: "textformat.abc") { practicing = true }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Tokens.Space.s7)
    }

    // MARK: - Badges

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            SectionHeader(title: "Badges")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(BadgeEngine.all) { badge in
                        let earned = profile.earnedBadgeIDs.contains(badge.id)
                        Image(systemName: badge.systemImage)
                            .font(.system(size: 28))
                            .foregroundStyle(earned ? Tokens.Colour.starOn : Tokens.Colour.starOff)
                            .frame(width: 64, height: 64)
                            .background(earned ? Tokens.Colour.paperRaised : Tokens.Colour.paperSunk, in: Circle())
                            .hjShadow(earned ? Tokens.Elevation.card : Tokens.ShadowSpec(radius: 0, y: 0, opacity: 0))
                            .accessibilityLabel(earned ? "\(badge.name), earned" : "\(badge.name), not earned yet")
                    }
                }
                .padding(.vertical, Tokens.Space.s1)
            }
        }
        .padding(.top, Tokens.Space.s8)
    }

    // MARK: - Entries

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            SectionHeader(title: query.isEmpty ? "My Journal" : resultsTitle)
            if entries.isEmpty {
                emptyState
            } else {
                ForEach(entries) { session in
                    NavigationLink { EntryDetailView(session: session) } label: {
                        EntryRow(session: session)
                    }
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
/// journal at a glance, not like a list of scores.
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
            StarsView(earned: session.stars, size: StarsView.row.size, gap: StarsView.row.gap)
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
