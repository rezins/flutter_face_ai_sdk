import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_face_ai_sdk/flutter_face_ai_sdk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face AI SDK',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const FaceAIHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class FaceAIHomePage extends StatefulWidget {
  const FaceAIHomePage({super.key});

  @override
  State<FaceAIHomePage> createState() => _FaceAIHomePageState();
}

class _FaceAIHomePageState extends State<FaceAIHomePage> {
  final _faceAiSdk = FlutterFaceAiSdk();
  final _faceIdController = TextEditingController();
  String _platformVersion = 'Loading...';
  String _status = 'Not Initialized';
  String _lastEvent = 'No events';
  String? _enrolledFaceData;
  String? _enrolledFaceID;
  bool _isInitialized = false;
  int _livenessType = 1; // 0: NONE, 1: MOTION, 2: COLOR_FLASH_MOTION, 3: COLOR_FLASH
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _initPlatform();
    _listenEvents();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _faceIdController.dispose();
    super.dispose();
  }

  Future<void> _initPlatform() async {
    try {
      final version = await _faceAiSdk.getPlatformVersion() ?? 'Unknown';
      setState(() => _platformVersion = version);
    } catch (e) {
      setState(() => _platformVersion = 'Error');
    }
  }

  void _listenEvents() {
    _eventSubscription = _faceAiSdk.getFaceEventStream().listen(
      (event) {
        print('📱 Flutter received event: $event');

        final eventName = event['event'] as String?;
        final code = event['code'] as int?;
        final faceData = event['face_base64'] as String?;
        final faceID = event['faceID'] as String?;

        print('📱 Event: $eventName, Code: $code, FaceID: $faceID');

        setState(() {
          _lastEvent = '$eventName - ${code == 1 ? "Success" : "Failed"}';

          if (eventName == 'Enrolled' && code == 1) {
            _enrolledFaceData = faceData;
            _enrolledFaceID = faceID;
            print('✅ Face enrolled! FaceID: $faceID, Data length: ${faceData?.length}');
            _showMessage('Face Enrolled Successfully');
          } else if (eventName == 'Verified') {
            final similarity = event['similarity'] as num?;
            final message = code == 1
                ? 'Verified ✓ (${(similarity ?? 0).toStringAsFixed(2)})'
                : 'Not Verified ✗';
            _showMessage(message);
          }
        });
      },
      onError: (error) {
        print('❌ Event stream error: $error');
      },
    );
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _initSDK() async {
    try {
      final result = await _faceAiSdk.initializeSDK({'apiKey': 'demo-key'});
      setState(() {
        _status = result;
        _isInitialized = true;
      });
      _showMessage('SDK Initialized');
    } catch (e) {
      _showMessage('Init Failed');
    }
  }

  Future<void> _enroll() async {
    if (!_isInitialized) {
      _showMessage('Initialize SDK first');
      return;
    }

    // Get faceId from text field
    final faceId = _faceIdController.text.trim();
    if (faceId.isEmpty) {
      _showMessage('Please enter Face ID first');
      return;
    }

    try {
      print('🚀 Starting enrollment with faceId: $faceId');

      // Call startEnroll with faceId
      final faceFeature = await _faceAiSdk.startEnroll(faceId);

      if (faceFeature != null) {
        print('✅ Enrollment Success!');
        print('📝 FaceID: $faceId');
        print('🔑 Face Feature (first 100 chars): ${faceFeature.substring(0, faceFeature.length > 100 ? 100 : faceFeature.length)}...');
        print('📏 Feature Length: ${faceFeature.length} characters');

        // Update state
        setState(() {
          _enrolledFaceID = faceId;
          _enrolledFaceData = faceFeature;
        });

        _showMessage('Enrollment Success! Check logs for feature');
      } else {
        print('❌ Enrollment returned null feature');
        _showMessage('Enrollment failed: No feature returned');
      }
    } catch (e) {
      print('❌ Enrollment Error: $e');
      _showMessage('Enroll Failed: $e');
    }
  }

  Future<void> _verify() async {
    if (!_isInitialized) {
      _showMessage('Initialize SDK first');
      return;
    }
    if (_enrolledFaceID == null) {
      _showMessage('Enroll face first');
      return;
    }
    try {
      await _faceAiSdk.startVerify(
        _enrolledFaceID!,
        livenessType: _livenessType,
        motionStepSize: 2,
        motionTimeout: 9,
        threshold: 0.85,
      );
    } catch (e) {
      _showMessage('Verify Failed: $e');
    }
  }

  Future<void> _startLivenessTest() async {
    if (!_isInitialized) {
      _showMessage('Initialize SDK first');
      return;
    }
    try {
      await _faceAiSdk.startLivenessDetection(
        livenessType: _livenessType,
        motionStepSize: 2,
        motionTimeout: 9,
      );
    } catch (e) {
      _showMessage('Liveness Test Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face AI SDK Demo'),
        centerTitle: true,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Status Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoText('Platform', _platformVersion),
                  const SizedBox(height: 8),
                  _InfoText(
                    'SDK Status',
                    _status,
                    valueColor: _isInitialized ? Colors.green : null,
                  ),
                  const SizedBox(height: 8),
                  _InfoText(
                    'Face Data',
                    _enrolledFaceID != null ? 'Enrolled ✓ ($_enrolledFaceID)' : 'Not Enrolled',
                    valueColor: _enrolledFaceID != null ? Colors.green : null,
                  ),
                  const SizedBox(height: 8),
                  _InfoText('Last Event', _lastEvent),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Face ID Input
            TextField(
              controller: _faceIdController,
              decoration: InputDecoration(
                labelText: 'Face ID / Name',
                hintText: 'Enter user ID (e.g., user123)',
                prefixIcon: const Icon(Icons.badge),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              enabled: _isInitialized,
            ),

            const SizedBox(height: 16),

            // Buttons
            ElevatedButton.icon(
              onPressed: _isInitialized ? null : _initSDK,
              icon: const Icon(Icons.power_settings_new),
              label: const Text('Initialize SDK'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _isInitialized ? _enroll : null,
              icon: const Icon(Icons.person_add),
              label: const Text('Enroll Face'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed:
                  _isInitialized && _enrolledFaceID != null ? _verify : null,
              icon: const Icon(Icons.verified_user),
              label: const Text('Verify Face'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 12),

            // ElevatedButton.icon(
            //   onPressed: _isInitialized ? _startLivenessTest : null,
            //   icon: const Icon(Icons.face_retouching_natural),
            //   label: const Text('Liveness Test'),
            //   style: ElevatedButton.styleFrom(
            //     padding: const EdgeInsets.symmetric(vertical: 14),
            //     backgroundColor: Colors.orange,
            //     foregroundColor: Colors.white,
            //   ),
            // ),
            //
            // const SizedBox(height: 24),

            // Liveness Type Selector
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Liveness Detection Type:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _LivenessChip(
                        label: 'None',
                        value: 0,
                        selected: _livenessType == 0,
                        onSelected: () => setState(() => _livenessType = 0),
                      ),
                      _LivenessChip(
                        label: 'Motion',
                        value: 1,
                        selected: _livenessType == 1,
                        onSelected: () => setState(() => _livenessType = 1),
                      ),
                      _LivenessChip(
                        label: 'Flash+Motion',
                        value: 2,
                        selected: _livenessType == 2,
                        onSelected: () => setState(() => _livenessType = 2),
                      ),
                      _LivenessChip(
                        label: 'Flash',
                        value: 3,
                        selected: _livenessType == 3,
                        onSelected: () => setState(() => _livenessType = 3),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instructions:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _InstructionText('1. Initialize SDK'),
                  _InstructionText('2. Select liveness type'),
                  _InstructionText('3. Enroll your face'),
                  _InstructionText('4. Test liveness or verify'),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _InfoText extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoText(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.black87,
              fontWeight: valueColor != null ? FontWeight.bold : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _InstructionText extends StatelessWidget {
  final String text;

  const _InstructionText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: Colors.blue[800]),
      ),
    );
  }
}

class _LivenessChip extends StatelessWidget {
  final String label;
  final int value;
  final bool selected;
  final VoidCallback onSelected;

  const _LivenessChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: Colors.blue[100],
      checkmarkColor: Colors.blue[700],
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
