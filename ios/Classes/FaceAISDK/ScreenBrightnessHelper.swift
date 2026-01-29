import UIKit

// Screen Brightness Helper Singleton
public class ScreenBrightnessHelper {

    // Singleton instance
    public static let shared = ScreenBrightnessHelper()

    // Internal state
    private var originalBrightness: CGFloat?
    private var wasIdleTimerDisabled: Bool = false

    // Flag to prevent repeated settings
    private var isMaximized = false

    private init() {}

    // MARK: - Public API

    /// Save current brightness and maximize (thread-safe)
    public func maximizeBrightness() {
        runOnMain { [weak self] in
            guard let self = self else { return }

            // Only save original value if not already maximized
            if !self.isMaximized {
                self.originalBrightness = self.getCurrentBrightness()
                self.wasIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
                self.isMaximized = true
            }

            // Maximize brightness
            self.setBrightness(1.0)

            // Disable auto-lock
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }

    /// Restore brightness (thread-safe)
    public func restoreBrightness() {
        runOnMain { [weak self] in
            guard let self = self else { return }

            // Only restore if maximized
            guard self.isMaximized, let original = self.originalBrightness else { return }

            // Restore brightness
            self.setBrightness(original)

            // Restore auto-lock setting
            UIApplication.shared.isIdleTimerDisabled = self.wasIdleTimerDisabled

            // Reset state
            self.isMaximized = false
            self.originalBrightness = nil
        }
    }

    // MARK: - Private Methods

    /// Get current brightness (iOS 15+ compatible)
    private func getCurrentBrightness() -> CGFloat {
        if #available(iOS 15.0, *) {
            let scene = UIApplication.shared.connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .compactMap { $0 as? UIWindowScene }
                .first
            return scene?.screen.brightness ?? UIScreen.main.brightness
        } else {
            return UIScreen.main.brightness
        }
    }

    /// Set brightness (iOS 15+ compatible)
    private func setBrightness(_ value: CGFloat) {
        if #available(iOS 15.0, *) {
            if let scene = UIApplication.shared.connectedScenes
                .filter({ $0.activationState == .foregroundActive })
                .compactMap({ $0 as? UIWindowScene })
                .first {
                scene.screen.brightness = value
            } else {
                UIScreen.main.brightness = value
            }
        } else {
            UIScreen.main.brightness = value
        }
    }

    /// Helper: ensure closure runs on main thread
    private func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }
}
