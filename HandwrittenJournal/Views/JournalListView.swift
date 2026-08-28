import SwiftUI
import SwiftData

/// Frames 11 and 12. Each row is a session. Unfinished sessions sit in a "Still to
/// write" section at the top — there is no separate drafts concept (§4.6).
struct JournalListView: View {
    @Environment(\.modelContext) private var context
    let profile: UserProfile

    @State private var query = ""
    @State private var resuming: WritingSession?
    @State private var showExport = false

    private var all: [WritingSession] { profile.orderedSessions }
    private var unfinished: [WritingSession] { all.filter { !$0.isComplete && $0.totalWords > 0 } }
    private var complete: [WritingSession] { all.filter(\.isComplete) }

    private var results: [WritingSession] {
        guard !query.isEmpty else { return [] }
        let needle = query.lowercased()
        // Search matches what the child said, not how they wrote it.
        return all.filter { $0.transcript.lowercased().contains(needle) }
    }

    private var months: [(String, [WritingSession])] {
        let grouped = Dictionary(grouping: complete) { session in
            session.startedAt.formatted(.dateTime.month(.wide).year()).uppercased()
        }
        return grouped.sorted { ($0.value.first?.startedAt ?? .distantPast) > ($1.value.first?.startedAt ?? .distantPast) }
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                if !query.isEmpty {
                    header(results.isEmpty ? "NO RESULTS" : "\(results.count) RESULT\(results.count == 1 ? "" : "S")")
                    ForEach(results) { row(for: $0) }
                    if results.isEmpty {
                        EmptyStateView(systemImage: "magnifyingglass",
                                       heading: "Nothing found",
                                       message: "Search looks at what you said, not how you wrote it.")
                            .padding(.vertical, Tokens.Space.s8)
                    }
                } else {
                    if !unfinished.isEmpty {
                        header("STILL TO WRITE (\(unfinished.count))")
                        ForEach(unfinished) { unfinishedRow(for: $0) }
                    }
                    ForEach(months, id: \.0) { month, sessions in
                        header(month)
                        ForEach(sessions) { row(for: $0) }
                    }
                    if all.isEmpty {
                        EmptyStateView(systemImage: "book.closed",
                                       heading: "Your journal is empty",
                                       message: "Everything you write will collect here.")
                            .padding(.vertical, Tokens.Space.s9)
                    }
                }
            }
            .padding(.horizontal, Tokens.Layout.screenMargin)
            .padding(.bottom, Tokens.Space.s8)
        }
        .background(Tokens.Colour.paper)
        .navigationTitle("My Journal")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search what you said")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showExport = true } label: { Image(systemName: "square.and.arrow.up") }
            }
        }
        .fullScreenCover(item: $resuming) { session in
            WriteSessionView(profile: profile, context: context, resuming: session)
        }
        .sheet(isPresented: $showExport) {
            ExportView(profile: profile, session: nil).presentationDetents([.large])
        }
    }

    private func header(_ title: String) -> some View {
        Text(title).font(.hjBodyEm).foregroundStyle(Tokens.Colour.textSecondary)
            .padding(.top, Tokens.Space.s5)
    }

    private func row(for session: WritingSession) -> some View {
        NavigationLink { EntryDetailView(session: session) } label: {
            HStack(spacing: Tokens.Space.s4) {
                thumbnail(for: session)
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    Text("\(session.shortDate)  ·  \(session.timeOfDay)")
                        .font(.hjBodyEm).foregroundStyle(Tokens.Colour.textPrimary)
                    Text("\u{201C}\(session.firstLine)\u{201D}")
                        .font(.hjBody).foregroundStyle(Tokens.Colour.textPrimary)
                        .lineLimit(1)
                    Text(metadata(for: session))
                        .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                }
                Spacer()
                StarsView(earned: session.stars, size: StarsView.row.size, gap: StarsView.row.gap)
            }
            .padding(Tokens.Space.s4)
            .frame(height: 132)
            .card()
        }
        .buttonStyle(.plain)
    }

    private func unfinishedRow(for session: WritingSession) -> some View {
        HStack(spacing: Tokens.Space.s4) {
            thumbnail(for: session)
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Text("\(session.shortDate)  ·  \(session.timeOfDay)")
                    .font(.hjBodyEm).foregroundStyle(Tokens.Colour.textPrimary)
                Text("Next: \u{201C}\(session.nextWords)\u{201D}")
                    .font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                    .lineLimit(1)
                ProgressView(value: Double(session.wordsWritten), total: Double(max(1, session.totalWords)))
                    .tint(Tokens.Colour.action)
                Text("\(session.wordsWritten) of \(session.totalWords) words")
                    .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
            }
            Spacer()
            SecondaryButton(title: "Keep writing", minWidth: 200) { resuming = session }
        }
        .padding(Tokens.Space.s4)
        .frame(height: 132)
        .background(Tokens.Colour.paperRaised, in: RoundedRectangle(cornerRadius: Tokens.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.card)
            .strokeBorder(Tokens.Colour.starOff, style: StrokeStyle(lineWidth: 2, dash: [8, 6])))
    }

    private func thumbnail(for session: WritingSession) -> some View {
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

    private func metadata(for session: WritingSession) -> String {
        let words = session.totalWords == 1 ? "1 word" : "\(session.totalWords) words"
        guard session.hasWriting else { return "\(words) · not written yet" }
        return "\(words)  ·  \(session.accuracyPercent)%  ·  \(session.setup.shortSummary)"
    }
}
