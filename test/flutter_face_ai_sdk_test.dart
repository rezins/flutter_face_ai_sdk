import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_face_ai_sdk/flutter_face_ai_sdk.dart';
import 'package:flutter_face_ai_sdk/flutter_face_ai_sdk_platform_interface.dart';
import 'package:flutter_face_ai_sdk/flutter_face_ai_sdk_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterFaceAiSdkPlatform
    with MockPlatformInterfaceMixin
    implements FlutterFaceAiSdkPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterFaceAiSdkPlatform initialPlatform = FlutterFaceAiSdkPlatform.instance;

  test('$MethodChannelFlutterFaceAiSdk is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterFaceAiSdk>());
  });

  test('getPlatformVersion', () async {
    FlutterFaceAiSdk flutterFaceAiSdkPlugin = FlutterFaceAiSdk();
    MockFlutterFaceAiSdkPlatform fakePlatform = MockFlutterFaceAiSdkPlatform();
    FlutterFaceAiSdkPlatform.instance = fakePlatform;

    expect(await flutterFaceAiSdkPlugin.getPlatformVersion(), '42');
  });
}
