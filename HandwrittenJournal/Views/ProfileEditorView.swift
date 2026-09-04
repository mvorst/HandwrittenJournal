import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation

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
    @State private var photoStage: PhotoStage?
    @State private var showCameraDenied = false
    /// The full-resolution photo behind the current avatar, kept so "Adjust" can
    /// re-frame the original instead of re-cropping an already-cropped 512 px JPEG.
    @State private var sourceImage: UIImage?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (!usePIN || pin.count == 4)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // The photo carries its own two controls: tap it to re-frame,
                    // and the X to take it off. Everything else stays a button.
                    ZStack(alignment: .topTrailing) {
                        AvatarView(image: avatar, initial: name.isEmpty ? nil : String(name.prefix(1)).uppercased(),
                                   diameter: Tokens.Layout.editorAvatar,
                                   isAddTile: avatar == nil && name.isEmpty)
                            .contentShape(Circle())
                            .onTapGesture { adjust() }
                            .accessibilityAddTraits(avatar == nil ? [] : .isButton)
                            .accessibilityHint(avatar == nil ? Text(verbatim: "") : Text("Move and zoom the photo"))

                        if avatar != nil {
                            Button {
                                avatar = nil
                                sourceImage = nil
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(Tokens.Colour.textOnAction)
                                    .frame(width: Tokens.Target.minimum, height: Tokens.Target.minimum)
                                    .background(Tokens.Colour.danger, in: Circle())
                                    // Against a dark photo the badge needs its own
                                    // edge to stay legible.
                                    .overlay(Circle().strokeBorder(Tokens.Colour.paper, lineWidth: 3))
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityLabel("Remove photo")
                        }
                    }
                    .frame(width: Tokens.Layout.editorAvatar, height: Tokens.Layout.editorAvatar)
                    .padding(.top, Tokens.Space.s6)

                    HStack(spacing: Tokens.Space.s4) {
                        if CameraPicker.isAvailable {
                            SecondaryButton(title: "Take Photo", systemImage: "camera", minWidth: 216) {
                                requestCamera()
                            }
                        }
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            HStack(spacing: Tokens.Space.s3) {
                                Image(systemName: "photo.on.rectangle").font(.system(size: 22))
                                Text("Choose Photo").font(.hjButtonSm)
                            }
                            .foregroundStyle(Tokens.Colour.action)
                            .frame(minWidth: 216, minHeight: 56)
                            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.button)
                                .stroke(Tokens.Colour.action, lineWidth: Tokens.Stroke.emphasis))
                        }
                    }
                    .padding(.top, Tokens.Space.s5)

                    if avatar != nil {
                        Text("Tap the photo to move or zoom it")
                            .font(.hjCaption)
                            .foregroundStyle(Tokens.Colour.textSecondary)
                            .padding(.top, Tokens.Space.s2)
                    }

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
                        Text("Trace writing keeps the guide beneath each stroke.")
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
        .fullScreenCover(item: $photoStage) { stage in
            switch stage {
            case .camera:
                CameraPicker { image in
                    // Straight into framing — swapping the stage keeps one
                    // presentation alive rather than dismissing and re-presenting.
                    photoStage = .crop(image)
                } onFinish: {
                    if case .camera = photoStage { photoStage = nil }
                }
                .ignoresSafeArea()
            case .crop(let image):
                AvatarCropView(image: image) { data in
                    avatar = data
                    sourceImage = image
                    photoStage = nil
                } onCancel: {
                    photoStage = nil
                }
            }
        }
        .alert("Camera is turned off", isPresented: $showCameraDenied) {
            if let settings = URL(string: UIApplication.openSettingsURLString) {
                Button("Open Settings") { UIApplication.shared.open(settings) }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("A grown-up can let Journal use the camera in Settings. You can still choose a photo instead.")
        }
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
    private func group<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
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

    /// The camera prompt only appears once ever, so a later "no" has to be explained
    /// rather than silently handing back a black viewfinder.
    private func requestCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            photoStage = .camera
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted { photoStage = .camera } else { showCameraDenied = true }
                }
            }
        default:
            showCameraDenied = true
        }
    }

    private func loadPhoto() async {
        guard let photoItem,
              let data = try? await photoItem.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        // Clear the selection so picking the same photo twice still opens the cropper.
        self.photoItem = nil
        photoStage = .crop(image)
    }

    /// Re-frame what is already there: the original if this session picked it,
    /// otherwise the saved avatar, which can still be panned and zoomed.
    private func adjust() {
        if let sourceImage {
            photoStage = .crop(sourceImage)
        } else if let avatar, let image = UIImage(data: avatar) {
            photoStage = .crop(image)
        }
    }

    private func save() {
        let target: UserProfile
        if let profile {
            target = profile
        } else {
            target = UserProfile()
            // v3.4 — the welcome's answer to "Should the iPad talk?" (§4.10).
            target.soundEnabled = Onboarding.shared.voiceFeedbackDefault
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

    /// One presentation, two steps. Camera and cropper share a cover so the hand-off
    /// from shutter to framing is a content swap, not a dismiss-then-present race.
    private enum PhotoStage: Identifiable {
        case camera
        case crop(UIImage)

        var id: String {
            switch self {
            case .camera: "camera"
            case .crop: "crop"
            }
        }
    }
}
