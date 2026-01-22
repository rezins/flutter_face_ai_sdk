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
}
