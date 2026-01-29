import SwiftUI
import PhotosUI
import FaceAISDK_Core


// Add face from photo album
public struct AddFaceByUIImage: View {

    // State management
    @State private var showImagePicker = false
    @State private var isLoading = false
    @State private var canSave = false

    @State private var selectedImage: UIImage?

    @StateObject private var viewModel: addFaceByUIImageModel = addFaceByUIImageModel()

    let faceID: String
    let onDismiss: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    // Localized tip helper - Force English
    private func localizedTip(for code: Int) -> String {
        let key = "Face_Tips_Code_\(code)"
        let defaultValue = "AddFace Tips Code=\(code)"

        let frameworkBundle = Bundle(for: FaceSDKSwiftManager.self)

        if let resourceBundlePath = frameworkBundle.path(forResource: "flutter_face_ai_sdk", ofType: "bundle"),
           let resourceBundle = Bundle(path: resourceBundlePath),
           let enPath = resourceBundle.path(forResource: "en", ofType: "lproj"),
           let enBundle = Bundle(path: enPath) {
            return NSLocalizedString(key, tableName: nil, bundle: enBundle, value: defaultValue, comment: "")
        }

        if let enPath = frameworkBundle.path(forResource: "en", ofType: "lproj"),
           let enBundle = Bundle(path: enPath) {
            return NSLocalizedString(key, tableName: nil, bundle: enBundle, value: defaultValue, comment: "")
        }

        if let enPath = Bundle.main.path(forResource: "en", ofType: "lproj"),
           let enBundle = Bundle(path: enPath) {
            return NSLocalizedString(key, tableName: nil, bundle: enBundle, value: defaultValue, comment: "")
        }

        return defaultValue
    }

    public var body: some View {
        ZStack {
            VStack(spacing: 20) {

                // MARK: - Custom top bar
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
                .padding(.horizontal, 20)
                .padding(.top, 10)

                // MARK: - Main content area
                ScrollView {
                    VStack(spacing: 25) {

                        // Status tip
                        Text(localizedTip(for: viewModel.sdkInterfaceTips.code))
                            .font(.system(size: 16).bold())
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .foregroundColor(.white)
                            .background(Color.brown)
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)

                        // Image preview area
                        if let selectedImage {
                            ZStack {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 166, maxHeight: 166)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(radius: 8)

                                if isLoading {
                                    ZStack {
                                        Color.black.opacity(0.4)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                        ProgressView()
                                            .scaleEffect(1.5)
                                            .tint(.white)
                                    }
                                    .frame(maxWidth: 166, maxHeight: 166)
                                }
                            }
                        } else {
                            // Placeholder
                            VStack(spacing: 12) {
                                Image(systemName: "photo.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .foregroundStyle(.tertiary)

                                Text("Select from album")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 166, height: 166)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5]))
                            )
                        }

                        Button(action: {
                            showImagePicker = true
                        }) {
                            Label("Select Image", systemImage: "photo.on.rectangle.angled")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .padding(.horizontal, 40)

                        // Save button
                        if canSave {
                            Button(action: {
                                if let image = selectedImage {
                                    let faceFeature = viewModel.getFaceFeature(faceUIImage: image)
                                    UserDefaults.standard.set(faceFeature, forKey: faceID)
                                    print("[FaceAISDK] UIImage feature: \(faceFeature)")

                                    onDismiss(1)
                                    dismiss()
                                }
                            }) {
                                Text("Save Face Feature")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .padding(.horizontal, 40)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .background(Color.white.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .navigationBarHidden(true)

            .onChange(of: viewModel.croppedFaceImage) { newValue in
                withAnimation {
                    selectedImage = newValue
                    isLoading = false
                    canSave = true
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedImage) { uiImage in
                    isLoading = true
                    canSave = false
                    viewModel.addFaceByUIImage(faceUIImage: uiImage)
                }
            }
        }
    }
}


struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    var onImagePicked: ((UIImage) -> Void)?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                return
            }

            provider.loadObject(ofClass: UIImage.self) { image, error in
                if let uiImage = image as? UIImage {
                    DispatchQueue.main.async {
                        self.parent.selectedImage = uiImage
                        self.parent.onImagePicked?(uiImage)
                    }
                }
            }
        }
    }
}
