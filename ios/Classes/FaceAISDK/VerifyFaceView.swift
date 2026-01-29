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

    /// Capture and save the face image
    private func captureAndSaveImage() -> String? {
        // Use the captured image from photo helper
        if let capturedImage = photoCapture.capturedImage {
            print("[FaceAISDK] Using captured image from photo helper")
            return saveImageToDocuments(capturedImage)
        }

        print("[FaceAISDK] No captured image available")
        return nil
    }

    /// Setup photo capture on the session
    private func setupPhotoCaptureIfNeeded() {
        guard let session = viewModel.captureSession as? AVCaptureSession else {
            print("[FaceAISDK] Could not get capture session for photo capture")
            return
        }
        photoCapture.setupPhotoOutput(session: session)
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

                FaceAICameraView(session: viewModel.captureSession, cameraSize: FaceCameraSize)
                    .frame(
                        width: FaceCameraSize,
                        height: FaceCameraSize
                    )
                    .padding(.vertical, 8)
                    .aspectRatio(1.0, contentMode: .fit)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray, lineWidth: 1))

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

            // Setup photo capture after SDK initialization (with delay)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                setupPhotoCaptureIfNeeded()
            }
        }
        .onChange(of: viewModel.faceVerifyResult.code) { newValue in
            toastViewTips = ""

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
                    var capturedImagePath: String? = nil
                    if isSuccess {
                        // Try to save the captured image
                        capturedImagePath = captureAndSaveImage()
                        print("[FaceAISDK] Verification SUCCESS - Image path: \(capturedImagePath ?? "nil")")
                    } else {
                        print("[FaceAISDK] Verification FAILED - Code: \(resultCode)")
                    }

                    onDismiss(resultCode, capturedImagePath)
                    dismiss()
                }
            }
        }
        .onDisappear {
            if autoControlBrightness {
                ScreenBrightnessHelper.shared.restoreBrightness()
            }

            viewModel.stopFaceVerify()
        }
        .animation(.easeInOut(duration: 0.3), value: showToast)
    }
}

// MARK: - Photo Capture Helper
/// Helper class to capture photos using AVCapturePhotoOutput (works alongside SDK's video processing)
class PhotoCaptureHelper: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var capturedImage: UIImage?

    private var photoOutput: AVCapturePhotoOutput?
    private var isSetup = false

    /// Setup photo output on the session (non-invasive - AVCapturePhotoOutput is designed to coexist)
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

            // Capture a photo immediately and periodically to always have a recent image
            capturePhoto()
        } else {
            print("[PhotoCaptureHelper] Could not add photo output")
        }

        session.commitConfiguration()

        // Start periodic capture to always have a recent image
        startPeriodicCapture()
    }

    /// Start capturing photos periodically
    private func startPeriodicCapture() {
        // Capture every 0.5 seconds to always have a recent image
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self, self.isSetup else {
                timer.invalidate()
                return
            }
            self.capturePhoto()
        }
    }

    /// Capture a single photo
    func capturePhoto() {
        guard let photoOutput = photoOutput else {
            print("[PhotoCaptureHelper] Photo output not ready")
            return
        }

        let settings = AVCapturePhotoSettings()
        // Use default settings for best compatibility
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - AVCapturePhotoCaptureDelegate

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("[PhotoCaptureHelper] Capture error: \(error.localizedDescription)")
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("[PhotoCaptureHelper] Could not create image from photo")
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.capturedImage = image
            print("[PhotoCaptureHelper] Photo captured successfully")
        }
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
