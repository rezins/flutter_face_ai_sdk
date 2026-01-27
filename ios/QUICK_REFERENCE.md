# iOS Face AI SDK - Quick Reference Card

## 🚀 Quick Setup (3 Steps)

```bash
# 1. Install dependencies
cd your_app/ios && pod install

# 2. Add to Info.plist
<key>NSCameraUsageDescription</key>
<string>We need camera for face recognition</string>

# 3. Run app
flutter run -d ios
```

## 📱 Basic Usage

### Enroll a Face
```dart
final feature = await _plugin.startEnroll('user_123');
// Returns: 1024-char string
// Store securely!
```

### Verify a Face
```dart
final result = await _plugin.startVerify(
  [storedFeature],
  livenessType: 1,    // 0=none, 1=color, 2=motion, 3=both
  threshold: 0.85,    // 0.0-1.0 match sensitivity
);
// Returns: "Verify" or "Not Verify"
```

### Liveness Only
```dart
final result = await _plugin.startLivenessDetection(
  livenessType: 2,
  motionStepSize: 2,
  motionTimeout: 9,
);
// Returns: {"status": "success"}
```

## 🎛️ Parameters

### Liveness Types
- `0` - None (face match only)
- `1` - Color flash (recommended for speed)
- `2` - Motion (head movements)
- `3` - Both (recommended for security)

### Threshold
- `0.70` - Low security, permissive
- `0.85` - **Recommended** balanced
- `0.95` - High security, strict

### Motion Settings
- `motionStepSize`: 1-5 actions
- `motionTimeout`: Seconds (recommended: 9)

## 🔧 Error Codes

```dart
try {
  // ... operation
} on PlatformException catch (e) {
  switch (e.code) {
    case 'ENROLL_CANCELLED':
    case 'VERIFY_CANCELLED':
    case 'LIVENESS_CANCELLED':
      // User pressed back
    case 'LIVENESS_FAILED':
      // Liveness check failed
    case 'LIVENESS_TIMEOUT':
      // Took too long
    case 'VERIFY_ERROR':
      // Invalid parameters
  }
}
```

## 📡 Events

```dart
EventChannel('flutter_face_ai_sdk/events')
    .receiveBroadcastStream()
    .listen((event) {
      print('${event["type"]}: ${event["status"]}');
    });
```

## 🔍 Common Issues

| Problem | Solution |
|---------|----------|
| Pod install takes forever | Normal for first time (~30 mins) |
| Camera not working | Add NSCameraUsageDescription to Info.plist |
| Build errors | Clean: `flutter clean && cd ios && pod install` |
| Image not loading | Verify Resources/Assets.xcassets exists |

## 📊 Architecture

```
Flutter
  ↓ Method Channel
FlutterFaceAiSdkPlugin
  ↓ Bridge
FaceAIBridgeViewController
  ↓ UIHostingController
Native SwiftUI Views
  ↓ FaceAISDK_Core
TensorFlow Lite
  ↓ Result
Back to Flutter
```

## 💾 Face Feature Storage

```dart
// DON'T: Plain text
SharedPreferences.setString('face', feature); // ❌

// DO: Encrypted storage
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
final storage = FlutterSecureStorage();
await storage.write(key: 'face_user123', value: feature); // ✅
```

## 🎯 Best Practices

1. **Use appropriate liveness for context**
   - Login: `livenessType: 1` (fast)
   - Payment: `livenessType: 3` (secure)

2. **Adjust threshold by use case**
   - Convenience: `0.80`
   - Standard: `0.85`
   - Banking: `0.90`

3. **Handle cancellations gracefully**
   ```dart
   } on PlatformException catch (e) {
     if (e.code.contains('CANCELLED')) {
       // Show retry option
     }
   }
   ```

4. **Test on real device**
   - Simulator cameras are poor quality
   - Test in various lighting conditions

## 📚 Full Docs

- **Setup Guide**: `ios/SETUP_GUIDE.md`
- **Technical Docs**: `ios/IMPLEMENTATION_COMPLETE.md`
- **Summary**: `IMPLEMENTATION_SUMMARY.md`

## 🆘 Support

**Issue?** Check SETUP_GUIDE.md "Common Issues" section first!

**Still stuck?** Create GitHub issue with:
- iOS version
- Error message
- Code snippet

---

**TIP**: Start with enrollment test → verify same person → verify different person → test liveness types
