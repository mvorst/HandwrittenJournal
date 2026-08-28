import UIKit
import CoreText

/// Registers every font file bundled under `Resources/Fonts` at launch.
///
/// Doing this in code rather than via `UIAppFonts` means adding one of the faces listed
/// in WIREFRAME_SPEC §7.2 is a pure drag-and-drop: drop the TTF into
/// `HandwrittenJournal/Resources/Fonts`, run `xcodegen generate`, and it appears in the
/// font picker. No plist edit, no build-setting edit.
enum FontRegistry {

    private static var didRegister = false

    static func registerBundledFonts() {
        guard !didRegister else { return }
        didRegister = true

        let extensions = ["ttf", "otf", "ttc"]
        let urls = extensions.flatMap { Bundle.main.urls(forResourcesWithExtension: $0, subdirectory: nil) ?? [] }

        for url in urls {
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                // Already registered is not a failure worth shouting about.
                let code = error.map { CFErrorGetCode($0.takeUnretainedValue()) } ?? 0
                if code != CTFontManagerError.alreadyRegistered.rawValue {
                    print("[FontRegistry] could not register \(url.lastPathComponent) (\(code))")
                }
            }
        }
    }

    /// Diagnostic used by the font picker and the tests.
    static func isAvailable(_ postScriptName: String) -> Bool {
        UIFont(name: postScriptName, size: 12) != nil
    }
}
