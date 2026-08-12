import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import '../models/trip.dart';
import '../models/landmark.dart';
import '../data/sample_data.dart';

enum MapTileStyle {
  macaronCream,
  light,
  dark,
  osm,
  satellite,
}

enum LabelDisplayMode {
  onMap, // Mode 1: 地圖常駐標籤
  hidden, // Mode 2: 隱藏標籤
  bottomDeck, // Mode 3: 螢幕下方橫向卡片列
}

class TripProvider with ChangeNotifier {
  List<Trip> _trips = [];
  String? _activeTripId;

  // Visual Map Controls
  LabelDisplayMode _labelDisplayMode = LabelDisplayMode.onMap;
  bool _showRouteLines = true;
  int? _selectedDayFilter;
  MapTileStyle _tileStyle = MapTileStyle.light;

  TripProvider() {
    _loadTrips();
  }

  List<Trip> get trips => _trips;
  String? get activeTripId => _activeTripId;

  Trip? get activeTrip {
    if (_trips.isEmpty) return null;
    return _trips.firstWhere(
      (t) => t.id == _activeTripId,
      orElse: () => _trips.first,
    );
  }

  LabelDisplayMode get labelDisplayMode => _labelDisplayMode;
  bool get showPermanentLabels => _labelDisplayMode == LabelDisplayMode.onMap;
  bool get showRouteLines => _showRouteLines;
  int? get selectedDayFilter => _selectedDayFilter;
  MapTileStyle get tileStyle => _tileStyle;

  List<Landmark> get currentLandmarks {
    final trip = activeTrip;
    if (trip == null) return [];
    if (_selectedDayFilter == null) {
      final sorted = List<Landmark>.from(trip.landmarks);
      sorted.sort((a, b) => a.day.compareTo(b.day));
      return sorted;
    }
    return trip.landmarks.where((l) => l.day == _selectedDayFilter).toList();
  }

  void cycleLabelDisplayMode() {
    switch (_labelDisplayMode) {
      case LabelDisplayMode.onMap:
        _labelDisplayMode = LabelDisplayMode.hidden;
        break;
      case LabelDisplayMode.hidden:
        _labelDisplayMode = LabelDisplayMode.bottomDeck;
        break;
      case LabelDisplayMode.bottomDeck:
        _labelDisplayMode = LabelDisplayMode.onMap;
        break;
    }
    notifyListeners();
  }

  void togglePermanentLabels() {
    cycleLabelDisplayMode();
  }

  void toggleRouteLines() {
    _showRouteLines = !_showRouteLines;
    notifyListeners();
  }

  void setSelectedDayFilter(int? day) {
    _selectedDayFilter = day;
    notifyListeners();
  }

  void setTileStyle(MapTileStyle style) {
    _tileStyle = style;
    notifyListeners();
  }

  void setActiveTrip(String tripId) {
    _activeTripId = tripId;
    _selectedDayFilter = null;
    notifyListeners();
    _saveToPrefs();
  }

  void addTrip(String title, String description, {int totalDays = 5}) {
    final newTrip = Trip(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      totalDays: totalDays,
      landmarks: [],
    );
    _trips.add(newTrip);
    _activeTripId = newTrip.id;
    notifyListeners();
    _saveToPrefs();
  }

  void updateTrip(String tripId, String title, String description, int totalDays) {
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index != -1) {
      _trips[index] = _trips[index].copyWith(
        title: title,
        description: description,
        totalDays: totalDays,
      );
      notifyListeners();
      _saveToPrefs();
    }
  }

  void deleteTrip(String tripId) {
    _trips.removeWhere((t) => t.id == tripId);
    if (_activeTripId == tripId) {
      _activeTripId = _trips.isNotEmpty ? _trips.first.id : null;
    }
    notifyListeners();
    _saveToPrefs();
  }

  void addLandmark(Landmark landmark) {
    final trip = activeTrip;
    if (trip == null) return;

    final updatedLandmarks = List<Landmark>.from(trip.landmarks)..add(landmark);
    _updateActiveTripLandmarks(updatedLandmarks);
  }

  void deleteLandmark(String landmarkId) {
    final trip = activeTrip;
    if (trip == null) return;

    final updatedLandmarks = List<Landmark>.from(trip.landmarks)
      ..removeWhere((l) => l.id == landmarkId);
    _updateActiveTripLandmarks(updatedLandmarks);
  }

  void updateAllLandmarks(List<Landmark> newLandmarks) {
    _updateActiveTripLandmarks(newLandmarks);
  }

  void updateLandmarkDay(String landmarkId, int newDay) {
    final trip = activeTrip;
    if (trip == null) return;

    final updatedLandmarks = trip.landmarks.map((l) {
      if (l.id == landmarkId) {
        return l.copyWith(day: newDay);
      }
      return l;
    }).toList();

    _updateActiveTripLandmarks(updatedLandmarks);
  }

  void swapDays(int dayA, int dayB) {
    final trip = activeTrip;
    if (trip == null || dayA == dayB) return;

    final updatedLandmarks = trip.landmarks.map((l) {
      if (l.day == dayA) {
        return l.copyWith(day: dayB);
      } else if (l.day == dayB) {
        return l.copyWith(day: dayA);
      }
      return l;
    }).toList();

    updatedLandmarks.sort((a, b) => a.day.compareTo(b.day));
    _updateActiveTripLandmarks(updatedLandmarks);
  }

  void reorderLandmarks(int oldIndex, int newIndex) {
    final trip = activeTrip;
    if (trip == null) return;

    if (newIndex > oldIndex) newIndex -= 1;

    if (_selectedDayFilter == null) {
      final landmarks = List<Landmark>.from(trip.landmarks);
      if (oldIndex < 0 || oldIndex >= landmarks.length) return;
      var item = landmarks.removeAt(oldIndex);
      landmarks.insert(newIndex, item);

      // Robust target day determination:
      int targetDay = item.day;
      if (landmarks.length > 1) {
        if (newIndex == 0) {
          targetDay = landmarks[1].day;
        } else if (newIndex == landmarks.length - 1) {
          targetDay = landmarks[newIndex - 1].day;
        } else {
          final prevDay = landmarks[newIndex - 1].day;
          final nextDay = landmarks[newIndex + 1].day;
          if (prevDay == nextDay) {
            targetDay = prevDay;
          } else {
            // Placed at boundary before nextDay section
            targetDay = nextDay;
          }
        }
      }

      if (item.day != targetDay) {
        item = item.copyWith(day: targetDay);
        landmarks[newIndex] = item;
      }

      _updateActiveTripLandmarks(landmarks);
    } else {
      final dayLandmarks =
          trip.landmarks.where((l) => l.day == _selectedDayFilter).toList();
      if (oldIndex < 0 || oldIndex >= dayLandmarks.length) return;

      final movedItem = dayLandmarks.removeAt(oldIndex);
      dayLandmarks.insert(newIndex, movedItem);

      final updatedGlobal = <Landmark>[];
      int dayIdx = 0;
      for (final l in trip.landmarks) {
        if (l.day == _selectedDayFilter) {
          updatedGlobal.add(dayLandmarks[dayIdx++]);
        } else {
          updatedGlobal.add(l);
        }
      }
      _updateActiveTripLandmarks(updatedGlobal);
    }
  }

  void _updateActiveTripLandmarks(List<Landmark> newLandmarks) {
    final index = _trips.indexWhere((t) => t.id == _activeTripId);
    if (index != -1) {
      _trips[index] = _trips[index].copyWith(landmarks: newLandmarks);
      notifyListeners();
      _saveToPrefs();
    }
  }

  Future<void> resetToSampleData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_trips');
    await prefs.remove('active_trip_id');
    _trips = sampleTrips;
    _activeTripId = sampleTrips.first.id;
    _selectedDayFilter = null;
    notifyListeners();
    await _saveToPrefs();
  }

  Future<void> _loadTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tripsJson = prefs.getString('saved_trips');

    if (tripsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(tripsJson);
        _trips = decoded.map((item) => Trip.fromJson(item)).map((t) {
          if (t.id == 'tokyo-sample' && t.title == '東京 5 天 4 夜精華行程') {
            return t.copyWith(title: '【範例】東京 5 天 4 夜精華行程');
          }
          if (t.id == 'kyoto-sample' && t.title == '京都古都巡禮與咖啡散策') {
            return t.copyWith(title: '【範例】京都古都巡禮與咖啡散策');
          }
          return t;
        }).toList();
        _activeTripId = prefs.getString('active_trip_id');
      } catch (e) {
        _trips = sampleTrips;
      }
    } else {
      _trips = sampleTrips;
    }

    if (_trips.isNotEmpty &&
        (_activeTripId == null || !_trips.any((t) => t.id == _activeTripId))) {
      _activeTripId = _trips.first.id;
    }

    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _trips.map((t) => t.toJson()).toList();
    await prefs.setString('saved_trips', jsonEncode(jsonList));
    if (_activeTripId != null) {
      await prefs.setString('active_trip_id', _activeTripId!);
    }
  }

  // Calculate Haversine distance between two points in km
  double calculateDistanceKm(LatLng p1, LatLng p2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, p1, p2);
  }
}
