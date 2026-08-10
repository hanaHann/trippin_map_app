import 'package:flutter_test/flutter_test.dart';
import 'package:trip_pin_app/services/google_maps_parser.dart';

void main() {
  test('Parse Google Maps short link for Odaiba', () async {
    final result = await GoogleMapsParser.parseInput('https://maps.app.goo.gl/A9zkPTQX6CjjEn6XA');
    expect(result, isNotNull);
    expect(result!.latitude, closeTo(35.631, 0.05));
    expect(result.longitude, closeTo(139.778, 0.05));
    expect(result.name, contains('台場'));
  });
}
