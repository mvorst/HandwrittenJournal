import SwiftUI
import SwiftData

struct WelcomeView: View {
    @ObservedObject var navigationState: NavigationState
    @Environment(\.modelContext) private var modelContext
    @State private var name: String = ""
    @FocusState private var isNameFieldFocused: Bool

    private var canProceed: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Text("Welcome to TraceRight!")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(AppConstants.primaryAction)

            Text("What's your first name?")
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)

            TextField("Your name", text: $name)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                )
                .frame(maxWidth: 400)
                .focused($isNameFieldFocused)
                .onChange(of: name) { _, newValue in
                    if newValue.count > AppConstants.maxNameLength {
                        name = String(newValue.prefix(AppConstants.maxNameLength))
                    }
                }
                .onSubmit {
                    if canProceed { proceed() }
                }

            Button(action: proceed) {
                Text("Let's Go!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 220, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(canProceed ? AppConstants.primaryAction : Color.gray.opacity(0.4))
                    )
            }
            .disabled(!canProceed)

            Spacer()
        }
        .padding()
        .appBackground()
        .onAppear {
            isNameFieldFocused = true
        }
    }

    private func proceed() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let player = PlayerProgress(firstName: trimmed)
        modelContext.insert(player)

        // GameState will be loaded via ContentView on re-render
        navigationState.currentScreen = .dashboard
    }
}
