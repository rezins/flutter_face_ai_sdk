import SwiftUI
import AVFoundation
import FaceAISDK_Core

// Camera size using @MainActor for thread safety
@MainActor
var FaceCameraSize: CGFloat {
    7 * min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) / 10
}

public struct AddFaceByCamera: View {
    let faceID: String
    let onDismiss: (Int) -> Void // 0: user cancelled, 1: success

    // Control flag, default true (native friendly)
    // If called by Manager, set to false to control brightness externally
    var autoControlBrightness: Bool = true

    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: AddFaceByCameraModel = AddFaceByCameraModel()

    // Localized tip helper - Auto detect language
    private func localizedTip(for code: Int) -> String {
        return FaceSDKLocalization.shared.localizedTip(for: code)
    }

    // Localized string helper
    private func localized(_ key: String) -> String {
        return FaceSDKLocalization.shared.localizedString(key, defaultValue: key)
    }

    public var body: some View {
        ZStack {
            VStack(spacing: 20) {
                // Custom top bar (close button)
                HStack {
                    Button(action: {
                        onDismiss(0)
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

                // Top tip area
                Text(localizedTip(for: viewModel.sdkInterfaceTips.code))
                    .font(.system(size: 19).bold())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .foregroundColor(.white)
                    .background(Color.faceMain)
                    .cornerRadius(20)

                // Core area: camera preview
                FaceAICameraView(session: viewModel.captureSession, cameraSize: FaceCameraSize)
                    .frame(width: FaceCameraSize, height: FaceCameraSize)
                    .aspectRatio(1.0, contentMode: .fit)
                    .clipShape(Circle())
                    .background(Circle().fill(Color.white))
                    .overlay(Circle().stroke(Color.gray, lineWidth: 1))

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .navigationBarHidden(true)

            .onAppear {
                if autoControlBrightness {
                    ScreenBrightnessHelper.shared.maximizeBrightness()
                }

                viewModel.initAddFace()
            }
            .onChange(of: viewModel.sdkInterfaceTips.code) { newValue in
                print("[FaceAISDK] AddFaceBySDKCamera: \(viewModel.sdkInterfaceTips.message)")
            }
            .onChange(of: viewModel.readyConfirmFace) { isReady in
                // Auto-save face when ready (no confirmation dialog)
                if isReady {
                    print("[FaceAISDK] Face captured - auto saving...")
                    print("FaceFeature: \(String(describing: viewModel.faceFeatureBySDKCamera))")
                    UserDefaults.standard.set(viewModel.faceFeatureBySDKCamera, forKey: faceID)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onDismiss(1)
                        dismiss()
                    }
                }
            }
            .onDisappear {
                if autoControlBrightness {
                    ScreenBrightnessHelper.shared.restoreBrightness()
                }

                viewModel.stopAddFace()
            }
        }
    }
}

