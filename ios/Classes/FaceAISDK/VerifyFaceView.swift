import SwiftUI
import FaceAISDK_Core
import AVFoundation

/**
 * 1:1 Face Verification + Liveness Detection
 * Result codes:
 *   0 = user cancelled (back button) -> return nil
 *   1 = verification success -> return captured image path
 *   4 = timeout -> return "Timeout"
 *   others = not verified -> return "Not Verify"
 */
struct VerifyFaceView: View {
    @StateObject private var viewModel: VerifyFaceModel = VerifyFaceModel()
    @StateObject private var photoCapture = PhotoCaptureHelper()
    @Environment(\.dismiss) private var dismiss
    @State private var showLightHighDialog = false
    @State private var showToast = false
    @State private var toastViewTips: String = ""

    // Timer states
    @State private var elapsedTime: Int = 0
    @State private var timerActive: Bool = false
    @State private var timer: Timer? = nil

    var autoControlBrightness: Bool = true

    // Business parameters
    let faceFeature: String
    let threshold: Float

    // 0: No liveness, 1: Motion only, 2: Motion+Color, 3: Color only
    let livenessType: Int
    // Motion liveness types: 1=Open mouth, 2=Smile, 3=Blink, 4=Shake head, 5=Nod
    let motionLiveness: String

    let motionLivenessTimeOut: Int  // seconds
    let motionLivenessSteps: Int    // number of motion actions

    // Callback: (resultCode, capturedImagePath?)
    let onDismiss: (Int, String?) -> Void

    // Adjusted timeout: add 4 seconds for color flash liveness (type 2 or 3)
    private var adjustedTimeOut: Int {
        if livenessType == 2 || livenessType == 3 {
            return motionLivenessTimeOut + 4
        }
        return motionLivenessTimeOut
    }

    // Localized tip helper - Auto detect language
    private func localizedTip(for code: Int) -> String {
        return FaceSDKLocalization.shared.localizedTip(for: code)
    }

    // Get localized result tip based on verification result code
    private func getLocalizedResultTip(code: Int, similarity: Float) -> String {
        switch code {
        case 1, 10:
            // Success
            if similarity > threshold {
                return FaceSDKLocalization.shared.localizedString("Face_Tips_Code_62", defaultValue: "Verifikasi wajah berhasil")
            } else {
                return FaceSDKLocalization.shared.localizedString("Face_Tips_Code_63", defaultValue: "Verifikasi wajah gagal")
            }
        case 3:
            return FaceSDKLocalization.shared.localizedString("Face_Tips_Code_34", defaultValue: "Deteksi liveness gerakan selesai")
        case 4:
            return FaceSDKLocalization.shared.localizedString("Face_Tips_Code_35", defaultValue: "Deteksi liveness gerakan waktu habis")
        case 5:
            return FaceSDKLocalization.shared.localizedString("Face_Tips_Code_38", defaultValue: "Tidak ada wajah beberapa kali")
        case 7:
            return FaceSDKLocalization.shared.localizedString("Face_Tips_Code_51", defaultValue: "Deteksi kilat warna berhasil")
        case 8:
            return FaceSDKLocalization.shared.localizedString("Face_Tips_Code_52", defaultValue: "Deteksi kilat warna gagal")
        case 9:
            return FaceSDKLocalization.shared.localizedString("Face_Tips_Code_53", defaultValue: "Terlalu terang")
        default:
            return FaceSDKLocalization.shared.localizedString("Face_Tips_Code_63", defaultValue: "Verifikasi wajah gagal")
        }
    }

    /// Capture and save the face image (async - captures photo then saves)
    private func captureAndSaveImage(completion: @escaping (String?) -> Void) {
        photoCapture.capturePhoto { [self] image in
            if let capturedImage = image {
                print("[FaceAISDK] Photo captured, saving...")
                let path = saveImageToDocuments(capturedImage)
                completion(path)
            } else {
                print("[FaceAISDK] No captured image available")
                completion(nil)
            }
        }
    }

    /// Setup photo capture on the session
    private func setupPhotoCaptureIfNeeded() {
        guard let session = viewModel.captureSession as? AVCaptureSession else {
            print("[FaceAISDK] Could not get capture session for photo capture")
            return
        }
        photoCapture.setupPhotoOutput(session: session)
    }

    // MARK: - Timer Computed Properties

    /// Remaining time in seconds
    private var remainingTime: Int {
        max(0, adjustedTimeOut - elapsedTime)
    }

    /// Timer progress (0.0 to 1.0)
    private var timerProgress: CGFloat {
        guard adjustedTimeOut > 0 else { return 1.0 }
        return CGFloat(remainingTime) / CGFloat(adjustedTimeOut)
    }

    /// Timer color based on remaining time
    private var timerColor: Color {
        let percentage = Double(remainingTime) / Double(adjustedTimeOut)
        if percentage > 0.5 {
            return Color.green
        } else if percentage > 0.25 {
            return Color.orange
        } else {
            return Color.red
        }
    }

    /// Start the countdown timer
    private func startTimer() {
        guard !timerActive else { return }
        timerActive = true
        elapsedTime = 0

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if elapsedTime < adjustedTimeOut {
                elapsedTime += 1
            }
        }
        print("[FaceAISDK] Timer started - Total time: \(adjustedTimeOut)s (livenessType: \(livenessType))")
    }

    /// Stop the countdown timer
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerActive = false
        print("[FaceAISDK] Timer stopped at \(elapsedTime)s")
    }

    /// Save UIImage to documents directory and return the path
    private func saveImageToDocuments(_ image: UIImage) -> String? {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[FaceAISDK] Could not access documents directory")
            return nil
        }

        // Create FaceAISDK subdirectory
        let faceSDKDirectory = documentsDirectory.appendingPathComponent("FaceAISDK")
        if !fileManager.fileExists(atPath: faceSDKDirectory.path) {
            do {
                try fileManager.createDirectory(at: faceSDKDirectory, withIntermediateDirectories: true)
            } catch {
                print("[FaceAISDK] Failed to create directory: \(error)")
                return nil
            }
        }

        // Generate unique filename with timestamp
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let filename = "verify_\(timestamp).jpg"
        let fileURL = faceSDKDirectory.appendingPathComponent(filename)

        // Save as JPEG with high quality (no scaling)
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            print("[FaceAISDK] Failed to convert image to JPEG")
            return nil
        }

        do {
            try imageData.write(to: fileURL)
            print("[FaceAISDK] Image saved to: \(fileURL.path)")
            return fileURL.path
        } catch {
            print("[FaceAISDK] Failed to save image: \(error)")
            return nil
        }
    }

    var body: some View {
        ZStack {
            VStack {
                 HStack {
                    Button(action: {
                        onDismiss(0, nil) // 0 = user cancelled, return nil
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(10)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 2)
                .padding(.top, 10)

                 Text(localizedTip(for: viewModel.sdkInterfaceTips.code))
                    .font(.system(size: 20).bold())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .foregroundColor(.white)
                    .background(Color.faceMain)
                    .cornerRadius(20)

                Text(localizedTip(for: viewModel.sdkInterfaceTipsExtra.code))
                    .font(.system(size: 19).bold())
                    .padding(.bottom, 6)
                    .frame(minHeight: 30)
                    .foregroundColor(.black)

                // Camera with timer ring
                ZStack {
                    // Timer progress ring (background) - thinner
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                        .frame(width: FaceCameraSize + 16, height: FaceCameraSize + 16)

                    // Timer progress ring (foreground - countdown)
                    TimerProgressRing(progress: timerProgress, color: timerColor)
                        .frame(width: FaceCameraSize + 16, height: FaceCameraSize + 16)

                    // Camera view
                    FaceAICameraView(session: viewModel.captureSession, cameraSize: FaceCameraSize)
                        .frame(
                            width: FaceCameraSize,
                            height: FaceCameraSize
                        )
                        .aspectRatio(1.0, contentMode: .fit)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.gray, lineWidth: 1))

                    // Timer countdown text at bottom of circle
                    VStack {
                        Spacer()
                        TimerBadge(remainingTime: remainingTime, color: timerColor)
                            .offset(y: 10)
                    }
                    .frame(width: FaceCameraSize, height: FaceCameraSize)
                }
                .padding(.vertical, 8)

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(viewModel.colorFlash.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .navigationBarHidden(true)
            if showToast {
                let similarity = String(format: "%.2f", viewModel.faceVerifyResult.similarity)
                // Use localized tips instead of SDK's Chinese tips
                let resultCode = viewModel.faceVerifyResult.code
                let localizedResultTip = getLocalizedResultTip(code: resultCode, similarity: viewModel.faceVerifyResult.similarity)
                let displayTips = toastViewTips.isEmpty ? localizedResultTip : toastViewTips
                let displayMessage = (toastViewTips.isEmpty && resultCode != 1 && resultCode != 10) ? displayTips : "\(displayTips) \(similarity)"

                let isSuccess = viewModel.faceVerifyResult.similarity > threshold && toastViewTips.isEmpty
                let toastStyle: ToastStyle = isSuccess ? .success : .failure

                VStack {
                    Spacer()
                    CustomToastView(
                        message: displayMessage,
                        style: toastStyle
                    )
                    .padding(.bottom, 77)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }

            // Light too high dialog
            if showLightHighDialog {
                ZStack {
                    VStack(spacing: 22) {
                        Text(FaceSDKLocalization.shared.localizedString("Face_Tips_Code_53", defaultValue: "Deteksi gagal: Terlalu terang. Hindari cahaya langsung dan gunakan di lingkungan dalam ruangan dengan pencahayaan lembut"))
                            .font(.system(size: 16).bold())
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                            .padding(.horizontal, 25)


                        if let uiImage = UIImage(named: "light_too_high") {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 120)
                                        .padding(.horizontal, 1)}

                        Button(action: {
                            withAnimation {
                                showLightHighDialog = false
                                onDismiss(viewModel.faceVerifyResult.code, nil) // Light too high = Not Verify
                                dismiss()
                            }
                        }) {
                            Text(FaceSDKLocalization.shared.localizedString("Confirm", defaultValue: "Confirm"))
                                .font(.system(size: 18).bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.faceMain)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 30)
                    }
                    .padding(.vertical, 22)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 30)
                }
                .zIndex(2)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
         .onAppear {
             if autoControlBrightness {
                 ScreenBrightnessHelper.shared.maximizeBrightness()
             }

             withAnimation(.easeInOut(duration: 0.3)) {
                UIScreen.main.brightness = 1.0
            }

            // Validate face feature
            guard !faceFeature.isEmpty, faceFeature.count == 1024 else {
                toastViewTips = FaceSDKLocalization.shared.localizedString("No Face Feature", defaultValue: "No Face Feature")
                showToast = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showToast = false
                    onDismiss(6, nil) // VerifyResultCode.NO_FACE_FEATURE = Not Verify
                    dismiss()
                }
                return
            }

            // Use faceFeature directly
            viewModel.initFaceAISDK(
                faceIDFeature: faceFeature,
                threshold: threshold,
                livenessType: livenessType,
                onlyLiveness: false,
                motionLiveness: motionLiveness,
                motionLivenessTimeOut: motionLivenessTimeOut,
                motionLivenessSteps: motionLivenessSteps
            )

            // Start countdown timer
            startTimer()

            // Setup photo capture after SDK initialization (with delay)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                setupPhotoCaptureIfNeeded()
            }
        }
        .onChange(of: viewModel.faceVerifyResult.code) { newValue in
            toastViewTips = ""

            // Stop timer when we get a result
            stopTimer()

            if newValue == VerifyResultCode.COLOR_LIVENESS_LIGHT_TOO_HIGH {
                withAnimation {
                    showLightHighDialog = true
                }
            } else {
                showToast = true
                print("[FaceAISDK] Verify result: \(viewModel.faceVerifyResult)")

                // Determine result based on code
                let resultCode = viewModel.faceVerifyResult.code
                let isSuccess = (resultCode == 1 || resultCode == 10) &&
                                viewModel.faceVerifyResult.similarity > threshold

                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation {
                        showToast = false
                    }

                    // Handle different result cases:
                    // - Success (code 1 or 10 with similarity > threshold): capture image and return path
                    // - Timeout (code 4): return nil with code 4
                    // - Others: return nil with code
                    if isSuccess {
                        // Capture photo first, then dismiss with path
                        captureAndSaveImage { capturedImagePath in
                            print("[FaceAISDK] Verification SUCCESS - Image path: \(capturedImagePath ?? "nil")")
                            onDismiss(resultCode, capturedImagePath)
                            dismiss()
                        }
                    } else {
                        print("[FaceAISDK] Verification FAILED - Code: \(resultCode)")
                        onDismiss(resultCode, nil)
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            // Stop timer
            stopTimer()

            if autoControlBrightness {
                ScreenBrightnessHelper.shared.restoreBrightness()
            }

            viewModel.stopFaceVerify()
        }
    }
}

// MARK: - Timer UI Components

/// Separate view for timer progress ring with smooth animation
struct TimerProgressRing: View {
    let progress: CGFloat
    let color: Color

    // Darker color variants (700 shade equivalent)
    private var darkColor: Color {
        switch color {
        case Color.green:
            return Color(red: 21/255, green: 128/255, blue: 61/255) // green-700
        case Color.orange:
            return Color(red: 194/255, green: 65/255, blue: 12/255) // orange-700
        case Color.red:
            return Color(red: 185/255, green: 28/255, blue: 28/255) // red-700
        default:
            return color
        }
    }

    var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(
                darkColor,
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .animation(.linear(duration: 1), value: progress)
    }
}

/// Separate view for timer badge
struct TimerBadge: View {
    let remainingTime: Int
    let color: Color

    // Darker color variants (700 shade equivalent)
    private var darkColor: Color {
        switch color {
        case Color.green:
            return Color(red: 21/255, green: 128/255, blue: 61/255) // green-700
        case Color.orange:
            return Color(red: 194/255, green: 65/255, blue: 12/255) // orange-700
        case Color.red:
            return Color(red: 185/255, green: 28/255, blue: 28/255) // red-700
        default:
            return color
        }
    }

    var body: some View {
        Text("\(remainingTime)")
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .background(darkColor)
            .clipShape(Circle())
    }
}

// MARK: - Photo Capture Helper
/// Helper class to capture ONE photo when verification succeeds using AVCapturePhotoOutput
class PhotoCaptureHelper: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var capturedImage: UIImage?
    @Published var isCapturing: Bool = false

    private var photoOutput: AVCapturePhotoOutput?
    private var isSetup = false
    private var captureCompletion: ((UIImage?) -> Void)?

    /// Setup photo output on the session
    func setupPhotoOutput(session: AVCaptureSession) {
        guard !isSetup else {
            print("[PhotoCaptureHelper] Already setup")
            return
        }

        let newPhotoOutput = AVCapturePhotoOutput()

        session.beginConfiguration()

        if session.canAddOutput(newPhotoOutput) {
            session.addOutput(newPhotoOutput)
            self.photoOutput = newPhotoOutput
            self.isSetup = true
            print("[PhotoCaptureHelper] Added photo output successfully")
        } else {
            print("[PhotoCaptureHelper] Could not add photo output")
        }

        session.commitConfiguration()
    }

    /// Capture a single photo (called only when verification succeeds)
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        guard let photoOutput = photoOutput, !isCapturing else {
            print("[PhotoCaptureHelper] Photo output not ready or already capturing")
            completion(nil)
            return
        }

        isCapturing = true
        captureCompletion = completion

        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
        print("[PhotoCaptureHelper] Capturing photo...")
    }

    // MARK: - AVCapturePhotoCaptureDelegate

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        isCapturing = false

        if let error = error {
            print("[PhotoCaptureHelper] Capture error: \(error.localizedDescription)")
            captureCompletion?(nil)
            captureCompletion = nil
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("[PhotoCaptureHelper] Could not create image from photo")
            captureCompletion?(nil)
            captureCompletion = nil
            return
        }

        print("[PhotoCaptureHelper] Photo captured successfully")
        capturedImage = image
        captureCompletion?(image)
        captureCompletion = nil
    }

    /// Cleanup
    func cleanup(session: AVCaptureSession?) {
        guard let session = session, let output = photoOutput else { return }

        session.beginConfiguration()
        session.removeOutput(output)
        session.commitConfiguration()

        self.photoOutput = nil
        self.isSetup = false
        print("[PhotoCaptureHelper] Removed photo output")
    }
}
