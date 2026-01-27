import Foundation

/// Result codes matching native SDK behavior
struct FaceAIResultCode {
    // Common codes
    static let USER_CANCELLED = 0
    static let SUCCESS = 1

    // Enrollment/Verification codes
    static let NO_FACE_FEATURE = 6

    // Liveness codes
    static let COLOR_LIVENESS_LIGHT_TOO_HIGH = 53
    static let MOTION_LIVENESS_TIMEOUT = 60
    static let MOTION_LIVENESS_CANCELLED = 61

    // Error codes
    static let CAMERA_PERMISSION_DENIED = 100
    static let UNKNOWN_ERROR = 999
}

/// Liveness detection types
struct LivenessType {
    static let NONE = 0              // No liveness detection
    static let COLOR = 1             // Color-based liveness (flash detection)
    static let MOTION = 2            // Motion-based liveness (head movement)
    static let COLOR_AND_MOTION = 3  // Both color and motion
}
