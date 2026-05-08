import 'package:flutter/material.dart';
import 'package:healthmate_ai/features/symptoms/screens/symptoms_screen.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9), // Very light mint/grey background
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),
            
            // Body
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Chat Bubble Section
                    _buildAnimatedItem(0, _buildChatBubble()),
                    
                    const SizedBox(height: 20),
                    
                    // Options List
                    _buildAnimatedItem(1, _buildOption(context, Icons.medical_services_rounded, 'Symptom Diagnosis', const Color(0xFF47BC62))),
                    _buildAnimatedItem(2, _buildOption(context, Icons.support_agent_rounded, 'Talk to Personal AI Doctor', const Color(0xFF3282B8))),
                    _buildAnimatedItem(3, _buildOption(context, Icons.biotech_rounded, 'Lab Report Analysis', const Color(0xFFB55DD7))),
                    _buildAnimatedItem(4, _buildOption(context, Icons.psychology_rounded, 'Mind Coach Program', const Color(0xFFFF8C32))),
                    _buildAnimatedItem(5, _buildOption(context, Icons.restaurant_menu_rounded, 'Diet and Nutrition Plan', const Color(0xFFE94560))),
                    _buildAnimatedItem(6, _buildOption(context, Icons.grid_view_rounded, 'Other', Colors.blueGrey)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedItem(int index, Widget child) {
    const double staggerDelay = 0.1;
    final double start = index * staggerDelay;
    final double end = (start + 0.5).clamp(0.0, 1.0);
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double animValue = CurvedAnimation(
          parent: _controller,
          curve: Interval(
            start,
            end,
            curve: Curves.easeOutCubic,
          ),
        ).value;
        
        return Opacity(
          opacity: animValue,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - animValue)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.black87),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.withOpacity(0.08),
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'HealthMate Assistant',
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.w800, 
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF193B1F), Color(0xFF2E5336)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF193B1F).withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        // Bubble
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16), // Reduced padding
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: const Color(0xFF264C2E).withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Text(
              'Hello there! How can I help you today?',
              style: TextStyle(
                fontSize: 14, // Slightly smaller font
                color: Colors.black87, 
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOption(BuildContext context, IconData icon, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (title == 'Symptom Diagnosis') {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SymptomsScreen()));
            } else if (title == 'Talk to Personal AI Doctor') {
              Navigator.pop(context, 'chat');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$title coming soon!'), 
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFF193B1F),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(40),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: color.withOpacity(0.12), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: color.withOpacity(0.1)),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.withOpacity(0.5), size: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
