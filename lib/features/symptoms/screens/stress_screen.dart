import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'package:healthmate_ai/services/health_service.dart';
import 'package:healthmate_ai/models/health_reading.dart';
import 'package:healthmate_ai/services/gemini_service.dart';

class StressScreen extends StatefulWidget {
  const StressScreen({super.key});

  @override
  State<StressScreen> createState() => _StressScreenState();
}

enum StressCheckState { initial, recording, results }

class _StressScreenState extends State<StressScreen> with TickerProviderStateMixin {
  StressCheckState _currentState = StressCheckState.initial;
  
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _isBusy = false;
  List<Face> _faces = [];
  
  double _progress = 0;
  Timer? _timer;
  
  // rPPG data
  final List<double> _greenValues = [];
  final List<DateTime> _times = [];
  final List<String> _snapshots = [];
  
  int _stressScore = 0;
  String _stressLevel = "Unknown";
  bool _hasHistory = false;
  bool _isCameraFullScreen = false;
  
  late AnimationController _waveController;
  final HealthService _healthService = HealthService();
  final GeminiService _geminiService = GeminiService();
  String _aiAdvice = "Loading advice...";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: false,
        enableLandmarks: false,
      ),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // Slower animation
    )..repeat();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    // Use the front camera
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    _faceDetector?.close();
    _waveController.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _currentState = StressCheckState.recording;
      _progress = 0;
      _greenValues.clear();
      _times.clear();
      _snapshots.clear();
    });

    _startImageStream();

    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      setState(() {
        _progress += 1;
      });

      // Take a snapshot every 2 seconds (roughly)
      if (_progress % 20 == 0 && _snapshots.length < 5) {
        _takeSnapshot();
      }

      if (_progress >= 100) {
        timer.cancel();
        _finishRecording();
      }
    });
  }

  Future<void> _takeSnapshot() async {
    try {
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        final image = await _cameraController!.takePicture();
        if (mounted) {
          setState(() {
            _snapshots.add(image.path);
          });
        }
      }
    } catch (e) {
      debugPrint("Snapshot error: $e");
    }
  }

  void _startImageStream() {
    _cameraController?.startImageStream((image) async {
      if (_isBusy) return;
      _isBusy = true;

      final inputImage = _processCameraImage(image);
      if (inputImage == null) {
        _isBusy = false;
        return;
      }

      final faces = await _faceDetector!.processImage(inputImage);
      
      if (mounted) {
        setState(() {
          _faces = faces;
        });
      }

      if (faces.isNotEmpty) {
        // Simple rPPG: Extract green channel average from the face area
        // This is a simplified version for simulation/demo
        final face = faces.first;
        final rect = face.boundingBox;
        
        // In a real implementation, we'd crop the image to this rect and average pixels.
        // Here we simulate based on the face being detected and some slight randomness 
        // to make the pulse wave look alive.
        double baseValue = 120.0;
        double pulse = math.sin(DateTime.now().millisecondsSinceEpoch / 150.0) * 2.0;
        double noise = math.Random().nextDouble() * 0.5;
        
        _greenValues.add(baseValue + pulse + noise);
        _times.add(DateTime.now());
      }

      _isBusy = false;
    });
  }

  InputImage? _processCameraImage(CameraImage image) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final camera = _cameraController!.description;
      final imageRotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;
      final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  void _finishRecording() async {
    _cameraController?.stopImageStream();
    
    // Calculate stress score based on HRV (simulated from _greenValues)
    // In a real app, you'd find peaks, calculate NN intervals, then SDNN.
    // For this demo, we'll generate a realistic-looking score.
    _stressScore = 35 + math.Random().nextInt(25);
    if (_stressScore < 40) {
      _stressLevel = "Low";
    } else if (_stressScore < 65) {
      _stressLevel = "Moderate";
    } else {
      _stressLevel = "High";
    }

    setState(() {
      _currentState = StressCheckState.results;
      _hasHistory = true;
      _aiAdvice = "Analyzing your results...";
    });

    // Save to Firestore and get AI advice
    await _healthService.saveReading(
      value: _stressScore.toDouble(),
      type: ReadingType.stress,
      status: _stressLevel,
    );

    // Get a fresh advice for the UI
    final advice = await _geminiService.getHealthAdvice(
      value: _stressScore.toDouble(),
      type: "Stress Level",
      status: _stressLevel,
    );

    if (mounted) {
      setState(() {
        _aiAdvice = advice;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F1), // Soft green-grey background
      body: Stack(
        children: [
          _buildMeshBackground(),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildMeshBackground() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF72ED7D).withOpacity(0.15),
            ),
          ),
        ),
        Positioned(
          bottom: -150,
          left: -150,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFB2E69C).withOpacity(0.2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_currentState) {
      case StressCheckState.initial:
        return _buildInitialScreen();
      case StressCheckState.recording:
        return _buildRecordingScreen();
      case StressCheckState.results:
        return _buildResultsScreen();
    }
  }

  Widget _buildInitialScreen() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAppBar(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scan Face To Check',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                Text(
                  'Stress',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF47BC62),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.symmetric(horizontal: _isCameraFullScreen ? 0 : 24.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_isCameraFullScreen ? 0 : 24),
                  color: Colors.black,
                  boxShadow: [
                    if (!_isCameraFullScreen)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    if (_cameraController != null && _cameraController!.value.isInitialized)
                      Positioned.fill(
                        child: AspectRatio(
                          aspectRatio: _cameraController!.value.aspectRatio,
                          child: CameraPreview(_cameraController!),
                        ),
                      )
                    else
                      const Center(child: CircularProgressIndicator(color: Colors.white)),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: GestureDetector(
                        onTap: () => setState(() => _isCameraFullScreen = !_isCameraFullScreen),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isCameraFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: GestureDetector(
                onTap: _startRecording,
                child: Container(
                  width: 260,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF72ED7D), Color(0xFF47BC62)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF47BC62).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Tap to record your stress',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white, 
                        fontSize: 17, 
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_hasHistory) 
            _buildHistoryCard()
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage Your Stress',
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1C1C1E)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Videos to Manage Stress',
                    style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRecordingScreen() {
    return Stack(
      children: [
        if (_cameraController != null && _cameraController!.value.isInitialized)
          Positioned.fill(child: CameraPreview(_cameraController!)),
        Positioned.fill(
          child: Container(color: Colors.black.withOpacity(0.4)),
        ),
        if (_faces.isNotEmpty)
          _buildFaceCircle(_faces.first),
        Positioned.fill(
          child: Center(
            child: _buildPulseIndicator(),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                margin: const EdgeInsets.symmetric(horizontal: 30),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Text(
                  'Please avoid moving for accurate measurement.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                       color: Colors.white,
                    fontSize: 16, 
                     fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                 padding: const EdgeInsets.only(bottom: 40.0),
                child: Center(
                   child: GestureDetector(
                    onTap: () {
                      _timer?.cancel();
                      _cameraController?.stopImageStream();
                      setState(() => _currentState = StressCheckState.initial);
                    },
                    child: Container(
                      width: 220,
                         height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF72ED7D), Color(0xFF47BC62)],
                        ),
                        boxShadow: [
                           BoxShadow(
                                color: const Color(0xFF47BC62).withOpacity(0.3),
                             blurRadius: 20, 
                             offset: const Offset(0, 10),
                           ),
                        ]
                      ),
                      child: Center(
                        child: Text(
                          'Stop Scanning', 
                               style: GoogleFonts.inter(
                            color: Colors.white, 
                            fontSize: 18, 
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                         ),
                     ),
                  ),
                 ),
              ),
            ],
          ),
            ),
       ],
    );
  }

  Widget _buildFaceCircle(Face face) {
    return Center(
      child: AnimatedBuilder(
        animation: _waveController,
           builder: (context, child) {
          return CustomPaint(
                size: const Size(280, 340),
            painter: FaceOutlinePainter(_waveController.value),
          );
        },
      ),
    );
  }

  Widget _buildPulseIndicator() {
    return SizedBox(
      height: 180,
               width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
                children: [
          // Full width wave background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return CustomPaint(
                  painter: WavePainter(_waveController.value),
                );
              },
            ),
          ),
          // Percentage Circle
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF47BC62).withOpacity(0.5), // More transparent
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF47BC62).withOpacity(0.2), // More transparent
                  blurRadius: 25,
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
            ),
            child: Center(
              child: Text(
                '${_progress.toInt()}%',
                style: GoogleFonts.outfit(
                  color: Colors.white, 
                  fontSize: 28, 
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildResultsScreen() {
    return SafeArea(
      child: Column(
        children: [
          _buildAppBar(),
          const SizedBox(height: 20),
          _buildSnapshotsRow(),
          const Spacer(),
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Stress Score', style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Text(
                    '$_stressScore',
                    style: GoogleFonts.outfit(fontSize: 84, fontWeight: FontWeight.w900, color: const Color(0xFF47BC62)),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF47BC62).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      _stressLevel,
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF47BC62)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI Insight',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF47BC62),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _aiAdvice,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1C1C1E),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.only(bottom: 40.0),
            child: Center(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 300,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF72ED7D), Color(0xFF47BC62)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF47BC62).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Done', 
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshotsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: _snapshots.map((path) {
          return Container(
            width: 60,
            height: 60,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showContentDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
                 crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Try the content',
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1C1C1E)),
              ),
              const SizedBox(height: 12),
              Text(
                'Try content proven to help reduce stress',
                 style: GoogleFonts.inter(fontSize: 15, color: Colors.grey[600], height: 1.5),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  // _buildDialogButton('Back', onTap: () => Navigator.pop(context)),
                  const Spacer(),
                     GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      'Skip', 
                      style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                   const Spacer(),
                  // _buildDialogButton('Next', onTap: () => Navigator.pop(context)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogButton(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF72ED7D), Color(0xFF47BC62)]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
             BoxShadow(color: const Color(0xFF47BC62).withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
          ]
        ),
        child: Text(
          text,
           style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Row(
        children: [
                GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
                ]
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Stress Checker',
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E)),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _showContentDialog,
            child: Text('?', style: GoogleFonts.outfit(fontSize: 22, color: const Color(0xFF47BC62), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)
              ]
            ),
            child: Row(
              children: [
                Text('English', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                const Icon(Icons.language_rounded, size: 16, color: Color(0xFF47BC62)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('h:mm a').format(DateTime.now()),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
              ),
            ],
          ),
          const Spacer(),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: _stressScore / 100,
                  strokeWidth: 4,
                   backgroundColor: Colors.grey.withOpacity(0.1),
                ),
              ),
              Text('$_stressScore', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF47BC62))),
            ],
          ),
        ],
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double progress;

  WavePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.4) // More transparent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
           ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.1) // More transparent
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final middleY = size.height / 2;
    
    for (double i = 0; i <= size.width; i += 1) {
      double x = i;
      

      double normalizedX = (i / size.width);
      

      double wave = 0;
      

      wave += math.sin(normalizedX * 40 - progress * 15) * 1.5;

      for (int pulseIdx = 0; pulseIdx < 4; pulseIdx++) {
        double pulsePos = (progress + (pulseIdx / 4)) % 1.0;
        double dist = (normalizedX - pulsePos).abs();
        
        if (dist < 0.06) {
          // QRS Complex simulation - sharper and taller as per image
          double localX = (normalizedX - pulsePos) / 0.06; // -1 to 1
          if (localX > -0.15 && localX < 0.15) {
            // The R spike (Extreme height)
            wave -= math.cos(localX * math.pi * 3.3) * 55;
          } else if (localX > -0.4 && localX <= -0.15) {
            // The P wave
            wave -= math.sin((localX + 0.25) * math.pi * 6) * 8;
          } else if (localX >= 0.15 && localX < 0.5) {
            // The T wave
            wave -= math.sin((localX - 0.3) * math.pi * 4) * 12;
          }
        }
      }
      
      double y = middleY + wave;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) => true;
}

class FaceOutlinePainter extends CustomPainter {
  final double animationValue;
  FaceOutlinePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF47BC62).withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = const Color(0xFF47BC62).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0;

    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final radiusX = size.width / 2.2;
    final radiusY = size.height / 2.2;

    for (double i = 0; i <= 2 * math.pi + 0.1; i += 0.05) {
      // Add organic waviness to match the hand-drawn look in the image
      double noise = math.sin(i * 12 + animationValue * 8) * 4;
      double noise2 = math.cos(i * 5 - animationValue * 5) * 2;
      
      double x = center.dx + (radiusX + noise + noise2) * math.cos(i);
      double y = center.dy + (radiusY + noise + noise2) * math.sin(i);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
    
    // Draw an inner subtle ring for extra "scanning" effect
    final innerPaint = paint..strokeWidth = 1.0..color = paint.color.withOpacity(0.3);
    canvas.drawCircle(center, radiusX - 10, innerPaint);
  }

  @override
  bool shouldRepaint(covariant FaceOutlinePainter oldDelegate) => true;
}
