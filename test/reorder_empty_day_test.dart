import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_pin_app/models/landmark.dart';
import 'package:trip_pin_app/providers/trip_provider.dart';
import 'package:trip_pin_app/widgets/landmark_list_drawer.dart';

/// Drags [handle] toward [target], re-reading [target]'s *current*
/// on-screen position after every small step (it shifts as the list
/// reflows around the drag), stopping once the pointer actually lands
/// inside its live vertical band. A single position computed before the
/// drag starts goes stale the moment neighbouring items animate.
Future<void> _dragUntilOver(
  WidgetTester tester, {
  required Finder handle,
  required Finder target,
}) async {
  final startPos = tester.getCenter(handle);
  final gesture = await tester.startGesture(startPos);
  await tester.pump(const Duration(milliseconds: 100));

  var current = startPos;
  for (var i = 0; i < 60; i++) {
    final targetRect = tester.getRect(target);
    final direction = targetRect.center.dy >= current.dy ? 1 : -1;
    current = current + Offset(0, 12.0 * direction);
    await gesture.moveTo(current);
    await tester.pump(const Duration(milliseconds: 30));
    final liveRect = tester.getRect(target);
    if (current.dy >= liveRect.top && current.dy <= liveRect.bottom) {
      break;
    }
  }
  await tester.pump(const Duration(milliseconds: 100));
  await gesture.up();
  await tester.pumpAndSettle();
}

Finder _dragHandleFor(Finder cardFinder) {
  return find.descendant(
    of: cardFinder,
    matching: find.byIcon(Icons.drag_handle),
  );
}

void main() {
  testWidgets('drag a day-1 card down into an empty day 2',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = TripProvider();
    await tester.pump();

    provider.addTrip('Test Trip', '', totalDays: 3);
    provider.addLandmark(Landmark(
        id: 'A', name: 'Landmark A', latitude: 35.0, longitude: 139.0, day: 1));
    provider.addLandmark(Landmark(
        id: 'B', name: 'Landmark B', latitude: 35.1, longitude: 139.1, day: 1));
    provider.addLandmark(Landmark(
        id: 'C', name: 'Landmark C', latitude: 35.2, longitude: 139.2, day: 3));
    // day 2 intentionally has zero landmarks.

    await tester.pumpWidget(
      ChangeNotifierProvider<TripProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: LandmarkListDrawer(onSelectLandmark: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cardA = find.byKey(const ValueKey('landmark_card_A'));
    final day2Target = find.byKey(const ValueKey('empty_day_placeholder_2'));
    expect(cardA, findsOneWidget);
    expect(day2Target, findsOneWidget);

    await _dragUntilOver(
      tester,
      handle: _dragHandleFor(cardA),
      target: day2Target,
    );

    final landmarks = provider.activeTrip!.landmarks;
    final aDay = landmarks.firstWhere((l) => l.id == 'A').day;
    final bDay = landmarks.firstWhere((l) => l.id == 'B').day;
    final cDay = landmarks.firstWhere((l) => l.id == 'C').day;

    expect(aDay, 2,
        reason: 'Dragging A down onto the empty day-2 header should move '
            'it into day 2, not leave it in day 1 or skip into day 3.');
    expect(bDay, 1);
    expect(cDay, 3);
  });

  testWidgets('drag a day-3 card up into an empty day 2',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = TripProvider();
    await tester.pump();

    provider.addTrip('Test Trip', '', totalDays: 3);
    provider.addLandmark(Landmark(
        id: 'A', name: 'Landmark A', latitude: 35.0, longitude: 139.0, day: 1));
    provider.addLandmark(Landmark(
        id: 'C', name: 'Landmark C', latitude: 35.2, longitude: 139.2, day: 3));
    provider.addLandmark(Landmark(
        id: 'D', name: 'Landmark D', latitude: 35.3, longitude: 139.3, day: 3));
    // day 2 intentionally has zero landmarks.

    await tester.pumpWidget(
      ChangeNotifierProvider<TripProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: LandmarkListDrawer(onSelectLandmark: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cardC = find.byKey(const ValueKey('landmark_card_C'));
    final day2Target = find.byKey(const ValueKey('empty_day_placeholder_2'));
    expect(cardC, findsOneWidget);
    expect(day2Target, findsOneWidget);

    await _dragUntilOver(
      tester,
      handle: _dragHandleFor(cardC),
      target: day2Target,
    );

    final landmarks = provider.activeTrip!.landmarks;
    final aDay = landmarks.firstWhere((l) => l.id == 'A').day;
    final cDay = landmarks.firstWhere((l) => l.id == 'C').day;
    final dDay = landmarks.firstWhere((l) => l.id == 'D').day;

    expect(cDay, 2,
        reason: 'Dragging C up onto the empty day-2 header should move it '
            'into day 2, not leave it in day 3 or skip into day 1.');
    expect(aDay, 1);
    expect(dDay, 3);
  });
}
