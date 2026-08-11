import 'package:flutter_test/flutter_test.dart';
import 'package:trip_pin_app/services/google_maps_parser.dart';

void main() {
  group('GoogleMapsParser Tests', () {
    test('Parse Google Maps short link for Odaiba with resolutionMethod and Feature ID', () async {
      final result = await GoogleMapsParser.parseInput(
          'https://maps.app.goo.gl/A9zkPTQX6CjjEn6XA');

      expect(result, isNotNull);
      expect(result!.sourceUrl, equals('https://maps.app.goo.gl/A9zkPTQX6CjjEn6XA'));
      expect(result.expandedUrl, isNotEmpty);
      expect(result.latitude, closeTo(35.631, 0.05));
      expect(result.longitude, closeTo(139.778, 0.05));
      expect(result.name, anyOf(contains('台場'), contains('Daiba')));
      expect(result.resolutionMethod, anyOf(equals('feature_id'), equals('exact_pin'), equals('place_name_search')));
    });

    test('Parse Google Maps share text with title prefix', () async {
      final result = await GoogleMapsParser.parseInput(
          '「東京晴空塔」 https://maps.app.goo.gl/A9zkPTQX6CjjEn6XA');

      expect(result, isNotNull);
      expect(result!.name, equals('東京晴空塔'));
      expect(result.sourceUrl, equals('「東京晴空塔」 https://maps.app.goo.gl/A9zkPTQX6CjjEn6XA'));
    });

    test('Parse user short link https://maps.app.goo.gl/vcrrAQ6UXD3EChRS9 (木村堂 楊梅店)', () async {
      final result = await GoogleMapsParser.parseInput(
          'https://maps.app.goo.gl/vcrrAQ6UXD3EChRS9');

      expect(result, isNotNull);
      expect(result!.name, equals('木村堂 楊梅店'));
      expect(result.latitude, closeTo(24.908, 0.02));
      expect(result.longitude, closeTo(121.167, 0.02));
      expect(result.resolutionMethod, anyOf(equals('feature_id'), equals('exact_pin'), equals('place_name_search')));
    });

    test('Error Handling: empty input returns null', () async {
      final result = await GoogleMapsParser.parseInput('  ');
      expect(result, isNull);
    });

    test('Error Handling: invalid URL graceful fallback', () async {
      final result = await GoogleMapsParser.parseInput('invalid_url_text_without_coords');
      expect(result, isNull);
    });
  });
}
