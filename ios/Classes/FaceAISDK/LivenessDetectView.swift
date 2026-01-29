import SwiftUI
import AVFoundation
import FaceAISDK_Core

/**
 * Liveness Detection Only (Motion and Color Liveness)
 */
struct LivenessDetectView: View {
    @StateObject private var viewModel: VerifyFaceModel = VerifyFaceModel()
    @State private var showToast = false
    @State private var showLightHighDialog = false
    @Environment(\.dismiss) private var dismiss

    var autoControlBrightness: Bool = true

    // 0: No liveness, 1: Motion only, 2: Motion+Color, 3: Color only
    let livenessType: Int
    // Motion liveness types: 1=Open mouth, 2=Smile, 3=Blink, 4=Shake head, 5=Nod
    let motionLiveness: String

    let motionLivenessTimeOut: Int // seconds
    let motionLivenessSteps: Int   // number of motion actions

    let onDismiss: (Int) -> Void

    // Localized tip helper - Auto detect language
    private func localizedTip(for code: Int) -> String {
        return FaceSDKLocalization.shared.localizedTip(for: code)
    }


    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Button(action: {
                        onDismiss(0) // 0 = user cancelled
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
                .padding(.horizontal, 10)
                .padding(.top, 10)

                Text(localizedTip(for: viewModel.sdkInterfaceTips.code))
                    .font(.system(size: 20).bold())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .foregroundColor(.white)
                    .background(Color.faceMain)
                    .cornerRadius(20)

                Text(localizedTip(for: viewModel.sdkInterfaceTipsExtra.code))
                    .font(.system(size: 19).bold())
                    .padding(.bottom, 8)
                    .frame(minHeight: 30)
                    .foregroundColor(.black)

                FaceAICameraView(session: viewModel.captureSession, cameraSize: FaceCameraSize)
                    .frame(width: FaceCameraSize, height: FaceCameraSize)
                    .aspectRatio(1.0, contentMode: .fit)
                    .padding(.vertical, 8)
                    .clipShape(Circle())

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(viewModel.colorFlash.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .navigationBarHidden(true)

             if showToast {
                VStack {
                    Spacer()
                    CustomToastView(
                        message: "\(viewModel.faceVerifyResult.tips)",
                        style: .success
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
                        Text(viewModel.faceVerifyResult.tips)
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
                                onDismiss(viewModel.faceVerifyResult.code)
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

            viewModel.initFaceAISDK(faceIDFeature: "",
                                    livenessType: livenessType,
                                    onlyLiveness: true,
                                    motionLiveness: motionLiveness,
                                    motionLivenessTimeOut: motionLivenessTimeOut,
                                    motionLivenessSteps: motionLivenessSteps)
        }
        .onChange(of: viewModel.faceVerifyResult.code) { newValue in
            if newValue == VerifyResultCode.COLOR_LIVENESS_LIGHT_TOO_HIGH {
                withAnimation {
                    showLightHighDialog = true
                }
            } else {
                showToast = true
                print("[FaceAISDK] Liveness result: \(viewModel.faceVerifyResult)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
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
