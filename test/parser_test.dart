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
    });

    test('Parse user short link https://maps.app.goo.gl/NWXkuk8W13Hv6zmr9?g_st=ic (Ichika Pre-wedding in Tokyo)', () async {
      final result = await GoogleMapsParser.parseInput(
          'https://maps.app.goo.gl/NWXkuk8W13Hv6zmr9?g_st=ic');

      expect(result, isNotNull);
      expect(result!.name, anyOf(contains('一花婚紗'), contains('Nishiasakusa'), contains('浅草'), contains('Tokyo'), contains('東京都')));
      expect(result.latitude, closeTo(35.69, 0.1));
      expect(result.longitude, closeTo(139.73, 0.1));
    });

    test('Parse user short link https://maps.app.goo.gl/vcrrAQ6UXD3EChRS9 (木村堂 楊梅店)', () async {
      final result = await GoogleMapsParser.parseInput(
          'https://maps.app.goo.gl/vcrrAQ6UXD3EChRS9');

      expect(result, isNotNull);
      expect(result!.name, equals('木村堂 楊梅店'));
      expect(result.latitude, closeTo(24.908, 0.02));
      expect(result.longitude, closeTo(121.167, 0.02));
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
