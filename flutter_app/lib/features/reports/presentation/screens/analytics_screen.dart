import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../../core/providers/supabase_provider.dart';

// ── Demo data ─────────────────────────────────────────────────────────────────

final _demoRevenueSummary = {
  'total_revenue': 284500,
  'collected_revenue': 198000,
  'total_bookings': 18,
  'avg_booking_value': 15806,
};

final _demoRevenueDailyList = List.generate(30, (i) {
  final d = DateTime.now().subtract(Duration(days: 29 - i));
  return {'date': d.toIso8601String().split('T')[0], 'total_revenue': (i % 7 == 0 ? 4200 : i % 3 == 0 ? 8500 : 6000) + (i * 110)};
});

final _demoBilledRooms = [
  {'room_number': '101', 'guest_name': 'Priya Sharma',  'status': 'CHECKED_IN',   'total_amount': 12250, 'check_in_date': '2026-10-06', 'num_adults': 2, 'num_children': 0, 'package_name': 'Deluxe'},
  {'room_number': '102', 'guest_name': 'Rajesh Kumar',  'status': 'CHECKED_IN',   'total_amount': 13650, 'check_in_date': '2026-10-07', 'num_adults': 2, 'num_children': 0, 'package_name': 'Suite'},
  {'room_number': '201', 'guest_name': 'Anita Patel',   'status': 'BOOKED',        'total_amount': 2464,  'check_in_date': '2026-10-08', 'num_adults': 1, 'num_children': 1, 'package_name': 'Standard'},
  {'room_number': '205', 'guest_name': 'Vikram Singh',  'status': 'CHECKED_IN',   'total_amount': 17360, 'check_in_date': '2026-10-05', 'num_adults': 3, 'num_children': 0, 'package_name': 'Deluxe'},
  {'room_number': '301', 'guest_name': 'Meena Gupta',   'status': 'ADVANCE_PAID', 'total_amount': 10848, 'check_in_date': '2026-10-08', 'num_adults': 2, 'num_children': 0, 'package_name': 'Cottage'},
  {'room_number': '302', 'guest_name': 'Suresh Patil',  'status': 'ADVANCE_PAID', 'total_amount': 15456, 'check_in_date': '2026-10-07', 'num_adults': 4, 'num_children': 1, 'package_name': 'Cottage'},
];

final _demoRoomStatuses = [
  {'room_number': '101', 'status': 'OCCUPIED',     'room_types': {'name': 'Deluxe Room'}},
  {'room_number': '102', 'status': 'OCCUPIED',     'room_types': {'name': 'Suite'}},
  {'room_number': '103', 'status': 'AVAILABLE',    'room_types': {'name': 'Deluxe Room'}},
  {'room_number': '104', 'status': 'CLEANING',     'room_types': {'name': 'Standard Room'}},
  {'room_number': '201', 'status': 'RESERVED',     'room_types': {'name': 'Standard Room'}},
  {'room_number': '202', 'status': 'AVAILABLE',    'room_types': {'name': 'Deluxe Room'}},
  {'room_number': '203', 'status': 'MAINTENANCE',  'room_types': {'name': 'Suite'}},
  {'room_number': '205', 'status': 'OCCUPIED',     'room_types': {'name': 'Deluxe Room'}},
  {'room_number': '301', 'status': 'RESERVED',     'room_types': {'name': 'Cottage'}},
  {'room_number': '302', 'status': 'RESERVED',     'room_types': {'name': 'Cottage'}},
];

// ─────────────────────────────────────────────────────────────────────────────

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
    return {'summary': _demoRevenueSummary, 'daily': _demoRevenueDailyList};
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

  Future<void> _downloadReport(BuildContext context, WidgetRef ref) async {
    try {
      final reportData = ref.read(revenueReportProvider).valueOrNull;
      final summary = (reportData?['summary'] as Map<String, dynamic>?) ?? _demoRevenueSummary;
      final now = DateTime.now();
      final monthLabel = DateFormat('MMMM yyyy').format(now);

      final doc = pw.Document();
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(color: PdfColor.fromHex('1B5E20'), borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('ANJANVEL AGRO TOURISM', style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('Monthly Analytics Report — $monthLabel', style: pw.TextStyle(color: PdfColor(1, 1, 1, 0.7), fontSize: 11)),
              ]),
              pw.Text('📊', style: const pw.TextStyle(fontSize: 28)),
            ]),
          ),
          pw.SizedBox(height: 24),
          pw.Text('Revenue Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Row(children: [
            _pdfStat(ctx, 'Total Revenue', '₹${(summary['total_revenue'] ?? 0)}'),
            pw.SizedBox(width: 12),
            _pdfStat(ctx, 'Collected', '₹${(summary['collected_revenue'] ?? 0)}'),
            pw.SizedBox(width: 12),
            _pdfStat(ctx, 'Total Bookings', '${summary['total_bookings'] ?? 0}'),
            pw.SizedBox(width: 12),
            _pdfStat(ctx, 'Avg. Booking', '₹${(summary['avg_booking_value'] ?? 0)}'),
          ]),
          pw.SizedBox(height: 24),
          pw.Text('Room Occupancy', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          ..._demoRoomStatuses.map((r) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Row(children: [
              pw.SizedBox(width: 60, child: pw.Text('Room ${r['room_number']}', style: const pw.TextStyle(fontSize: 11))),
              pw.Text(' — ${r['status']}', style: const pw.TextStyle(fontSize: 11)),
            ]),
          )),
          pw.SizedBox(height: 24),
          pw.Text('Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(now)}',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ]),
      ));

      final bytes = await doc.save();
      await Printing.sharePdf(bytes: bytes, filename: 'Anjanvel-Report-$monthLabel.pdf');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  pw.Widget _pdfStat(pw.Context ctx, String label, String value) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(revenueReportProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(
        title: 'Analytics & Reports',
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Download Report',
            onPressed: () => _downloadReport(context, ref),
          ),
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

// ── Bookings Tab ──────────────────────────────────────────────────────────────

class _BookingsTab extends ConsumerWidget {
  const _BookingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(_bookingsStatsProvider);
    return bookingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      error: (_, __) => _BookingsStaticView(),
      data: (data) => _BookingsStaticView(data: data),
    );
  }
}

final _bookingsStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1).toIso8601String().split('T')[0];
  try {
    final bookings = await client.from('bookings').select('status, total_amount, num_adults, num_children, check_in_date, package_name').gte('check_in_date', monthStart);
    return {'bookings': bookings.isEmpty ? _demoBilledRooms : bookings};
  } catch (_) {
    return {'bookings': _demoBilledRooms};
  }
});

class _BookingsStaticView extends StatelessWidget {
  final Map<String, dynamic>? data;
  const _BookingsStaticView({this.data});

  @override
  Widget build(BuildContext context) {
    final bookings = (data?['bookings'] as List<dynamic>?) ?? [];
    final total = bookings.length;
    final confirmed = bookings.where((b) => b['status'] == 'CONFIRMED').length;
    final checkedIn = bookings.where((b) => b['status'] == 'CHECKED_IN').length;
    final checkedOut = bookings.where((b) => b['status'] == 'CHECKED_OUT').length;
    final cancelled = bookings.where((b) => b['status'] == 'CANCELLED').length;
    final inquiry = bookings.where((b) => b['status'] == 'INQUIRY').length;
    final totalGuests = bookings.fold<int>(0, (s, b) =>
        s + ((b['num_adults'] as int? ?? 0) + (b['num_children'] as int? ?? 0)));

    // Package breakdown
    final pkgMap = <String, int>{};
    for (final b in bookings) {
      final pkg = b['package_name'] as String? ?? 'Unknown';
      pkgMap[pkg] = (pkgMap[pkg] ?? 0) + 1;
    }
    final pkgSorted = pkgMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status breakdown
          const SectionHeader(title: 'This Month\'s Bookings'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.2,
            children: [
              _MiniStat('Total', '$total', AppTheme.primary),
              _MiniStat('Inquiry', '$inquiry', AppTheme.textHint),
              _MiniStat('Confirmed', '$confirmed', AppTheme.info),
              _MiniStat('In-House', '$checkedIn', AppTheme.success),
              _MiniStat('Checked Out', '$checkedOut', AppTheme.secondary),
              _MiniStat('Cancelled', '$cancelled', AppTheme.error),
            ],
          ),
          const SizedBox(height: 20),
          _InfoCard('Total Guests This Month', '$totalGuests guests', Icons.people_outline, AppTheme.primary),
          const SizedBox(height: 20),
          if (pkgSorted.isNotEmpty) ...[
            const SectionHeader(title: 'Popular Packages'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
              child: Column(
                children: pkgSorted.take(5).map((e) {
                  final pct = total > 0 ? e.value / total : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 120,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(value: pct, backgroundColor: Colors.grey.shade200,
                              color: AppTheme.primary, minHeight: 6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ]),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Occupancy Tab ─────────────────────────────────────────────────────────────

class _OccupancyTab extends ConsumerWidget {
  const _OccupancyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final occupancyAsync = ref.watch(_occupancyProvider);
    return occupancyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      error: (_, __) => _OccupancyView(rooms: []),
      data: (rooms) => _OccupancyView(rooms: rooms),
    );
  }
}

final _occupancyProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    final rooms = await client.from('rooms').select('room_number, status, room_types(name)').order('room_number');
    return rooms.isEmpty ? _demoRoomStatuses : rooms;
  } catch (_) {
    return _demoRoomStatuses;
  }
});

class _OccupancyView extends StatelessWidget {
  final List<Map<String, dynamic>> rooms;
  const _OccupancyView({required this.rooms});

  @override
  Widget build(BuildContext context) {
    final total = rooms.isEmpty ? 10 : rooms.length;
    final occupied = rooms.where((r) => r['status'] == 'OCCUPIED').length;
    final available = rooms.where((r) => r['status'] == 'AVAILABLE').length;
    final reserved = rooms.where((r) => r['status'] == 'RESERVED').length;
    final cleaning = rooms.where((r) => r['status'] == 'CLEANING').length;
    final maintenance = rooms.where((r) => r['status'] == 'MAINTENANCE').length;
    final occupancyRate = total > 0 ? occupied / total : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Occupancy gauge
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: occupancyRate > 0.7
                    ? [const Color(0xFF2E7D32), const Color(0xFF43A047)]
                    : occupancyRate > 0.4
                        ? [const Color(0xFF0277BD), const Color(0xFF0288D1)]
                        : [const Color(0xFF37474F), const Color(0xFF546E7A)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            ),
            child: Column(
              children: [
                Text('${(occupancyRate * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                const Text('Occupancy Rate', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: occupancyRate,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Text('$occupied of $total rooms occupied',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Room Status Breakdown'),
          const SizedBox(height: 12),
          _RoomStatusBar('Occupied', occupied, total, AppTheme.statusOccupied),
          _RoomStatusBar('Available', available, total, AppTheme.statusAvailable),
          _RoomStatusBar('Reserved', reserved, total, AppTheme.info),
          _RoomStatusBar('Cleaning', cleaning, total, AppTheme.statusCleaning),
          _RoomStatusBar('Maintenance', maintenance, total, AppTheme.statusMaintenance),
          const SizedBox(height: 20),
          if (rooms.isNotEmpty) ...[
            const SectionHeader(title: 'Room-wise Status'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
              child: Column(
                children: rooms.map((r) {
                  final status = r['status'] as String? ?? 'AVAILABLE';
                  final rt = r['room_types'] as Map<String, dynamic>?;
                  final statusColor = {
                    'OCCUPIED': AppTheme.statusOccupied,
                    'AVAILABLE': AppTheme.statusAvailable,
                    'RESERVED': AppTheme.info,
                    'CLEANING': AppTheme.statusCleaning,
                    'MAINTENANCE': AppTheme.statusMaintenance,
                  }[status] ?? AppTheme.textHint;
                  return ListTile(
                    dense: true,
                    title: Text(r['room_number'] as String? ?? '', style: const TextStyle(fontSize: 13)),
                    subtitle: Text(rt?['name'] as String? ?? '', style: const TextStyle(fontSize: 11)),
                    trailing: StatusBadge(label: status, color: statusColor),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoomStatusBar extends StatelessWidget {
  final String label;
  final int count, total;
  final Color color;
  const _RoomStatusBar(this.label, this.count, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct, backgroundColor: Colors.grey.shade200, color: color, minHeight: 8),
        )),
        const SizedBox(width: 8),
        SizedBox(width: 40, child: Text('$count rooms', style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary), textAlign: TextAlign.right)),
      ]),
    );
  }
}

// ── Activities Tab ────────────────────────────────────────────────────────────

class _ActivitiesTab extends StatelessWidget {
  const _ActivitiesTab();

  @override
  Widget build(BuildContext context) {
    // Static popular activities for Anjanvel
    final activities = [
      {'name': 'Farm Tour',       'bookings': 24, 'revenue': 12000.0, 'color': const Color(0xFF2E7D32)},
      {'name': 'Bonfire Night',   'bookings': 20, 'revenue':  6000.0, 'color': const Color(0xFFE64A19)},
      {'name': 'Rappelling',      'bookings': 15, 'revenue': 12000.0, 'color': const Color(0xFFE53935)},
      {'name': 'Bullock Cart',    'bookings': 18, 'revenue':  4500.0, 'color': const Color(0xFF6A1B9A)},
      {'name': 'Bird Watching',   'bookings': 12, 'revenue':  4800.0, 'color': const Color(0xFF00838F)},
      {'name': 'Cooking Class',   'bookings': 10, 'revenue':  7000.0, 'color': const Color(0xFF0277BD)},
      {'name': 'Nature Walk',     'bookings':  8, 'revenue':  1600.0, 'color': const Color(0xFF558B2F)},
    ];
    final totalBookings = activities.fold<int>(0, (s, a) => s + (a['bookings'] as int));
    final totalRevenue = activities.fold<double>(0, (s, a) => s + (a['revenue'] as double));
    final maxBookings = activities.map((a) => a['bookings'] as int).reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: _InfoCard('Total Registrations', '$totalBookings', Icons.event_note_outlined, const Color(0xFF00838F))),
            const SizedBox(width: 12),
            Expanded(child: _InfoCard('Activity Revenue', '₹${totalRevenue.toStringAsFixed(0)}', Icons.currency_rupee, AppTheme.success)),
          ]),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Activity Popularity'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
            child: Column(
              children: activities.map((a) {
                final pct = maxBookings > 0 ? (a['bookings'] as int) / maxBookings : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: a['color'] as Color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    SizedBox(width: 110, child: Text(a['name'] as String, style: const TextStyle(fontSize: 12))),
                    Expanded(child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: pct, backgroundColor: Colors.grey.shade200,
                          color: a['color'] as Color, minHeight: 8),
                    )),
                    const SizedBox(width: 8),
                    Text('${a['bookings']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ]),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Revenue by Activity'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
            child: Column(
              children: (activities..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double))).map((a) =>
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: a['color'] as Color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(a['name'] as String, style: const TextStyle(fontSize: 12))),
                    Text('₹${(a['revenue'] as double).toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ]),
                ),
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textPrimary), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _InfoCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary)),
          ],
        )),
      ]),
    );
  }
}
