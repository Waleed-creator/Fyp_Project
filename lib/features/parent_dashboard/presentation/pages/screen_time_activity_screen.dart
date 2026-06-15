import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/design_system/app_design_system.dart';
import '../../../../core/widgets/modern_app_bar.dart';
import '../../../app_limits/data/models/app_usage_firebase.dart';
import '../../data/services/parent_dashboard_firebase_service.dart';
import '../../utils/app_category_helper.dart';
import 'package:intl/intl.dart';

class ScreenTimeActivityScreen extends StatefulWidget {
  final String childId;
  final String childName;
  final String parentId;

  const ScreenTimeActivityScreen({
    super.key,
    required this.childId,
    required this.childName,
    required this.parentId,
  });

  @override
  State<ScreenTimeActivityScreen> createState() => _ScreenTimeActivityScreenState();
}

class _ScreenTimeActivityScreenState extends State<ScreenTimeActivityScreen> {
  final ParentDashboardFirebaseService _firebaseService = ParentDashboardFirebaseService();
  String _selectedView = 'Today';
  bool _showByCategory = true;

  static const double _barAreaHeight = 200.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightCyan,
      appBar: ModernAppBar(
        title: '${widget.childName}\'s Screen Time',
      ),
      body: StreamBuilder<List<AppUsageFirebase>>(
        stream: _firebaseService.getAppUsageStream(
          childId: widget.childId,
          parentId: widget.parentId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading data: ${snapshot.error}'),
                ],
              ),
            );
          }

          final apps = snapshot.data ?? [];
          final userApps = apps.where((app) => !app.isSystemApp).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppDesignSystem.spacingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildViewSelector(),
                const SizedBox(height: AppDesignSystem.spacingL),
                if (_selectedView == 'Today') ...[
                  _buildTodayView(userApps),
                ] else if (_selectedView == 'Weekly') ...[
                  _buildWeeklyView(userApps),
                ] else if (_selectedView == 'Monthly') ...[
                  _buildMonthlyView(userApps),
                ],
                const SizedBox(height: AppDesignSystem.spacingXL),
                _buildMostUsedAppsSection(userApps),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildViewSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildViewButton('Today', 0),
          _buildViewButton('Weekly', 1),
          _buildViewButton('Monthly', 2),
        ],
      ),
    );
  }

  Widget _buildViewButton(String label, int index) {
    final isSelected = _selectedView == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedView = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.darkCyan : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppDesignSystem.labelLarge.copyWith(
              color: isSelected ? AppColors.white : AppColors.textLight,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayView(List<AppUsageFirebase> apps) {
    final todayApps = _getTodayApps(apps);
    final totalMinutes = todayApps.fold<int>(0, (sum, app) => sum + app.usageDuration);
    final categoryData = _getCategoryData(todayApps);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppDesignSystem.spacingL),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                _formatTotalTime(totalMinutes),
                style: AppDesignSystem.headline1.copyWith(
                  color: AppColors.darkCyan,
                  fontSize: 48,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Today's Usage",
                style: AppDesignSystem.bodyLarge.copyWith(color: AppColors.textLight),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDesignSystem.spacingL),
        _buildDonutChart(categoryData, totalMinutes),
        const SizedBox(height: AppDesignSystem.spacingL),
        _buildCategoryLegend(categoryData),
      ],
    );
  }

  Widget _buildWeeklyView(List<AppUsageFirebase> apps) {
    final weeklyData = _getWeeklyData(apps);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppDesignSystem.spacingL),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This Week', style: AppDesignSystem.headline2),
              const SizedBox(height: 8),
              Text(
                _formatTotalTime(weeklyData['totalMinutes'] as int),
                style: AppDesignSystem.headline3.copyWith(color: AppColors.darkCyan),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Switch(
                    value: _showByCategory,
                    onChanged: (value) => setState(() => _showByCategory = value),
                    activeThumbColor: AppColors.darkCyan,
                  ),
                  const SizedBox(width: 8),
                  Text('Show by Category', style: AppDesignSystem.bodyMedium),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDesignSystem.spacingL),
        _buildWeeklyStackedBarChart(weeklyData),
      ],
    );
  }

  Widget _buildMonthlyView(List<AppUsageFirebase> apps) {
    final monthlyData = _getMonthlyData(apps);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppDesignSystem.spacingL),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This Month', style: AppDesignSystem.headline2),
              const SizedBox(height: 8),
              Text(
                _formatTotalTime(monthlyData['totalMinutes'] as int),
                style: AppDesignSystem.headline3.copyWith(color: AppColors.darkCyan),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDesignSystem.spacingL),
        _buildMonthlyBarChart(monthlyData),
      ],
    );
  }

  Widget _buildDonutChart(Map<AppCategory, int> categoryData, int totalMinutes) {
    if (totalMinutes == 0) {
      return Container(
        height: 300,
        padding: const EdgeInsets.all(AppDesignSystem.spacingL),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pie_chart_outline, size: 64, color: AppColors.textLight),
              const SizedBox(height: 16),
              Text(
                'No usage data for today',
                style: AppDesignSystem.bodyLarge.copyWith(color: AppColors.textLight),
              ),
            ],
          ),
        ),
      );
    }

    final pieChartData = categoryData.entries
        .where((entry) => entry.value > 0)
        .map((entry) {
      final percentage = (entry.value / totalMinutes) * 100;
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${percentage.toStringAsFixed(0)}%',
        color: Color(AppCategoryHelper.getCategoryColor(entry.key)),
        radius: 80,
        titleStyle: AppDesignSystem.labelSmall.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.bold,
        ),
      );
    }).toList();

    return Container(
      height: 300,
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: PieChart(
        PieChartData(
          sections: pieChartData,
          sectionsSpace: 2,
          centerSpaceRadius: 60,
          startDegreeOffset: -90,
        ),
      ),
    );
  }

  Widget _buildCategoryLegend(Map<AppCategory, int> categoryData) {
    final entries = categoryData.entries
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Usage by Category', style: AppDesignSystem.headline3),
          const SizedBox(height: AppDesignSystem.spacingM),
          ...entries.map((entry) => _buildLegendItem(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildLegendItem(AppCategory category, int minutes) {
    final color = Color(AppCategoryHelper.getCategoryColor(category));
    final categoryName = AppCategoryHelper.getCategoryName(category);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignSystem.spacingM),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(categoryName, style: AppDesignSystem.bodyMedium)),
          Text(
            _formatDuration(minutes),
            style: AppDesignSystem.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.darkCyan,
            ),
          ),
        ],
      ),
    );
  }

  // ── WEEKLY CHART ─────────────────────────────────────────────────────────────

  Widget _buildWeeklyStackedBarChart(Map<String, dynamic> weeklyData) {
    final dailyData = weeklyData['dailyData'] as List<Map<String, dynamic>>;

    if (dailyData.isEmpty) {
      return Container(
        height: 300,
        padding: const EdgeInsets.all(AppDesignSystem.spacingL),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(child: Text('No weekly data available')),
      );
    }

    final maxMinutes = dailyData
        .map((day) => day['totalMinutes'] as int)
        .reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // ← shrink-wrap; no fixed height needed
        children: [
          Text('Daily Screen Time', style: AppDesignSystem.headline3),
          const SizedBox(height: AppDesignSystem.spacingM),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: dailyData.map((day) {
              final dayName      = day['dayName']      as String;
              final totalMinutes = day['totalMinutes'] as int;
              final categoryMinutes =
                  day['categoryMinutes'] as Map<AppCategory, int>;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Fixed-height bar slot ──────────────────────────────
                      SizedBox(
                        height: _barAreaHeight,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (_showByCategory)
                              _buildStackedBar(
                                  categoryMinutes, totalMinutes, maxMinutes)
                            else
                              Container(
                                height: maxMinutes > 0
                                    ? (totalMinutes / maxMinutes) *
                                        _barAreaHeight
                                    : 0,
                                decoration: BoxDecoration(
                                  color: AppColors.darkCyan,
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // ── Labels always below bar slot ──────────────────────
                      const SizedBox(height: 6),
                      Text(
                        dayName,
                        style: AppDesignSystem.labelSmall,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDuration(totalMinutes),
                        style: AppDesignSystem.labelSmall.copyWith(
                            fontSize: 9, color: AppColors.textLight),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStackedBar(
      Map<AppCategory, int> categoryMinutes, int totalMinutes, int maxMinutes) {
    final entries = categoryMinutes.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final barHeight =
        maxMinutes > 0 ? (totalMinutes / maxMinutes) * _barAreaHeight : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: entries.map((entry) {
        final segmentHeight = totalMinutes > 0
            ? (entry.value / totalMinutes) * barHeight
            : 0.0;
        final color = Color(AppCategoryHelper.getCategoryColor(entry.key));

        return Container(
          height: segmentHeight,
          decoration: BoxDecoration(
            color: color,
            borderRadius: entries.indexOf(entry) == 0
                ? const BorderRadius.vertical(top: Radius.circular(4))
                : null,
          ),
        );
      }).toList(),
    );
  }

  // ── MONTHLY CHART ─────────────────────────────────────────────────────────────

  Widget _buildMonthlyBarChart(Map<String, dynamic> monthlyData) {
    final weeklyData = monthlyData['weeklyData'] as List<Map<String, dynamic>>;

    if (weeklyData.isEmpty) {
      return Container(
        height: 300,
        padding: const EdgeInsets.all(AppDesignSystem.spacingL),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(child: Text('No monthly data available')),
      );
    }

    final maxMinutes = weeklyData
        .map((week) => week['totalMinutes'] as int)
        .reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // ← shrink-wrap
        children: [
          Text('Weekly Screen Time', style: AppDesignSystem.headline3),
          const SizedBox(height: AppDesignSystem.spacingM),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: weeklyData.map((week) {
              final weekLabel    = week['weekLabel']    as String;
              final totalMinutes = week['totalMinutes'] as int;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Fixed-height bar slot ──────────────────────────────
                      SizedBox(
                        height: _barAreaHeight,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: maxMinutes > 0
                                  ? (totalMinutes / maxMinutes) * _barAreaHeight
                                  : 0,
                              decoration: BoxDecoration(
                                color: AppColors.darkCyan,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ── Labels always below bar slot ──────────────────────
                      const SizedBox(height: 6),
                      Text(
                        weekLabel,
                        style: AppDesignSystem.labelSmall,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDuration(totalMinutes),
                        style: AppDesignSystem.labelSmall.copyWith(
                            fontSize: 9, color: AppColors.textLight),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── MOST USED APPS ────────────────────────────────────────────────────────────

  Widget _buildMostUsedAppsSection(List<AppUsageFirebase> apps) {
    final mostUsed = apps
        .where((app) => !app.isSystemApp)
        .toList()
      ..sort((a, b) => b.usageDuration.compareTo(a.usageDuration));

    final topApps = mostUsed.take(10).toList();
    if (topApps.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Most Used Apps', style: AppDesignSystem.headline2),
        const SizedBox(height: AppDesignSystem.spacingM),
        ...topApps.map((app) => _buildAppCard(app)),
      ],
    );
  }

  Widget _buildAppCard(AppUsageFirebase app) {
    final category      = AppCategoryHelper.getCategory(app.appName, app.packageName);
    final categoryColor = Color(AppCategoryHelper.getCategoryColor(category));

    return Container(
      margin: const EdgeInsets.only(bottom: AppDesignSystem.spacingM),
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                app.appName.isNotEmpty ? app.appName[0].toUpperCase() : 'A',
                style: AppDesignSystem.headline3.copyWith(color: categoryColor),
              ),
            ),
          ),
          const SizedBox(width: AppDesignSystem.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.appName,
                  style: AppDesignSystem.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  AppCategoryHelper.getCategoryName(category),
                  style: AppDesignSystem.bodySmall.copyWith(color: AppColors.textLight),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDuration(app.usageDuration),
                style: AppDesignSystem.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkCyan,
                ),
              ),
              Text(
                '${app.launchCount} launches',
                style: AppDesignSystem.bodySmall.copyWith(color: AppColors.textLight),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────────

  List<AppUsageFirebase> _getTodayApps(List<AppUsageFirebase> apps) {
    final today      = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    return apps.where((app) => app.lastUsed.isAfter(startOfDay)).toList();
  }

  Map<AppCategory, int> _getCategoryData(List<AppUsageFirebase> apps) {
    final categoryData = <AppCategory, int>{};
    for (final app in apps) {
      final category = AppCategoryHelper.getCategory(app.appName, app.packageName);
      categoryData[category] = (categoryData[category] ?? 0) + app.usageDuration;
    }
    return categoryData;
  }

  Map<String, dynamic> _getWeeklyData(List<AppUsageFirebase> apps) {
    final now        = DateTime.now();
    final dailyData  = <Map<String, dynamic>>[];
    int totalMinutes = 0;

    for (int i = 6; i >= 0; i--) {
      final date       = now.subtract(Duration(days: i));
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay   = startOfDay.add(const Duration(days: 1));

      final dayApps = apps
          .where((app) =>
              app.lastUsed.isAfter(startOfDay) &&
              app.lastUsed.isBefore(endOfDay))
          .toList();

      final dayMinutes      = dayApps.fold<int>(0, (s, a) => s + a.usageDuration);
      final categoryMinutes = _getCategoryData(dayApps);

      dailyData.add({
        'dayName':         DateFormat('E').format(date),
        'totalMinutes':    dayMinutes,
        'categoryMinutes': categoryMinutes,
      });
      totalMinutes += dayMinutes;
    }

    return {'totalMinutes': totalMinutes, 'dailyData': dailyData};
  }

  Map<String, dynamic> _getMonthlyData(List<AppUsageFirebase> apps) {
    final now        = DateTime.now();
    final weeklyData = <Map<String, dynamic>>[];
    int totalMinutes = 0;

    for (int i = 3; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: (i * 7) + now.weekday - 1));
      final weekEnd   = weekStart.add(const Duration(days: 7));

      final weekApps = apps
          .where((app) =>
              app.lastUsed.isAfter(weekStart) &&
              app.lastUsed.isBefore(weekEnd))
          .toList();

      final weekMinutes = weekApps.fold<int>(0, (s, a) => s + a.usageDuration);
      weeklyData.add({'weekLabel': 'W${4 - i}', 'totalMinutes': weekMinutes});
      totalMinutes += weekMinutes;
    }

    return {'totalMinutes': totalMinutes, 'weeklyData': weeklyData};
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String _formatTotalTime(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}hrs' : '${h}hrs ${m}mins';
  }
}