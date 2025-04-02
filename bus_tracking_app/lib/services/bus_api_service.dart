import 'package:http/http.dart' as http;
import 'dart:convert';

class BusApiService {
  Future<List<String>> getStops(String busNumber) async {
    final client = http.Client();
    try {
      final response = await client.get(
        Uri.parse('http://192.168.1.10:8080/bus/$busNumber'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['stops']);
      } else {
        throw Exception('Failed to load bus stops');
      }
    } finally {
      client.close();
    }
  }
}
