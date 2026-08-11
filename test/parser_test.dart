import 'package:flutter_test/flutter_test.dart';
import 'package:trip_pin_app/services/google_maps_parser.dart';

void main() {
  test('Parse Google Maps short link for Odaiba', () async {
    final result = await GoogleMapsParser.parseInput('https://maps.app.goo.gl/A9zkPTQX6CjjEn6XA');
    expect(result, isNotNull);
    expect(result!.latitude, closeTo(35.631, 0.05));
    expect(result.longitude, closeTo(139.778, 0.05));
    expect(result.name, anyOf(contains('台場'), contains('Daiba')));
  });

  test('Parse Google Maps share text with title prefix', () async {
    final result = await GoogleMapsParser.parseInput('「東京晴空塔」 https://maps.app.goo.gl/A9zkPTQX6CjjEn6XA');
    expect(result, isNotNull);
    expect(result!.name, equals('東京晴空塔'));
  });

  test('Parse user short link https://maps.app.goo.gl/vcrrAQ6UXD3EChRS9', () async {
    final result = await GoogleMapsParser.parseInput('https://maps.app.goo.gl/vcrrAQ6UXD3EChRS9');
    expect(result, isNotNull);
    expect(result!.name, equals('木村堂 楊梅店'));
    expect(result.latitude, closeTo(24.908, 0.01));
    expect(result.longitude, closeTo(121.167, 0.01));
  });
}
