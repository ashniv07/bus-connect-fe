import 'package:flutter/material.dart';
import 'screens/landing_page.dart';
import 'screens/qr_scanner_page.dart';

void main() {
  runApp(const BusTrackingApp());
}

class BusTrackingApp extends StatelessWidget {
  const BusTrackingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bus Connect',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.deepPurple,
        colorScheme: const ColorScheme.dark(
          primary: Colors.deepPurple,
          secondary: Colors.tealAccent,
          surface: Color(0xFF1E1E1E),
          background: Color(0xFF121212),
        ),
      ),
      home: const LandingPage(),
    );
  }
}
