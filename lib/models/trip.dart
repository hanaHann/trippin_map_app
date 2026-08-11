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
    return Trip(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      totalDays: json['totalDays'] ?? 5,
      landmarks: (json['landmarks'] as List<dynamic>?)
              ?.map((l) => Landmark.fromJson(l))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
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
