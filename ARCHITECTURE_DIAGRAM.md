# iOS Face AI SDK - Architecture Diagram

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Flutter Application                      │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  FlutterFaceAiSdk Dart Class                          │     │
│  │  • startEnroll(faceId, format)                        │     │
│  │  • startVerify(features, liveness, threshold)         │     │
│  │  • startLivenessDetection(type, steps, timeout)       │     │
│  └────────────────────────────────────────────────────────┘     │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           │ MethodChannel('flutter_face_ai_sdk')
                           │ EventChannel('flutter_face_ai_sdk/events')
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                    iOS Platform Layer                            │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  FlutterFaceAiSdkPlugin.swift                         │     │
│  │  ┌─────────────────────────────────────────────┐      │     │
│  │  │ handle(_ call: FlutterMethodCall)           │      │     │
│  │  │ • initializeSDK    → No-op                  │      │     │
│  │  │ • startEnroll      → handleStartEnroll()    │      │     │
│  │  │ • startVerify      → handleStartVerify()    │      │     │
│  │  │ • startLiveness... → handleStartLiveness()  │      │     │
│  │  │ • getPlatformVer   → Return iOS version     │      │     │
│  │  └─────────────────────────────────────────────┘      │     │
│  │                                                         │     │
│  │  FlutterStreamHandler                                  │     │
│  │  • onListen()  → Set eventSink                        │     │
│  │  • onCancel()  → Clear eventSink                      │     │
│  │  • sendEvent() → Emit to Flutter                      │     │
│  └────────────────────────────────────────────────────────┘     │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           │ DispatchQueue.main.async { }
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                      Bridge Layer                                │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  FaceAIBridgeViewController.swift                     │     │
│  │                                                         │     │
│  │  presentEnrollView(faceId, format, result)            │     │
│  │  ┌────────────────────────────────────────┐           │     │
│  │  │ 1. Store FlutterResult callback        │           │     │
│  │  │ 2. Create AddFaceByCamera view         │           │     │
│  │  │ 3. Wrap in UIHostingController         │           │     │
│  │  │ 4. Present modally full-screen         │           │     │
│  │  │ 5. Wait for onDismiss callback         │           │     │
│  │  │ 6. Retrieve face feature from UD       │           │     │
│  │  │ 7. Call result() with feature          │           │     │
│  │  │ 8. Cleanup & dismiss                   │           │     │
│  │  └────────────────────────────────────────┘           │     │
│  │                                                         │     │
│  │  presentVerifyView(params, result)                    │     │
│  │  ┌────────────────────────────────────────┐           │     │
│  │  │ 1. Store FlutterResult callback        │           │     │
│  │  │ 2. Use first feature (iOS 1:1)         │           │     │
│  │  │ 3. Store temp feature in UD            │           │     │
│  │  │ 4. Convert motion params to string     │           │     │
│  │  │ 5. Create VerifyFaceView               │           │     │
│  │  │ 6. Wrap in UIHostingController         │           │     │
│  │  │ 7. Present modally full-screen         │           │     │
│  │  │ 8. Wait for onDismiss callback         │           │     │
│  │  │ 9. Map result code to "Verify"/"Not"   │           │     │
│  │  │ 10. Call result() with string          │           │     │
│  │  │ 11. Cleanup temp UD & dismiss          │           │     │
│  │  └────────────────────────────────────────┘           │     │
│  │                                                         │     │
│  │  presentLivenessView(params, result)                  │     │
│  │  └─> Similar flow to verification                     │     │
│  │                                                         │     │
│  │  Helper Methods:                                       │     │
│  │  • convertToMotionLivenessString()                    │     │
│  │  • getRootViewController()                            │     │
│  │  • presentSwiftUIView()                               │     │
│  │  • dismissHostingController()                         │     │
│  └────────────────────────────────────────────────────────┘     │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           │ UIHostingController<AnyView>
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                   Native SwiftUI Views                           │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  AddFaceByCamera.swift                                │     │
│  │  ┌───────────────────────────────────────────────┐    │     │
│  │  │ • Shows camera preview                        │    │     │
│  │  │ • Face detection guidance overlay             │    │     │
│  │  │ • Auto-capture when positioned correctly      │    │     │
│  │  │ • Stores feature in UserDefaults[faceID]      │    │     │
│  │  │ • Calls onDismiss(1) on success               │    │     │
│  │  │ • Calls onDismiss(0) on cancel                │    │     │
│  │  └───────────────────────────────────────────────┘    │     │
│  └────────────────────────────────────────────────────────┘     │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  VerifyFaceView.swift                                 │     │
│  │  ┌───────────────────────────────────────────────┐    │     │
│  │  │ • Shows camera preview with face oval         │    │     │
│  │  │ • Liveness detection (color/motion)           │    │     │
│  │  │ • Retrieves stored feature from UD[faceID]    │    │     │
│  │  │ • Compares live face with stored feature      │    │     │
│  │  │ • Calls onDismiss(1) on match                 │    │     │
│  │  │ • Calls onDismiss(6) on no match              │    │     │
│  │  │ • Calls onDismiss(0) on cancel                │    │     │
│  │  │ • Calls onDismiss(53) on light too high       │    │     │
│  │  └───────────────────────────────────────────────┘    │     │
│  └────────────────────────────────────────────────────────┘     │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  LivenessDetectView.swift                             │     │
│  │  ┌───────────────────────────────────────────────┐    │     │
│  │  │ • Shows camera preview                        │    │     │
│  │  │ • Color flash liveness detection              │    │     │
│  │  │ • Motion instruction (smile, blink, nod...)   │    │     │
│  │  │ • Timeout handling                            │    │     │
│  │  │ • Calls onDismiss(1) on success               │    │     │
│  │  │ • Calls onDismiss(60) on timeout              │    │     │
│  │  └───────────────────────────────────────────────┘    │     │
│  └────────────────────────────────────────────────────────┘     │
│                                                                  │
│  Supporting Views:                                               │
│  • CustomToastView.swift        → Toast notifications           │
│  • ScreenBrightnessHelper.swift → Auto brightness control       │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           │ import FaceAISDK_Core
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                  FaceAISDK_Core Framework                        │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  Native iOS SDK (from GitHub)                         │     │
│  │  • Face detection                                      │     │
│  │  • Face feature extraction (1024-char string)         │     │
│  │  • Face comparison                                     │     │
│  │  • Liveness detection (color flash, motion)           │     │
│  │  • TensorFlow Lite models                             │     │
│  └────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

### Enrollment Flow

```
1. Flutter calls startEnroll('user_123')
         ↓
2. FlutterFaceAiSdkPlugin.handleStartEnroll()
         ↓
3. DispatchQueue.main.async { }
         ↓
4. FaceAIBridgeViewController.presentEnrollView()
         ↓
5. Create AddFaceByCamera(faceID: "user_123", onDismiss: { code in ... })
         ↓
6. Wrap in UIHostingController(rootView: AnyView(enrollView))
         ↓
7. Present modally: rootVC.present(hostingVC, animated: true)
         ↓
8. User sees camera UI, positions face, captures
         ↓
9. FaceAISDK_Core extracts feature → UserDefaults["user_123"] = "1024chars..."
         ↓
10. AddFaceByCamera calls onDismiss(1) ← SUCCESS
         ↓
11. FaceAIBridgeViewController.handleEnrollResult(1, "user_123")
         ↓
12. Retrieve: UserDefaults.string(forKey: "user_123")
         ↓
13. Cleanup: UserDefaults.removeObject(forKey: "user_123")
         ↓
14. Dismiss: hostingController?.dismiss(animated: true)
         ↓
15. Call result("1024char_feature_string...")
         ↓
16. Send event: eventSink?({type: "enrollment", status: "success"})
         ↓
17. Flutter receives feature string ← SUCCESS
```

### Verification Flow

```
1. Flutter calls startVerify([feature1, feature2], liveness: 1, threshold: 0.85)
         ↓
2. FlutterFaceAiSdkPlugin.handleStartVerify()
         ↓
3. Create VerifyParams(faceFeatures: [feature1, feature2], ...)
         ↓
4. DispatchQueue.main.async { }
         ↓
5. FaceAIBridgeViewController.presentVerifyView(params)
         ↓
6. Use first feature: primaryFeature = params.faceFeatures[0]
         ↓
7. Create temp key: tempFaceId = "temp_verify_UUID"
         ↓
8. Store temp: UserDefaults[tempFaceId] = primaryFeature
         ↓
9. Convert motion: "1,3" ← convertToMotionLivenessString(2)
         ↓
10. Create VerifyFaceView(faceID: tempFaceId, threshold: 0.85, ...)
         ↓
11. Wrap in UIHostingController
         ↓
12. Present modally
         ↓
13. User sees camera UI
         ↓
14. Color flash liveness detection (if type=1)
         ↓
15. FaceAISDK_Core retrieves: UserDefaults[tempFaceId]
         ↓
16. Captures live face, extracts feature
         ↓
17. Compares: live_feature vs stored_feature (threshold: 0.85)
         ↓
18. VerifyFaceView calls onDismiss(1) ← MATCH or onDismiss(6) ← NO MATCH
         ↓
19. FaceAIBridgeViewController.handleVerifyResult(code, tempFaceId)
         ↓
20. Cleanup: UserDefaults.removeObject(forKey: tempFaceId)
         ↓
21. Map code: 1 → "Verify", 6 → "Not Verify"
         ↓
22. Dismiss: hostingController?.dismiss(animated: true)
         ↓
23. Call result("Verify") or result("Not Verify")
         ↓
24. Send event: eventSink?({type: "verification", status: "success", result: "Verify"})
         ↓
25. Flutter receives "Verify" or "Not Verify" ← SUCCESS
```

## Memory Management

```
FlutterFaceAiSdkPlugin (strong)
  ↓ (strong ref)
FaceAIBridgeViewController (strong)
  ↓ (strong ref)
UIHostingController<AnyView> (strong)
  ↓ (strong ref)
AddFaceByCamera/VerifyFaceView (strong)
  ↓ (closure with weak self)
onDismiss: { [weak self] code in
    self?.handleResult(code)  ← Prevents retain cycle
}
```

**Key Points:**
- All closures use `[weak self]` to prevent retain cycles
- `defer` blocks ensure cleanup even on error
- `completionHandler = nil` clears strong reference after use
- `hostingController?.dismiss()` releases view hierarchy

## Threading Model

```
┌──────────────────────────────────────────────────────────┐
│  Flutter Thread (Platform Channel Message Handler)       │
│  • Can be any thread                                      │
│  • Must NOT perform UI operations directly               │
└────────────────┬─────────────────────────────────────────┘
                 │
                 │ DispatchQueue.main.async { }
                 │
┌────────────────▼─────────────────────────────────────────┐
│  Main Thread (UI Thread)                                  │
│  • Present/dismiss UIHostingController                    │
│  • Show camera preview                                    │
│  • Update SwiftUI views                                   │
│  • All FaceAISDK_Core UI operations                      │
└────────────────┬─────────────────────────────────────────┘
                 │
                 │ Completion callback
                 │
┌────────────────▼─────────────────────────────────────────┐
│  Any Thread (FlutterResult Callback)                      │
│  • result() can be called from any thread                │
│  • Flutter handles thread marshalling                    │
│  • eventSink?() dispatched to main (safe)                │
└──────────────────────────────────────────────────────────┘
```

## Resource Loading

```
Flutter Plugin Bundle
  ↓
s.resource_bundles = {'flutter_face_ai_sdk' => ['Resources/**/*']}
  ↓
Bundle(identifier: "com.example.flutter_face_ai_sdk")
  ↓
UIImage.fromPluginBundle(named: "light_too_high")
  ↓
Search Order:
  1. Bundle(identifier: "...")
  2. Bundle.allBundles (fallback)
  3. Bundle.main (testing)
  ↓
UIImage(named: "light_too_high", in: bundle, compatibleWith: nil)
  ↓
Returns UIImage or nil
```

## Error Handling Flow

```
Error Occurs in Native Code
         ↓
Check Error Type:
  • User cancelled? → FlutterError("ENROLL_CANCELLED", ...)
  • Liveness failed? → FlutterError("LIVENESS_FAILED", ...)
  • Invalid params? → FlutterError("INVALID_ARGS", ...)
  • Unknown? → FlutterError("UNKNOWN_ERROR", ...)
         ↓
defer {
    // Cleanup ALWAYS runs
    UserDefaults.removeObject(forKey: ...)
    hostingController?.dismiss(...)
    completionHandler = nil
}
         ↓
result(FlutterError(...))
         ↓
Flutter receives PlatformException
         ↓
User Code Handles Error:
try {
    await _plugin.startEnroll(...)
} on PlatformException catch (e) {
    if (e.code == 'ENROLL_CANCELLED') { ... }
}
```

## File Dependencies

```
flutter_face_ai_sdk.podspec
  ├─ Depends on: FaceAISDK_Core (Git, tag: 2026.01.04)
  ├─ Requires: SwiftUI, AVFoundation, Photos
  └─ Source files: Classes/**/*

FlutterFaceAiSdkPlugin.swift
  ├─ Imports: Flutter, UIKit
  └─ References: FaceAIBridgeViewController

FaceAIBridgeViewController.swift
  ├─ Imports: UIKit, SwiftUI, Flutter
  ├─ References: FaceAIResultCodes
  └─ Uses: AddFaceByCamera, VerifyFaceView, LivenessDetectView

SwiftUIViews/*.swift
  ├─ Imports: SwiftUI, FaceAISDK_Core
  └─ Uses: UIImage.fromPluginBundle(named:)

UIImage+Bundle.swift
  ├─ Imports: UIKit
  └─ Extends: UIImage

FaceAIResultCodes.swift
  ├─ Imports: Foundation
  └─ Defines: Constants only
```

---

**This architecture follows the UIHostingController Bridge Pattern:**
- ✅ Clean separation of concerns
- ✅ Native UI/UX preserved
- ✅ Type-safe completion handlers
- ✅ Proper memory management
- ✅ Thread-safe operations
- ✅ Comprehensive error handling
