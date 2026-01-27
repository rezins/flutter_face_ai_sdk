# iOS Setup Guide - Flutter Face AI SDK

## Quick Start

### 1. Install Dependencies

```bash
cd your_flutter_app/ios
pod install
```

**Note**: First-time installation downloads TensorFlowLite (~200MB, 20-30 mins). Be patient!

### 2. Add Camera Permissions

Edit `ios/Runner/Info.plist`:

```xml
<dict>
    <!-- Existing keys... -->

    <!-- Face AI SDK Permissions -->
    <key>NSCameraUsageDescription</key>
    <string>We need camera access for face recognition and verification</string>

    <key>NSPhotoLibraryUsageDescription</key>
    <string>We need photo library access for face enrollment from images</string>
</dict>
```

### 3. Update iOS Deployment Target

The plugin requires iOS 15.0+. Update in Xcode or edit `ios/Podfile`:

```ruby
platform :ios, '15.0'
```

### 4. Run Your App

```bash
flutter run -d ios
```

## Usage Examples

### Initialize SDK

```dart
import 'package:flutter_face_ai_sdk/flutter_face_ai_sdk.dart';

final _plugin = FlutterFaceAiSdk();

// iOS doesn't require explicit initialization
await _plugin.initializeSDK();
```

### Enroll a Face

```dart
try {
  final faceFeature = await _plugin.startEnroll(
    'user_123',
    format: 'base64',
  );

  print('Enrollment successful!');
  print('Feature length: ${faceFeature.length}'); // 1024 chars

  // Store faceFeature securely (e.g., encrypted local storage or backend)
  await saveFaceFeature('user_123', faceFeature);

} on PlatformException catch (e) {
  if (e.code == 'ENROLL_CANCELLED') {
    print('User cancelled enrollment');
  } else {
    print('Enrollment failed: ${e.message}');
  }
}
```

### Verify a Face

```dart
try {
  // Retrieve stored face feature(s)
  final storedFeature = await loadFaceFeature('user_123');

  final result = await _plugin.startVerify(
    [storedFeature],           // List of face features to match against
    livenessType: 1,           // 0=none, 1=color, 2=motion, 3=both
    motionStepSize: 2,         // Number of motion actions (1-5)
    motionTimeout: 9,          // Timeout in seconds
    threshold: 0.85,           // Match threshold (0.0-1.0)
  );

  if (result == "Verify") {
    print('✅ Face verified successfully!');
    // Grant access
  } else {
    print('❌ Face verification failed');
    // Deny access
  }

} on PlatformException catch (e) {
  if (e.code == 'VERIFY_CANCELLED') {
    print('User cancelled verification');
  } else if (e.code == 'LIVENESS_FAILED') {
    print('Liveness check failed: ${e.message}');
  } else {
    print('Verification error: ${e.message}');
  }
}
```

### Liveness Detection Only

```dart
try {
  final result = await _plugin.startLivenessDetection(
    livenessType: 2,      // Motion liveness
    motionStepSize: 3,    // 3 random actions
    motionTimeout: 12,    // 12 seconds
  );

  print('Liveness check passed: ${result["status"]}');

} on PlatformException catch (e) {
  if (e.code == 'LIVENESS_TIMEOUT') {
    print('Liveness detection timeout');
  } else {
    print('Liveness check failed: ${e.message}');
  }
}
```

### Listen to Events

```dart
final eventStream = EventChannel('flutter_face_ai_sdk/events')
    .receiveBroadcastStream();

eventStream.listen((event) {
  final eventData = event as Map;

  switch (eventData['type']) {
    case 'enrollment':
      if (eventData['status'] == 'success') {
        print('Enrollment completed for: ${eventData["faceId"]}');
      }
      break;

    case 'verification':
      if (eventData['status'] == 'success') {
        print('Verification result: ${eventData["result"]}');
      }
      break;

    case 'liveness':
      print('Liveness check: ${eventData["status"]}');
      break;
  }
});
```

## Parameters Explained

### Liveness Types

| Value | Type | Description |
|-------|------|-------------|
| 0 | None | No liveness detection (face match only) |
| 1 | Color | Color flash-based liveness detection |
| 2 | Motion | Motion-based liveness (head movements) |
| 3 | Both | Combined color + motion liveness |

**Recommendation**: Use `livenessType: 1` for quick verification, `livenessType: 3` for high-security scenarios.

### Motion Parameters

- **motionStepSize** (1-5): Number of random motion actions user must perform
  - `1`: Single action (e.g., "Smile")
  - `2`: Two actions (e.g., "Smile" then "Blink")
  - `5`: All five actions

- **motionTimeout** (seconds): Time limit for completing all actions
  - Recommended: `9` seconds for 2 actions
  - Increase for more actions or accessibility

- **Motion Actions**: Open mouth, Smile, Blink, Shake head, Nod

### Threshold

- **threshold** (0.0-1.0): Face matching sensitivity
  - `0.70`: Low security, more permissive
  - `0.85`: **Recommended** - balanced
  - `0.95`: High security, strict matching

Higher values = fewer false positives, more false negatives.

## Common Issues

### Pod Install Fails

**Error**: "Unable to find FaceAISDK_Core"

**Solution**: Check GitHub access. May need VPN in some regions.

```bash
# Test GitHub access
curl -I https://github.com/FaceAISDK/FaceAISDK_Core.git

# Clear cache and retry
pod cache clean --all
pod install --repo-update
```

### Camera Not Working

**Error**: "Camera permission denied"

**Solution**: Add NSCameraUsageDescription to Info.plist (see step 2 above).

### Build Errors

**Error**: "Undefined symbols for architecture arm64"

**Solution**: Clean build folder:
```bash
cd ios
rm -rf Pods/ Podfile.lock
pod install
cd ..
flutter clean
flutter run
```

### Image Not Loading

**Error**: `light_too_high.png` not found

**Solution**: Resource bundle issue. Verify:
```bash
ls ios/Resources/Assets.xcassets/light_too_high.imageset/
# Should show: Contents.json, light_too_high.png
```

## Testing on Simulator

**Note**: Simulators have limited camera support. For best results:

1. Use a **real iOS device** (iPhone/iPad)
2. iOS 15.0 or later
3. Good lighting conditions
4. Front-facing camera

Simulators may show camera UI but face detection quality will be poor.

## Architecture Notes

### How It Works

1. **Flutter calls method** → Method channel
2. **iOS plugin receives call** → FlutterFaceAiSdkPlugin
3. **Bridge controller invoked** → FaceAIBridgeViewController
4. **SwiftUI view presented** → UIHostingController wraps native view
5. **User interacts** → Native camera UI (AddFaceByCamera/VerifyFaceView)
6. **Result captured** → Completion handler
7. **Bridge dismisses view** → Returns to Flutter
8. **Result sent back** → FlutterResult callback
9. **Event emitted** → Event channel (optional)

### Threading

- Flutter calls can come on **any thread**
- UI presentation requires **main thread**
- All view operations automatically dispatched to main thread
- Result callbacks work on **any thread**

### Memory Management

- Weak self references prevent retain cycles
- Hosting controllers dismissed after completion
- Temporary UserDefaults cleaned up
- No memory leaks in repeated operations

## Advanced Configuration

### Custom Threshold Per User

```dart
// VIP users: higher security
await _plugin.startVerify([vipFeature], threshold: 0.95);

// Regular users: balanced
await _plugin.startVerify([userFeature], threshold: 0.85);

// Low-security scenario: convenience
await _plugin.startVerify([feature], threshold: 0.75);
```

### Adaptive Liveness

```dart
// High-security transaction
await _plugin.startVerify(
  [feature],
  livenessType: 3,        // Both color + motion
  motionStepSize: 4,      // 4 actions
  motionTimeout: 15,      // More time
  threshold: 0.90,        // Strict matching
);

// Quick login
await _plugin.startVerify(
  [feature],
  livenessType: 1,        // Color only
  motionStepSize: 1,      // Not used
  motionTimeout: 5,       // Not used
  threshold: 0.80,        // Relaxed
);
```

### Multi-User Management

```dart
class FaceManager {
  final Map<String, String> _features = {};

  Future<void> enrollUser(String userId) async {
    final feature = await _plugin.startEnroll(userId);
    _features[userId] = feature;
    await saveToSecureStorage(userId, feature);
  }

  Future<bool> verifyUser(String userId) async {
    final feature = _features[userId] ?? await loadFromSecureStorage(userId);
    if (feature == null) return false;

    final result = await _plugin.startVerify([feature]);
    return result == "Verify";
  }

  Future<void> deleteUser(String userId) async {
    _features.remove(userId);
    await deleteFromSecureStorage(userId);
  }
}
```

## Security Best Practices

1. **Never store face features in plain text**
   - Use encrypted storage (flutter_secure_storage)
   - Or store on backend with secure transmission

2. **Validate on backend** (if possible)
   - Send face features to backend
   - Perform verification server-side
   - Prevents client-side tampering

3. **Use appropriate liveness for context**
   - Financial: `livenessType: 3`
   - Login: `livenessType: 1`
   - Low-risk: `livenessType: 0`

4. **Handle user privacy**
   - Clear camera permissions usage
   - Don't store unnecessary biometric data
   - Comply with local regulations (GDPR, CCPA, etc.)

5. **Test edge cases**
   - Poor lighting
   - Different angles
   - Glasses/masks
   - Multiple people in frame

## Support

- **Issues**: https://github.com/your-repo/flutter_face_ai_sdk/issues
- **Documentation**: See IMPLEMENTATION_COMPLETE.md
- **Native SDK**: https://github.com/FaceAISDK/FaceAISDK_Core

## Changelog

### v0.0.1 (2026-01-27)
- ✅ Initial iOS implementation
- ✅ Face enrollment support
- ✅ Face verification with liveness
- ✅ Standalone liveness detection
- ✅ Event channel streaming
- ⚠️ 1:N verification uses first feature only

---

**Ready to integrate? Start with the enrollment example above!** 🚀
