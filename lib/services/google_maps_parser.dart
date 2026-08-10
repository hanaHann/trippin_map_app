import 'dart:convert';
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
  /// Smart parser for Google Maps URLs, share snippets, or coordinates
  static Future<ParsedLocationResult?> parseInput(String input) async {
    String trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // 1. Extract Name prefix if share text contains both text and URL
    // e.g., "淺草寺 https://maps.app.goo.gl/..." or "「SHIBUYA SKY」 https://..."
    String? extractedPrefixName;
    final urlRegex = RegExp(r'https?://[^\s]+');
    final urlMatch = urlRegex.firstMatch(trimmed);

    if (urlMatch != null) {
      final urlIndex = urlMatch.start;
      final prefixText = trimmed
          .substring(0, urlIndex)
          .replaceAll('「', '')
          .replaceAll('」', '')
          .replaceAll('"', '')
          .trim();
      if (prefixText.isNotEmpty && !prefixText.startsWith('http')) {
        extractedPrefixName = prefixText;
      }
      // Keep only the URL for web parsing
      trimmed = urlMatch.group(0)!;
    }

    double? lat;
    double? lng;
    String? parsedName = extractedPrefixName;

    // 2. Direct Lat,Lng format (e.g. "@35.7148,139.7967" or "35.7148, 139.7967")
    final coordRegex = RegExp(r'@?(-?\d+\.\d+)\s*,\s*(-?\d+\.\d+)');
    final coordMatch = coordRegex.firstMatch(trimmed);
    if (coordMatch != null) {
      lat = double.tryParse(coordMatch.group(1)!);
      lng = double.tryParse(coordMatch.group(2)!);
    }

    // 3. Extract Place Name from Google Maps URL path (/maps/place/NAME/...)
    if (trimmed.contains('/maps/place/')) {
      final placeMatch = RegExp(r'/maps/place/([^/@?]+)').firstMatch(trimmed);
      if (placeMatch != null) {
        final rawName = placeMatch.group(1)!.replaceAll('+', ' ');
        final decoded = Uri.decodeFull(rawName);
        if (decoded.isNotEmpty && parsedName == null) {
          parsedName = decoded;
        }
      }
    }

    // 4. Fetch Web URL to resolve short link (maps.app.goo.gl) and get HTML meta tags / final URL
    if (trimmed.startsWith('http')) {
      try {
        final client = http.Client();
        final response = await client.get(
          Uri.parse(trimmed),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
            'Accept-Language': 'zh-TW,zh;q=0.9,en;q=0.8',
          },
        );

        final finalUrl = response.request?.url.toString() ?? trimmed;

        // Try extracting lat/lng from final redirected URL
        if (lat == null || lng == null) {
          final atMatch =
              RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(finalUrl);
          if (atMatch != null) {
            lat = double.tryParse(atMatch.group(1)!);
            lng = double.tryParse(atMatch.group(2)!);
          } else {
            final qMatch =
                RegExp(r'[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(finalUrl);
            if (qMatch != null) {
              lat = double.tryParse(qMatch.group(1)!);
              lng = double.tryParse(qMatch.group(2)!);
            }
          }
        }

        // Try extracting Name from URL path of finalUrl
        if (parsedName == null && finalUrl.contains('/maps/place/')) {
          final placeMatch =
              RegExp(r'/maps/place/([^/@?]+)').firstMatch(finalUrl);
          if (placeMatch != null) {
            final rawName = placeMatch.group(1)!.replaceAll('+', ' ');
            parsedName = Uri.decodeFull(rawName);
          }
        }

        // Try extracting Name from HTML OpenGraph meta tag or <title>
        if (parsedName == null) {
          final ogTitleMatch = RegExp(r'og:title"[^>]*content="([^"]+)"', caseSensitive: false)
                  .firstMatch(response.body) ??
              RegExp(r'content="([^"]+)"[^>]*og:title', caseSensitive: false)
                  .firstMatch(response.body);

          if (ogTitleMatch != null) {
            final titleContent = ogTitleMatch.group(1)!;
            parsedName = titleContent.split('·').first.split('-').first.trim();
          } else {
            final titleMatch = RegExp(r'<title>(.*?)</title>', caseSensitive: false)
                .firstMatch(response.body);
            if (titleMatch != null) {
              final rawTitle = titleMatch.group(1)!;
              if (rawTitle.contains('Google')) {
                parsedName = rawTitle
                    .replaceAll('- Google 地圖', '')
                    .replaceAll('- Google Maps', '')
                    .trim();
              }
            }
          }
        }
      } catch (e) {
        // Fallback gracefully if network fails
      }
    }

    if (lat == null || lng == null) return null;

    // 5. Reverse Geocoding fallback if no name was discovered
    if (parsedName == null ||
        parsedName.isEmpty ||
        parsedName == 'Google 地圖' ||
        parsedName == 'Google Maps') {
      parsedName = await _reverseGeocode(lat, lng) ??
          '自訂地點 (${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)})';
    }

    return ParsedLocationResult(
      name: parsedName,
      latitude: lat,
      longitude: lng,
    );
  }

  /// Reverse geocodes coordinates to a readable place name via Nominatim
  static Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&accept-language=zh-TW',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'TripPinFlutterMapApp/1.0'},
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final name = data['name'] as String?;
        if (name != null && name.isNotEmpty) return name;

        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          return address['amenity'] ??
              address['attraction'] ??
              address['building'] ??
              address['road'] ??
              address['suburb'];
        }
      }
    } catch (_) {}
    return null;
  }
}
