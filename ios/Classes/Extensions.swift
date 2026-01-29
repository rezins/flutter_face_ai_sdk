import SwiftUI

// Color Extension for theme
extension Color {
    static var faceMain: Color {
        return Color(red: 11 / 255.0, green: 77 / 255.0, blue: 70 / 255.0)
    }
}

// MARK: - Localization Helper
public class FaceSDKLocalization {

    public static let shared = FaceSDKLocalization()

    private var cachedBundle: Bundle?

    private init() {}

    /// Get localized string for Face Tips Code
    public func localizedTip(for code: Int) -> String {
        let key = "Face_Tips_Code_\(code)"
        let defaultValue = "Tips Code=\(code)"
        return localizedString(key, defaultValue: defaultValue)
    }

    /// Get localized string for a given key
    public func localizedString(_ key: String, defaultValue: String = "") -> String {
        let bundle = getLocalizedBundle()
        let fallbackValue = defaultValue.isEmpty ? key : defaultValue
        return NSLocalizedString(key, tableName: nil, bundle: bundle, value: fallbackValue, comment: "")
    }

    /// Get the appropriate localized bundle based on device language
    private func getLocalizedBundle() -> Bundle {
        if let cached = cachedBundle {
            return cached
        }

        // Get preferred language
        let preferredLanguage = getPreferredLanguageCode()

        // Try to find the localized bundle
        if let bundle = findLocalizedBundle(for: preferredLanguage) {
            cachedBundle = bundle
            return bundle
        }

        // Fallback to Indonesian (default)
        if let bundle = findLocalizedBundle(for: "id") {
            cachedBundle = bundle
            return bundle
        }

        // Last resort: main bundle
        cachedBundle = Bundle.main
        return Bundle.main
    }

    /// Get the preferred language code (id, en, zh-Hans, etc.)
    /// Default: Indonesian (id)
    private func getPreferredLanguageCode() -> String {
        // Default to Indonesian
        return "id"
    }

    /// Find localized bundle for a specific language
    private func findLocalizedBundle(for languageCode: String) -> Bundle? {
        let frameworkBundle = Bundle(for: FaceSDKLocalization.self)

        // Try Flutter plugin bundle path
        if let resourceBundlePath = frameworkBundle.path(forResource: "flutter_face_ai_sdk", ofType: "bundle"),
           let resourceBundle = Bundle(path: resourceBundlePath),
           let lprojPath = resourceBundle.path(forResource: languageCode, ofType: "lproj"),
           let lprojBundle = Bundle(path: lprojPath) {
            return lprojBundle
        }

        // Try direct path in framework bundle
        if let lprojPath = frameworkBundle.path(forResource: languageCode, ofType: "lproj"),
           let lprojBundle = Bundle(path: lprojPath) {
            return lprojBundle
        }

        // Try main bundle
        if let lprojPath = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let lprojBundle = Bundle(path: lprojPath) {
            return lprojBundle
        }

        return nil
    }

    /// Clear cached bundle (call when language changes)
    public func clearCache() {
        cachedBundle = nil
    }
}
