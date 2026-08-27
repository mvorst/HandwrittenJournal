import SwiftUI
import SwiftData

struct SettingsView: View {
    @Bindable var player: PlayerProgress
    @ObservedObject var gameState: GameStateViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var navigationState: NavigationState
    @State private var editingName: String = ""
    @State private var parentalGateAnswer: String = ""
    @State private var parentalGateNumbers: (Int, Int) = (0, 0)
    @State private var showResetGate: Bool = false
    @State private var showDeleteGate: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("First name", text: $editingName)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 200)
                            .onChange(of: editingName) { _, newValue in
                                if newValue.count > AppConstants.maxNameLength {
                                    editingName = String(newValue.prefix(AppConstants.maxNameLength))
                                }
                            }
                    }
                }

                Section("Preferences") {
                    Toggle("Left-handed mode", isOn: $player.isLeftHanded)
                    Toggle("Sound effects", isOn: $player.soundEnabled)
                    Toggle("Haptic feedback", isOn: $player.hapticsEnabled)
                    Toggle("Guide lines", isOn: $player.guideLinesEnabled)
                }

                Section {
                    Button(role: .destructive) {
                        prepareParentalGate()
                        showResetGate = true
                    } label: {
                        Text("Reset Progress")
                    }

                    Button(role: .destructive) {
                        prepareParentalGate()
                        showDeleteGate = true
                    } label: {
                        Text("Delete All Data")
                    }
                } footer: {
                    Text("Reset Progress clears your stars, points, and badges but keeps your name. Delete All Data removes everything and returns to the welcome screen.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            player.firstName = trimmed
                        }
                        dismiss()
                    }
                }
            }
            .alert("Parental Check", isPresented: $showResetGate) {
                TextField("Answer", text: $parentalGateAnswer)
                    .keyboardType(.numberPad)
                Button("Cancel", role: .cancel) {
                    parentalGateAnswer = ""
                }
                Button("Reset", role: .destructive) {
                    if parentalGateAnswer == "\(parentalGateNumbers.0 + parentalGateNumbers.1)" {
                        gameState.resetProgress()
                    }
                    parentalGateAnswer = ""
                }
            } message: {
                Text("What is \(parentalGateNumbers.0) + \(parentalGateNumbers.1)?\n\nThis will reset all stars, points, badges, and level progress.")
            }
            .alert("Parental Check", isPresented: $showDeleteGate) {
                TextField("Answer", text: $parentalGateAnswer)
                    .keyboardType(.numberPad)
                Button("Cancel", role: .cancel) {
                    parentalGateAnswer = ""
                }
                Button("Delete Everything", role: .destructive) {
                    if parentalGateAnswer == "\(parentalGateNumbers.0 + parentalGateNumbers.1)" {
                        deleteAllData()
                    }
                    parentalGateAnswer = ""
                }
            } message: {
                Text("What is \(parentalGateNumbers.0) + \(parentalGateNumbers.1)?\n\nThis will permanently delete all data and return to the welcome screen.")
            }
            .onAppear {
                editingName = player.firstName
            }
        }
    }

    private func prepareParentalGate() {
        parentalGateNumbers = (Int.random(in: 10...50), Int.random(in: 10...50))
    }

    private func deleteAllData() {
        // Delete all attempt records
        do {
            try modelContext.delete(model: AttemptRecord.self)
        } catch {
            // Continue even if this fails
        }

        // Delete the player
        modelContext.delete(player)
        gameState.player = nil

        dismiss()
        navigationState.currentScreen = .welcome
    }
}
