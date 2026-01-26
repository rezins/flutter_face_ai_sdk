
import 'flutter_face_ai_sdk_platform_interface.dart';

class FlutterFaceAiSdk {
  Future<String?> getPlatformVersion() {
    return FlutterFaceAiSdkPlatform.instance.getPlatformVersion();
  }

  /// Initialize Face AI SDK with configuration
  Future<String> initializeSDK(Map<String, dynamic> config) {
    return FlutterFaceAiSdkPlatform.instance.initializeSDK(config);
  }

  /// Detect face from image path
  Future<Map<String, dynamic>> detectFace(String imagePath) {
    return FlutterFaceAiSdkPlatform.instance.detectFace(imagePath);
  }

  /// Add face from image path
  Future<Map<String, dynamic>> addFace(String imagePath) {
    return FlutterFaceAiSdkPlatform.instance.addFace(imagePath);
  }

  /// Start face enrollment process
  /// [faceId] - Unique identifier for the face (e.g., "user123")
  /// [format] - Format for face data (e.g., "base64")
  /// Returns face feature string
  Future<String?> startEnroll(String faceId, {String format = 'base64'}) {
    return FlutterFaceAiSdkPlatform.instance.startEnroll(faceId, format);
  }

  /// Start face verification process with liveness detection
  /// [faceData] - Face ID to verify against
  /// [livenessType] - 0: NONE, 1: MOTION (default), 2: COLOR_FLASH_MOTION, 3: COLOR_FLASH
  /// [motionStepSize] - Number of motion steps (default: 2)
  /// [motionTimeout] - Timeout in seconds (default: 9)
  /// [threshold] - Similarity threshold (default: 0.85)
  Future<void> startVerify(
    String faceData, {
    int livenessType = 1,
    int motionStepSize = 2,
    int motionTimeout = 9,
    double threshold = 0.85,
  }) {
    return FlutterFaceAiSdkPlatform.instance.startVerify(
      faceData,
      livenessType: livenessType,
      motionStepSize: motionStepSize,
      motionTimeout: motionTimeout,
      threshold: threshold,
    );
  }

  /// Start liveness detection only (no face verification)
  /// [livenessType] - 0: NONE, 1: MOTION (default), 2: COLOR_FLASH_MOTION, 3: COLOR_FLASH
  /// [motionStepSize] - Number of motion steps (default: 2)
  /// [motionTimeout] - Timeout in seconds (default: 9)
  Future<void> startLivenessDetection({
    int livenessType = 1,
    int motionStepSize = 2,
    int motionTimeout = 9,
  }) {
    return FlutterFaceAiSdkPlatform.instance.startLivenessDetection(
      livenessType: livenessType,
      motionStepSize: motionStepSize,
      motionTimeout: motionTimeout,
    );
  }

  /// Stream of face recognition events
  /// Returns events like Enrolled, Verified with results
  Stream<Map<String, dynamic>> getFaceEventStream() {
    return FlutterFaceAiSdkPlatform.instance.getFaceEventStream();
  }
}
