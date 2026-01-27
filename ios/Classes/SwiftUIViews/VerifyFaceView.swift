import SwiftUI
import FaceAISDK_Core
import AVFoundation

/**
 * 1:1 人脸识别+活体检测
 */
struct VerifyFaceView: View {
    // 确保ViewModel的生命周期与视图一致
    @StateObject private var viewModel: VerifyFaceModel = VerifyFaceModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showLightHighDialog = false
    @State private var showToast = false
    @State private var toastViewTips: String = ""
    
    var autoControlBrightness: Bool = true

    // 业务参数
    let faceID: String
    let threshold: Float
    
    //0.无需活体检测 1.仅仅动作 2.动作+炫彩 3.炫彩
    let livenessType:Int
    //动作活体种类：1. 张张嘴  2.微笑  3.眨眨眼  4.摇摇头  5.点头
    let motionLiveness:String
    
    let motionLivenessTimeOut:Int  //时间为秒
    let motionLivenessSteps:Int    //动作活体个数
    
    let onDismiss: (Int) -> Void 

    // 多语言提示
    private func localizedTip(for code: Int) -> String {
        let key = "Face_Tips_Code_\(code)"
        let defaultValue = "VerifyFace Tips Code=\(code)"
        return NSLocalizedString(key, value: defaultValue, comment: "")
    }
    
    // MARK: - Helper Methods

    /// Capture current frame from camera session for attendance
    private func captureAttendanceImage() {
        guard let captureSession = viewModel.captureSession else {
            print("⚠️ No capture session available")
            return
        }

        // Find video output
        guard let videoOutput = captureSession.outputs.first(where: { $0 is AVCaptureVideoDataOutput }) as? AVCaptureVideoDataOutput else {
            print("⚠️ No video output found")

            // Fallback: try to capture from camera connection
            captureFromCameraConnection(captureSession)
            return
        }

        print("📸 Attempting to capture frame from video output...")
        // Note: Direct frame capture requires delegate setup
        // For now, we'll use connection-based capture
        captureFromCameraConnection(captureSession)
    }

    /// Fallback method to capture from camera connection
    private func captureFromCameraConnection(_ session: AVCaptureSession) {
        // Get photo output if available
        if let photoOutput = session.outputs.first(where: { $0 is AVCapturePhotoOutput }) as? AVCapturePhotoOutput {
            let settings = AVCapturePhotoSettings()
            // Note: This requires AVCapturePhotoCaptureDelegate which we don't have access to
            print("ℹ️ Photo output available but requires delegate setup")
        }

        // Alternative: Capture from preview layer (if accessible)
        print("ℹ️ Frame capture would require SDK to expose captured image")
        print("ℹ️ For full implementation, SDK needs to provide captured frame callback")
    }

    var body: some View {
        ZStack {
            VStack {
                 HStack {
                    Button(action: {
                        onDismiss(0) // 0 代表用户取消
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
                    .background(Color.brown)
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
            //隐藏系统导航栏
            .navigationBarBackButtonHidden(true)
            .navigationBarHidden(true)
            if showToast {
                // 计算显示内容
                let similarity = String(format: "%.2f", viewModel.faceVerifyResult.similarity)
                // 优先使用手动设置的 toastViewTips (用于处理无特征值的情况)，否则使用 SDK 返回的 tips
                let displayTips = toastViewTips.isEmpty ? viewModel.faceVerifyResult.tips : toastViewTips
                let displayMessage = (toastViewTips.isEmpty) ? "\(displayTips) \(similarity)" : displayTips
                
                // 计算样式：如果是无特征值错误，或者相似度低，则为 failure
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
            
            // --- 顶层：光线过强自定义弹窗 (Dialog) ---
            if showLightHighDialog {
                ZStack {
                    VStack(spacing: 22) {
                        Text(viewModel.faceVerifyResult.tips)
                            .font(.system(size: 16).bold())
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                            .padding(.horizontal,25)


                        if let uiImage = UIImage.fromPluginBundle(named: "light_too_high") {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 120)
                                        .padding(.horizontal,1)}
                        
                        Button(action: {
                            withAnimation {
                                showLightHighDialog = false
                                onDismiss(viewModel.faceVerifyResult.code)
                                dismiss()
                            }
                        }) {
                            Text("Confirm")
                                .font(.system(size: 18).bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.brown)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 30)
                    }
                    .padding(.vertical, 22)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 30) // 设置弹窗左右边距
                }
                .zIndex(2)
                .transition(.scale(scale: 0.8).combined(with: .opacity)) // 添加出现动画
            }
        }
         .onAppear {
             if autoControlBrightness {
                 ScreenBrightnessHelper.shared.maximizeBrightness()
             }
             
             withAnimation(.easeInOut(duration: 0.3)) {
                UIScreen.main.brightness = 1.0
            }
            
            // 校验本地是否有特征值
            guard let faceFeature = UserDefaults.standard.string(forKey: faceID) else {
                toastViewTips = "No Face Feature for key: \(faceID)"
                showToast = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showToast = false
                    // 假设 VerifyResultCode.NO_FACE_FEATURE 是 6 (参考注释)
                    onDismiss(6)
                    dismiss()
                }
                return
            }
            
            viewModel.initFaceAISDK(
                faceIDFeature: faceFeature,
                threshold: threshold,
                livenessType: livenessType,
                onlyLiveness: false,
                motionLiveness: motionLiveness,
                motionLivenessTimeOut:motionLivenessTimeOut,
                motionLivenessSteps:motionLivenessSteps
            )
        }
        .onChange(of: viewModel.faceVerifyResult.code) { newValue in
            // 清空手动的 tips，使用 SDK 的结果
            toastViewTips = ""

            if newValue == VerifyResultCode.COLOR_LIVENESS_LIGHT_TOO_HIGH{
                withAnimation { //光线太强了
                    showLightHighDialog = true
                }
            }else{
                showToast = true
                print("检测返回 ： \(viewModel.faceVerifyResult)")

                // ✅ Capture attendance image if verification successful
                // Check if verification passed (similarity > threshold)
                if viewModel.faceVerifyResult.similarity > threshold {
                    print("✅ Verification SUCCESS - attempting to capture attendance image...")
                    print("📊 Similarity: \(viewModel.faceVerifyResult.similarity) > Threshold: \(threshold)")

                    // Try to capture frame for attendance
                    // Note: This requires SDK to expose captured frame
                    // For now, we attempt capture but SDK may not provide image
                    captureAttendanceImage()

                    // TODO: If SDK provides captured UIImage in faceVerifyResult,
                    // store it here using AttendanceImageHelper
                    // Example:
                    // if let capturedImage = viewModel.faceVerifyResult.capturedImage {
                    //     AttendanceImageHelper.shared.storeTempImage(capturedImage)
                    //     print("✅ Stored captured image for attendance")
                    // }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation {
                        showToast = false
                    }
                    onDismiss(viewModel.faceVerifyResult.code)
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
