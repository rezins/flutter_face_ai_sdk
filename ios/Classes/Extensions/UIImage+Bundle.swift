import UIKit

extension UIImage {
    /// Load image from plugin bundle
    /// - Parameter name: Image name in Assets.xcassets
    /// - Returns: UIImage if found, nil otherwise
    static func fromPluginBundle(named name: String) -> UIImage? {
        // Try to get the plugin bundle
        let bundleIdentifier = "com.example.flutter_face_ai_sdk"

        // Method 1: Try direct bundle lookup
        if let bundle = Bundle(identifier: bundleIdentifier),
           let image = UIImage(named: name, in: bundle, compatibleWith: nil) {
            return image
        }

        // Method 2: Try to find bundle in all bundles
        for bundle in Bundle.allBundles {
            if let image = UIImage(named: name, in: bundle, compatibleWith: nil) {
                return image
            }
        }

        // Method 3: Fallback to main bundle (for testing)
        return UIImage(named: name)
    }
}
