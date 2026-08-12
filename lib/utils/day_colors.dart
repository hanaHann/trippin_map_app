import 'package:flutter/material.dart';

/// Returns a consistent, vibrant, high-contrast color for a specific trip day.
Color getDayColor(int day) {
  const dayColors = [
    Color(0xFFE53935), // Day 1: Bright Coral Red
    Color(0xFF00897B), // Day 2: Emerald Mint Teal
    Color(0xFF673AB7), // Day 3: Deep Royal Purple
    Color(0xFFFB8C00), // Day 4: Warm Sunset Amber/Orange
    Color(0xFF0288D1), // Day 5: Electric Sky Blue
    Color(0xFFD81B60), // Day 6: Vivid Hot Rose Pink
    Color(0xFF43A047), // Day 7: Fresh Green
    Color(0xFFFFB300), // Day 8: Golden Sunflower Yellow
    Color(0xFF8E24AA), // Day 9: Bright Orchid Purple
    Color(0xFF00ACC1), // Day 10: Deep Cyan
  ];

  final index = (day - 1) % dayColors.length;
  return dayColors[index < 0 ? 0 : index];
}
