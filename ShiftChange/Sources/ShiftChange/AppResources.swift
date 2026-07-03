import Foundation

/// Resolves the SwiftPM resource bundle in every context the app runs in.
///
/// Do NOT use `Bundle.module` directly from app code. SwiftPM's generated
/// accessor for executable targets only checks two places: the .app bundle
/// ROOT (`Bundle.main.bundleURL`) and a baked-in absolute path into the
/// build machine's `.build` directory. It never looks in Contents/Resources,
/// where create-dmg.sh places the bundle — so `Bundle.module` fatalErrors at
/// launch in the packaged app on any machine but the one that built it.
/// That was the v1.0.0–v1.2.0 launch crash, masked on dev machines by the
/// baked-in fallback path.
enum AppResources {
    static let bundle: Bundle = {
        let name = "ShiftChange_ShiftChange.bundle"

        // Packaged .app: Contents/Resources. Dev build (`swift build` and
        // running the bare binary): the directory containing the executable.
        // Bundle.main.resourceURL covers both.
        if let url = Bundle.main.resourceURL?.appendingPathComponent(name),
           let bundle = Bundle(url: url) {
            return bundle
        }

        // Last resort (e.g. unusual test runners). May trap if the bundle is
        // truly absent — same behavior as before this helper existed.
        return Bundle.module
    }()
}
