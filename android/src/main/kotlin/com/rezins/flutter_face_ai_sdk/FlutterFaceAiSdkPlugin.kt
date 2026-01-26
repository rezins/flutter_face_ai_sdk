package com.rezins.flutter_face_ai_sdk

import android.app.Activity
import android.content.Intent
import android.util.Log
import android.widget.Toast
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import com.rezins.flutter_face_ai_sdk.SysCamera.addFace.AddFaceFeatureActivity
import com.rezins.flutter_face_ai_sdk.SysCamera.verify.FaceVerificationActivity

/** FlutterFaceAiSdkPlugin */
class FlutterFaceAiSdkPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener,
    EventChannel.StreamHandler {

    companion object {
        private const val TAG = "FlutterFaceAiSdkPlugin"
        private const val METHOD_CHANNEL = "flutter_face_ai_sdk"
        private const val EVENT_CHANNEL = "flutter_face_ai_sdk/events"
        private const val REQUEST_CODE_ENROLL = 1001
        private const val REQUEST_CODE_VERIFY = 1002
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var eventSink: EventChannel.EventSink? = null
    private var pendingEnrollResult: Result? = null
    private var pendingVerifyResult: Result? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initializeSDK" -> {
                try {
                    val config = call.argument<Map<String, Any>>("config")
                    val apiKey = config?.get("apiKey") as? String
                    Log.d(TAG, "Initializing with key: $apiKey")

                    activity?.applicationContext?.let {
                        // Initialize MMKV and SDK config
                        FaceSDKConfig.init(it)
                        // Initialize AI config (directories)
                        FaceAIConfig.init(it)
                        result.success("SDK Initialized")
                    } ?: result.error("ACTIVITY_NULL", "No activity available", null)
                } catch (e: Exception) {
                    result.error("INIT_ERROR", e.message, null)
                }
            }

            "detectFace" -> {
                try {
                    val imagePath = call.argument<String>("imagePath")
                    val resultMap = hashMapOf(
                        "faceId" to "fake-face-id-123",
                        "confidence" to 0.95,
                        "image" to "fake-base64-image"
                    )
                    result.success(resultMap)
                } catch (e: Exception) {
                    result.error("DETECT_ERROR", e.message, null)
                }
            }

            "addFace" -> {
                try {
                    val imagePath = call.argument<String>("imagePath")
                    val intent = Intent(activity, AddFaceFeatureActivity::class.java)
                    activity?.startActivity(intent)

                    val resultMap = hashMapOf(
                        "faceId" to "fake-face-id-123",
                        "confidence" to 0.95,
                        "image" to "fake-base64-image"
                    )
                    result.success(resultMap)
                } catch (e: Exception) {
                    result.error("ADD_FACE_ERROR", e.message, null)
                }
            }

            "startEnroll" -> {
                try {
                    val faceId = call.argument<String>("faceId") ?: ""
                    val format = call.argument<String>("format") ?: "base64"
                    Log.d(TAG, "startEnroll with faceId: $faceId, format: $format")

                    if (faceId.isEmpty()) {
                        result.error("ENROLL_ERROR", "faceId is required", null)
                        return
                    }

                    // Store result callback for later use
                    pendingEnrollResult = result

                    activity?.let { act ->
                        val intent = Intent(act, AddFaceFeatureActivity::class.java).apply {
                            putExtra("FACE_RESULT_FORMAT", format)
                            putExtra("ADD_FACE_IMAGE_TYPE_KEY", "FACE_VERIFY")
                            putExtra("FACE_ID_FROM_FLUTTER", faceId)  // Pass faceId from Flutter
                            putExtra("SKIP_DIALOG", true)  // Flag to skip dialog
                        }
                        act.startActivityForResult(intent, REQUEST_CODE_ENROLL)
                    } ?: result.error("ACTIVITY_NULL", "No activity available", null)
                } catch (e: Exception) {
                    result.error("ENROLL_ERROR", e.message, null)
                }
            }

            "startVerify" -> {
                try {
                    val faceFeatures = call.argument<ArrayList<String>>("face_features") ?: ArrayList()
                    val livenessType = call.argument<Int>("liveness_type") ?: 1
                    val motionStepSize = call.argument<Int>("motion_step_size") ?: 2
                    val motionTimeout = call.argument<Int>("motion_timeout") ?: 9
                    val threshold = call.argument<Double>("threshold") ?: 0.85

                    Log.d(TAG, "startVerify - faceFeatures count: ${faceFeatures.size}, liveness: $livenessType")

                    // Validate list has at least 1 item
                    if (faceFeatures.isEmpty()) {
                        result.error("VERIFY_ERROR", "faceFeatures list must have at least 1 item", null)
                        return
                    }

                    // Always use first item (index 0)
                    val faceFeature = faceFeatures[0]
                    Log.d(TAG, "Using faceFeature (first 50 chars): ${faceFeature.take(50)}...")

                    if (faceFeature.isEmpty()) {
                        result.error("VERIFY_ERROR", "Face feature at index 0 is empty", null)
                        return
                    }

                    // Store result callback for later use
                    pendingVerifyResult = result

                    activity?.let { act ->
                        val intent = Intent(act, FaceVerificationActivity::class.java).apply {
                            putExtra(FaceVerificationActivity.FACE_DATA_KEY, faceFeature)  // Pass face feature directly
                            putExtra(FaceVerificationActivity.FACE_LIVENESS_TYPE, livenessType)
                            putExtra(FaceVerificationActivity.MOTION_STEP_SIZE, motionStepSize)
                            putExtra(FaceVerificationActivity.MOTION_TIMEOUT, motionTimeout)
                            putExtra(FaceVerificationActivity.THRESHOLD_KEY, threshold.toFloat())
                        }
                        act.startActivityForResult(intent, REQUEST_CODE_VERIFY)
                    } ?: result.error("ACTIVITY_NULL", "No activity available", null)
                } catch (e: Exception) {
                    result.error("VERIFY_ERROR", e.message, null)
                }
            }

            "startLivenessDetection" -> {
                try {
                    val livenessType = call.argument<Int>("liveness_type") ?: 1
                    val motionStepSize = call.argument<Int>("motion_step_size") ?: 2
                    val motionTimeout = call.argument<Int>("motion_timeout") ?: 9

                    Log.d(TAG, "startLivenessDetection - type: $livenessType")

                    activity?.let { act ->
                        val intent = Intent(act, com.rezins.flutter_face_ai_sdk.SysCamera.verify.LivenessDetectActivity::class.java).apply {
                            putExtra("FACE_LIVENESS_TYPE", livenessType)
                            putExtra("MOTION_STEP_SIZE", motionStepSize)
                            putExtra("MOTION_TIMEOUT", motionTimeout)
                        }
                        act.startActivityForResult(intent, REQUEST_CODE_VERIFY)
                        result.success(null)
                    } ?: result.error("ACTIVITY_NULL", "No activity available", null)
                } catch (e: Exception) {
                    result.error("LIVENESS_ERROR", e.message, null)
                }
            }

            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        when (requestCode) {
            REQUEST_CODE_ENROLL -> {
                handleEnrollResult(resultCode, data)
                return true
            }
            REQUEST_CODE_VERIFY -> {
                handleVerifyResult(resultCode, data)
                return true
            }
        }
        return false
    }

    private fun handleEnrollResult(resultCode: Int, data: Intent?) {
        if (resultCode == Activity.RESULT_OK) {
            val faceFeature = data?.getStringExtra("faceFeature")
            val faceID = data?.getStringExtra("faceID")
            val msg = data?.getStringExtra("msg")
            Log.d(TAG, "Enroll success - faceID: $faceID, feature: ${faceFeature?.take(20)}...")

            // Return face feature to Flutter via pending result
            pendingEnrollResult?.success(faceFeature)
            pendingEnrollResult = null

            // Also send event for backward compatibility
            val eventData = hashMapOf(
                "event" to "Enrolled",
                "code" to 1,
                "result" to "success",
                "face_base64" to faceFeature,
                "faceID" to faceID,
                "message" to msg
            )
            sendEvent(eventData)
        } else {
            // Return error to Flutter
            pendingEnrollResult?.error("ENROLL_FAILED", "Enrollment was cancelled or failed", null)
            pendingEnrollResult = null

            // Send failure event
            val eventData = hashMapOf(
                "event" to "Enrolled",
                "code" to 0,
                "result" to "fail"
            )
            sendEvent(eventData)
        }
    }

    private fun handleVerifyResult(resultCode: Int, data: Intent?) {
        val resultString = if (resultCode == Activity.RESULT_OK) {
            val code = data?.getIntExtra("code", 0) ?: 0
            val faceID = data?.getStringExtra("faceID")
            val msg = data?.getStringExtra("msg")
            val similarity = data?.getFloatExtra("similarity", 0f) ?: 0f
            Log.d(TAG, "Verify result - code: $code, faceID: $faceID, similarity: $similarity")

            // Return result string to Flutter via pending result
            val result = if (code == 1) "Verify" else "Not Verify"
            pendingVerifyResult?.success(result)
            pendingVerifyResult = null

            // Also send event for backward compatibility
            val eventData = hashMapOf(
                "event" to "Verified",
                "code" to code,
                "result" to if (code == 1) "success" else "fail",
                "faceID" to faceID,
                "message" to msg,
                "similarity" to similarity
            )
            sendEvent(eventData)

            result
        } else {
            // Return "Not Verify" to Flutter
            pendingVerifyResult?.success("Not Verify")
            pendingVerifyResult = null

            // Send failure event
            val eventData = hashMapOf(
                "event" to "Verified",
                "code" to 0,
                "result" to "fail"
            )
            sendEvent(eventData)

            "Not Verify"
        }

        Log.d(TAG, "Verify final result: $resultString")
    }

    private fun sendEvent(params: Map<String, Any?>) {
        Log.d(TAG, "Sending event to Flutter: $params")
        activity?.runOnUiThread {
            if (eventSink != null) {
                eventSink?.success(params)
                Log.d(TAG, "Event sent successfully")
            } else {
                Log.e(TAG, "EventSink is null! Event not sent.")
            }
        }
    }

    // EventChannel.StreamHandler methods
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        Log.d(TAG, "Event stream started")
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        Log.d(TAG, "Event stream cancelled")
    }

    // ActivityAware methods
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
        Log.d(TAG, "Attached to activity")
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
        Log.d(TAG, "Detached from activity")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}
