import Foundation
import UIKit

/// Debug helper to trace FaceAISDK issues
public class FaceAISDKDebugHelper {

    public static let shared = FaceAISDKDebugHelper()

    private init() {}

    /// Trace and validate model loading before FaceAISDK uses it
    public func traceModelLoading() {
        print("========== FaceAISDK Debug Trace ==========")

        // 1. Check all bundles
        traceBundles()

        // 2. Find and validate model file
        traceModelFile()

        // 3. Try to load model data
        traceModelData()

        // 4. Check TensorFlow Lite availability
        traceTensorFlowLite()

        print("========== End Debug Trace ==========")
    }

    private func traceBundles() {
        print("\n[DEBUG] === Bundle Information ===")

        let mainBundle = Bundle.main
        print("[DEBUG] Main Bundle Path: \(mainBundle.bundlePath)")
        print("[DEBUG] Main Bundle ID: \(mainBundle.bundleIdentifier ?? "nil")")

        // List all bundles in main bundle
        if let resourcePath = mainBundle.resourcePath {
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                let bundles = contents.filter { $0.hasSuffix(".bundle") }
                print("[DEBUG] Bundles in app: \(bundles)")
            } catch {
                print("[DEBUG] Error listing bundles: \(error)")
            }
        }

        // Check for subModel.bundle specifically
        if let subModelPath = mainBundle.path(forResource: "subModel", ofType: "bundle") {
            print("[DEBUG] ✓ subModel.bundle found at: \(subModelPath)")
        } else {
            print("[DEBUG] ✗ subModel.bundle NOT FOUND in main bundle")
        }
    }

    private func traceModelFile() {
        print("\n[DEBUG] === Model File Search ===")

        let mainBundle = Bundle.main
        let possiblePaths = [
            mainBundle.path(forResource: "FaceAI", ofType: "model"),
            mainBundle.path(forResource: "FaceAI.model", ofType: nil),
            mainBundle.path(forResource: "subModel", ofType: "bundle").map { "\($0)/FaceAI.model" },
        ].compactMap { $0 }

        print("[DEBUG] Searching for FaceAI.model...")

        for path in possiblePaths {
            let exists = FileManager.default.fileExists(atPath: path)
            print("[DEBUG] Path: \(path)")
            print("[DEBUG]   Exists: \(exists)")

            if exists {
                do {
                    let attrs = try FileManager.default.attributesOfItem(atPath: path)
                    let size = attrs[.size] as? Int64 ?? 0
                    print("[DEBUG]   Size: \(size) bytes (\(Double(size) / 1024 / 1024) MB)")

                    // Check if readable
                    let readable = FileManager.default.isReadableFile(atPath: path)
                    print("[DEBUG]   Readable: \(readable)")
                } catch {
                    print("[DEBUG]   Error getting attributes: \(error)")
                }
            }
        }

        // Also search recursively
        print("\n[DEBUG] Recursive search for *.model files:")
        if let resourcePath = mainBundle.resourcePath {
            findFilesRecursively(in: resourcePath, withExtension: "model")
        }
    }

    private func findFilesRecursively(in path: String, withExtension ext: String) {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: path) else { return }

        while let file = enumerator.nextObject() as? String {
            if file.hasSuffix(".\(ext)") {
                let fullPath = (path as NSString).appendingPathComponent(file)
                print("[DEBUG]   Found: \(fullPath)")

                do {
                    let attrs = try fileManager.attributesOfItem(atPath: fullPath)
                    let size = attrs[.size] as? Int64 ?? 0
                    print("[DEBUG]     Size: \(size) bytes")
                } catch {
                    print("[DEBUG]     Error: \(error)")
                }
            }
        }
    }

    private func traceModelData() {
        print("\n[DEBUG] === Model Data Loading Test ===")

        // Try to find and load the model file
        guard let subModelPath = Bundle.main.path(forResource: "subModel", ofType: "bundle"),
              let subModelBundle = Bundle(path: subModelPath) else {
            print("[DEBUG] ✗ Cannot create subModel bundle")
            return
        }

        print("[DEBUG] subModel bundle created: \(subModelBundle.bundlePath)")

        guard let modelPath = subModelBundle.path(forResource: "FaceAI", ofType: "model") else {
            // Try direct path
            let directPath = "\(subModelPath)/FaceAI.model"
            if FileManager.default.fileExists(atPath: directPath) {
                print("[DEBUG] Model found at direct path: \(directPath)")
                loadAndValidateModel(at: directPath)
            } else {
                print("[DEBUG] ✗ FaceAI.model not found in subModel bundle")
            }
            return
        }

        print("[DEBUG] Model path from bundle: \(modelPath)")
        loadAndValidateModel(at: modelPath)
    }

    private func loadAndValidateModel(at path: String) {
        print("[DEBUG] Attempting to load model data from: \(path)")

        do {
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url)
            print("[DEBUG] ✓ Model data loaded successfully")
            print("[DEBUG]   Data size: \(data.count) bytes")

            // Check first few bytes (TFLite models start with specific magic bytes)
            if data.count >= 8 {
                let header = data.prefix(8)
                let headerHex = header.map { String(format: "%02x", $0) }.joined(separator: " ")
                print("[DEBUG]   Header bytes: \(headerHex)")

                // TFLite FlatBuffer magic: typically starts with specific pattern
                // Check if it looks like a valid TFLite model
                if data.count > 4 {
                    // FlatBuffer files have size at offset 4
                    let byte0 = data[0]
                    let byte1 = data[1]
                    let byte2 = data[2]
                    let byte3 = data[3]
                    print("[DEBUG]   First 4 bytes: \(byte0), \(byte1), \(byte2), \(byte3)")
                }
            }

            // Validate data is not empty or corrupted
            if data.count < 1000 {
                print("[DEBUG] ⚠ WARNING: Model file seems too small!")
            }

        } catch {
            print("[DEBUG] ✗ Failed to load model data: \(error)")
            print("[DEBUG]   Error type: \(type(of: error))")
            print("[DEBUG]   Localized: \(error.localizedDescription)")
        }
    }

    private func traceTensorFlowLite() {
        print("\n[DEBUG] === TensorFlow Lite Check ===")

        // Check if TensorFlowLiteSwift module is available
        // We can't import it here without adding dependency, but we can check bundles

        if let tflBundle = Bundle.main.path(forResource: "TensorFlowLite", ofType: "bundle") {
            print("[DEBUG] ✓ TensorFlowLite.bundle found: \(tflBundle)")
        } else {
            print("[DEBUG] ✗ TensorFlowLite.bundle not found")
        }

        if let tflCBundle = Bundle.main.path(forResource: "TensorFlowLiteC", ofType: "bundle") {
            print("[DEBUG] ✓ TensorFlowLiteC.bundle found: \(tflCBundle)")
        } else {
            print("[DEBUG] ✗ TensorFlowLiteC.bundle not found")
        }

        // Check framework
        let frameworksPath = Bundle.main.privateFrameworksPath ?? ""
        print("[DEBUG] Frameworks path: \(frameworksPath)")

        if FileManager.default.fileExists(atPath: frameworksPath) {
            do {
                let frameworks = try FileManager.default.contentsOfDirectory(atPath: frameworksPath)
                let tfLiteFrameworks = frameworks.filter { $0.contains("TensorFlow") }
                print("[DEBUG] TensorFlow frameworks: \(tfLiteFrameworks)")
            } catch {
                print("[DEBUG] Error listing frameworks: \(error)")
            }
        }
    }

    /// Call this method to add exception handler
    public func setupExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            print("========== UNCAUGHT EXCEPTION ==========")
            print("Name: \(exception.name)")
            print("Reason: \(exception.reason ?? "nil")")
            print("User Info: \(exception.userInfo ?? [:])")
            print("Call Stack:")
            for symbol in exception.callStackSymbols {
                print("  \(symbol)")
            }
            print("=========================================")
        }

        print("[DEBUG] Exception handler installed")
    }

    /// Print memory info
    public func traceMemoryInfo() {
        print("\n[DEBUG] === Memory Information ===")

        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024 / 1024
            print("[DEBUG] Memory used: \(String(format: "%.2f", usedMB)) MB")
        } else {
            print("[DEBUG] Failed to get memory info")
        }

        // Device memory
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let totalMB = Double(totalMemory) / 1024 / 1024 / 1024
        print("[DEBUG] Device total memory: \(String(format: "%.2f", totalMB)) GB")
    }
}
