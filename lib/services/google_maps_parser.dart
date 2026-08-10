import 'package:http/http.dart' as http;

class ParsedLocationResult {
  final String name;
  final double latitude;
  final double longitude;

  ParsedLocationResult({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

class GoogleMapsParser {
  /// Parses Google Maps link, share text, or raw coordinates `@35.68,139.76` or `35.68, 139.76`
  static Future<ParsedLocationResult?> parseInput(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // 1. Direct Lat,Lng format (e.g. "35.6812, 139.7671" or "@35.6812,139.7671")
    final coordRegex = RegExp(r'@?(-?\d+\.\d+)\s*,\s*(-?\d+\.\d+)');
    final match = coordRegex.firstMatch(trimmed);
    if (match != null) {
      final lat = double.tryParse(match.group(1)!);
      final lng = double.tryParse(match.group(2)!);
      if (lat != null && lng != null) {
        return ParsedLocationResult(
          name: '自訂定位點 (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})',
          latitude: lat,
          longitude: lng,
        );
      }
    }

    // 2. Google Maps Shortened link (e.g., https://maps.app.goo.gl/...)
    if (trimmed.contains('goo.gl') || trimmed.contains('maps.app.goo.gl')) {
      try {
        final client = http.Client();
        final request = http.Request('GET', Uri.parse(trimmed))..followRedirects = false;
        final response = await client.send(request);
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          return parseInput(redirectUrl);
        }
      } catch (e) {
        // Fallback to normal HTTP GET
      }
    }

    // 3. Google Maps Place URL (e.g., https://www.google.com/maps/place/Senso-ji/@35.7148,139.7967,17z/...)
    if (trimmed.contains('google.com/maps')) {
      // Extract place name if present
      String placeName = '匯入地點';
      final placeNameMatch = RegExp(r'/maps/place/([^/@]+)').firstMatch(trimmed);
      if (placeNameMatch != null) {
        placeName = Uri.decodeFull(placeNameMatch.group(1)!.replaceAll('+', ' '));
      }

      // Extract @lat,lng
      final atMatch = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(trimmed);
      if (atMatch != null) {
        final lat = double.parse(atMatch.group(1)!);
        final lng = double.parse(atMatch.group(2)!);
        return ParsedLocationResult(
          name: placeName,
          latitude: lat,
          longitude: lng,
        );
      }

      // Extract q=lat,lng
      final qMatch = RegExp(r'[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(trimmed);
      if (qMatch != null) {
        final lat = double.parse(qMatch.group(1)!);
        final lng = double.parse(qMatch.group(2)!);
        return ParsedLocationResult(
          name: placeName,
          latitude: lat,
          longitude: lng,
        );
      }
    }

    return null;
  }
}
