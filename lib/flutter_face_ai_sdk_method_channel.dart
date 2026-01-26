import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_face_ai_sdk_platform_interface.dart';

/// An implementation of [FlutterFaceAiSdkPlatform] that uses method channels.
class MethodChannelFlutterFaceAiSdk extends FlutterFaceAiSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_face_ai_sdk');

  /// The event channel for receiving face recognition events
  @visibleForTesting
  final eventChannel = const EventChannel('flutter_face_ai_sdk/events');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<String> initializeSDK(Map<String, dynamic> config) async {
    final result = await methodChannel.invokeMethod<String>(
      'initializeSDK',
      {'config': config},
    );
    return result ?? 'Failed to initialize';
  }

  @override
  Future<Map<String, dynamic>> detectFace(String imagePath) async {
    final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
      'detectFace',
      {'imagePath': imagePath},
    );
    return Map<String, dynamic>.from(result ?? {});
  }

  @override
  Future<Map<String, dynamic>> addFace(String imagePath) async {
    final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
      'addFace',
      {'imagePath': imagePath},
    );
    return Map<String, dynamic>.from(result ?? {});
  }

  @override
  Future<String?> startEnroll(String faceId, String format) async {
    final result = await methodChannel.invokeMethod<String>(
      'startEnroll',
      {
        'faceId': faceId,
        'format': format,
      },
    );
    return result;
  }

  @override
  Future<String?> startVerify(List<String> faceFeatures, {
    int livenessType = 1,
    int motionStepSize = 2,
    int motionTimeout = 9,
    double threshold = 0.85,
  }) async {
    final result = await methodChannel.invokeMethod<String>(
      'startVerify',
      {
        'face_features': faceFeatures,
        'liveness_type': livenessType,
        'motion_step_size': motionStepSize,
        'motion_timeout': motionTimeout,
        'threshold': threshold,
      },
    );
    return result;
  }

  @override
  Future<void> startLivenessDetection({
    int livenessType = 1,
    int motionStepSize = 2,
    int motionTimeout = 9,
  }) async {
    await methodChannel.invokeMethod<void>(
      'startLivenessDetection',
      {
        'liveness_type': livenessType,
        'motion_step_size': motionStepSize,
        'motion_timeout': motionTimeout,
      },
    );
  }

  @override
  Stream<Map<String, dynamic>> getFaceEventStream() {
    return eventChannel.receiveBroadcastStream().map((event) {
      return Map<String, dynamic>.from(event as Map);
    });
  }
}
