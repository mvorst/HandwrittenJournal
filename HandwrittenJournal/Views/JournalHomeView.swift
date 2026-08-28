import SwiftUI
import SwiftData

/// Frame 9 and its unfinished-session variant.
///
/// When a session is unfinished the resume card takes the primary slot. Without it,
/// talking for four minutes and writing three sentences feels like failing (§4.3).
struct JournalHomeView: View {
    @Environment(\.modelContext) private var context
    @Bindable var profile: UserProfile
    @Binding var selected: UserProfile?

    @State private var writing = false
    @State private var resuming: WritingSession?
    @State private var showSettings = false
    @State private var showProgress = false
    @State private var showJournal = false

    private var sessions: [WritingSession] { profile.orderedSessions }
    private var recent: [WritingSession] { sessions.filter(\.hasWriting).prefix(5).map { $0 } }
    private var unfinished: WritingSession? { profile.unfinishedSession }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    if let unfinished { resumeCard(unfinished) } else { writingSetupCard }
                    primaryActions
                    recentSection
                    badgesSection
                }
                .padding(.horizontal, Tokens.Layout.screenMargin)
                .padding(.bottom, Tokens.Space.s8)
            }
            .background(Tokens.Colour.paper)
            .navigationDestination(isPresented: $showJournal) {
                JournalListView(profile: profile)
            }
        }
        .fullScreenCover(isPresented: $writing) {
            WriteSessionView(profile: profile, context: context)
        }
        .fullScreenCover(item: $resuming) { session in
            WriteSessionView(profile: profile, context: context, resuming: session)
        }
        .sheet(isPresented: $showSettings) {
            ProfileSettingsView(profile: profile, selected: $selected).presentationDetents([.large])
        }
        .sheet(isPresented: $showProgress) {
            ProgressReportView(profile: profile).presentationDetents([.large])
        }
        .task {
            #if DEBUG
            switch DemoData.screen {
            case "trace":    resuming = profile.unfinishedSession
            case "journal":  showJournal = true
            case "progress": showProgress = true
            case "settings": showSettings = true
            case "write":    writing = true
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

    // MARK: - Cards

    private var writingSetupCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("YOUR WRITING").font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                Text(profile.setup.summary).font(.hjHeadline).foregroundStyle(Tokens.Colour.textPrimary)
            }
            Spacer()
            HStack(spacing: Tokens.Space.s2) {
                Text("Change").font(.hjButtonSm).foregroundStyle(Tokens.Colour.action)
                Image(systemName: "chevron.right").foregroundStyle(Tokens.Colour.action)
            }
        }
        .padding(Tokens.Space.s5)
        .frame(height: 96)
        .sunkCard()
        .contentShape(Rectangle())
        .onTapGesture { showSettings = true }
        .padding(.top, Tokens.Space.s6)
    }

    private func resumeCard(_ session: WritingSession) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("YOU WERE WRITING").font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
            Text("\u{201C}\(session.nextWords)\u{201D}")
                .font(.hjHeadline).foregroundStyle(Tokens.Colour.textPrimary)
                .lineLimit(2)
            ProgressView(value: Double(session.wordsWritten), total: Double(max(1, session.totalWords)))
                .tint(Tokens.Colour.action)
                .padding(.top, Tokens.Space.s2)
            Text("\(session.wordsWritten) of \(session.totalWords) words  ·  said at \(session.timeOfDay)")
                .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
        }
        .padding(Tokens.Space.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .padding(.top, Tokens.Space.s6)
    }

    private var primaryActions: some View {
        VStack(spacing: Tokens.Space.s3) {
            if let unfinished {
                PrimaryButton(title: "Keep writing", systemImage: "pencil.line", minWidth: 340, height: 72) {
                    resuming = unfinished
                }
                TextButton(title: "Start something new instead", systemImage: "mic.fill") { writing = true }
            } else {
                PrimaryButton(title: "New Entry", systemImage: "pencil.line", minWidth: 320, height: 72) {
                    writing = true
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Tokens.Space.s7)
    }

    // MARK: - Sections

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            SectionHeader(title: "Recent", trailing: AnyView(
                TextButton(title: "See all", trailingImage: "chevron.right") { showJournal = true }
            ))
            if recent.isEmpty {
                EmptyStateView(systemImage: "pencil.line",
                               heading: "Nothing written yet",
                               message: "Tap New Entry and tell me about your day.")
                    .padding(.vertical, Tokens.Space.s7)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Tokens.Space.s5) {
                        ForEach(recent) { session in
                            NavigationLink { EntryDetailView(session: session) } label: {
                                SessionCard(session: session)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.top, Tokens.Space.s8)
    }

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            SectionHeader(title: "Badges")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(BadgeEngine.all) { badge in
                        let earned = profile.earnedBadgeIDs.contains(badge.id)
                        VStack(spacing: Tokens.Space.s2) {
                            Image(systemName: badge.systemImage)
                                .font(.system(size: 28))
                                .foregroundStyle(earned ? Tokens.Colour.starOn : Tokens.Colour.starOff)
                                .frame(width: 64, height: 64)
                                .background(earned ? Tokens.Colour.paperRaised : Tokens.Colour.paperSunk, in: Circle())
                                .hjShadow(earned ? Tokens.Elevation.card : Tokens.ShadowSpec(radius: 0, y: 0, opacity: 0))
                        }
                    }
                }
                .padding(.vertical, Tokens.Space.s1)
            }
        }
        .padding(.top, Tokens.Space.s8)
    }
}

/// §10.6 Card / Session — the handwriting thumbnail, not the typed text. The journal
/// should look like a journal at a glance.
struct SessionCard: View {
    let session: WritingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Rectangle().fill(Tokens.Colour.paper)
                if let data = session.thumbnailData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFit().padding(Tokens.Space.s2)
                } else {
                    Text(session.firstLine).font(.hjCaptionSm)
                        .foregroundStyle(Tokens.Colour.textSecondary)
                        .padding(Tokens.Space.s3)
                }
            }
            .frame(width: 200, height: 140)
            .clipped()
            .overlay(Rectangle().stroke(Tokens.Colour.divider, lineWidth: 1))

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    Text(session.shortDate).font(.hjCaption).foregroundStyle(Tokens.Colour.textPrimary)
                    StarsView(earned: session.stars, size: StarsView.compact.size, gap: StarsView.compact.gap)
                }
                Spacer()
                if !session.isComplete && session.wordsWritten > 0 {
                    Text("\(Int(session.progress * 100))%")
                        .font(.hjCaptionSm).foregroundStyle(Tokens.Colour.textSecondary)
                        .padding(.horizontal, Tokens.Space.s3).padding(.vertical, Tokens.Space.s1)
                        .background(Tokens.Colour.paperSunk, in: Capsule())
                }
            }
            .padding(Tokens.Space.s3)
            .frame(height: 100, alignment: .top)
        }
        .frame(width: 200, height: 240)
        .card()
    }
}
