import 'landmark.dart';

class Trip {
  final String id;
  final String title;
  final String description;
  final List<Landmark> landmarks;
  final DateTime createdAt;

  Trip({
    required this.id,
    required this.title,
    this.description = '',
    required this.landmarks,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'landmarks': landmarks.map((l) => l.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
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
    List<Landmark>? landmarks,
  }) {
    return Trip(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      landmarks: landmarks ?? List.from(this.landmarks),
      createdAt: createdAt,
    );
  }
}
