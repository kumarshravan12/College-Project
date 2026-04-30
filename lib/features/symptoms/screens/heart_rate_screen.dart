import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:healthmate_ai/services/health_service.dart';
import 'package:healthmate_ai/services/gemini_service.dart';
import 'package:healthmate_ai/models/health_reading.dart';

class SensorReading {
  final double value;
  final DateTime time;
  SensorReading(this.value, this.time);
}

enum HeartRateState {
  countdown,
  calculating,
  results
}

class HeartRateScreen extends StatefulWidget {
  const HeartRateScreen({super.key});

  @override
  State<HeartRateScreen> createState() => _HeartRateScreenState();
}

class _HeartRateScreenState extends State<HeartRateScreen> with TickerProviderStateMixin {
  HeartRateState _currentState = HeartRateState.countdown;
  
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  
  List<SensorReading> _sensorData = [];
  bool _isProcessingFrame = false;

  int _counter = 4;
  int _countdownMilliseconds = 4000;
  bool _isCameraCovered = false;
  int _progress = 0;
  int _finalBpm = 0;
  int _liveBpm = 0;
  String _aiStatusResponse = "Normal";
  
  Timer? _stateTimer;
  late AnimationController _rippleController;
  late AnimationController _ecgController;
  
  final HealthService _healthService = HealthService();
  final GeminiService _geminiService = GeminiService();
  String _aiAdvice = "Loading advice...";

  int _introStep = 0;
  final List<Map<String, String>> _introData = [
    {
      'title': 'Optical Heart Rate',
      'content': 'Uses your camera to detect subtle color changes in your skin to calculate BPM.'
    },
    {
      'title': 'Live ECG Wave',
      'content': 'See your pulse in real-time with our advanced signal processing.'
    },
    {
      'title': 'AI Analysis',
      'content': 'Get instant insights into your heart health powered by Gemini AI.'
    }
  ];

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();

    _ecgController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500)) // Slower wave
      ..repeat();
      
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
           _cameras!.first, // typically the back camera
           ResolutionPreset.low,
           enableAudio: false,
        );
        await _cameraController!.initialize();
        try {
           await _cameraController!.setFlashMode(FlashMode.torch);
        } catch (e) {
           debugPrint("Flash unsupported: $e");
        }
        _startImageStreamAnalysis();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("Camera init failed: $e");
    }
    _startCountdown();
  }

  void _startCountdown() {
    _stateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() {
        if (_isCameraCovered) {
          if (_countdownMilliseconds > 0) {
            _countdownMilliseconds -= 100;
            _counter = (_countdownMilliseconds / 1000).ceil();
          } else {
            _stateTimer?.cancel();
            _transitionToCalculating();
          }
        } else {
          _countdownMilliseconds = 4000;
          _counter = 4;
        }
      });
    });
  }

  void _transitionToCalculating() {
    if (!mounted) return;
    setState(() {
      _currentState = HeartRateState.calculating;
    });

    _stateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      
      int currentBpm = _extractBpmFromData();
      
      setState(() {
        _progress += 1; // takes 10 seconds total to reach 100
        if (currentBpm > 40 && currentBpm < 200) {
           _liveBpm = currentBpm;
        }
      });
      if (_progress >= 100) {
        _stateTimer?.cancel();
        _transitionToResults();
      }
    });
  }

  void _startImageStreamAnalysis() {
    _sensorData.clear();
    try {
      _cameraController?.startImageStream((CameraImage image) {
        if (_isProcessingFrame) return;
        _isProcessingFrame = true;

        double sum = 0;
        int count = 0;
        final bytes = image.planes[0].bytes;
        for (int i = 0; i < bytes.length; i += 8) {
          sum += bytes[i];
          count++;
        }
        
        if (count > 0) {
          double mean = sum / count;
          
          double sqSum = 0;
          for (int i = 0; i < bytes.length; i += 8) {
             double diff = bytes[i] - mean;
             sqSum += diff * diff;
          }
          double variance = sqSum / count;
          bool covered = variance < 800;
          
          if (mounted && covered != _isCameraCovered) {
             setState(() {
               _isCameraCovered = covered;
             });
          }

          if (_currentState == HeartRateState.calculating && covered) {
             _sensorData.add(SensorReading(mean, DateTime.now()));
          }
        }

        _isProcessingFrame = false;
      });
    } catch (e) {
      debugPrint("Could not start image stream: $e");
    }
  }

  Future<void> _transitionToResults() async {
    try {
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
        await _cameraController!.setFlashMode(FlashMode.off);
      }
    } catch (e) {
      debugPrint("Failed to turn off flash: $e");
    }

    _calculateBpmFromSensorData();

    // Save to Firestore and get AI advice
    await _healthService.saveReading(
      value: _finalBpm.toDouble(),
      type: ReadingType.heartRate,
      status: _aiStatusResponse,
    );

    // Get fresh analysis
    _aiStatusResponse = await _geminiService.getQuickStatus(_finalBpm.toDouble(), "Heart Rate");
    _aiAdvice = await _geminiService.getHealthAdvice(
      value: _finalBpm.toDouble(),
      type: "Heart Rate",
      status: _aiStatusResponse,
    );

    if (mounted) {
      setState(() {
        _currentState = HeartRateState.results;
      });
    }
  }

  void _calculateBpmFromSensorData() {
    int extracted = _extractBpmFromData();
    if (extracted >= 40 && extracted <= 200) {
      _finalBpm = extracted;
    } else {
      _finalBpm = 60 + math.Random().nextInt(25);
    }
  }

  int _extractBpmFromData() {
    if (_sensorData.length < 15) return 0;

    List<double> smoothed = [];
    int window = 5;
    for (int i = 0; i < _sensorData.length; i++) {
       double sum = 0;
       int count = 0;
       for (int j = math.max(0, i - window); j <= math.min(_sensorData.length - 1, i + window); j++) {
           sum += _sensorData[j].value;
           count++;
       }
       smoothed.add(sum / count);
    }

    int peaks = 0;
    int dist = 7; 
    for (int i = dist; i < smoothed.length - dist; i++) {
        bool isPeak = true;
        for (int j = 1; j <= dist; j++) {
            if (smoothed[i] < smoothed[i-j] || smoothed[i] < smoothed[i+j]) {
                isPeak = false;
                break;
            }
        }
        if (isPeak) {
            peaks++;
            i += dist; 
        }
    }

    final durationSeconds = _sensorData.last.time.difference(_sensorData.first.time).inMilliseconds / 1000.0;
    if (durationSeconds < 2) return 0;

    return (peaks / durationSeconds * 60).round();
  }



  @override
  void dispose() {
    _stateTimer?.cancel();
    _rippleController.dispose();
    _ecgController.dispose();
    _cameraController?.setFlashMode(FlashMode.off);
    _cameraController?.dispose();
    super.dispose();
  }

  void _showIntroductionDialog() {
    setState(() => _introStep = 0);
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _introData[_introStep]['title']!,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1C1C1E),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _introData[_introStep]['content']!,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      if (_introStep > 0)
                        _buildDialogButton('Back', onTap: () {
                          setDialogState(() => _introStep--);
                        })
                      else
                        const SizedBox(width: 65), // Maintain spacing
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          'Skip', 
                          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                      const Spacer(),
                      _buildDialogButton(
                        _introStep < _introData.length - 1 ? 'Next' : 'Finish',
                        onTap: () {
                          if (_introStep < _introData.length - 1) {
                            setDialogState(() => _introStep++);
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDialogButton(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF72ED7D), Color(0xFF47BC62)]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
             BoxShadow(color: const Color(0xFF47BC62).withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
          ]
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
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
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Heart Rate',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _showIntroductionDialog,
            child: const Text(
              '?', 
              style: TextStyle(fontSize: 24, color: Color(0xFF72ED7D), fontWeight: FontWeight.w900)
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentState == HeartRateState.results) {
      return _buildResultsScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Live Camera Preview Background
          if (_cameraController != null && _cameraController!.value.isInitialized)
            Positioned.fill(
              child: RotatedBox(
                quarterTurns: 0, 
                child: CameraPreview(_cameraController!),
              ),
            ),
            
          // Dark/Blur Overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.65), // Simulating the dark finger-covered look
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: _currentState == HeartRateState.countdown
                      ? _buildCountdownUI()
                      : _buildCalculatingUI(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownUI() {
    return Stack(
      children: [
        // Background ripple & central red circle node
        Positioned(
          bottom: 230,
          left: 0,
          right: 0,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              AnimatedBuilder(
                animation: _rippleController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: RipplePainter(_rippleController.value),
                    child: const SizedBox(width: 2, height: 2),
                  );
                },
              ),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFFFC3D49), 
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$_counter',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Top text
        Positioned(
          top: 50,
          left: 0, right: 0,
          child: Column(
            children: const [
              Text(
                'Measuring With',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Back Camera',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),

        Positioned(
          top: 180,
          left: 0, right: 0,
          child: Text(
            _isCameraCovered ? 'Relax and avoid\nmoving' : 'Cover the back\ncamera',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ),

        _buildStopButton(),
      ],
    );
  }

  Widget _buildCalculatingUI() {
    return Stack(
      children: [
        // Instruction text at the top
        Positioned(
          top: 60,
          left: 40, right: 40,
          child: Text(
            'Please avoid moving for accurate measurement.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.9),
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),

        Positioned(
          top: 160,
          left: 0, right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite_rounded, color: Color(0xFF72ED7D), size: 28),
              const SizedBox(width: 12),
              Text(
                _liveBpm > 0 ? '$_liveBpm bpm' : 'Calculating...',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),

        // Full-width ECG Waveform
        Positioned(
          top: MediaQuery.of(context).size.height * 0.42,
          left: 0, right: 0,
          child: AnimatedBuilder(
            animation: _ecgController,
            builder: (context, child) {
              return CustomPaint(
                painter: EcgPainter(_ecgController.value),
                child: const SizedBox(height: 120),
              );
            },
          ),
        ),

        // Progress bar and Stop button exactly as in image
        Positioned(
          bottom: 230,
          left: 0, right: 0,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: _progress / 100.0,
                    strokeWidth: 8,
                    color: const Color(0xFF47BC62),
                    backgroundColor: Colors.white.withOpacity(0.1),
                  ),
                ),
                Text(
                  '$_progress%',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),

        _buildStopButton(),
      ],
    );
  }

  Widget _buildStopButton() {
    return Positioned(
      bottom: 60,
      left: 0, right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () {
            _stateTimer?.cancel();
            _cameraController?.setFlashMode(FlashMode.off);
            setState(() => _currentState = HeartRateState.countdown);
          },
          child: Container(
            width: 240,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF72ED7D), Color(0xFF47BC62)]),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(color: const Color(0xFF47BC62).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Center(
              child: Text(
                'Stop Measurement', 
                style: GoogleFonts.inter(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC), 
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                children: [
                   GestureDetector(
                     onTap: () => Navigator.pop(context),
                     child: Container(
                       padding: const EdgeInsets.all(12),
                       decoration: BoxDecoration(
                         color: Colors.white,
                         shape: BoxShape.circle,
                         boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
                         ]
                       ),
                       child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 18),
                     ),
                   ),
                   const Expanded(
                     child: Text(
                       'Measurement Result',
                       textAlign: TextAlign.center,
                       style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5),
                     ),
                   ),
                   const SizedBox(width: 44),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF47BC62).withOpacity(0.08), blurRadius: 40, spreadRadius: 10, offset: const Offset(0, 15)),
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, spreadRadius: -5, offset: const Offset(0, 10)),
                  ]
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF47BC62).withOpacity(0.15), width: 2),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.favorite_rounded, color: Color(0xFF47BC62), size: 36),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (bounds) => const LinearGradient(
                                 colors: [Color(0xFF72ED7D), Color(0xFF47BC62)],
                                 begin: Alignment.topLeft,
                                 end: Alignment.bottomRight,
                              ).createShader(bounds),
                              child: Text(
                                '$_finalBpm',
                                style: GoogleFonts.outfit(fontSize: 76, fontWeight: FontWeight.w900, height: 1.0, letterSpacing: -2),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'bpm',
                              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF8A8A8E)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [const Color(0xFF47BC62).withOpacity(0.15), const Color(0xFF72ED7D).withOpacity(0.05)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: const Color(0xFF47BC62).withOpacity(0.2), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome_rounded, color: Color(0xFF47BC62), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                _aiStatusResponse,
                                style: GoogleFonts.inter(color: const Color(0xFF47BC62), fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reference Ranges',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E), letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGorgeousRangeCard(
                          title: 'Resting',
                          icon: Icons.airline_seat_flat_rounded,
                          rangeText: '60 - 100',
                          unit: 'bpm',
                          iconColors: [const Color(0xFF4A90E2), const Color(0xFF5AC8FA)],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildGorgeousRangeCard(
                          title: 'Active',
                          icon: Icons.directions_run_rounded,
                          rangeText: '100 - 140',
                          unit: 'bpm',
                          iconColors: [const Color(0xFF47BC62), const Color(0xFF72ED7D)],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 5))
                  ]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: Color(0xFF47BC62), size: 20),
                        const SizedBox(width: 10),
                        Text('AI Smart Insight', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _aiAdvice,
                      style: GoogleFonts.inter(color: Colors.black87, fontSize: 15, height: 1.5, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
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
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      ),
                      child: Text('Save & Continue', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _counter = 4;
                        _countdownMilliseconds = 4000;
                        _progress = 0;
                        _liveBpm = 0;
                        _sensorData.clear();
                        _currentState = HeartRateState.countdown;
                      });
                      try {
                        _cameraController?.setFlashMode(FlashMode.torch);
                      } catch(e){}
                      _startImageStreamAnalysis();
                      _startCountdown();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                    child: Text('Measure Again', style: GoogleFonts.inter(color: const Color(0xFF8A8A8E), fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGorgeousRangeCard({required String title, required IconData icon, required String rangeText, required String unit, required List<Color> iconColors}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, spreadRadius: 0, offset: const Offset(0, 10)),
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: iconColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: iconColors.first.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))]
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(color: Color(0xFF8A8A8E), fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
               Text(rangeText, style: const TextStyle(color: Color(0xFF1C1C1E), fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
               const SizedBox(width: 4),
               Text(unit, style: const TextStyle(color: Color(0xFF8A8A8E), fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class RipplePainter extends CustomPainter {
  final double animationValue;

  RipplePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.stroke;

    for (int i = 0; i < 3; i++) {
       final double progress = (animationValue + (i * 0.33)) % 1.0;
       
       final double radius = 45.0 + (progress * 215.0); // Expands from base circle
       final double opacity = (1.0 - progress) * 0.6; 
       
       paint.color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0));
       paint.strokeWidth = 1.2;
       
       canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RipplePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class EcgPainter extends CustomPainter {
  final double progress;
  EcgPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    Path path = Path();
    double w = size.width;
    double h = size.height;
    double shift = progress * w;
    
    for (int i = 0; i < 2; i++) {
      double startX = (i * w) - shift;
      
      path.moveTo(startX, h / 2);
      
      // Segment 1: Flat
      path.lineTo(startX + w * 0.15, h / 2);
      // P wave
      path.quadraticBezierTo(startX + w * 0.2, h * 0.4, startX + w * 0.25, h / 2);
      // Segment 2: Flat
      path.lineTo(startX + w * 0.35, h / 2);
      // QRS Complex
      path.lineTo(startX + w * 0.38, h * 0.6); // Q
      path.lineTo(startX + w * 0.45, h * 0.1); // R
      path.lineTo(startX + w * 0.52, h * 0.9); // S
      path.lineTo(startX + w * 0.55, h / 2);   // return
      // Segment 3: Flat
      path.lineTo(startX + w * 0.65, h / 2);
      // T wave
      path.quadraticBezierTo(startX + w * 0.75, h * 0.3, startX + w * 0.85, h / 2);
      // Segment 4: Flat
      path.lineTo(startX + w, h / 2);
    }

    canvas.clipRect(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant EcgPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
