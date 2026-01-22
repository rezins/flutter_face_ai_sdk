import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_face_ai_sdk_platform_interface.dart';

/// An implementation of [FlutterFaceAiSdkPlatform] that uses method channels.
class MethodChannelFlutterFaceAiSdk extends FlutterFaceAiSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_face_ai_sdk');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
