import 'dart:convert';
import 'package:http/http.dart' as http;
import 'nominatim_service.dart';

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
  /// Bulletproof parser for Google Maps URLs, share snippets, or coordinates
  static Future<ParsedLocationResult?> parseInput(String rawInput) async {
    String input = rawInput.trim();
    if (input.isEmpty) return null;

    String? extractedName;
    String targetUrl = input;

    // 1. Separate place name prefix if user pasted share text like "台場 https://maps.app.goo.gl/..."
    final urlRegex = RegExp(r'https?://[^\s]+');
    final urlMatch = urlRegex.firstMatch(input);

    if (urlMatch != null) {
      targetUrl = urlMatch.group(0)!;
      final prefixText = input
          .substring(0, urlMatch.start)
          .replaceAll('「', '')
          .replaceAll('」', '')
          .replaceAll('"', '')
          .replaceAll('\'', '')
          .trim();
      if (prefixText.isNotEmpty && !prefixText.startsWith('http')) {
        extractedName = prefixText;
      }
    }

    double? lat;
    double? lng;

    // 2. Extract coordinates directly from input string
    final directCoords = _extractCoordinates(input);
    if (directCoords != null) {
      lat = directCoords[0];
      lng = directCoords[1];
    }

    // 3. Extract place name directly from input URL (/maps/place/台場/ or ?q=台場)
    extractedName ??= _extractNameFromUrl(targetUrl);

    // 4. Resolve Web URL if input is a URL (including maps.app.goo.gl short links)
    if (targetUrl.startsWith('http')) {
      try {
        final client = http.Client();
        final response = await client.get(
          Uri.parse(targetUrl),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
            'Accept-Language': 'zh-TW,zh;q=0.9,en;q=0.8',
          },
        );

        final finalUrl = response.request?.url.toString() ?? targetUrl;
        final htmlBody = response.body;

        // Try extracting coordinates from final redirected URL
        if (lat == null || lng == null) {
          final redirectedCoords = _extractCoordinates(finalUrl);
          if (redirectedCoords != null) {
            lat = redirectedCoords[0];
            lng = redirectedCoords[1];
          }
        }

        // Try extracting coordinates from HTML body
        if (lat == null || lng == null) {
          final htmlCoords = _extractCoordinates(htmlBody);
          if (htmlCoords != null) {
            lat = htmlCoords[0];
            lng = htmlCoords[1];
          }
        }

        // Try extracting place name from redirected URL path
        extractedName ??= _extractNameFromUrl(finalUrl);

        // Try extracting place name from HTML meta/title tags
        extractedName ??= _extractNameFromHtml(htmlBody);
      } catch (e) {
        // Continue fallback if HTTP fails
      }
    }

    // 5. If we have a place name but missing coordinates, search via Nominatim
    if ((lat == null || lng == null) && extractedName != null && extractedName.isNotEmpty) {
      try {
        final searchResults = await NominatimService.searchPlaces(extractedName);
        if (searchResults.isNotEmpty) {
          lat = searchResults.first.latitude;
          lng = searchResults.first.longitude;
        }
      } catch (_) {}
    }

    // 6. If we have coordinates, resolve place name (reverse geocode if name is still missing or generic)
    if (lat != null && lng != null) {
      if (extractedName == null ||
          extractedName.isEmpty ||
          extractedName == 'Google 地圖' ||
          extractedName == 'Google Maps' ||
          extractedName.startsWith('自訂地點') ||
          extractedName.startsWith('自訂定位點')) {
        extractedName = await _reverseGeocode(lat, lng) ??
            '自訂地點 (${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)})';
      }

      return ParsedLocationResult(
        name: extractedName,
        latitude: lat,
        longitude: lng,
      );
    }

    return null;
  }

  /// Extracts [lat, lng] using 5 Google Maps coordinate patterns
  static List<double>? _extractCoordinates(String str) {
    // Pattern 1: @35.6268,139.7766
    final p1 = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(str);
    if (p1 != null) {
      final lat = double.tryParse(p1.group(1)!);
      final lng = double.tryParse(p1.group(2)!);
      if (lat != null && lng != null) return [lat, lng];
    }

    // Pattern 2: !3d35.6268!4d139.7766 (Google Maps internal data format)
    final p2 = RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)').firstMatch(str);
    if (p2 != null) {
      final lat = double.tryParse(p2.group(1)!);
      final lng = double.tryParse(p2.group(2)!);
      if (lat != null && lng != null) return [lat, lng];
    }

    // Pattern 3: center=35.6268%2C139.7766 or center=35.6268,139.7766
    final p3 = RegExp(r'center=(-?\d+\.\d+)(?:%2C|,)(-?\d+\.\d+)').firstMatch(str);
    if (p3 != null) {
      final lat = double.tryParse(p3.group(1)!);
      final lng = double.tryParse(p3.group(2)!);
      if (lat != null && lng != null) return [lat, lng];
    }

    // Pattern 4: q=35.6268,139.7766 or ll=35.6268,139.7766 or query=35.6268,139.7766
    final p4 = RegExp(r'(?:q|ll|query)=(-?\d+\.\d+)(?:%2C|,)(-?\d+\.\d+)').firstMatch(str);
    if (p4 != null) {
      final lat = double.tryParse(p4.group(1)!);
      final lng = double.tryParse(p4.group(2)!);
      if (lat != null && lng != null) return [lat, lng];
    }

    // Pattern 5: Raw 35.6268, 139.7766
    final p5 = RegExp(r'(-?\d{1,2}\.\d{3,})\s*,\s*(-?\d{1,3}\.\d{3,})').firstMatch(str);
    if (p5 != null) {
      final lat = double.tryParse(p5.group(1)!);
      final lng = double.tryParse(p5.group(2)!);
      if (lat != null && lng != null) return [lat, lng];
    }

    return null;
  }

  /// Extracts place name from Google Maps URL path (/maps/place/台場/ or /search/台場/ or ?q=台場)
  static String? _extractNameFromUrl(String url) {
    // Match /maps/place/PLACE_NAME/ or /maps/search/PLACE_NAME/
    final placeMatch = RegExp(r'/maps/(?:place|search)/([^/@?]+)').firstMatch(url);
    if (placeMatch != null) {
      final raw = placeMatch.group(1)!.replaceAll('+', ' ');
      final decoded = Uri.decodeFull(raw).trim();
      if (decoded.isNotEmpty &&
          !decoded.startsWith('http') &&
          !RegExp(r'^-?\d+\.').hasMatch(decoded)) {
        return decoded;
      }
    }

    // Match ?q=PLACE_NAME or &q=PLACE_NAME or query=PLACE_NAME
    final qMatch = RegExp(r'[?&](?:q|query)=([^&]+)').firstMatch(url);
    if (qMatch != null) {
      final raw = qMatch.group(1)!.replaceAll('+', ' ');
      final decoded = Uri.decodeFull(raw).trim();
      if (decoded.isNotEmpty &&
          !RegExp(r'^-?\d+\.\d+(?:%2C|,)\s*-?\d+\.\d+$').hasMatch(decoded)) {
        return decoded;
      }
    }

    return null;
  }

  /// Extracts place name from HTML meta tags or title
  static String? _extractNameFromHtml(String html) {
    final ogMatch = RegExp(r'og:title"[^>]*content="([^"]+)"', caseSensitive: false)
            .firstMatch(html) ??
        RegExp(r'content="([^"]+)"[^>]*og:title', caseSensitive: false)
            .firstMatch(html);

    if (ogMatch != null) {
      final text = ogMatch.group(1)!;
      final clean = text.split('·').first.split('-').first.trim();
      if (clean.isNotEmpty && clean != 'Google 地圖' && clean != 'Google Maps') {
        return clean;
      }
    }

    final titleMatch =
        RegExp(r'<title>(.*?)</title>', caseSensitive: false).firstMatch(html);
    if (titleMatch != null) {
      final titleText = titleMatch
          .group(1)!
          .replaceAll('- Google 地圖', '')
          .replaceAll('- Google Maps', '')
          .trim();
      if (titleText.isNotEmpty) return titleText;
    }

    return null;
  }

  /// Reverse geocodes coordinates to a place name (e.g. "台場") via Nominatim
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
          final candidate = address['suburb'] ??
              address['neighbourhood'] ??
              address['quarter'] ??
              address['tourism'] ??
              address['amenity'] ??
              address['attraction'] ??
              address['building'] ??
              address['shop'] ??
              address['leisure'] ??
              address['commercial'] ??
              address['historic'] ??
              address['city_district'] ??
              address['road'];
          if (candidate != null && candidate.toString().isNotEmpty) {
            return candidate.toString();
          }
        }

        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          return displayName.split(',').first.trim();
        }
      }
    } catch (_) {}
    return null;
  }
}
