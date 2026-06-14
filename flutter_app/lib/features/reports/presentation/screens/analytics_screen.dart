import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../../core/providers/supabase_provider.dart';

final revenueReportProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1).toIso8601String().split('T')[0];
  final monthEnd = DateTime(now.year, now.month + 1, 0).toIso8601String().split('T')[0];

  try {
    final result = await client.rpc('get_revenue_summary', params: {
      'p_from': monthStart,
      'p_to': monthEnd,
    });
    final daily = await client.from('v_daily_revenue').select().gte('date', monthStart).lte('date', monthEnd).order('date');
    return {'summary': result?[0] ?? {}, 'daily': daily};
  } catch (_) {
    return {'summary': {}, 'daily': []};
  }
});

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(revenueReportProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(
        title: 'Analytics & Reports',
        actions: [
          IconButton(icon: const Icon(Icons.download_outlined), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textHint,
            indicatorColor: AppTheme.primary,
            tabs: const [
              Tab(text: 'Revenue'),
              Tab(text: 'Bookings'),
              Tab(text: 'Occupancy'),
              Tab(text: 'Activities'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Revenue Tab
                reportAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (data) => _RevenueTab(data: data),
                ),
                // Bookings Tab
                const _BookingsTab(),
                // Occupancy Tab
                const _OccupancyTab(),
                // Activities Tab
                const _ActivitiesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RevenueTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final daily = data['daily'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // KPI Cards
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              StatCard(
                label: 'Total Revenue',
                value: '₹${((summary['total_revenue'] ?? 0) as num).toStringAsFixed(0)}',
                icon: Icons.currency_rupee_rounded,
                color: AppTheme.success,
              ),
              StatCard(
                label: 'Collected',
                value: '₹${((summary['collected_revenue'] ?? 0) as num).toStringAsFixed(0)}',
                icon: Icons.account_balance_wallet_outlined,
                color: AppTheme.info,
              ),
              StatCard(
                label: 'Total Bookings',
                value: '${summary['total_bookings'] ?? 0}',
                icon: Icons.calendar_month_outlined,
                color: AppTheme.primary,
              ),
              StatCard(
                label: 'Avg. Booking',
                value: '₹${((summary['avg_booking_value'] ?? 0) as num).toStringAsFixed(0)}',
                icon: Icons.analytics_outlined,
                color: AppTheme.accent,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Revenue Chart
          if (daily.isNotEmpty) ...[
            const SectionHeader(title: 'Daily Revenue (This Month)'),
            const SizedBox(height: 12),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: daily.map((d) => ((d['total_revenue'] ?? 0) as num).toDouble()).reduce((a, b) => a > b ? a : b) * 1.2,
                  barGroups: daily.asMap().entries.map((e) => BarChartGroupData(
                    x: e.key,
                    barRods: [BarChartRodData(
                      toY: ((e.value['total_revenue'] ?? 0) as num).toDouble(),
                      color: AppTheme.primary,
                      width: 8,
                      borderRadius: BorderRadius.circular(4),
                    )],
                  )).toList(),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: false),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          // Payment method breakdown
          const SectionHeader(title: 'Payment Methods'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            ),
            child: const Column(
              children: [
                _PaymentMethodRow('Cash', 0.35, AppTheme.success),
                SizedBox(height: 10),
                _PaymentMethodRow('UPI', 0.45, AppTheme.primary),
                SizedBox(height: 10),
                _PaymentMethodRow('Card', 0.15, AppTheme.info),
                SizedBox(height: 10),
                _PaymentMethodRow('Online', 0.05, AppTheme.accent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodRow extends StatelessWidget {
  final String label;
  final double fraction;
  final Color color;
  const _PaymentMethodRow(this.label, this.fraction, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 60, child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${(fraction * 100).toStringAsFixed(0)}%', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _BookingsTab extends StatelessWidget {
  const _BookingsTab();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Bookings Report - Coming Soon'));
  }
}

class _OccupancyTab extends StatelessWidget {
  const _OccupancyTab();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Occupancy Report - Coming Soon'));
  }
}

class _ActivitiesTab extends StatelessWidget {
  const _ActivitiesTab();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Activities Report - Coming Soon'));
  }
}
