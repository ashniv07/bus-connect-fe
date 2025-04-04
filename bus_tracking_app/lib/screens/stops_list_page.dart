import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'fare_page.dart';
import 'package:geolocator/geolocator.dart';

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
      home: const QRScannerPage(),
    );
  }
}

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

class StopsListPage extends StatefulWidget {
  final String busNumber;
  final List<String> stops;

  const StopsListPage({super.key, required this.busNumber, required this.stops});

  @override
  State<StopsListPage> createState() => _StopsListPageState();
}

class _StopsListPageState extends State<StopsListPage> {
  String? selectedSource;
  String? selectedDestination;
  bool isLoadingLocation = true;
  String? locationError;

  @override
  void initState() {
    super.initState();
    _getNearestBusStop();
  }

  Future<void> _getNearestBusStop() async {
    try {
      // Get current location
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print('\n=== Finding Nearest Bus Stop ===');
      print('Your Location: Latitude=${position.latitude}, Longitude=${position.longitude}');

      // Get nearest bus stop from API
      final url = Uri.parse('http://192.168.1.10:8080/nearest-stop?lat=${position.latitude}&lon=${position.longitude}');
      print('API URL: $url');
      
      final response = await http.get(url);
      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Decoded Response: $data');
        
        // Check if the response has the expected format
        if (data is! Map<String, dynamic>) {
          throw Exception('Invalid API response format');
        }

        // Try different possible field names
        final stopName = data['stopname'] ?? data['stopName'] ?? data['name'] ?? data['stop'] ?? data['busStop'];
        
        if (stopName == null) {
          print('Available fields in response: ${data.keys.join(', ')}');
          throw Exception('No bus stop found in the response. Available fields: ${data.keys.join(', ')}');
        }

        print('Found Nearest Bus Stop: $stopName');

        // Check if the nearest stop exists in our list of stops (case-insensitive)
        bool stopExists = widget.stops.any((stop) => 
          stop.toLowerCase() == stopName.toLowerCase()
        );

        if (stopExists) {
          // Find the exact case version from our stops list
          final exactStopName = widget.stops.firstWhere(
            (stop) => stop.toLowerCase() == stopName.toLowerCase()
          );
          
          setState(() {
            selectedSource = exactStopName;
            isLoadingLocation = false;
          });
        } else {
          print('Available stops in route: ${widget.stops.join(', ')}');
          throw Exception('Nearest bus stop "$stopName" not found in this bus route');
        }
      } else {
        throw Exception('Failed to get nearest bus stop. Status code: ${response.statusCode}, Response: ${response.body}');
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        locationError = e.toString();
        isLoadingLocation = false;
      });
    }
  }

  void _toggleStop(String stop) {
    setState(() {
      if (selectedDestination == stop) {
        selectedDestination = null;
      } else if (selectedDestination == null) {
        selectedDestination = stop;
        // Navigate to fare page when destination is selected
        _navigateToFarePage();
      }
    });
  }

  void _navigateToFarePage() {
    if (selectedSource != null && selectedDestination != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FarePage(
            busNumber: widget.busNumber,
            source: selectedSource!,
            destination: selectedDestination!,
          ),
        ),
      );
    }
  }

  Color _getStopColor(String stop) {
    if (selectedSource == stop) return Colors.green;
    if (selectedDestination == stop) return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.only(right: 12),
              child: const Icon(
                Icons.directions_bus,
                color: Colors.tealAccent,
              ),
            ),
            Text('Bus ${widget.busNumber} Stops'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Column(
        children: [
          if (isLoadingLocation)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                ),
              ),
            )
          else if (locationError != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Error: $locationError',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _getNearestBusStop,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (selectedSource != null)
            Card(
              margin: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.tealAccent,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Nearest Bus Stop',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.tealAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.tealAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.tealAccent.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedSource!,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'This is your nearest bus stop',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select your destination from the list below',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                itemCount: widget.stops.length,
                itemBuilder: (context, index) {
                  final stop = widget.stops[index];
                  final isFirst = index == 0;
                  final isLast = index == widget.stops.length - 1;
                  
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Route timeline with circles and connecting line
                      SizedBox(
                        width: 40,
                        child: Column(
                          children: [
                            // Circle indicator
                            GestureDetector(
                              onTap: () => _toggleStop(stop),
                              child: Container(
                                width: 14,
                                height: 14,
                                margin: const EdgeInsets.only(top: 16),
                                decoration: BoxDecoration(
                                  color: _getStopColor(stop),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                            // Connecting line (not for the last item)
                            if (!isLast)
                              Container(
                                width: 2,
                                height: 50,
                                color: Colors.grey.withOpacity(0.5),
                              ),
                          ],
                        ),
                      ),
                      // Stop details
                      Expanded(
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8, top: 8),
                          color: Theme.of(context).colorScheme.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stop,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isFirst
                                      ? 'Starting Point'
                                      : isLast
                                          ? 'Final Stop'
                                          : 'Bus Stop',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FarePage extends StatefulWidget {
  final String busNumber;
  final String source;
  final String destination;

  const FarePage({
    super.key,
    required this.busNumber,
    required this.source,
    required this.destination,
  });

  @override
  State<FarePage> createState() => _FarePageState();
}

class _FarePageState extends State<FarePage> {
  bool isLoading = true;
  String? fare;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchFare();
  }

  Future<void> _fetchFare() async {
    try {
      final response = await http.get(Uri.parse(
        'http://192.168.1.10:8080/calculate?source=${widget.source}&destination=${widget.destination}',
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          fare = data['fare'].toString();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to calculate fare');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.directions_bus, color: Colors.tealAccent),
            const SizedBox(width: 8),
            Text('Bus ${widget.busNumber} Fare'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Source: ${widget.source}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Destination: ${widget.destination}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                ),
              )
            else if (error != null)
              Center(
                child: Text(
                  'Error: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              )
            else
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Estimated Fare',
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹$fare',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.tealAccent,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}