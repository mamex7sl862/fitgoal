import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthToken();
  }

  Future<void> _checkAuthToken() async {
    // Artificial delay for splash branding effect (optional)
    await Future.delayed(const Duration(seconds: 1));

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      // Token exists, route to Main Navigation home
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } else {
      // No token found, route to Login
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF101112),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, color: Color(0xFFFF7043), size: 64),
            SizedBox(height: 16),
            Text(
              'FitGoal',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Color(0xFFFF7043)),
          ],
        ),
      ),
    );
  }
}