# Attendance Image Capture Implementation (iOS)

## Overview
This document describes the implementation of attendance image capture feature for iOS platform.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  VerifyFaceView.swift (SwiftUI)                         │
│  - Detects verification success (similarity > threshold)│
│  - Attempts to capture frame from camera                │
│  - Stores UIImage via AttendanceImageHelper             │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  AttendanceImageHelper.swift (Helper Class)             │
│  - storeTempImage(UIImage) → UserDefaults              │
│  - retrieveAndClearTempImage() → UIImage?              │
│  - saveAttendanceImage(UIImage, faceID) → String?      │
│  - Saves with ORIGINAL resolution (no scaling/crop)    │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  FaceAIBridgeViewController.swift (Bridge)              │
│  - handleVerifyResult(code, tempFaceId)                │
│  - Retrieves temp image via AttendanceImageHelper      │
│  - Saves to file with timestamp                        │
│  - Returns image path or "Not Verify" to Flutter       │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  FlutterFaceAiSdkPlugin.swift (Plugin)                 │
│  - handleStartVerify() → Bridge                        │
│  - Returns: String (image path or "Not Verify")        │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  Flutter App (main.dart)                               │
│  - Receives image path or "Not Verify"                │
│  - Displays image using Image.file(File(imagePath))   │
└─────────────────────────────────────────────────────────┘
```

## Implementation Details

### 1. AttendanceImageHelper.swift
**Location:** `ios/Classes/Extensions/AttendanceImageHelper.swift`

**Features:**
- ✅ Save UIImage with **original resolution** (no scaling, no crop)
- ✅ JPEG format with 100% quality
- ✅ Unique filename with timestamp: `attendance_<faceID>_<timestamp>.jpg`
- ✅ Stored in: `<CacheDirectory>/FaceAI_Face/`
- ✅ Temporary storage via UserDefaults for passing between views
- ✅ Thread-safe singleton pattern

**Methods:**
```swift
// Save image to file with original resolution
func saveAttendanceImage(_ image: UIImage, faceID: String?) -> String?

// Temporary storage for passing between views
func storeTempImage(_ image: UIImage)
func retrieveAndClearTempImage() -> UIImage?
```

### 2. VerifyFaceView.swift Modifications
**Location:** `ios/Classes/SwiftUIViews/VerifyFaceView.swift`

**Changes:**
- ✅ Added `captureAttendanceImage()` method
- ✅ Captures frame when `similarity > threshold`
- ✅ Stores via `AttendanceImageHelper.storeTempImage()`

**Trigger:**
```swift
.onChange(of: viewModel.faceVerifyResult.code) { newValue in
    if viewModel.faceVerifyResult.similarity > threshold {
        captureAttendanceImage()
        // Store via AttendanceImageHelper when SDK provides image
    }
}
```

### 3. FaceAIBridgeViewController.swift Modifications
**Location:** `ios/Classes/FaceAIBridgeViewController.swift`

**Changes:**
```swift
private func handleVerifyResult(_ code: Int, tempFaceId: String) {
    if code == FaceAIResultCode.SUCCESS {
        if let capturedImage = AttendanceImageHelper.shared.retrieveAndClearTempImage() {
            if let imagePath = AttendanceImageHelper.shared.saveAttendanceImage(capturedImage, faceID: faceID) {
                completion(imagePath)  // ✅ Return image path
            }
        } else {
            completion("Verify")  // ⚠️ Fallback if no image
        }
    } else {
        completion("Not Verify")  // ❌ Failed
    }
}
```

## Return Values

| Scenario | Return Value | Type |
|----------|--------------|------|
| ✅ Verification Success + Image Captured | `/path/to/attendance_user123_1706329200000.jpg` | String (path) |
| ⚠️ Verification Success + No Image | `"Verify"` | String |
| ❌ Verification Failed | `"Not Verify"` | String |
| ❌ User Cancelled | FlutterError | Error |

## Current Limitations

### 🚧 Image Capture Requires SDK Support

**Issue:**
The FaceAISDK_Core framework (native iOS SDK) does not currently expose the captured frame/UIImage when verification completes.

**Current Status:**
- ✅ Infrastructure ready (AttendanceImageHelper, file saving, path return)
- ⚠️ Actual frame capture requires SDK modification
- 📝 Placeholder implementation with fallback to "Verify"

**Solutions:**

#### Option 1: SDK Enhancement (Recommended)
Modify `FaceAISDK_Core` to expose captured UIImage:
```swift
// In SDK's VerifyFaceModel or similar
struct FaceVerifyResult {
    let code: Int
    let similarity: Float
    let tips: String
    let capturedImage: UIImage?  // ← Add this
}
```

Then in VerifyFaceView.swift:
```swift
if let capturedImage = viewModel.faceVerifyResult.capturedImage {
    AttendanceImageHelper.shared.storeTempImage(capturedImage)
}
```

#### Option 2: AVCaptureVideoDataOutput Delegate
Implement custom video frame capture:
```swift
extension VerifyFaceView: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {
        // Capture frame when verification succeeds
        if shouldCaptureFrame {
            let image = imageFromSampleBuffer(sampleBuffer)
            AttendanceImageHelper.shared.storeTempImage(image)
        }
    }
}
```

#### Option 3: Screenshot Approach (Not Recommended)
Take screenshot of camera view region - lower quality and includes UI elements.

## File Structure

```
ios/
├── Classes/
│   ├── Extensions/
│   │   ├── AttendanceImageHelper.swift    ← NEW: Image capture & save helper
│   │   └── UIImage+Bundle.swift
│   ├── SwiftUIViews/
│   │   └── VerifyFaceView.swift          ← MODIFIED: Capture trigger
│   ├── FaceAIBridgeViewController.swift   ← MODIFIED: Return image path
│   └── FlutterFaceAiSdkPlugin.swift      ← No changes needed
└── ATTENDANCE_IMAGE_CAPTURE.md            ← This file
```

## Image Specifications

| Property | Value |
|----------|-------|
| **Resolution** | Original (no scaling) |
| **Format** | JPEG |
| **Quality** | 100% |
| **Filename** | `attendance_<faceID>_<timestamp>.jpg` |
| **Directory** | `<CacheDirectory>/FaceAI_Face/` |
| **Typical Size** | 100-500 KB (depends on camera resolution) |

## Testing

### Test Cases

1. **Success with Image:**
   - ✅ Verify face successfully
   - ✅ Check return value is file path
   - ✅ Verify file exists at path
   - ✅ Verify image has original resolution

2. **Success without Image (Current):**
   - ✅ Verify face successfully
   - ⚠️ Returns "Verify" (no image available from SDK)

3. **Failure:**
   - ❌ Face not matched
   - ✅ Returns "Not Verify"
   - ✅ No image file created

### Debug Logs

```swift
// When verification succeeds
print("✅ Verification SUCCESS - attempting to capture attendance image...")
print("📊 Similarity: 0.92 > Threshold: 0.85")

// When image is captured
print("✅ Attendance image saved: /path/to/image.jpg")
print("📏 Image size: 1920x1080 pixels")

// When no image available
print("⚠️ No captured image available from SDK")
print("ℹ️ Note: Image capture requires VerifyFaceView/SDK to store captured frame")
```

## Comparison with Android

| Feature | Android | iOS |
|---------|---------|-----|
| **Image Source** | `Bitmap` from `onVerifyMatched()` | ⚠️ Requires SDK enhancement |
| **Save Location** | `CACHE_FACE_LOG_DIR` | `<Cache>/FaceAI_Face/` |
| **Resolution** | ✅ Original (no scaling) | ✅ Original (no scaling) |
| **Format** | JPEG 100% | JPEG 100% |
| **Return Value** | Image path or "Not Verify" | Image path or "Not Verify" |
| **Status** | ✅ Fully Implemented | ⚠️ Infrastructure Ready, Needs SDK |

## Next Steps

1. **Short-term:** Use current implementation with "Verify" fallback
2. **Long-term:** Request FaceAISDK_Core to expose captured UIImage
3. **Alternative:** Implement custom AVCaptureVideoDataOutput delegate

## Flutter Usage (Same as Android)

```dart
final result = await _faceAiSdk.startVerify(
  faceFeatures,
  livenessType: _livenessType,
  motionStepSize: _motionStepSize,
  motionTimeout: _motionTimeout,
  threshold: _threshold,
);

if (result == 'Not Verify') {
  print('❌ Verification failed');
} else if (result == 'Verify') {
  print('⚠️ Verification success (no image available)');
} else {
  print('✅ Success! Image: $result');
  // Display image
  Image.file(File(result));
}
```

---

**Implementation Date:** January 27, 2026
**Platform:** iOS
**Status:** 🚧 Infrastructure Complete, Awaiting SDK Enhancement for Full Feature
