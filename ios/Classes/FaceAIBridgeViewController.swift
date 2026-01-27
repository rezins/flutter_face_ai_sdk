import UIKit
import SwiftUI
import Flutter

/// Parameters for face verification
struct VerifyParams {
    let faceFeatures: [String]
    let livenessType: Int
    let motionStepSize: Int
    let motionTimeout: Int
    let threshold: Float
}

/// Parameters for liveness detection
struct LivenessParams {
    let livenessType: Int
    let motionStepSize: Int
    let motionTimeout: Int
}

/// Bridge controller connecting Flutter with native SwiftUI views
/// This is the KEY architectural component using UIHostingController pattern
class FaceAIBridgeViewController: UIViewController {

    private var completionHandler: FlutterResult?
    private var hostingController: UIHostingController<AnyView>?

    // MARK: - Enrollment

    /// Present face enrollment UI
    /// - Parameters:
    ///   - faceId: Unique identifier for the face to enroll
    ///   - format: Data format (currently unused, reserved for future)
    ///   - result: Flutter result callback
    func presentEnrollView(faceId: String, format: String, result: @escaping FlutterResult) {
        self.completionHandler = result

        let enrollView = AddFaceByCamera(
            faceID: faceId,
            onDismiss: { [weak self] resultCode in
                self?.handleEnrollResult(resultCode, faceId: faceId)
            },
            autoControlBrightness: true
        )

        presentSwiftUIView(enrollView)
    }

    private func handleEnrollResult(_ code: Int, faceId: String) {
        defer {
            dismissHostingController()
        }

        guard let completion = completionHandler else { return }

        if code == FaceAIResultCode.SUCCESS {
            // Enrollment successful - retrieve face feature from UserDefaults
            if let faceFeature = UserDefaults.standard.string(forKey: faceId) {
                // Clean up stored feature
                UserDefaults.standard.removeObject(forKey: faceId)
                completion(faceFeature)
            } else {
                completion(FlutterError(
                    code: "ENROLL_ERROR",
                    message: "Face feature not found after enrollment",
                    details: nil
                ))
            }
        } else if code == FaceAIResultCode.USER_CANCELLED {
            completion(FlutterError(
                code: "ENROLL_CANCELLED",
                message: "User cancelled enrollment",
                details: ["resultCode": code]
            ))
        } else {
            completion(FlutterError(
                code: "ENROLL_FAILED",
                message: "Enrollment failed with code: \(code)",
                details: ["resultCode": code]
            ))
        }

        completionHandler = nil
    }

    // MARK: - Verification

    /// Present face verification UI
    /// - Parameters:
    ///   - params: Verification parameters including face features and liveness settings
    ///   - result: Flutter result callback
    func presentVerifyView(params: VerifyParams, result: @escaping FlutterResult) {
        self.completionHandler = result

        // iOS SDK limitation: Use first feature as primary
        // TODO: Implement 1:N matching loop for multi-face verification
        let primaryFeature = params.faceFeatures[0]
        let tempFaceId = "temp_verify_\(UUID().uuidString)"

        // Store temporarily in UserDefaults (native SDK reads from here)
        UserDefaults.standard.set(primaryFeature, forKey: tempFaceId)

        // Convert motion step size to action string format
        let motionLivenessString = convertToMotionLivenessString(params.motionStepSize)

        let verifyView = VerifyFaceView(
            faceID: tempFaceId,
            threshold: params.threshold,
            livenessType: params.livenessType,
            motionLiveness: motionLivenessString,
            motionLivenessTimeOut: params.motionTimeout,
            motionLivenessSteps: params.motionStepSize,
            onDismiss: { [weak self] resultCode in
                self?.handleVerifyResult(resultCode, tempFaceId: tempFaceId)
            },
            autoControlBrightness: true
        )

        presentSwiftUIView(verifyView)
    }

    private func handleVerifyResult(_ code: Int, tempFaceId: String) {
        defer {
            // Clean up temporary feature
            UserDefaults.standard.removeObject(forKey: tempFaceId)
            dismissHostingController()
        }

        guard let completion = completionHandler else { return }

        if code == FaceAIResultCode.SUCCESS {
            // Verification successful - Try to capture and save attendance image

            // Check if there's a temporarily stored captured image
            if let capturedImage = AttendanceImageHelper.shared.retrieveAndClearTempImage() {
                // Extract faceID from tempFaceId (remove "temp_verify_" prefix)
                let faceID = tempFaceId.replacingOccurrences(of: "temp_verify_", with: "")

                // Save image with original resolution
                if let imagePath = AttendanceImageHelper.shared.saveAttendanceImage(capturedImage, faceID: faceID) {
                    print("✅ iOS Attendance image captured: \(imagePath)")
                    completion(imagePath)  // Return image path on success
                } else {
                    print("⚠️ Failed to save attendance image, returning 'Verify'")
                    completion("Verify")  // Fallback to simple "Verify" if save failed
                }
            } else {
                // No captured image available - this means SDK didn't provide image
                // For now, return "Verify" (image capture requires SDK support)
                print("⚠️ No captured image available from SDK")
                print("ℹ️ Note: Image capture requires VerifyFaceView/SDK to store captured frame")
                completion("Verify")  // Return simple "Verify" without image path
            }
        } else if code == FaceAIResultCode.USER_CANCELLED {
            completion(FlutterError(
                code: "VERIFY_CANCELLED",
                message: "User cancelled verification",
                details: ["resultCode": code]
            ))
        } else if code == FaceAIResultCode.NO_FACE_FEATURE {
            // Face not matched
            completion("Not Verify")
        } else if code == FaceAIResultCode.COLOR_LIVENESS_LIGHT_TOO_HIGH {
            completion(FlutterError(
                code: "LIVENESS_FAILED",
                message: "Liveness check failed: Light too high",
                details: ["resultCode": code]
            ))
        } else {
            // Other verification failures - return "Not Verify"
            completion("Not Verify")
        }

        completionHandler = nil
    }

    // MARK: - Liveness Detection

    /// Present liveness detection UI (without face verification)
    /// - Parameters:
    ///   - params: Liveness detection parameters
    ///   - result: Flutter result callback
    func presentLivenessView(params: LivenessParams, result: @escaping FlutterResult) {
        self.completionHandler = result

        let motionLivenessString = convertToMotionLivenessString(params.motionStepSize)

        let livenessView = LivenessDetectView(
            livenessType: params.livenessType,
            motionLiveness: motionLivenessString,
            motionLivenessTimeOut: params.motionTimeout,
            motionLivenessSteps: params.motionStepSize,
            onDismiss: { [weak self] resultCode in
                self?.handleLivenessResult(resultCode)
            },
            autoControlBrightness: true
        )

        presentSwiftUIView(livenessView)
    }

    private func handleLivenessResult(_ code: Int) {
        defer {
            dismissHostingController()
        }

        guard let completion = completionHandler else { return }

        if code == FaceAIResultCode.SUCCESS {
            completion(["status": "success", "message": "Liveness check passed"])
        } else if code == FaceAIResultCode.USER_CANCELLED {
            completion(FlutterError(
                code: "LIVENESS_CANCELLED",
                message: "User cancelled liveness detection",
                details: ["resultCode": code]
            ))
        } else if code == FaceAIResultCode.MOTION_LIVENESS_TIMEOUT {
            completion(FlutterError(
                code: "LIVENESS_TIMEOUT",
                message: "Liveness detection timeout",
                details: ["resultCode": code]
            ))
        } else {
            completion(FlutterError(
                code: "LIVENESS_FAILED",
                message: "Liveness detection failed with code: \(code)",
                details: ["resultCode": code]
            ))
        }

        completionHandler = nil
    }

    // MARK: - Helper Methods

    /// Convert motion step size to action string format
    /// Native SDK expects comma-separated action IDs (1-5)
    /// Example: stepSize=2 → "3,1" (random 2 actions)
    private func convertToMotionLivenessString(_ stepSize: Int) -> String {
        let allActions = [1, 2, 3, 4, 5]
        let selectedActions = Array(allActions.shuffled().prefix(stepSize))
        return selectedActions.map { String($0) }.joined(separator: ",")
    }

    /// Present SwiftUI view using UIHostingController
    private func presentSwiftUIView<Content: View>(_ content: Content) {
        let hostingVC = UIHostingController(rootView: AnyView(content))
        hostingVC.modalPresentationStyle = .fullScreen
        self.hostingController = hostingVC

        // Present from root view controller
        if let rootVC = getRootViewController() {
            rootVC.present(hostingVC, animated: true)
        }
    }

    /// Dismiss the hosting controller
    private func dismissHostingController() {
        hostingController?.dismiss(animated: true) { [weak self] in
            self?.hostingController = nil
        }
    }

    /// Get the root view controller from the key window
    private func getRootViewController() -> UIViewController? {
        // iOS 13+ compatible way to get root view controller
        if #available(iOS 13.0, *) {
            let keyWindow = UIApplication.shared.windows.first { $0.isKeyWindow }
            return keyWindow?.rootViewController
        } else {
            return UIApplication.shared.keyWindow?.rootViewController
        }
    }
}
