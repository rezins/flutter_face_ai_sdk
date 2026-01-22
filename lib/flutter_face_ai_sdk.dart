
import 'flutter_face_ai_sdk_platform_interface.dart';

class FlutterFaceAiSdk {
  Future<String?> getPlatformVersion() {
    return FlutterFaceAiSdkPlatform.instance.getPlatformVersion();
  }
}
