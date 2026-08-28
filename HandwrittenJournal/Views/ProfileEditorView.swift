import SwiftUI
import SwiftData
import PhotosUI

/// Frames 5 and 6. Starting level is gone; font, size and mode take its place.
struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let profile: UserProfile?
    let isNew: Bool

    @State private var name = ""
    @State private var usePIN = false
    @State private var pin = ""
    @State private var setup = WritingSetup.default
    @State private var avatar: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var showDeleteConfirm = false
    @State private var showFontPicker = false
    @State private var showSizePicker = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (!usePIN || pin.count == 4)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    AvatarView(image: avatar, initial: name.isEmpty ? nil : String(name.prefix(1)).uppercased(),
                               diameter: 160, isAddTile: avatar == nil && name.isEmpty)
                        .padding(.top, Tokens.Space.s6)

                    HStack(spacing: Tokens.Space.s4) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            HStack(spacing: Tokens.Space.s3) {
                                Image(systemName: "photo.on.rectangle").font(.system(size: 22))
                                Text("Choose Photo").font(.hjButtonSm)
                            }
                            .foregroundStyle(Tokens.Colour.action)
                            .frame(minWidth: 238, minHeight: 56)
                            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.button)
                                .stroke(Tokens.Colour.action, lineWidth: Tokens.Stroke.emphasis))
                        }
                        if avatar != nil {
                            SecondaryButton(title: "Remove", minWidth: 160, destructive: true) { avatar = nil }
                        }
                    }
                    .padding(.top, Tokens.Space.s5)

                    group("NAME") {
                        TextField("Type a name", text: $name)
                            .font(.hjBody)
                            .textInputAutocapitalization(.words)
                            .padding(Tokens.Space.s4)
                            .frame(height: 64)
                            .sunkCard(radius: Tokens.Radius.button)
                        Text("1–20 characters").font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, Tokens.Space.s1)
                    }

                    group("SECRET PIN") {
                        Toggle(isOn: $usePIN) {
                            Text("Use a 4-digit PIN").font(.hjBody).foregroundStyle(Tokens.Colour.textPrimary)
                        }
                        .tint(Tokens.Colour.action)
                        .frame(minHeight: 44)

                        if usePIN {
                            TextField("Four digits", text: $pin)
                                .font(.hjBody)
                                .keyboardType(.numberPad)
                                .onChange(of: pin) { pin = String(pin.filter(\.isNumber).prefix(4)) }
                                .padding(Tokens.Space.s4)
                                .frame(height: 64)
                                .sunkCard(radius: Tokens.Radius.button)
                        }
                        Text("A PIN keeps a sibling out — it is not security.")
                            .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, Tokens.Space.s1)
                    }

                    group("WRITING") {
                        Button { showFontPicker = true } label: {
                            SettingRow(title: "Font") {
                                HStack(spacing: Tokens.Space.s2) {
                                    Text(setup.face.label).font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                                    Image(systemName: "chevron.right").foregroundStyle(Tokens.Colour.textSecondary)
                                }
                            }
                        }
                        Button { showSizePicker = true } label: {
                            SettingRow(title: "Font size") {
                                HStack(spacing: Tokens.Space.s2) {
                                    Text(setup.size.label).font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                                    Image(systemName: "chevron.right").foregroundStyle(Tokens.Colour.textSecondary)
                                }
                            }
                        }
                        SettingRow(title: "Mode") {
                            Text("Trace").font(.hjBody).foregroundStyle(Tokens.Colour.textSecondary)
                        }
                        Text("Copy mode — writing on a line under the words — is coming later.")
                            .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, Tokens.Space.s2)
                    }

                    if !isNew {
                        SecondaryButton(title: "Delete Profile", systemImage: "trash", minWidth: 300, destructive: true) {
                            showDeleteConfirm = true
                        }
                        .padding(.top, Tokens.Space.s8)
                        Text("Grown-ups only · this cannot be undone")
                            .font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                            .padding(.top, Tokens.Space.s2)
                    }
                }
                .padding(.horizontal, Tokens.Layout.screenMargin)
                .padding(.bottom, Tokens.Space.s8)
            }
            .background(Tokens.Colour.paper)
            .navigationTitle(isNew ? "New Profile" : "Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave).fontWeight(.semibold)
                }
            }
        }
        .task { load() }
        .onChange(of: photoItem) { Task { await loadPhoto() } }
        .sheet(isPresented: $showFontPicker) { FontPickerView(setup: $setup).presentationDetents([.large]) }
        .sheet(isPresented: $showSizePicker) { SizePickerView(setup: $setup).presentationDetents([.large]) }
        .confirmationDialog("Delete this profile?",
                            isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) { deleteProfile() }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Every sentence, every tracing and every recording will be gone. This cannot be undone.")
        }
    }

    @ViewBuilder
    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text(title).font(.hjCaption).foregroundStyle(Tokens.Colour.textSecondary)
                .padding(.top, Tokens.Space.s7)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func load() {
        guard let profile else { return }
        name = profile.name
        usePIN = profile.hasPIN
        setup = profile.setup
        avatar = profile.avatarImageData
    }

    private func loadPhoto() async {
        guard let photoItem,
              let data = try? await photoItem.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        avatar = Self.squareJPEG(image)
    }

    /// Centre-cropped to 512 × 512, JPEG q0.8 — roughly 40 KB (§4.2).
    static func squareJPEG(_ image: UIImage, side: CGFloat = 512) -> Data? {
        let shortest = min(image.size.width, image.size.height)
        let crop = CGRect(x: (image.size.width - shortest) / 2,
                          y: (image.size.height - shortest) / 2,
                          width: shortest, height: shortest)
        guard let cg = image.cgImage?.cropping(to: crop) else { return image.jpegData(compressionQuality: 0.8) }
        let square = UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { _ in
            square.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }.jpegData(compressionQuality: 0.8)
    }

    private func save() {
        let target: UserProfile
        if let profile {
            target = profile
        } else {
            target = UserProfile()
            context.insert(target)
        }
        target.name = String(name.trimmingCharacters(in: .whitespaces).prefix(20))
        target.setup = setup
        target.avatarImageData = avatar
        if usePIN, pin.count == 4 { target.setPIN(pin) }
        if !usePIN { target.clearPIN() }
        dismiss()
    }

    private func deleteProfile() {
        guard let profile else { return }
        context.delete(profile)
        dismiss()
    }
}
