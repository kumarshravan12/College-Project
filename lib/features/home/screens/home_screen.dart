import 'package:flutter/material.dart';
import 'package:healthmate_ai/services/auth_service.dart';
import 'package:healthmate_ai/features/auth/screens/login_screen.dart';
import 'package:healthmate_ai/features/chat/screens/chat_screen.dart';
import 'package:healthmate_ai/features/symptoms/screens/symptoms_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _drinkWaterReminder = true;
  bool _dailyExerciseReminder = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _logout(BuildContext context) async {
    try {
      await AuthService().signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().getCurrentUser();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB), // Very light modern background
      body: IndexedStack(
        index: _currentIndex <= 1 ? 0 : (_currentIndex == 2 ? 1 : 2),
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: [
              SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, user),

                      const SizedBox(height: 20),
                      _buildGreeting(),

                      const SizedBox(height: 32),
                      _buildCenterOrb(),
                      const SizedBox(height: 32),
                      _buildSearchBar(),

                      const SizedBox(height: 32),
                      _buildSectionTitle('Quick Actions'),
                      const SizedBox(height: 16),
                      _buildQuickActionsGrid(),
                      const SizedBox(height: 32),

                      _buildSectionTitle('Trending Features'),
                      const SizedBox(height: 16),
                      _buildTrendingFeatures(),
                      const SizedBox(height: 32),

                      _buildSectionTitle('Smart Reminders'),
                      const SizedBox(height: 16),

                      _buildSmartReminders(),
                      const SizedBox(height: 48), // Padding for Bottom Nav Bar
                    ],
                  ),
                ),
              ),
              ChatScreen(
                onBackPressed: () {
                  if (_pageController.hasClients) {
                    _pageController.animateToPage(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                  setState(() {
                    _currentIndex = 0;
                  });
                },
              ),
            ],
          ),
          const Scaffold(body: Center(child: Text("Plans coming soon..."))),
          const Scaffold(body: Center(child: Text("Profile coming soon..."))),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF264C2E).withOpacity(0.4),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {},
          backgroundColor: const Color(0xFF264C2E), // Dark Green
          elevation: 0,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildHeader(BuildContext context, user) {
    final emailHeader = user?.email?.split('@')[0] ?? 'User';
    final avatarUrl = 'https://ui-avatars.com/api/?name=$emailHeader&background=193B1F&color=fff&size=150';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
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
                    emailHeader.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
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
            onTap: () => _logout(context), // Added logout here for functionality
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
              child: const Icon(Icons.notifications_none_rounded, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    return Center(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('👋', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                'Hello Users!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4A8B63), // Soft green
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'How are you feeling\ntoday?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2C2C2C),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterOrb() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              width: 170, // Outermost third circle
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE4F3EA).withOpacity(0.4), 
              ),
              child: Center(
                child: Container(
                  width: 135, // Middle circle
                  height: 135,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE4F3EA), 
                    border: Border.all(color: Colors.green.withOpacity(0.1), width: 2),
                  ),
                  child: Center(
                    child: Container(
                      width: 105, // Innermost circle
                      height: 105,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFD1EADC),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.2), 
                            width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
                  BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: 24.0, right: 12.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Ask HealthMate anything...',
                    hintStyle: TextStyle(color: Colors.black38, fontSize: 16),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                    filled: false,
                  ),
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ),
            ),
            GestureDetector(
                             onTap: () {
                // Navigate to Chat Screen
                FocusScope.of(context).unfocus(); // Dismiss keyboard if open
                if (_currentIndex != 1) {
                  setState(() {
                    _currentIndex = 1;
                  });
                  _pageController.animateToPage(
                    1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  width: 44,
                  height: 44,
                             decoration: const BoxDecoration(
                    color: Color(0xFF2E5336), // Dark green
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic_none_rounded, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: Color(0xFF2C2C2C),
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    final actions = [
      {'title': 'AI Chat', 'icon': Icons.auto_awesome_rounded, 'color': const Color(0xFF4DB065), 'bgColor': const Color(0xFFE8F5E9)},
      {'title': 'Symptom\nChecker', 'icon': Icons.monitor_heart_rounded, 'color': const Color(0xFFAB47BC), 'bgColor': const Color(0xFFF3E5F5)},
      {'title': 'Diet Plan', 'icon': Icons.set_meal_rounded, 'color': const Color(0xFFFF9800), 'bgColor': const Color(0xFFFFF3E0)},
      {'title': 'Coming Soon', 'icon': Icons.hourglass_empty_rounded, 'color': const Color(0xFF9E9E9E), 'bgColor': const Color(0xFFF5F5F5)},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
                mainAxisSpacing: 16,
          childAspectRatio: 1.15,
        ),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          return GestureDetector(
            onTap: () {
              if (action['title'] == 'AI Chat') {
                setState(() {
                  _currentIndex = 1;
                });
                _pageController.animateToPage(
                         1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              } else if (action['title'] == 'Symptom\nChecker') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SymptomsScreen()),
                );
              }
            },
            child: Container(
              decoration: BoxDecoration(
                     color: Colors.white.withOpacity(0.7), // Transparent glass box
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white, width: 2), // Frosted white edge
              boxShadow: [
                BoxShadow(
                  color: (action['color'] as Color).withOpacity(0.08), // Dynamic ambient color bleed
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                          color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (action['color'] as Color).withOpacity(0.25), // Glowing icon effect
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: action['bgColor'] as Color, width: 2),
                    ),
                    child: Icon(
                      action['icon'] as IconData,
                      color: action['color'] as Color,
                      size: 26,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    action['title'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                             color: Color(0xFF2C2C2C),
                      letterSpacing: 0.2, // Premium tighter kerning 
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrendingFeatures() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          // Card 1
          Container(
                   width: 300,
            height: 160,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
              gradient: LinearGradient(
                     colors: [
                  const Color(0xFF193B1F).withOpacity(0.85),
                  const Color(0xFF2E5336).withOpacity(0.8)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E5336).withOpacity(0.2),
                          blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.bar_chart_rounded, color: Colors.white70, size: 28),
                      const SizedBox(height: 16),
                const Text(
                  'AI Health Report',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Personalized biometrics analysis',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Card 2 - Nearby Health Services
          Container(
            width: 300,
            height: 160,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                   gradient: LinearGradient(
                colors: [
                  const Color(0xFF1E3C72).withOpacity(0.85),
                  const Color(0xFF2A5298).withOpacity(0.8)
                ], // Sleek medical blue gradient
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3C72).withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.location_on_rounded, color: Colors.white70, size: 28),
                const SizedBox(height: 16),
                const Text(
                  'Nearby Services',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Find hospitals & clinics around you',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartReminders() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          _buildReminderItem(
            title: 'Drink Water',
            subtitle: 'Scheduled at 2:00 PM',
            customIcon: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF81D4FA), Color(0xFF0288D1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0288D1).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Text('💧', style: TextStyle(fontSize: 24)),
              ),
            ),
            value: _drinkWaterReminder,
            onChanged: (val) => setState(() => _drinkWaterReminder = val),
          ),
          const SizedBox(height: 16),
          _buildReminderItem(
            title: 'Daily Exercise',
            subtitle: 'Scheduled at 5:30 PM',
            customIcon: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFA5D6A7), Color(0xFF2E7D32)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E7D32).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Text('🏃‍♂️', style: TextStyle(fontSize: 24)),
              ),
            ),
            value: _dailyExerciseReminder,
            onChanged: (val) => setState(() => _dailyExerciseReminder = val),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderItem({
    required String title,
    required String subtitle,
    required Widget customIcon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          customIcon,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.black87),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF264C2E), // Dark green
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomAppBar(
      color: Colors.white,
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      elevation: 20,
      clipBehavior: Clip.none,
      shadowColor: Colors.black26,
      child: SizedBox(
        height: 65,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildNavItem(0, Icons.home_rounded, 'HOME'),
            _buildNavItem(1, Icons.chat_bubble_outline_rounded, 'CHAT'),
            const SizedBox(width: 48), // Space for FAB
            _buildNavItem(2, Icons.description_outlined, 'REPORT'),
            _buildNavItem(3, Icons.person_outline_rounded, 'PROFILE'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (index <= 1) {
          if (_currentIndex <= 1) {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          } else {
            // Instantly sync the PageView before we reveal it
            _pageController.jumpToPage(index);
          }
        }
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64, // Wider to comfortably fit the pill
        height: 65,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Liquid active pill background
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: isSelected ? 58 : 40,
              height: isSelected ? 58 : 40,
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFF193B1F).withOpacity(0.13)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(40),
              ),
            ),
            // Centered Content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  margin: EdgeInsets.only(bottom: isSelected ? 2 : 0),
                  child: Icon(
                    icon, 
                    color: isSelected ? const Color(0xFF193B1F) : Colors.black45, 
                    size: 26, // Perfect balance for icons
                  ),
                ),
                // Text expands beautifully below
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  height: isSelected ? 14 : 0,
                  alignment: Alignment.topCenter,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: isSelected ? 1.0 : 0.0,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10, 
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF193B1F),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

