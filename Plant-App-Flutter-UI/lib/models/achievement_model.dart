import 'package:flutter/material.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int currentProgress;
  final int maxProgress;
  final bool isUnlocked;
  final String category;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.currentProgress,
    required this.maxProgress,
    required this.isUnlocked,
    this.category = 'General',
  });

  double get progressRatio {
    if (maxProgress <= 0) return 0.0;
    final ratio = currentProgress / maxProgress;
    return ratio > 1.0 ? 1.0 : ratio;
  }

  String get progressLabel => '$currentProgress / $maxProgress';
}
