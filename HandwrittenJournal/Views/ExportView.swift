import SwiftUI
import PDFKit

/// Frames 19 and 43. Two scopes from one screen — a page, or the book.
struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    let profile: UserProfile?
    let session: WritingSession?

    enum Scope: Hashable { case entry, month, everything }
    @State private var scope: Scope = .entry
    @State private var includeTyped = true
    @State private var includeAccuracy = false
    @State private var document: Data?
    @State private var shareURL: URL?

    private var sessions: [WritingSession] {
        let all = profile?.orderedSessions.filter(\.hasWriting) ?? []
        switch scope {
        case .entry:      return session.map { [$0] } ?? Array(all.prefix(1))
        case .month:
            guard let anchor = (session ?? all.first)?.startedAt else { return [] }
            return all.filter {
                Calendar.current.isDate($0.startedAt, equalTo: anchor, toGranularity: .month)
            }
        case .everything: return all
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if session != nil {
                    SegmentedControl(options: [(Scope.entry, "This entry"),
                                               (Scope.month, "This month"),
                                               (Scope.everything, "Everything")],
                                     selection: $scope, height: 44)
                        .padding(.horizontal, Tokens.Layout.screenMargin)
                        .padding(.top, Tokens.Space.s5)
                }

                if let document, let pdf = PDFDocument(data: document) {
                    PDFPreview(document: pdf)
                        .padding(Tokens.Space.s5)
                } else {
                    Spacer()
                    ProgressView().controlSize(.large)
                    Spacer()
                }

                VStack(spacing: Tokens.Space.s2) {
                    Text("\(sessions.count) page\(sessions.count == 1 ? "" : "s")  ·  one per session, oldest first")
                        .font(.hjBody).foregroundStyle(Tokens.Colour.textPrimary)
                    Text("Everything is rendered on this iPad — nothing is uploaded.")
                        .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                }
                .padding(.top, Tokens.Space.s3)

                VStack(spacing: 0) {
                    SettingRow(title: "Include the typed words") {
                        Toggle("", isOn: $includeTyped).labelsHidden().tint(Tokens.Colour.action)
                    }
                    SettingRow(title: "Include accuracy scores") {
                        Toggle("", isOn: $includeAccuracy).labelsHidden().tint(Tokens.Colour.action)
                    }
                }
                .padding(.horizontal, Tokens.Layout.screenMargin)
                .padding(.top, Tokens.Space.s4)
                .padding(.bottom, Tokens.Space.s5)
            }
            .background(Tokens.Colour.paper)
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(scope == .everything ? "Make the book" : "Share") { share() }
                        .fontWeight(.semibold)
                        .disabled(document == nil)
                }
            }
        }
        .task(id: taskKey) { rebuild() }
        .sheet(item: $shareURL) { url in ShareSheet(items: [url]) }
    }

    private var taskKey: String { "\(scope)-\(includeTyped)-\(includeAccuracy)" }

    private func rebuild() {
        document = PDFBookBuilder.build(
            sessions: sessions,
            options: .init(includeTypedWords: includeTyped,
                           includeAccuracy: includeAccuracy,
                           childName: profile?.name ?? "")
        )
    }

    private func share() {
        guard let document else { return }
        let name = scope == .everything
            ? "\(profile?.name ?? "Journal")-journal.pdf"
            : "\(session?.shortDate ?? "entry").pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? document.write(to: url)
        shareURL = url
    }
}

extension URL: @retroactive Identifiable { public var id: String { absoluteString } }

struct PDFPreview: UIViewRepresentable {
    let document: PDFDocument
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.backgroundColor = UIColor(Tokens.Colour.paperSunk)
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) { view.document = document }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
