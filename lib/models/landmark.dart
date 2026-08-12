import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum LandmarkCategory {
  food,
  attraction,
  hotel,
  shopping,
  cafe,
  transport,
  favorite,
}

extension LandmarkCategoryExtension on LandmarkCategory {
  String get displayName {
    switch (this) {
      case LandmarkCategory.food:
        return '美食餐飲';
      case LandmarkCategory.attraction:
        return '觀光景點';
      case LandmarkCategory.hotel:
        return '住宿飯店';
      case LandmarkCategory.shopping:
        return '購物逛街';
      case LandmarkCategory.cafe:
        return '咖啡甜點';
      case LandmarkCategory.transport:
        return '交通車站';
      case LandmarkCategory.favorite:
        return '口袋名單';
    }
  }

  String get iconSymbol {
    switch (this) {
      case LandmarkCategory.food:
        return '🍕';
      case LandmarkCategory.attraction:
        return '⛩️';
      case LandmarkCategory.hotel:
        return '🏨';
      case LandmarkCategory.shopping:
        return '🛍️';
      case LandmarkCategory.cafe:
        return '☕';
      case LandmarkCategory.transport:
        return '🚌';
      case LandmarkCategory.favorite:
        return '⭐';
    }
  }

  Color get color {
    switch (this) {
      case LandmarkCategory.food:
        return Colors.deepOrange;
      case LandmarkCategory.attraction:
        return Colors.indigo;
      case LandmarkCategory.hotel:
        return Colors.teal;
      case LandmarkCategory.shopping:
        return Colors.pink;
      case LandmarkCategory.cafe:
        return Colors.amber.shade700;
      case LandmarkCategory.transport:
        return Colors.blue;
      case LandmarkCategory.favorite:
        return Colors.purple;
    }
  }
}

class Landmark {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final LandmarkCategory category;
  final String address;
  final String notes;
  final int day;

  Landmark({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.category = LandmarkCategory.attraction,
    this.address = '',
    this.notes = '',
    this.day = 1,
  });

  LatLng get location => LatLng(latitude, longitude);

  Landmark copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    LandmarkCategory? category,
    String? address,
    String? notes,
    int? day,
  }) {
    return Landmark(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      day: day ?? this.day,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'category': category.name,
      'address': address,
      'notes': notes,
      'day': day,
    };
  }

  factory Landmark.fromJson(Map<String, dynamic> json) {
    return Landmark(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] ?? '未命名地點',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      category: LandmarkCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => LandmarkCategory.attraction,
      ),
      address: json['address'] ?? '',
      notes: json['notes'] ?? '',
      day: json['day'] ?? 1,
    );
  }
}
