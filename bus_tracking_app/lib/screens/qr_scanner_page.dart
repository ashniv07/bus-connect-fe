import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'stops_list_page.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  MobileScannerController controller = MobileScannerController();
  bool isLoading = false;

  void _onDetect(BarcodeCapture capture) {
    if (isLoading) return; // Prevent multiple scans while loading
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() => isLoading = true);
        controller.stop();
        _fetchBusStops(barcode.rawValue!);
        break;
      }
    }
  }

  Future<void> _fetchBusStops(String busNo) async {
    try {
      final response = await http.get(Uri.parse('http://192.168.1.10:8080/bus/$busNo'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<String> stops = List<String>.from(data['stops'] ?? []);
        if (stops.isNotEmpty) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => StopsListPage(busNumber: busNo, stops: stops),
              ),
            );
          }
        } else {
          throw Exception('No stops found for this bus');
        }
      } else {
        throw Exception('Bus not found');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() => isLoading = false);
        controller.start(); // Restart the scanner after error
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: MobileScanner(
                  controller: controller,
                  onDetect: _onDetect,
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Scan Bus QR Code',
                  style: TextStyle(fontSize: 18, color: Colors.tealAccent),
                ),
              ),
            ],
          ),
          if (isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
} 