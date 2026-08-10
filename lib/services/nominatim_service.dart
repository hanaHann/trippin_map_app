import 'dart:convert';
import 'package:http/http.dart' as http;

class SearchPlaceResult {
  final String displayName;
  final double latitude;
  final double longitude;

  SearchPlaceResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });
}

class NominatimService {
  static Future<List<SearchPlaceResult>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=7&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'TripPinFlutterMapApp/1.0 (contact@trippin.app)'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) {
          return SearchPlaceResult(
            displayName: item['display_name'] ?? '',
            latitude: double.parse(item['lat']),
            longitude: double.parse(item['lon']),
          );
        }).toList();
      }
    } catch (e) {
      // Handle network error gracefully
    }
    return [];
  }
}
