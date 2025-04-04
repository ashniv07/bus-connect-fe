import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'qr_scanner_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  @override
  void initState() {
    super.initState();
    // Navigate to scanner page after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const QRScannerPage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const Spacer(),

                // Logo
                Image.asset(
                  'assets/images/bus_ticket_icon.png',
                  height: 120,
                ),

                const SizedBox(height: 20),

                // Main Text
                const Text(
                  'BUS CONNECT',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Lottie Loader
                Lottie.asset(
                  'assets/animations/loader.json',
                  height: 150,
                ),

                const SizedBox(height: 30),

                // Bold Bottom Text
                const Text(
                  'Track. Book. Ride. Relax',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 