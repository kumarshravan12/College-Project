import 'package:flutter/material.dart';
import 'package:healthmate_ai/services/auth_service.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:healthmate_ai/features/symptoms/screens/heart_rate_screen.dart';
import 'package:healthmate_ai/features/symptoms/screens/stress_screen.dart';

class SymptomsScreen extends StatefulWidget {
  const SymptomsScreen({super.key});

  @override
  State<SymptomsScreen> createState() => _SymptomsScreenState();
}

class _SymptomsScreenState extends State<SymptomsScreen> {
  int _currentInsightIndex = 0;
  bool _isLoadingInsight = false;
  List<InlineSpan> _dynamicAiInsight = [];

  // Fetching Gemini API Key from .env
  String get _geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  final List<List<InlineSpan>> _insights = [
    [
      const TextSpan(text: 'Drinking a glass of water\n'),
      const TextSpan(
        text: 'right after waking up ',
        style: TextStyle(
          color: Color(0xFF2E5336),
          decoration: TextDecoration.underline,
          decorationColor: Color(0xFF2E5336), 
        ),
      ),
      const TextSpan(text: 'boosts\nyour metabolism by '),
      const TextSpan(
        text: '24%.',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
    [
      const TextSpan(text: 'A brisk walk for just\n'),
      const TextSpan(
        text: '15 minutes daily ',
        style: TextStyle(
          color: Color(0xFF2E5336),
          decoration: TextDecoration.underline,
          decorationColor: Color(0xFF2E5336), 
        ),
      ),
      const TextSpan(text: 'can reduce\nstress levels by '),
      const TextSpan(
        text: '30%.',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
    [
      const TextSpan(text: 'Getting at least\n'),
      const TextSpan(
        text: '7 hours of sleep ',
        style: TextStyle(
          color: Color(0xFF2E5336),
          decoration: TextDecoration.underline,
          decorationColor: Color(0xFF2E5336), 
        ),
      ),
      const TextSpan(text: 'enhances\nimmune function by '),
      const TextSpan(
        text: '40%.',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  ];

  int _refreshCount = 0;

  Future<void> _fetchAiInsight() async {
    setState(() {
      _isLoadingInsight = true;
    });

    try {
      if (_geminiApiKey.isEmpty || _geminiApiKey == 'YOUR_API_KEY') {
        // Fallback if the user hasn't put their API key in yet
        await Future.delayed(const Duration(milliseconds: 600));
        setState(() {
          _currentInsightIndex = (_currentInsightIndex + 1) % _insights.length;
          _dynamicAiInsight = []; // Clear AI insight to use hardcoded list
          _refreshCount++;
          _isLoadingInsight = false;
        });
        return;
      }

      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _geminiApiKey);
      final prompt = 'Generate a short 1-sentence interesting health tip. Use *word* for underlining the key action or habit, and **value** for highlighting the key metric or statistic. Do not use quotes context. Keep it exactly one short sentence!';
      
      final response = await model.generateContent([Content.text(prompt)]);
      
      if (response.text != null && response.text!.isNotEmpty) {
        setState(() {
          _dynamicAiInsight = _parseMarkdownToSpans(response.text!);
          _refreshCount++;
          _isLoadingInsight = false;
        });
      } else {
        throw Exception("Empty AI response");
      }
    } catch (e) {
      debugPrint("Failed to load AI tip: $e");
      // Fallback
       setState(() {
        _currentInsightIndex = (_currentInsightIndex + 1) % _insights.length;
        _dynamicAiInsight = [];
        _refreshCount++;
        _isLoadingInsight = false;
      });
    }
  }

  List<InlineSpan> _parseMarkdownToSpans(String text) {
    final spans = <InlineSpan>[];
    final RegExp exp = RegExp(r'\*\*(.*?)\*\*|\*(.*?)\*');
    int start = 0;
    
    for (final match in exp.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      if (match.group(1) != null) {
        // **Bold** (Value/Stat)
        spans.add(TextSpan(
          text: match.group(1), 
          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2C2C2C), fontSize: 24)
        ));
      } else if (match.group(2) != null) {
        // *Italic/Single Asterisk* (Underline action)
        spans.add(TextSpan(
          text: match.group(2), 
          style: const TextStyle(decoration: TextDecoration.underline, decorationColor: Color(0xFF2E5336), color: Color(0xFF2E5336))
        ));
      }
      start = match.end;
    }
    
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().getCurrentUser();
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB), 
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, user),
              const SizedBox(height: 32),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'Check Your Symptoms Here...',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2C2C2C),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _buildActionBox(
                title: 'Heart rate',
                subtitle: 'Track your beat & flow.',
                icon: Icons.monitor_heart_rounded,
                gradientColors: [const Color(0xFFDCFCE7), const Color(0xFFBBE5CE)],
                textColor: const Color(0xFF14532D),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HeartRateScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              _buildActionBox(
                title: 'Check Stress',
                subtitle: 'Calculate mental load.',
                icon: Icons.psychology_rounded,
                gradientColors: [const Color(0xFFF3E8FF), const Color(0xFFE2D1F9)],
                textColor: const Color(0xFF581C87),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StressScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.cable_outlined, color: Color(0xFF64748B), size: 16),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Upcoming Features..',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 250, // Gives enough room for the 200px card + its massive drop shadow
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  padding: const EdgeInsets.symmetric(horizontal: 30.0),
                  clipBehavior: Clip.none,
                  children: [
                    _buildComingSoonCard(
                      title: 'Emotional\nWellness',
                      icon: Icons.spa_rounded,
                      color: const Color(0xFFF4A261),
                    ),
                    _buildComingSoonCard(
                      title: 'FaceScan\nPro',
                      icon: Icons.document_scanner_rounded,
                      color: const Color(0xEF24CA22),
                    ),
                    _buildComingSoonCard(
                      title: 'Sleep\nScore',
                      icon: Icons.nights_stay_rounded,
                      color: const Color(0xFF4EA8DE),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildDailyInsight(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, user) {
    final emailHeader = user?.email?.split('@')[0] ?? 'User';
    final avatarUrl = 'https://ui-avatars.com/api/?name=$emailHeader&background=193B1F&color=fff&size=150';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF193B1F),
            backgroundImage: NetworkImage(avatarUrl),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'WELCOME BACK',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.black45,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.auto_awesome, color: Color(0xFFFFB300), size: 14),
                ],
              ),
              Row(
                children: [
                  Text(
                    emailHeader.length > 10 ? 'HealthMate AI' : 'HealthMate AI',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF193B1F),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 10),
                  )
                ],
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.close_rounded, color: Colors.black87, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBox({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required Color textColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24.0),
        height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withOpacity(0.5),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            Positioned(
              right: -25,
              bottom: -25,
              child: Transform.rotate(
                angle: -0.1,
                child: Icon(
                  icon,
                  size: 160,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 28.0, top: 28.0, bottom: 28.0, right: 80.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor.withOpacity(0.75),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 24,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: textColor.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                ),
                child: Icon(Icons.arrow_forward_rounded, color: textColor, size: 20),
              ),
            )
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildComingSoonCard({
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 160, 
      height: 200,
      margin: const EdgeInsets.only(right: 16, bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [color.withOpacity(0.12), Colors.transparent],
                  stops: const [0.2, 1.0],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.12),
                  ),
                  child: Center(
                    child: Icon(icon, color: color, size: 32),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.1)),
                  ),
                  child: Text(
                    'COMING SOON',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                    height: 1.2,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Icon(
                Icons.lock_rounded,
                size: 16,
                color: color, 
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyInsight() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF5EA), 
              borderRadius: BorderRadius.circular(36),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Column(
                // Provide unique key to trigger animation
                key: ValueKey<bool>(_dynamicAiInsight.isEmpty && !_isLoadingInsight ? false : true),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF193B1F),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.lightbulb_outline_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'DAILY INSIGHT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2C2C2C),
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            'Health Tip of the Day',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _isLoadingInsight ? null : _fetchAiInsight,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _isLoadingInsight ? Colors.grey.shade300 : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: _isLoadingInsight
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF193B1F)),
                                )
                              : const Icon(Icons.refresh_rounded, size: 18, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text.rich(
                      key: ValueKey<int>(_refreshCount),
                      TextSpan(
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.6,
                          color: Color(0xFF2C2C2C),
                          fontWeight: FontWeight.w600,
                        ),
                        children: _dynamicAiInsight.isNotEmpty ? _dynamicAiInsight : _insights[_currentInsightIndex],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
