import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bsafe_app/providers/report_provider.dart';
import 'package:bsafe_app/theme/app_theme.dart';
import 'package:bsafe_app/widgets/stat_card.dart';
import 'package:bsafe_app/widgets/recent_report_card.dart';
import 'package:bsafe_app/widgets/shimmer_loading.dart';
import 'package:bsafe_app/widgets/animated_counter.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // ignore: unused_element
  Widget _buildHealthBar(Map<String, dynamic> stats) {
    final highRisk = stats['highRisk'] ?? 0;
    final totalRisk = (stats['total'] ?? 0);

    // 決定社區健康狀態
    final bool isHealthy = highRisk <= 2;
    final String statusEmoji = isHealthy ? '😊' : '😰';
    final String statusText = isHealthy ? 'Community safety is good!' : 'Your attention is needed!';
    final List<Color> gradientColors = isHealthy
        ? [const Color(0xFF6BCB77), const Color(0xFF4ECDC4)]
        : [const Color(0xFFFF8C42), const Color(0xFFFF6B6B)];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(statusEmoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'Total of ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              AnimatedCounter(
                value: totalRisk,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                ' issues need attention',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<ReportProvider>(
        builder: (context, reportProvider, _) {
          if (reportProvider.isLoading && reportProvider.reports.isEmpty) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ShimmerLoading(
                      width: double.infinity,
                      height: 150,
                      borderRadius: BorderRadius.circular(30)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                          child: ShimmerLoading(
                              width: double.infinity,
                              height: 100,
                              borderRadius: BorderRadius.circular(24))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: ShimmerLoading(
                              width: double.infinity,
                              height: 100,
                              borderRadius: BorderRadius.circular(24))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: ShimmerLoading(
                              width: double.infinity,
                              height: 100,
                              borderRadius: BorderRadius.circular(24))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const ShimmerCard(),
                  const ShimmerCard(),
                  const ShimmerCard(),
                ],
              ),
            );
          }

          final stats = reportProvider.statistics;
          final recentReports = reportProvider.reports.take(5).toList();

          return RefreshIndicator(
            onRefresh: () => reportProvider.loadReports(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryLight,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Building Safety Monitor',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Monitoring ${stats['total'] ?? 0} issue report(s)',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                          ),
                        ),
                        if (reportProvider.pendingSyncCount > 0) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.sync,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${reportProvider.pendingSyncCount} pending sync',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Statistics Section
                  const Text(
                    'Risk Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: 'High Risk',
                          value: '${stats['highRisk'] ?? 0}',
                          icon: Icons.warning_amber_rounded,
                          color: AppTheme.riskHigh,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'Medium Risk',
                          value: '${stats['mediumRisk'] ?? 0}',
                          icon: Icons.error_outline,
                          color: AppTheme.riskMedium,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'Low Risk',
                          value: '${stats['lowRisk'] ?? 0}',
                          icon: Icons.check_circle_outline,
                          color: AppTheme.riskLow,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: 'Urgent',
                          value: '${stats['urgent'] ?? 0}',
                          icon: Icons.priority_high,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'Pending',
                          value: '${stats['pending'] ?? 0}',
                          icon: Icons.pending_actions,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'Resolved',
                          value: '${stats['resolved'] ?? 0}',
                          icon: Icons.task_alt,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Recent Reports Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Reports',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Navigate to history
                          // Could use a callback or navigation here
                        },
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (recentReports.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No reports yet',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap "Report" below to get started',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...recentReports.map((report) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: RecentReportCard(report: report),
                        )),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
