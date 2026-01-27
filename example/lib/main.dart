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

class FaceData {
  final String feature;
  final DateTime enrolledAt;
  final int index;

  FaceData({
    required this.feature,
    required this.enrolledAt,
    required this.index,
  });
}

class _FaceAIHomePageState extends State<FaceAIHomePage> {
  final _faceAiSdk = FlutterFaceAiSdk();
  final _faceIdController = TextEditingController();
  String _platformVersion = 'Loading...';
  String _status = 'Not Initialized';
  String _lastEvent = 'No events';
  List<FaceData> _enrolledFaces = []; // Changed to FaceData objects
  String? _enrolledFaceID;
  bool _isInitialized = false;
  int _livenessType = 1; // 0: NONE, 1: MOTION, 2: COLOR_FLASH_MOTION, 3: COLOR_FLASH
  //StreamSubscription<Map<String, dynamic>>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _initPlatform();
    _listenEvents();
  }

  @override
  void dispose() {
    //_eventSubscription?.cancel();
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
    /*_eventSubscription = _faceAiSdk.getFaceEventStream().listen(
      (event) {
        print('📱 Flutter received event: $event');

        final eventName = event['event'] as String?;
        final code = event['code'] as int?;
        final faceData = event['face_base64'] as String?;
        final faceID = event['faceID'] as String?;

        print('📱 Event: $eventName, Code: $code, FaceID: $faceID');

        setState(() {
          _lastEvent = '$eventName - ${code == 1 ? "Success" : "Failed"}';

          if (eventName == 'Enrolled' && code == 1 && faceData != null) {
            // Append new face feature to the list with timestamp
            _enrolledFaces.add(FaceData(
              feature: faceData,
              enrolledAt: DateTime.now(),
              index: _enrolledFaces.length + 1,
            ));
            _enrolledFaceID = faceID;
            print('✅ Face enrolled! FaceID: $faceID');
            print('📊 Total enrolled faces: ${_enrolledFaces.length}');
            print('📏 Feature Length: ${faceData.length} characters');
            _showMessage('Face #${_enrolledFaces.length} Enrolled Successfully');
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
    );*/
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
      print('🚀 Starting enrollment #${_enrolledFaces.length + 1} with faceId: $faceId');

      // Call startEnroll with faceId
      final faceFeature = await _faceAiSdk.startEnroll(faceId);

      if (faceFeature != null) {
        print('✅ Enrollment Success!');
        print('📝 FaceID: $faceId');
        print('🔑 Face Feature (first 100 chars): ${faceFeature.substring(0, faceFeature.length > 100 ? 100 : faceFeature.length)}...');
        print('📏 Feature Length: ${faceFeature.length} characters');

        // Append to list instead of replacing
        setState(() {
          _enrolledFaceID = faceId;
          _enrolledFaces.add(FaceData(
            feature: faceFeature,
            enrolledAt: DateTime.now(),
            index: _enrolledFaces.length + 1,
          ));
        });

        print('📊 Total enrolled faces: ${_enrolledFaces.length}');
        _showMessage('Face #${_enrolledFaces.length} Enrolled Successfully!');
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
    if (_enrolledFaces.isEmpty) {
      _showMessage('Enroll face first');
      return;
    }
    try {
      print('🔍 Starting verification with ${_enrolledFaces.length} face feature(s)');

      // Extract face features from FaceData objects
      final faceFeatures = _enrolledFaces.map((face) => face.feature).toList();

      // Log first 50 chars of each face feature
      for (int i = 0; i < faceFeatures.length; i++) {
        final preview = faceFeatures[i].substring(
          0,
          faceFeatures[i].length > 50 ? 50 : faceFeatures[i].length
        );
        print('   Face #${i + 1} (first 50 chars): $preview...');
      }

      // Pass ALL enrolled face features as List<String>
      final result = await _faceAiSdk.startVerify(
        faceFeatures,  // Pass entire list of face features
        livenessType: _livenessType,
        motionStepSize: 2,
        motionTimeout: 9,
        threshold: 0.85,
      );

      print('✅ Verification Result: $result');

      if (result == 'Verify') {
        _showMessage('✓ Verified! (Matched with one of ${_enrolledFaces.length} faces)');
      } else {
        _showMessage('✗ Not Verified (Tried ${_enrolledFaces.length} faces)');
      }
    } catch (e) {
      print('❌ Verification Error: $e');
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

  void _clearAllFaces() {
    setState(() {
      _enrolledFaces.clear();
      _enrolledFaceID = null;
    });
    print('🗑️ All enrolled faces cleared');
    _showMessage('All enrolled faces cleared');
  }

  void _deleteFace(int index) {
    setState(() {
      _enrolledFaces.removeAt(index);
      // Re-index remaining faces
      for (int i = 0; i < _enrolledFaces.length; i++) {
        _enrolledFaces[i] = FaceData(
          feature: _enrolledFaces[i].feature,
          enrolledAt: _enrolledFaces[i].enrolledAt,
          index: i + 1,
        );
      }
    });
    print('🗑️ Face #${index + 1} deleted');
    _showMessage('Face #${index + 1} deleted');
  }

  void _showFaceDetailsDialog(FaceData faceData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Face #${faceData.index} Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow('Enrolled At', _formatDateTime(faceData.enrolledAt)),
              const SizedBox(height: 12),
              _DetailRow('Feature Length', '${faceData.feature.length} chars'),
              const SizedBox(height: 12),
              const Text(
                'Feature Preview:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  faceData.feature.substring(
                    0,
                    faceData.feature.length > 200 ? 200 : faceData.feature.length
                  ) + '...',
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
                    'Enrolled Faces',
                    _enrolledFaces.isEmpty
                        ? 'None'
                        : '${_enrolledFaces.length} face(s) ✓',
                    valueColor: _enrolledFaces.isNotEmpty ? Colors.green : null,
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
                  _isInitialized && _enrolledFaces.isNotEmpty ? _verify : null,
              icon: const Icon(Icons.verified_user),
              label: Text('Verify Face (${_enrolledFaces.length})'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _enrolledFaces.isNotEmpty ? _clearAllFaces : null,
              icon: const Icon(Icons.delete_sweep),
              label: const Text('Clear All Faces'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),

            // Enrolled Faces List - Enhanced UI
            if (_enrolledFaces.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[300]!, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green[600],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.face,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Enrolled Faces',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[900],
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${_enrolledFaces.length} face${_enrolledFaces.length > 1 ? 's' : ''} registered',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[600],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_enrolledFaces.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    ..._enrolledFaces.asMap().entries.map((entry) {
                      final index = entry.key;
                      final faceData = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Colors.green[600],
                            child: Text(
                              '${faceData.index}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            'Face #${faceData.index}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 12,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDateTime(faceData.enrolledAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${faceData.feature.length} characters',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.info_outline,
                                  color: Colors.blue[600],
                                  size: 20,
                                ),
                                onPressed: () => _showFaceDetailsDialog(faceData),
                                tooltip: 'View Details',
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red[600],
                                  size: 20,
                                ),
                                onPressed: () => _deleteFace(index),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

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
                  _InstructionText('2. Enter Face ID and select liveness type'),
                  _InstructionText('3. Enroll multiple faces (repeat step 3)'),
                  _InstructionText('4. Verify with any enrolled face'),
                  _InstructionText('5. Clear all when done'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Multi-Face Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[800], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Multi-Face Feature: You can enroll multiple faces. During verification, the system will automatically try matching with all enrolled faces.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber[900],
                      ),
                    ),
                  ),
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}
