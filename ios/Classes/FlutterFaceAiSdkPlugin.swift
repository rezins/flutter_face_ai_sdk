import Flutter
import UIKit

public class FlutterFaceAiSdkPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        // Method Channel
        let channel = FlutterMethodChannel(name: "flutter_face_ai_sdk", binaryMessenger: registrar.messenger())
        let instance = FlutterFaceAiSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Event Channel for face recognition events
        let eventChannel = FlutterEventChannel(name: "flutter_face_ai_sdk/events", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)

        // Initialize FaceAISDK_Core early to set up model decryption
        print("[FlutterFaceAiSdkPlugin] Initializing FaceAISDK_Core...")
        FaceSDKSwiftManager.initializeSDK()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)

        case "initializeSDK":
            handleInitializeSDK(call: call, result: result)

        case "detectFace":
            handleDetectFace(call: call, result: result)

        case "addFace":
            handleAddFace(call: call, result: result)

        case "startEnroll":
            handleStartEnroll(call: call, result: result)

        case "startVerify":
            handleStartVerify(call: call, result: result)

        case "startLivenessDetection":
            handleStartLivenessDetection(call: call, result: result)

        case "getFaceFeature":
            handleGetFaceFeature(call: call, result: result)

        case "insertFaceFeature":
            handleInsertFaceFeature(call: call, result: result)

        case "isFaceFeatureExist":
            handleIsFaceFeatureExist(call: call, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - FlutterStreamHandler

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    // MARK: - Method Handlers

    /// Initialize SDK with configuration
    private func handleInitializeSDK(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Initialize the FaceAISDK_Core (also called during plugin registration)
        FaceSDKSwiftManager.initializeSDK()

        // Parse optional config
        if let args = call.arguments as? [String: Any],
           let config = args["config"] as? [String: Any] {
            // Apply any configuration settings if provided
            if let enableDebug = config["enableDebug"] as? Bool {
                FaceSDKSwiftManager.enableDebugTrace = enableDebug
            }
        }

        result("SDK Initialized Successfully")
    }

    /// Detect face from image path
    private func handleDetectFace(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let imagePath = args["imagePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "imagePath is required", details: nil))
            return
        }

        // Return detection result
        let response: [String: Any] = [
            "success": true,
            "faceDetected": false,
            "imagePath": imagePath,
            "message": "Use startEnroll or startVerify for full face processing"
        ]
        result(response)
    }

    /// Add face from image path
    private func handleAddFace(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let imagePath = args["imagePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "imagePath is required", details: nil))
            return
        }

        let response: [String: Any] = [
            "success": true,
            "imagePath": imagePath,
            "message": "Use startEnroll for camera-based face enrollment"
        ]
        result(response)
    }

    /// Start face enrollment process
    /// Parameters:
    /// - faceId: Unique identifier for the face (e.g., "user123")
    /// - format: Format for face data (e.g., "base64")
    /// Returns: Face feature string (1024 chars)
    private func handleStartEnroll(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let faceId = args["faceId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "faceId is required", details: nil))
            return
        }

        let _ = args["format"] as? String ?? "base64"

        // Show camera for face enrollment
        FaceSDKSwiftManager.showAddFaceByCamera(
            faceId,
            NSNumber(value: 0),    // mode
            true,                   // showConfirm
            { [weak self] (resultCode: NSNumber) in
                DispatchQueue.main.async {
                    let code = resultCode.intValue

                    if code == 1 {
                        // Success - get the enrolled face feature
                        let faceFeature = FaceSDKSwiftManager.getFaceFeature(faceId)

                        // Send event
                        self?.sendEvent(type: "Enrolled", data: [
                            "faceId": faceId,
                            "success": true,
                            "code": code,
                            "faceFeature": faceFeature
                        ])

                        result(faceFeature.isEmpty ? nil : faceFeature)
                    } else {
                        // User cancelled or failed
                        self?.sendEvent(type: "EnrollCancelled", data: [
                            "faceId": faceId,
                            "success": false,
                            "code": code
                        ])

                        result(nil)
                    }
                }
            }
        )
    }

    /// Start face verification process with liveness detection
    /// Parameters:
    /// - face_features: List of face feature strings from database
    /// - liveness_type: 0=NONE, 1=MOTION, 2=COLOR_FLASH_MOTION, 3=COLOR_FLASH
    /// - motion_step_size: Number of motion steps (default: 2)
    /// - motion_timeout: Timeout in seconds (default: 9)
    /// - threshold: Similarity threshold (default: 0.85)
    /// Returns:
    /// - Success: captured image path (String)
    /// - Cancelled (back button): null
    /// - Timeout: "Timeout" (String)
    /// - Not verified: "Not Verify" (String)
    private func handleStartVerify(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let faceFeatures = args["face_features"] as? [String],
              !faceFeatures.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "face_features list is required and must not be empty", details: nil))
            return
        }

        let livenessType = args["liveness_type"] as? Int ?? 1
        let motionStepSize = args["motion_step_size"] as? Int ?? 2
        let motionTimeout = args["motion_timeout"] as? Int ?? 9
        let threshold = args["threshold"] as? Double ?? 0.85

        // Use first face feature for verification
        let faceFeature = faceFeatures[0]

        // Validate face feature length
        guard faceFeature.count == 1024 else {
            result(FlutterError(code: "INVALID_FEATURE", message: "Invalid face feature format (must be 1024 chars)", details: nil))
            return
        }

        // Motion liveness types: default "1,2,3" (open mouth, smile, blink)
        let motionLivenessTypes = "1,2,3,4,5"

        // Pass faceFeature directly to showFaceVerify
        FaceSDKSwiftManager.showFaceVerify(
            faceFeature,
            NSNumber(value: threshold),
            NSNumber(value: livenessType),
            motionLivenessTypes,
            NSNumber(value: motionTimeout),
            NSNumber(value: motionStepSize),
            { [weak self] (resultCode: NSNumber, capturedImagePath: String?) in
                DispatchQueue.main.async {
                    let code = resultCode.intValue

                    // Result codes:
                    // 0 = cancelled (back button) -> return nil
                    // 1 = success (verify) -> return image path
                    // 4 = motion liveness timeout -> return "Timeout"
                    // 10 = all liveness passed -> return image path
                    // others = not verified -> return "Not Verify"

                    let isVerified = (code == 1 || code == 10) && capturedImagePath != nil

                    // Determine what to return to Flutter
                    let flutterResult: Any?
                    switch code {
                    case 0:
                        // User cancelled (back button) -> return nil
                        flutterResult = nil
                        print("[FaceAISDK] Verification CANCELLED by user")

                    case 1, 10:
                        // Success -> return image path
                        flutterResult = capturedImagePath
                        print("[FaceAISDK] Verification SUCCESS - Image: \(capturedImagePath ?? "nil")")

                    case 4:
                        // Timeout -> return "Timeout"
                        flutterResult = "Timeout"
                        print("[FaceAISDK] Verification TIMEOUT")

                    default:
                        // Not verified -> return "Not Verify"
                        flutterResult = "Not Verify"
                        print("[FaceAISDK] Verification FAILED - Code: \(code)")
                    }

                    // Send event for backward compatibility
                    self?.sendEvent(type: "Verified", data: [
                        "success": isVerified,
                        "code": code,
                        "result": isVerified ? "success" : "fail",
                        "imagePath": capturedImagePath as Any
                    ])

                    result(flutterResult)
                }
            }
        )
    }

    /// Start liveness detection only (no face verification)
    /// Parameters:
    /// - liveness_type: 0=NONE, 1=MOTION, 2=COLOR_FLASH_MOTION, 3=COLOR_FLASH
    /// - motion_step_size: Number of motion steps (default: 2)
    /// - motion_timeout: Timeout in seconds (default: 9)
    private func handleStartLivenessDetection(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]

        let livenessType = args["liveness_type"] as? Int ?? 1
        let motionStepSize = args["motion_step_size"] as? Int ?? 2
        let motionTimeout = args["motion_timeout"] as? Int ?? 9

        // Motion liveness types: default "1,2,3" (open mouth, smile, blink)
        let motionLivenessTypes = "1,2,3"

        FaceSDKSwiftManager.showLivenessVerify(
            NSNumber(value: livenessType),
            motionLivenessTypes,
            NSNumber(value: motionTimeout),
            NSNumber(value: motionStepSize),
            { [weak self] (resultCode: NSNumber) in
                DispatchQueue.main.async {
                    let code = resultCode.intValue

                    // Result codes for liveness:
                    // 0 = cancelled
                    // 3 = motion liveness success
                    // 4 = motion liveness timeout
                    // 5 = face not detected multiple times
                    // 7 = color liveness success
                    // 8 = color liveness failed
                    // 9 = too bright
                    // 10 = all liveness checks passed

                    let isSuccess = code == 3 || code == 7 || code == 10

                    self?.sendEvent(type: "LivenessDetected", data: [
                        "success": isSuccess,
                        "code": code
                    ])

                    result(nil)
                }
            }
        )
    }

    /// Get stored face feature for a faceId
    private func handleGetFaceFeature(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let faceId = args["faceId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "faceId is required", details: nil))
            return
        }

        let faceFeature = FaceSDKSwiftManager.getFaceFeature(faceId)
        result(faceFeature.isEmpty ? nil : faceFeature)
    }

    /// Insert face feature for a faceId
    private func handleInsertFaceFeature(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let faceId = args["faceId"] as? String,
              let faceFeature = args["faceFeature"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "faceId and faceFeature are required", details: nil))
            return
        }

        FaceSDKSwiftManager.insertFaceFeature(faceId, faceFeature) { (insertResult: NSNumber) in
            result(insertResult.intValue == 1)
        }
    }

    /// Check if face feature exists for a faceId
    private func handleIsFaceFeatureExist(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let faceId = args["faceId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "faceId is required", details: nil))
            return
        }

        FaceSDKSwiftManager.isFaceFeatureExist(faceId) { (existResult: NSNumber) in
            result(existResult.intValue == 1)
        }
    }

    // MARK: - Helper Methods

    /// Send event to Flutter via EventChannel
    private func sendEvent(type: String, data: [String: Any]) {
        guard let eventSink = eventSink else { return }

        var eventData = data
        eventData["type"] = type

        DispatchQueue.main.async {
            eventSink(eventData)
        }
    }
}
