import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_face_ai_sdk_method_channel.dart';

abstract class FlutterFaceAiSdkPlatform extends PlatformInterface {
  /// Constructs a FlutterFaceAiSdkPlatform.
  FlutterFaceAiSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterFaceAiSdkPlatform _instance = MethodChannelFlutterFaceAiSdk();

  /// The default instance of [FlutterFaceAiSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterFaceAiSdk].
  static FlutterFaceAiSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterFaceAiSdkPlatform] when
  /// they register themselves.
  static set instance(FlutterFaceAiSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String> initializeSDK(Map<String, dynamic> config) {
    throw UnimplementedError('initializeSDK() has not been implemented.');
  }

  Future<Map<String, dynamic>> detectFace(String imagePath) {
    throw UnimplementedError('detectFace() has not been implemented.');
  }

  Future<Map<String, dynamic>> addFace(String imagePath) {
    throw UnimplementedError('addFace() has not been implemented.');
  }

  Future<String?> startEnroll(String faceId, String format) {
    throw UnimplementedError('startEnroll() has not been implemented.');
  }

  Future<String?> startVerify(List<String> faceFeatures, {
    int livenessType = 1,
    int motionStepSize = 2,
    int motionTimeout = 9,
    double threshold = 0.85,
  }) {
    throw UnimplementedError('startVerify() has not been implemented.');
  }

  Future<void> startLivenessDetection({
    int livenessType = 1,
    int motionStepSize = 2,
    int motionTimeout = 9,
  }) {
    throw UnimplementedError('startLivenessDetection() has not been implemented.');
  }

  Stream<Map<String, dynamic>> getFaceEventStream() {
    throw UnimplementedError('getFaceEventStream() has not been implemented.');
  }
}
