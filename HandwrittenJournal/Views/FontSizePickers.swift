import SwiftUI

/// Frame 38. You cannot choose a typeface from a name — every option shows a live
/// preview at a traceable size, on a ruled line.
struct FontPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var setup: WritingSetup

    private var faces: [JournalFace] {
        let available = JournalFace.available
        return available.isEmpty ? [JournalFace.default] : available
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    Text("Every font here has thick strokes and open letters, so a beginner can stay inside them.")
                        .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)

                    ForEach(faces) { face in
                        let selected = face.id == setup.face.id
                        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                            HStack {
                                Text(face.label).font(.hjHeadline).foregroundStyle(Tokens.Colour.textPrimary)
                                Spacer()
                                if selected {
                                    Image(systemName: "checkmark").font(.system(size: 24, weight: .semibold))
                                        .foregroundStyle(Tokens.Colour.action)
                                }
                            }
                            Text(face.reason).font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                            GuidePreview(text: "I saw a red bird",
                                         setup: WritingSetup(face: face,
                                                             size: JournalSize(id: "preview", label: "Preview",
                                                                               size: 46, lineSpacing: 60),
                                                             mode: .trace))
                                .frame(height: 76)
                        }
                        .padding(Tokens.Space.s5)
                        .background(selected ? Tokens.Colour.paperRaised : Tokens.Colour.paperSunk,
                                    in: RoundedRectangle(cornerRadius: Tokens.Radius.card))
                        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.card)
                            .stroke(selected ? Tokens.Colour.action : .clear, lineWidth: Tokens.Stroke.selected))
                        .contentShape(Rectangle())
                        .onTapGesture { setup.face = face; Haptics.tap() }
                    }

                    if JournalFace.available.count < JournalFace.all.count {
                        Text("More faces are listed in the design but their font files are not bundled yet — see BUILD_LOG.md.")
                            .font(.hjCaptionSm).foregroundStyle(Tokens.Colour.textSecondary)
                    }
                    Text("Changing the font starts a new line on the accuracy chart — earlier sentences stay comparable.")
                        .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                }
                .padding(Tokens.Layout.screenMargin)
            }
            .background(Tokens.Colour.paper)
            .navigationTitle("Font")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

/// Frame 39. Bigger letters are easier; a grown-up moves the child down when tracing
/// is comfortable. Nothing here happens automatically.
struct SizePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var setup: WritingSetup

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    Text("Bigger letters are easier. Move down a size when tracing gets comfortable.")
                        .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)

                    ForEach(JournalSize.all) { size in
                        let selected = size.id == setup.size.id
                        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                            HStack {
                                Text(size.label).font(.hjBodyEm).foregroundStyle(Tokens.Colour.textPrimary)
                                Spacer()
                                Text("\(Int(size.size)) pt").font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                                if selected {
                                    Image(systemName: "checkmark").font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(Tokens.Colour.action)
                                }
                            }
                            GuidePreview(text: "I saw a bird",
                                         setup: WritingSetup(face: setup.face, size: size, mode: .trace),
                                         showRules: false)
                                .frame(height: size.size * 1.2)
                        }
                        .padding(Tokens.Space.s5)
                        .background(selected ? Tokens.Colour.paperRaised : Tokens.Colour.paperSunk,
                                    in: RoundedRectangle(cornerRadius: Tokens.Radius.card))
                        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.card)
                            .stroke(selected ? Tokens.Colour.action : .clear, lineWidth: Tokens.Stroke.selected))
                        .contentShape(Rectangle())
                        .onTapGesture { setup.size = size; Haptics.tap() }
                    }
                }
                .padding(Tokens.Layout.screenMargin)
            }
            .background(Tokens.Colour.paper)
            .navigationTitle("Font size")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

/// Guide text drawn exactly as the tracing surface would draw it.
struct GuidePreview: UIViewRepresentable {
    let text: String
    let setup: WritingSetup
    var showRules = true
    var inset: CGFloat = 0

    func makeUIView(context: Context) -> PreviewView { PreviewView() }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.text = text
        view.setup = setup
        view.showRules = showRules
        view.inset = inset
        view.setNeedsDisplay()
    }

    final class PreviewView: UIView {
        var text = ""
        var setup = WritingSetup.default
        var showRules = true
        var inset: CGFloat = 0
        private let renderer = MaskRenderer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            isOpaque = false
        }
        required init?(coder: NSCoder) { fatalError() }

        override func draw(_ rect: CGRect) {
            guard let ctx = UIGraphicsGetCurrentContext(), !text.isEmpty, bounds.width > 0 else { return }
            let top: CGFloat = inset > 0 ? Tokens.Space.s5 : 4
            renderer.generate(text: text, setup: setup, canvasSize: bounds.size, inset: inset, topPadding: top)
            if showRules {
                ctx.setStrokeColor(UIColor(Tokens.Colour.ruleLine).cgColor)
                ctx.setLineWidth(1)
                // Same rule as the writing page: rules follow the measured baselines.
                var index = 0
                var baseline = renderer.layout.baselines.first ?? (top + setup.size.ascent)
                repeat {
                    if index < renderer.layout.baselines.count { baseline = renderer.layout.baselines[index] }
                    for (y, dashed) in [(baseline - setup.size.ascent, true), (baseline, false),
                                        (baseline + setup.size.descent, true)] {
                        ctx.setLineDash(phase: 0, lengths: dashed ? [6, 4] : [])
                        ctx.move(to: CGPoint(x: inset, y: y.rounded() + 0.5))
                        ctx.addLine(to: CGPoint(x: bounds.width - inset, y: y.rounded() + 0.5))
                        ctx.strokePath()
                    }
                    index += 1
                    if index >= renderer.layout.baselines.count {
                        baseline += max(1, renderer.layout.lineSpacing)
                    }
                } while inset > 0 && baseline + setup.size.descent < bounds.height
                ctx.setLineDash(phase: 0, lengths: [])
            }
            renderer.drawGuide(in: ctx, colour: UIColor(Tokens.Colour.guideText))
        }
    }
}
