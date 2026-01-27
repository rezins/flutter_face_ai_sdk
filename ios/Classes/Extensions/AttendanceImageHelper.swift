import UIKit
import Foundation

/// Helper for capturing and saving attendance images
class AttendanceImageHelper {

    /// Shared singleton instance
    static let shared = AttendanceImageHelper()

    private init() {}

    /// Directory for storing attendance images
    private var attendanceDirectory: URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = paths[0]
        let attendanceDir = cacheDir.appendingPathComponent("FaceAI_Face", isDirectory: true)

        // Create directory if not exists
        if !FileManager.default.fileExists(atPath: attendanceDir.path) {
            try? FileManager.default.createDirectory(at: attendanceDir, withIntermediateDirectories: true, attributes: nil)
        }

        return attendanceDir
    }

    /// Save UIImage to attendance directory with original resolution (no scaling, no crop)
    /// - Parameters:
    ///   - image: The UIImage to save
    ///   - faceID: Face ID for naming the file (optional)
    /// - Returns: Full path to saved image, or nil if failed
    func saveAttendanceImage(_ image: UIImage, faceID: String? = nil) -> String? {
        // Create unique filename with timestamp
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let faceIdPart = faceID ?? "unknown"
        let fileName = "attendance_\(faceIdPart)_\(timestamp).jpg"

        let fileURL = attendanceDirectory.appendingPathComponent(fileName)

        // Convert to JPEG with 100% quality (original resolution, no scaling)
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            print("❌ Failed to convert UIImage to JPEG data")
            return nil
        }

        do {
            try imageData.write(to: fileURL)
            let fullPath = fileURL.path
            print("✅ Attendance image saved: \(fullPath)")
            print("📏 Image size: \(image.size.width)x\(image.size.height) pixels")
            return fullPath
        } catch {
            print("❌ Error saving attendance image: \(error.localizedDescription)")
            return nil
        }
    }

    /// Get temporary storage key for passing image between views
    static let capturedImageKey = "temp_captured_attendance_image"

    /// Store UIImage temporarily in UserDefaults (as JPEG data)
    func storeTempImage(_ image: UIImage) {
        if let imageData = image.jpegData(compressionQuality: 1.0) {
            UserDefaults.standard.set(imageData, forKey: Self.capturedImageKey)
        }
    }

    /// Retrieve and remove temporarily stored image
    func retrieveAndClearTempImage() -> UIImage? {
        guard let imageData = UserDefaults.standard.data(forKey: Self.capturedImageKey) else {
            return nil
        }

        // Clear immediately
        UserDefaults.standard.removeObject(forKey: Self.capturedImageKey)

        return UIImage(data: imageData)
    }
}
