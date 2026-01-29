import SwiftUI
import UIKit
import FaceAISDK_Core

@objcMembers
public class FaceSDKSwiftManager: NSObject {

    // Debug flag - set to true to enable trace logging
    public static var enableDebugTrace: Bool = true

    // Track SDK initialization state
    private static var isSDKInitialized = false

    // Run debug trace once
    private static var hasRunDebugTrace = false

    /// Initialize the FaceAISDK - must be called before any SDK operations
    public static func initializeSDK() {
        guard !isSDKInitialized else {
            print("[FaceAISDK] SDK already initialized")
            return
        }

        print("[FaceAISDK] Initializing FaceAISDK_Core...")

        // Call the SDK's initialization method to set up model decryption
        FaceAISDK.initSDK()

        isSDKInitialized = true
        print("[FaceAISDK] SDK initialized successfully")
    }

    private static func ensureSDKInitialized() {
        if !isSDKInitialized {
            initializeSDK()
        }
    }

    private static func runDebugTraceIfNeeded() {
        guard enableDebugTrace, !hasRunDebugTrace else { return }
        hasRunDebugTrace = true

        print("\n")
        print("╔══════════════════════════════════════════════════════════════╗")
        print("║           FaceAISDK Debug Trace Starting                      ║")
        print("╚══════════════════════════════════════════════════════════════╝")

        FaceAISDKDebugHelper.shared.setupExceptionHandler()
        FaceAISDKDebugHelper.shared.traceMemoryInfo()
        FaceAISDKDebugHelper.shared.traceModelLoading()

        print("\n")
    }

    // Get and validate face feature (sync)
    public static func getFaceFeature(_ faceID: String) -> String {
        guard let faceFeature = UserDefaults.standard.string(forKey: faceID) else {
            print("[FaceAISDK] getFaceFeature: No data found for \(faceID)")
            return ""
        }

        if faceFeature.count != 1024 {
            print("[FaceAISDK] getFaceFeature: Invalid Length! Current: \(faceFeature.count), Expected: 1024")
            return ""
        }

        print("[FaceAISDK] getFaceFeature: OK (Length 1024)")
        return faceFeature
    }

    // Check if face feature exists for faceID
    public static func isFaceFeatureExist(_ faceID: String,
                                          _ callback: @escaping (NSNumber) -> Void) {
        guard let faceFeature = UserDefaults.standard.string(forKey: faceID),
              faceFeature.count == 1024 else {
            print("[FaceAISDK] isFaceFeatureExist: No or Invalid Length!")
            callback(0)
            return
        }
        print("[FaceAISDK] FaceFeature (Length 1024): OK")
        callback(1)
    }

    // Insert face feature to storage
    public static func insertFaceFeature(_ faceID: String,
                                         _ faceFeature: String,
                                         _ callback: @escaping (NSNumber) -> Void) {
        guard !faceFeature.isEmpty, faceFeature.count == 1024 else {
            print("[FaceAISDK] insertFaceFeature: Invalid feature (Length: \(faceFeature.count))")
            callback(0)
            return
        }
        UserDefaults.standard.set(faceFeature, forKey: faceID)
        callback(1)
    }


    // MARK: - 1:1 Face Verification
    /// Callback returns: (resultCode, capturedImagePath?)
    /// - resultCode 0 = cancelled (return nil to Flutter)
    /// - resultCode 1 or 10 = success (return image path to Flutter)
    /// - resultCode 4 = timeout (return "Timeout" to Flutter)
    /// - others = not verified (return "Not Verify" to Flutter)
    public static func showFaceVerify(_ faceFeature: String,
                                          _ threshold: NSNumber,
                                          _ livenessType: NSNumber,
                                          _ motionLivenessTypes: String,
                                          _ motionLivenessTimeOut : NSNumber,
                                          _ motionLivenessSteps : NSNumber,
                                          _ callback: @escaping (NSNumber, String?) -> Void) {

        // Ensure SDK is initialized before any operation
        ensureSDKInitialized()

        // Run debug trace before any SDK operation
        runDebugTraceIfNeeded()

        print("[FaceAISDK] showFaceVerify called with faceFeature length: \(faceFeature.count), threshold: \(threshold)")

        DispatchQueue.main.async {
            guard let topVC = getTopViewController() else {
                print("[FaceAISDK] ERROR: Could not get top view controller!")
                return
            }

            print("[FaceAISDK] Got top view controller: \(type(of: topVC))")

            ScreenBrightnessHelper.shared.maximizeBrightness()

                var hostingController: UIHostingController<VerifyFaceView>? = nil

                var sdkView = VerifyFaceView(
                    faceFeature: faceFeature,
                    threshold: threshold.floatValue,
                    livenessType: livenessType.intValue,
                    motionLiveness: motionLivenessTypes,
                    motionLivenessTimeOut: motionLivenessTimeOut.intValue,
                    motionLivenessSteps: motionLivenessSteps.intValue,
                    onDismiss: { (resultCode: Int, capturedImagePath: String?) in
                        DispatchQueue.main.async {
                            ScreenBrightnessHelper.shared.restoreBrightness()

                            hostingController?.dismiss(animated: true) {
                                callback(NSNumber(value: resultCode), capturedImagePath)
                            }
                        }
                    }
                )

                sdkView.autoControlBrightness = false

                hostingController = UIHostingController(rootView: sdkView)
                hostingController?.modalPresentationStyle = .fullScreen
                topVC.present(hostingController!, animated: true)
            }
        }

    // MARK: - Liveness Detection Only
    public static func showLivenessVerify(_ livenessType: NSNumber,
                                          _ motionLivenessTypes: String,
                                          _ motionLivenessTimeOut : NSNumber,
                                          _ motionLivenessSteps : NSNumber,
                                          _ callback: @escaping (NSNumber) -> Void) {

        // Ensure SDK is initialized before any operation
        ensureSDKInitialized()

        // Run debug trace before any SDK operation
        runDebugTraceIfNeeded()

        print("[FaceAISDK] showLivenessVerify called with livenessType: \(livenessType)")

        DispatchQueue.main.async {
            guard let topVC = getTopViewController() else {
                print("[FaceAISDK] ERROR: Could not get top view controller!")
                return
            }

            print("[FaceAISDK] Got top view controller: \(type(of: topVC))")

            ScreenBrightnessHelper.shared.maximizeBrightness()

            var hostingController: UIHostingController<LivenessDetectView>? = nil

            var sdkView = LivenessDetectView(
                livenessType: livenessType.intValue,
                motionLiveness: motionLivenessTypes,
                motionLivenessTimeOut: motionLivenessTimeOut.intValue,
                motionLivenessSteps: motionLivenessSteps.intValue,
                onDismiss: { (resultCode: Int) in
                    DispatchQueue.main.async {
                        ScreenBrightnessHelper.shared.restoreBrightness()
                        hostingController?.dismiss(animated: true) {
                            callback(NSNumber(value: resultCode))
                        }
                    }
                }
            )

            sdkView.autoControlBrightness = false

            hostingController = UIHostingController(rootView: sdkView)
            hostingController?.modalPresentationStyle = .fullScreen
            topVC.present(hostingController!, animated: true)
        }
    }

    // MARK: - Face Enrollment by Camera
    public static func showAddFaceByCamera(_ faceID: String,
                                           _ mode: NSNumber,
                                           _ showConfirm: Bool,
                                           _ callback: @escaping (NSNumber) -> Void) {

        // Ensure SDK is initialized before any operation
        ensureSDKInitialized()

        // Run debug trace before any SDK operation
        runDebugTraceIfNeeded()

        print("[FaceAISDK] showAddFaceByCamera called with faceID: \(faceID)")

        DispatchQueue.main.async {
            guard let topVC = getTopViewController() else {
                print("[FaceAISDK] ERROR: Could not get top view controller!")
                return
            }

            print("[FaceAISDK] Got top view controller: \(type(of: topVC))")

            ScreenBrightnessHelper.shared.maximizeBrightness()

            var hostingController: UIHostingController<AddFaceByCamera>? = nil

            var sdkView = AddFaceByCamera(
                faceID: faceID,
                onDismiss: { (resultCode: Int) in
                    DispatchQueue.main.async {
                        ScreenBrightnessHelper.shared.restoreBrightness()

                        hostingController?.dismiss(animated: true) {
                            callback(NSNumber(value: resultCode))
                        }
                    }
                }
            )

            sdkView.autoControlBrightness = false

            hostingController = UIHostingController(rootView: sdkView)
            hostingController?.modalPresentationStyle = .fullScreen
            topVC.present(hostingController!, animated: true)
        }
    }

    // MARK: - Helper Methods
    private static func getTopViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .filter { $0.isKeyWindow }.first
            ?? UIApplication.shared.keyWindow

        guard let rootVC = keyWindow?.rootViewController else { return nil }
        var topController = rootVC
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }
        return topController
    }
}
