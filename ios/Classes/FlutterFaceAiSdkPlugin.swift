import Flutter
import UIKit

public class FlutterFaceAiSdkPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var bridgeViewController: FaceAIBridgeViewController?
    private var eventSink: FlutterEventSink?

    // MARK: - Plugin Registration

    public static func register(with registrar: FlutterPluginRegistrar) {
        // Method channel for SDK operations
        let methodChannel = FlutterMethodChannel(
            name: "flutter_face_ai_sdk",
            binaryMessenger: registrar.messenger()
        )

        // Event channel for streaming events (enrollment, verification updates)
        let eventChannel = FlutterEventChannel(
            name: "flutter_face_ai_sdk/events",
            binaryMessenger: registrar.messenger()
        )

        let instance = FlutterFaceAiSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)

        // Initialize bridge controller
        instance.bridgeViewController = FaceAIBridgeViewController()
    }

    // MARK: - Method Channel Handler

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initializeSDK":
            handleInitializeSDK(call, result)
        case "startEnroll":
            handleStartEnroll(call, result)
        case "startVerify":
            handleStartVerify(call, result)
        case "startLivenessDetection":
            handleStartLivenessDetection(call, result)
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Initialize SDK

    private func handleInitializeSDK(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        // iOS SDK doesn't require explicit initialization
        // FaceAISDK_Core is ready to use once imported
        result("SDK Initialized")
    }

    // MARK: - Enrollment

    private func handleStartEnroll(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let faceId = args["faceId"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "faceId is required",
                details: nil
            ))
            return
        }

        // Format parameter is optional and reserved for future use
        let format = args["format"] as? String ?? "base64"

        // Must present on main thread
        DispatchQueue.main.async { [weak self] in
            guard let bridge = self?.bridgeViewController else {
                result(FlutterError(
                    code: "BRIDGE_ERROR",
                    message: "Bridge controller not initialized",
                    details: nil
                ))
                return
            }

            bridge.presentEnrollView(faceId: faceId, format: format) { [weak self] enrollResult in
                // Send event on successful enrollment
                if let featureString = enrollResult as? String {
                    self?.sendEvent([
                        "type": "enrollment",
                        "status": "success",
                        "faceId": faceId
                    ])
                }
                result(enrollResult)
            }
        }
    }

    // MARK: - Verification

    private func handleStartVerify(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let faceFeatures = args["face_features"] as? [String] else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "face_features is required",
                details: nil
            ))
            return
        }

        // Validate face features
        if faceFeatures.isEmpty {
            result(FlutterError(
                code: "VERIFY_ERROR",
                message: "faceFeatures cannot be empty",
                details: nil
            ))
            return
        }

        // Parse parameters with defaults matching Android behavior
        let livenessType = args["liveness_type"] as? Int ?? 1
        let motionStepSize = args["motion_step_size"] as? Int ?? 2
        let motionTimeout = args["motion_timeout"] as? Int ?? 9
        let threshold = Float(args["threshold"] as? Double ?? 0.85)

        let params = VerifyParams(
            faceFeatures: faceFeatures,
            livenessType: livenessType,
            motionStepSize: motionStepSize,
            motionTimeout: motionTimeout,
            threshold: threshold
        )

        // Must present on main thread
        DispatchQueue.main.async { [weak self] in
            guard let bridge = self?.bridgeViewController else {
                result(FlutterError(
                    code: "BRIDGE_ERROR",
                    message: "Bridge controller not initialized",
                    details: nil
                ))
                return
            }

            bridge.presentVerifyView(params: params) { [weak self] verifyResult in
                // Send event on successful verification
                if let resultString = verifyResult as? String, resultString == "Verify" {
                    self?.sendEvent([
                        "type": "verification",
                        "status": "success",
                        "result": resultString
                    ])
                } else if let resultString = verifyResult as? String {
                    self?.sendEvent([
                        "type": "verification",
                        "status": "failed",
                        "result": resultString
                    ])
                }
                result(verifyResult)
            }
        }
    }

    // MARK: - Liveness Detection

    private func handleStartLivenessDetection(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "arguments required",
                details: nil
            ))
            return
        }

        // Parse parameters with defaults
        let livenessType = args["liveness_type"] as? Int ?? 1
        let motionStepSize = args["motion_step_size"] as? Int ?? 2
        let motionTimeout = args["motion_timeout"] as? Int ?? 9

        let params = LivenessParams(
            livenessType: livenessType,
            motionStepSize: motionStepSize,
            motionTimeout: motionTimeout
        )

        // Must present on main thread
        DispatchQueue.main.async { [weak self] in
            guard let bridge = self?.bridgeViewController else {
                result(FlutterError(
                    code: "BRIDGE_ERROR",
                    message: "Bridge controller not initialized",
                    details: nil
                ))
                return
            }

            bridge.presentLivenessView(params: params) { [weak self] livenessResult in
                // Send event on liveness detection completion
                if let resultDict = livenessResult as? [String: Any] {
                    self?.sendEvent([
                        "type": "liveness",
                        "status": resultDict["status"] as? String ?? "unknown"
                    ])
                }
                result(livenessResult)
            }
        }
    }

    // MARK: - FlutterStreamHandler

    public func onListen(withArguments arguments: Any?,
                        eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    /// Send event to Flutter event stream
    private func sendEvent(_ data: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(data)
        }
    }
}
