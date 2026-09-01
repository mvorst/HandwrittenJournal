import SwiftUI
import UIKit

/// The system camera, wrapped for SwiftUI. UIImagePickerController is the shortest
/// path to a single still capture — AVFoundation would mean building the shutter,
/// the preview and the retake screen by hand.
///
/// Present it full screen; the picker owns the whole surface.
struct CameraPicker: UIViewControllerRepresentable {
    /// The captured photo. Not called when the child backs out.
    let onCapture: (UIImage) -> Void
    /// Always called once the picker is done, captured or cancelled.
    let onFinish: () -> Void

    /// False in the simulator and on any iPad without a usable camera.
    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        // A profile photo is nearly always a self-portrait.
        picker.cameraDevice = UIImagePickerController.isCameraDeviceAvailable(.front) ? .front : .rear
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onCapture(image) }
            parent.onFinish()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onFinish()
        }
    }
}
