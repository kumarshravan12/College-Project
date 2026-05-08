import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:healthmate_ai/services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'configs/Theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Init error: $e");
  }
  
  final prefs = await SharedPreferences.getInstance();
  final hasSeenSplash = prefs.getBool('has_seen_splash') ?? false;

  runApp(MyApp(hasSeenSplash: hasSeenSplash));
}

class MyApp extends StatelessWidget {
  final bool hasSeenSplash;
  
  const MyApp({Key? key, required this.hasSeenSplash}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget initialScreen;
    if (!hasSeenSplash) {
      initialScreen = const SplashScreen();
    } else {
      final user = AuthService().getCurrentUser();
      initialScreen = user != null ? const HomeScreen() : const LoginScreen(); // Subsequent launches
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HealthMate AI',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: initialScreen,
    );
  }
}