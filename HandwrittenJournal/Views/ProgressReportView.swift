import SwiftUI
import Charts

/// Frames 31 and 32.
struct ProgressReportView: View {
    @Environment(\.dismiss) private var dismiss
    let profile: UserProfile

    private var report: ProgressReport { ProgressReport(profile: profile) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Accuracy over time").font(.hjTitle2).foregroundStyle(Tokens.Colour.textPrimary)
                        .padding(.top, Tokens.Space.s6)

                    if report.hasEnoughData, !report.trend.isEmpty {
                        chart
                        Text("5-entry rolling average. Marks show where the font or size changed — a dip after a change is expected, the letters just got harder.")
                            .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                            .padding(.top, Tokens.Space.s3)
                    } else {
                        EmptyStateView(systemImage: "chart.line.uptrend.xyaxis",
                                       heading: "Not enough entries yet",
                                       message: "A trend needs 5 entries with one font and size.\n\(profile.name) has \(report.currentRow?.count ?? 0) — keep going!")
                            .padding(.vertical, Tokens.Space.s8)
                            .frame(maxWidth: .infinity)
                            .sunkCard()
                            .padding(.top, Tokens.Space.s4)
                    }

                    Text("By mode and font").font(.hjTitle2).foregroundStyle(Tokens.Colour.textPrimary)
                        .padding(.top, Tokens.Space.s8)
                    table.padding(.top, Tokens.Space.s4)

                    if let suggestion = report.sizeSuggestion {
                        HStack(alignment: .top, spacing: Tokens.Space.s3) {
                            Image(systemName: "lightbulb").foregroundStyle(Tokens.Colour.action)
                            Text(suggestion).font(.hjCaption).foregroundStyle(Tokens.Colour.action)
                        }
                        .padding(Tokens.Space.s4)
                        .sunkCard(radius: Tokens.Radius.chip)
                        .padding(.top, Tokens.Space.s5)
                    }

                    stats.padding(.top, Tokens.Space.s7)
                }
                .padding(.horizontal, Tokens.Layout.screenMargin)
                .padding(.bottom, Tokens.Space.s8)
            }
            .background(Tokens.Colour.paper)
            .navigationTitle("\(profile.name)'s Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .onAppear { Telemetry.screen(.progress) }
    }

    private var chart: some View {
        Chart {
            ForEach(Array(report.trend.enumerated()), id: \.offset) { index, value in
                LineMark(x: .value("Sentence", index), y: .value("Accuracy", value * 100))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Tokens.Colour.action)
                    .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round))
            }
            ForEach(Array(report.settingMarkers.enumerated()), id: \.offset) { _, marker in
                RuleMark(x: .value("Change", marker.index))
                    .foregroundStyle(Tokens.Colour.starOff)
                    .annotation(position: .bottom) {
                        Text(marker.label).font(.hjCaptionSm).foregroundStyle(Tokens.Colour.textSecondary)
                    }
            }
        }
        .chartYScale(domain: 40...100)
        .chartYAxis { AxisMarks(values: [50, 75, 100]) }
        .chartXAxis(.hidden)
        .frame(height: 240)
        .padding(.top, Tokens.Space.s4)
    }

    private var table: some View {
        VStack(spacing: 0) {
            row(cells: ["Setting", "Mode", "Best", "Average", "Entries"], font: .hjCaption,
                colour: Tokens.Colour.textSecondary)
            ForEach(report.rows) { r in
                row(cells: [r.label, r.mode.label,
                            "\(Int((r.best * 100).rounded()))%",
                            "\(Int((r.average * 100).rounded()))%",
                            "\(r.count)"],
                    font: .hjBody,
                    colour: r.isCurrent ? Tokens.Colour.textPrimary : Tokens.Colour.textSecondary,
                    current: r.isCurrent)
            }
            if report.rows.isEmpty {
                Text("Nothing written yet.").font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                    .padding(.vertical, Tokens.Space.s5)
            }
            Text("Copy mode has no entries yet — it is coming later.")
                .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Tokens.Space.s4)
        }
    }

    private func row(cells: [String], font: Font, colour: Color, current: Bool = false) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { i, cell in
                Text(cell).font(font).foregroundStyle(colour)
                    .frame(maxWidth: .infinity, alignment: i == 0 ? .leading : .trailing)
            }
        }
        .padding(.vertical, Tokens.Space.s3)
        .overlay(alignment: .leading) {
            if current {
                Image(systemName: "checkmark").font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Tokens.Colour.action).offset(x: -18)
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Tokens.Colour.divider).frame(height: 1) }
    }

    private var stats: some View {
        VStack(spacing: 0) {
            statRow("Sessions written", "\(report.sessionCount)")
            statRow("Words written", "\(report.wordCount)")
            statRow("Days journaled", "\(report.daysJournaled)")
            statRow("Longest streak", String(localized: "\(profile.longestStreak) days"))
        }
        .padding(Tokens.Space.s5)
        .sunkCard()
    }

    private func statRow(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(label).font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
            Spacer()
            Text(value).font(.hjBodyEm).foregroundStyle(Tokens.Colour.textPrimary)
        }
        .frame(height: 44)
    }
}
