import 'package:flutter/material.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/achievement_model.dart';
import 'package:urbangreen/services/achievement_service.dart';

class AchievementsSheet extends StatelessWidget {
  const AchievementsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AchievementsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final achievements = AchievementService().getAchievements();
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;
    final totalCount = achievements.length;
    final progress = totalCount > 0 ? unlockedCount / totalCount : 0.0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: isDark ? kDarkSurfaceColor : kSurfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? kDarkBorderSubtle : kBorderSubtle,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9C46A).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFFD4A373),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gardener Milestones',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? kDarkTextPrimary : kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$unlockedCount of $totalCount Milestones Completed (${(progress * 100).toInt()}%)',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? kDarkTextSecondary : kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: isDark ? kDarkBorderSubtle : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0 ? Colors.amber.shade600 : kPrimaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: isDark ? kDarkBorderSubtle : kBorderSubtle,
          ),

          // Achievements List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              itemCount: achievements.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final a = achievements[index];
                return _buildAchievementCard(context, a, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(
    BuildContext context,
    Achievement a,
    bool isDark,
  ) {
    final cardBg = a.isUnlocked
        ? (isDark
            ? kDarkCardColor
            : a.color.withValues(alpha: 0.06))
        : (isDark ? const Color(0xFF131D17) : Colors.grey.shade50);

    final borderColor = a.isUnlocked
        ? a.color.withValues(alpha: 0.35)
        : (isDark ? kDarkBorderSubtle : Colors.grey.shade300);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: a.isUnlocked
                  ? a.color.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              a.icon,
              size: 22,
              color: a.isUnlocked ? a.color : Colors.grey.shade500,
            ),
          ),
          const SizedBox(width: 14),

          // Details & Progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      a.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: a.isUnlocked
                            ? (isDark ? kDarkTextPrimary : kTextPrimary)
                            : Colors.grey.shade600,
                      ),
                    ),
                    if (a.isUnlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'UNLOCKED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else
                      Text(
                        a.progressLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  a.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: a.isUnlocked
                        ? (isDark ? kDarkTextSecondary : kTextSecondary)
                        : Colors.grey.shade500,
                    height: 1.3,
                  ),
                ),
                if (!a.isUnlocked) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: a.progressRatio,
                      minHeight: 4,
                      backgroundColor: Colors.grey.shade300,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
