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
  /// Nominatim's free-text matching weighs a generic "station" suffix
  /// ("車站"/"站"/"駅") as heavily as the specific place name in front of
  /// it, so a query like "山形車站" or "京都站" reliably returns unrelated
  /// train stations in a completely different country instead of the
  /// intended one -- while the English equivalent ("山形 Station") reliably
  /// finds the correct match. Verified live against several stations.
  /// Kept as a cheap, zero-dependency safety net for when translation (see
  /// [_translateToEnglish]) is unavailable or rate-limited -- it only ever
  /// fires on the fallback path, after a translated search has already been
  /// tried and failed.
  static String _normalizeStationQuery(String query) {
    const stationSuffixes = ['車站', '站', '駅'];
    for (final suffix in stationSuffixes) {
      if (query.endsWith(suffix) && query.length > suffix.length) {
        final placeName =
            query.substring(0, query.length - suffix.length).trim();
        if (placeName.isNotEmpty) {
          return '$placeName Station';
        }
      }
    }
    return query;
  }

  static bool _looksNonEnglish(String query) {
    // CJK Unified Ideographs, Hiragana, and Katakana ranges. A query typed
    // in Chinese/Japanese is exactly the case where Nominatim's matching is
    // unreliable (see below), so only these need the translation step.
    return RegExp(r'[一-鿿぀-ヿｦ-ﾟ]')
        .hasMatch(query);
  }

  /// Nominatim's global full-text index matches non-English place names
  /// poorly in general -- not just the station-suffix case above, but any
  /// query mixing a specific place name with common words in Chinese or
  /// Japanese can rank an unrelated same-word match in a totally different
  /// country above the intended place. Translating the whole query to
  /// English first and searching with that is far more reliable in
  /// practice (verified live: "山形車站" -> "Yamagata Station",
  /// "成田機場" -> "Narita Airport", "淺草寺" -> "Sensoji Temple" all
  /// resolve correctly, where the raw Chinese queries do not).
  ///
  /// Uses MyMemory's free, keyless translation endpoint. This sends the
  /// user's search text to a third-party service, is best-effort, and is
  /// rate-limited -- any failure (network error, timeout, quota) must fall
  /// back to searching the original-language query rather than surfacing
  /// an error, since translation is an accuracy improvement, not a
  /// prerequisite for search.
  static Future<String?> _translateToEnglish(String query) async {
    try {
      final url = Uri.https('api.mymemory.translated.net', '/get', {
        'q': query,
        'langpair': 'zh-TW|en',
      });
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data['responseStatus'] != 200) return null;

      final translated =
          data['responseData']?['translatedText']?.toString().trim();
      if (translated == null || translated.isEmpty) return null;
      // MyMemory echoes the input back when it has no useful translation.
      if (translated == query.trim()) return null;
      return translated;
    } catch (_) {
      return null;
    }
  }

  static Future<List<SearchPlaceResult>> searchPlaces(
    String query, {
    double? biasLatitude,
    double? biasLongitude,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];

    if (_looksNonEnglish(trimmedQuery)) {
      final translated = await _translateToEnglish(trimmedQuery);
      if (translated != null) {
        final translatedResults = await _rawSearch(
          translated,
          biasLatitude: biasLatitude,
          biasLongitude: biasLongitude,
        );
        if (translatedResults.isNotEmpty) return translatedResults;
      }
    }

    // Fallback: translation unavailable/failed/rate-limited, the query was
    // already English, or the translated search came back empty. Still
    // apply the station-suffix normalization as a last-resort safety net.
    return _rawSearch(
      _normalizeStationQuery(trimmedQuery),
      biasLatitude: biasLatitude,
      biasLongitude: biasLongitude,
    );
  }

  static Future<List<SearchPlaceResult>> _rawSearch(
    String q, {
    double? biasLatitude,
    double? biasLongitude,
  }) async {
    try {
      final queryParams = {
        'format': 'json',
        'q': q,
        'limit': '7',
        'addressdetails': '1',
        // Prefer Traditional Chinese POI names/addresses when available,
        // falling back to Chinese then English.
        'accept-language': 'zh-TW,zh,en',
      };

      // Soft location bias (no `bounded` param, so it narrows relevance
      // ranking without excluding legitimate results elsewhere): a generic
      // query like "星巴克" or "7-11" should prefer the branch near the
      // trip's own area instead of an arbitrary global match.
      if (biasLatitude != null && biasLongitude != null) {
        const boxDegrees = 0.5; // roughly a 50km bias box
        queryParams['viewbox'] = [
          biasLongitude - boxDegrees,
          biasLatitude + boxDegrees,
          biasLongitude + boxDegrees,
          biasLatitude - boxDegrees,
        ].join(',');
      }

      final url = Uri.https(
          'nominatim.openstreetmap.org', '/search', queryParams);
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'TripPinFlutterMapApp/1.0 (contact@trippin.app)',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final results = <SearchPlaceResult>[];
        for (final item in data) {
          final lat = double.tryParse(item['lat']?.toString() ?? '');
          final lon = double.tryParse(item['lon']?.toString() ?? '');
          // Skip a malformed/out-of-range result instead of throwing and
          // discarding every other valid result in this response.
          if (lat == null ||
              lon == null ||
              !lat.isFinite ||
              !lon.isFinite ||
              lat < -90 ||
              lat > 90 ||
              lon < -180 ||
              lon > 180) {
            continue;
          }
          results.add(SearchPlaceResult(
            displayName: item['display_name']?.toString() ?? '',
            latitude: lat,
            longitude: lon,
          ));
        }
        return results;
      }
    } catch (e) {
      // Handle network error gracefully
    }
    return [];
  }
}
