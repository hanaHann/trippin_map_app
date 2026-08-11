import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'nominatim_service.dart';

/// Class representing the structured resolution result of a Google Maps URL or text input.
class ParsedLocationResult {
  /// The original input URL or share text provided by the user.
  final String sourceUrl;

  /// The expanded URL after following all HTTP redirects (e.g. maps.app.goo.gl -> full URL).
  final String expandedUrl;

  /// The extracted Google Feature ID, CID, or Place ID (e.g., 0x34683d5a4980f7ad:0x7c731fa55b85a3c1).
  final String? placeId;

  /// The resolved location/landmark name (e.g., "木村堂 楊梅店" or "東京晴空塔").
  final String name;

  /// The resolved latitude.
  final double latitude;

  /// The resolved longitude.
  final double longitude;

  /// The method used to resolve the location:
  /// - `feature_id`: Resolved via exact Google Feature ID / Place ID pin
  /// - `exact_pin`: Resolved via exact POI pin coordinates (!3d/!4d/q=)
  /// - `place_name_search`: Resolved via extracted place name geocoding search
  /// - `viewport_coords`: Resolved via camera viewport center (@lat,lng) as fallback
  final String resolutionMethod;

  ParsedLocationResult({
    required this.sourceUrl,
    required this.expandedUrl,
    this.placeId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.resolutionMethod,
  });

  @override
  String toString() {
    return 'ParsedLocationResult(name: $name, lat: $latitude, lng: $longitude, placeId: $placeId, method: $resolutionMethod)';
  }
}

class GoogleMapsParser {
  /// Timeout duration for HTTP requests
  static const Duration timeoutDuration = Duration(seconds: 8);

  /// Production-grade parser for Google Maps URLs (including maps.app.goo.gl), share snippets, or coordinates.
  ///
  /// Strict Priority Sequence:
  /// 1. HTTP Follow Redirect: Follow short links to obtain the expanded URL & HTML body.
  /// 2. Priority 1 (Highest): Extract Place ID / Feature ID (0x...:0x...) and exact POI pin (!3d/!4d).
  /// 3. Priority 2: Extract place name (/place/NAME/, og:title) and search via geocoder.
  /// 4. Priority 3 (Lowest Fallback): Extract viewport camera center (@lat,lng) ONLY if no POI or place name exists.
  static Future<ParsedLocationResult?> parseInput(String rawInput) async {
    final String input = rawInput.trim();
    if (input.isEmpty) return null;

    String? extractedName;
    String targetUrl = input;
    String expandedUrl = input;
    String htmlBody = '';

    // 1. Extract surrounding place name text from share snippet (e.g., 「東京晴空塔」 https://maps.app.goo.gl/...)
    final urlRegex = RegExp(r'https?://[^\s]+');
    final urlMatch = urlRegex.firstMatch(input);

    if (urlMatch != null) {
      targetUrl = urlMatch.group(0)!;
      expandedUrl = targetUrl;

      final surroundingText = input
          .replaceAll(urlRegex, '')
          .replaceAll('\n', ' ')
          .replaceAll('「', '')
          .replaceAll('」', '')
          .replaceAll('"', '')
          .replaceAll('\'', '')
          .replaceAll('Google 地圖', '')
          .replaceAll('Google Maps', '')
          .trim();

      if (surroundingText.isNotEmpty &&
          surroundingText.length < 100 &&
          !surroundingText.startsWith('http')) {
        extractedName = surroundingText;
      }
    }

    // 2. Extract Place ID / Feature ID if present directly in input
    String? placeId = _extractPlaceId(input);

    // 3. HTTP Follow Redirect if input contains a URL
    if (targetUrl.startsWith('http')) {
      try {
        final client = http.Client();
        final response = await client
            .get(
              Uri.parse(targetUrl),
              headers: {
                // Desktop User-Agent forces Google Maps to expand to full /maps/place/PLACE_NAME/ URL
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Accept-Language': 'zh-TW,zh;q=0.9,en;q=0.8',
              },
            )
            .timeout(timeoutDuration);

        expandedUrl = response.request?.url.toString() ?? targetUrl;
        htmlBody = response.body;

        // Try extracting placeId from redirected URL or HTML body
        placeId ??= _extractPlaceId(expandedUrl) ?? _extractPlaceId(htmlBody);

        // Extract place name from redirected URL path or HTML body
        extractedName ??= _extractNameFromUrl(expandedUrl);
        extractedName ??= _extractNameFromUrl(htmlBody);
        extractedName ??= _extractNameFromHtml(htmlBody);
      } catch (e) {
        // Fallback gracefully if HTTP redirect times out or network fails
      }
    }

    double? lat;
    double? lng;
    String resolutionMethod = 'unknown';

    // Priority 1 (Highest): Extract exact POI Pin coordinates (!3d...!4d...)
    final exactPinCoords = _extractExactPinCoordinates(input) ??
        _extractExactPinCoordinates(expandedUrl) ??
        _extractExactPinCoordinates(htmlBody);

    if (exactPinCoords != null) {
      lat = exactPinCoords[0];
      lng = exactPinCoords[1];
      resolutionMethod = placeId != null ? 'feature_id' : 'exact_pin';
    }

    // Priority 2: If exact POI pin is missing, search via extracted Place Name using Geocoder
    if ((lat == null || lng == null) &&
        extractedName != null &&
        extractedName.isNotEmpty &&
        extractedName != 'Google 地圖' &&
        extractedName != 'Google Maps') {
      try {
        final searchResults =
            await NominatimService.searchPlaces(extractedName);
        if (searchResults.isNotEmpty) {
          lat = searchResults.first.latitude;
          lng = searchResults.first.longitude;
          resolutionMethod = 'place_name_search';
        }
      } catch (_) {}
    }

    // Priority 3 (Lowest Fallback): Camera Viewport Center (@lat,lng)
    if (lat == null || lng == null) {
      final viewportCoords = _extractViewportCoordinates(input) ??
          _extractViewportCoordinates(expandedUrl) ??
          _extractViewportCoordinates(htmlBody);

      if (viewportCoords != null) {
        lat = viewportCoords[0];
        lng = viewportCoords[1];
        resolutionMethod = 'viewport_coords';
      }
    }

    // Resolve missing place name via Reverse Geocoding if name is missing or generic
    if (lat != null && lng != null) {
      if (extractedName == null ||
          extractedName.isEmpty ||
          extractedName == 'Google 地圖' ||
          extractedName == 'Google Maps' ||
          extractedName.startsWith('自訂地點') ||
          extractedName.startsWith('自訂定位點')) {
        final geocodedName = await _reverseGeocode(lat, lng);
        if (geocodedName != null && geocodedName.isNotEmpty) {
          extractedName = geocodedName;
        }
      }

      return ParsedLocationResult(
        sourceUrl: input,
        expandedUrl: expandedUrl,
        placeId: placeId,
        name: extractedName != null
            ? _cleanAndDecodeName(extractedName)
            : '自訂地點 (${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)})',
        latitude: lat,
        longitude: lng,
        resolutionMethod: resolutionMethod,
      );
    }

    return null;
  }

  /// Extracts Feature ID, CID, or Place ID from string
  static String? _extractPlaceId(String str) {
    if (str.isEmpty) return null;

    // Pattern 1: Feature ID Hex pair (e.g., !1s0x34683d5a4980f7ad:0x7c731fa55b85a3c1 or ftid=0x...:0x...)
    final pFtid = RegExp(r'(?:!1s|ftid=)?(0x[0-9a-fA-F]+(?:%3A|:)?0x[0-9a-fA-F]+)')
        .firstMatch(str);
    if (pFtid != null) {
      return pFtid.group(1)!.replaceAll('%3A', ':');
    }

    // Pattern 2: place_id query param (e.g., place_id=ChIJ...)
    final pPlaceId = RegExp(r'[?&]place_id=([a-zA-Z0-9_-]+)').firstMatch(str);
    if (pPlaceId != null) {
      return pPlaceId.group(1);
    }

    // Pattern 3: cid query param (e.g., cid=123456789)
    final pCid = RegExp(r'[?&]cid=(\d+)').firstMatch(str);
    if (pCid != null) {
      return 'cid:${pCid.group(1)}';
    }

    return null;
  }

  /// Extracts EXACT POI pin coordinates (!3d / !4d / q= / ll=)
  static List<double>? _extractExactPinCoordinates(String str) {
    if (str.isEmpty) return null;

    // Pattern 1: Exact POI pin !8m2!3d35.6311555!4d139.7787019 or !3d35.6311555!4d139.7787019
    final pExactPin =
        RegExp(r'!3d(-?\d+\.\d+)(?:!|\\x21|/)*4d(-?\d+\.\d+)').firstMatch(str);
    if (pExactPin != null) {
      final lat = double.tryParse(pExactPin.group(1)!);
      final lng = double.tryParse(pExactPin.group(2)!);
      if (lat != null && lng != null) return [lat, lng];
    }

    // Pattern 2: q=35.6268,139.7766 or ll=35.6268,139.7766
    final pQ = RegExp(r'[?&](?:q|ll|query)=(-?\d+\.\d+)(?:%2C|,)(-?\d+\.\d+)')
        .firstMatch(str);
    if (pQ != null) {
      final lat = double.tryParse(pQ.group(1)!);
      final lng = double.tryParse(pQ.group(2)!);
      if (lat != null && lng != null) return [lat, lng];
    }

    // Pattern 3: Raw coordinate string (e.g. 24.9144, 121.1467)
    final pRaw =
        RegExp(r'^\s*(-?\d{1,2}\.\d{3,})\s*,\s*(-?\d{1,3}\.\d{3,})\s*$')
            .firstMatch(str);
    if (pRaw != null) {
      final lat = double.tryParse(pRaw.group(1)!);
      final lng = double.tryParse(pRaw.group(2)!);
      if (lat != null && lng != null) return [lat, lng];
    }

    return null;
  }

  /// Extracts viewport camera center coordinates (@35.6268,139.7766 or center=35.6268,139.7766)
  static List<double>? _extractViewportCoordinates(String str) {
    if (str.isEmpty) return null;

    final pAt = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(str);
    if (pAt != null) {
      final lat = double.tryParse(pAt.group(1)!);
      final lng = double.tryParse(pAt.group(2)!);
      if (lat != null && lng != null) return [lat, lng];
    }

    final pCenter =
        RegExp(r'center=(-?\d+\.\d+)(?:%2C|,)(-?\d+\.\d+)').firstMatch(str);
    if (pCenter != null) {
      final lat = double.tryParse(pCenter.group(1)!);
      final lng = double.tryParse(pCenter.group(2)!);
      if (lat != null && lng != null) return [lat, lng];
    }

    return null;
  }

  /// Extracts place name from Google Maps URL path (/maps/place/PLACE_NAME/ or ?q=PLACE_NAME)
  static String? _extractNameFromUrl(String url) {
    if (url.isEmpty) return null;

    final placeMatch =
        RegExp(r'/maps/(?:place|search)/([^/@?\x26"]+)').firstMatch(url);
    if (placeMatch != null) {
      final raw = placeMatch.group(1)!;
      final decoded = _cleanAndDecodeName(raw);
      final firstSegment = decoded.split(',').first.trim();
      if (firstSegment.isNotEmpty &&
          !firstSegment.startsWith('http') &&
          !RegExp(r'^-?\d+\.').hasMatch(firstSegment)) {
        return firstSegment;
      }
    }

    final qMatch = RegExp(r'[?&](?:q|query)=([^&]+)').firstMatch(url);
    if (qMatch != null) {
      final raw = qMatch.group(1)!;
      final decoded = _cleanAndDecodeName(raw);
      final firstSegment = decoded.split(',').first.trim();
      if (firstSegment.isNotEmpty &&
          !RegExp(r'^-?\d+\.\d+(?:%2C|,)\s*-?\d+\.\d+$')
              .hasMatch(firstSegment)) {
        return firstSegment;
      }
    }

    return null;
  }

  /// Extracts place name from HTML meta tags or title
  static String? _extractNameFromHtml(String html) {
    if (html.isEmpty) return null;

    final ogMatch = RegExp(
                r'property="(?:og:title|twitter:title)"\s+content="([^"]+)"',
                caseSensitive: false)
            .firstMatch(html) ??
        RegExp(r'content="([^"]+)"\s+property="(?:og:title|twitter:title)"',
                caseSensitive: false)
            .firstMatch(html) ??
        RegExp(r'og:title"[^>]*content="([^"]+)"', caseSensitive: false)
            .firstMatch(html);

    if (ogMatch != null) {
      final raw = ogMatch.group(1)!;
      final decoded = _cleanAndDecodeName(raw);
      final clean =
          decoded.split('·').first.split('-').first.split('|').first.trim();
      if (clean.isNotEmpty && clean != 'Google 地圖' && clean != 'Google Maps') {
        return clean;
      }
    }

    final titleMatch =
        RegExp(r'<title>(.*?)</title>', caseSensitive: false).firstMatch(html);
    if (titleMatch != null) {
      final raw = titleMatch.group(1)!;
      final decoded = _cleanAndDecodeName(raw);
      final titleText = decoded
          .replaceAll('- Google 地圖', '')
          .replaceAll('- Google Maps', '')
          .replaceAll('· Google Maps', '')
          .replaceAll('· Google 地圖', '')
          .trim();
      if (titleText.isNotEmpty &&
          titleText != 'Google 地圖' &&
          titleText != 'Google Maps') {
        return titleText;
      }
    }

    return null;
  }

  /// Safely decodes URL encoded strings (including percent-encoding and + signs)
  static String _cleanAndDecodeName(String str) {
    String decoded = str.replaceAll('+', ' ').trim();
    try {
      decoded = Uri.decodeComponent(decoded);
    } catch (_) {
      try {
        decoded = Uri.decodeFull(decoded);
      } catch (_) {}
    }

    int iterations = 0;
    while (decoded.contains('%') && iterations < 3) {
      try {
        final next = Uri.decodeComponent(decoded);
        if (next == decoded) break;
        decoded = next;
      } catch (_) {
        break;
      }
      iterations++;
    }

    return decoded.replaceAll('+', ' ').trim();
  }

  /// Reverse geocodes coordinates to a place name via Nominatim
  static Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&accept-language=zh-TW',
      );
      final response = await http
          .get(
            url,
            headers: {'User-Agent': 'TripPinFlutterMapApp/1.0'},
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          final candidate = address['neighbourhood'] ??
              address['quarter'] ??
              address['suburb'] ??
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

        final name = data['name'] as String?;
        if (name != null && name.isNotEmpty) return name;

        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          final firstPart = displayName.split(',').first.trim();
          if (firstPart.isNotEmpty) return firstPart;
        }
      }
    } catch (_) {}
    return null;
  }
}
