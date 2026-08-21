import 'landmark.dart';

class Trip {
  final String id;
  final String title;
  final String description;
  final int totalDays;
  final List<Landmark> landmarks;
  final DateTime createdAt;

  Trip({
    required this.id,
    required this.title,
    this.description = '',
    this.totalDays = 5,
    required this.landmarks,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'totalDays': totalDays,
      'landmarks': landmarks.map((l) => l.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    // Parse landmarks defensively, one at a time: a single malformed
    // landmark should not discard this trip (or, transitively, every other
    // trip in the list -- see TripProvider._loadTrips).
    final landmarksJson = json['landmarks'] as List<dynamic>? ?? [];
    final landmarks = <Landmark>[];
    for (final l in landmarksJson) {
      try {
        landmarks.add(Landmark.fromJson(l as Map<String, dynamic>));
      } catch (_) {
        // Skip this landmark; keep the rest of the trip intact.
      }
    }

    final rawTotalDays = json['totalDays'];
    final totalDays = (rawTotalDays is num ? rawTotalDays.toInt() : 5)
        .clamp(1, 30);

    return Trip(
      id: (json['id'] as String?) ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: (json['title'] as String?) ?? '未命名行程',
      description: json['description'] ?? '',
      totalDays: totalDays,
      landmarks: landmarks,
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ??
              DateTime.now())
          : DateTime.now(),
    );
  }

  Trip copyWith({
    String? title,
    String? description,
    int? totalDays,
    List<Landmark>? landmarks,
  }) {
    return Trip(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      totalDays: totalDays ?? this.totalDays,
      landmarks: landmarks ?? List.from(this.landmarks),
      createdAt: createdAt,
    );
  }
}
