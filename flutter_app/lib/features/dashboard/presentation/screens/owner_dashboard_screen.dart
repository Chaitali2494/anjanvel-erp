import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/dashboard_provider.dart';
import '../../../housekeeping/presentation/widgets/housekeeping_panel.dart';
import '../../../activities/presentation/widgets/activities_panel.dart';
import '../../../billing/data/billing_state_provider.dart';
import '../../../activities/data/activity_bookings_provider.dart';
import '../../../rooms/data/room_service.dart';
import '../../../guest/data/guest_requests_provider.dart';
import '../../../bookings/data/session_bookings_provider.dart';
import '../../../bookings/data/booking_service.dart';
import '../../../food/data/food_orders_state_provider.dart';
import 'package:intl/intl.dart';

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final dashboardAsync = ref.watch(dashboardStatsProvider);

    // ── Live billing revenue — updates instantly when bills are paid ──────────
    final billingState = ref.watch(billingStateProvider);
    final paidBills    = billingState.values.where((b) => b['is_paid'] == true).toList();
    final paidRevenue  = paidBills.fold(0.0, (s, b) => s + ((b['amount'] as num?)?.toDouble() ?? 0.0));
    final paidCount    = paidBills.length;

    // ── Live session stats — reactive to every booking/check-in action ────────
    final sessionBookings = ref.watch(sessionBookingsProvider);
    final allFoodOrders   = ref.watch(foodOrdersStateProvider);
    final allActivities   = ref.watch(activityBookingsProvider).valueOrNull ?? [];
    final today = DateTime.now().toIso8601String().split('T')[0];

    // Force room panel to refresh when session bookings change
    ref.listen(sessionBookingsProvider, (_, __) {
      ref.invalidate(allRoomsProvider);
    });

    // Arrivals today = bookings with check_in_date == today (any active status)
    final arrivalsToday = sessionBookings.where((b) {
      final ci  = b['check_in_date'] as String? ?? '';
      final eff = sessionStatusOverrides[b['id']] ?? b['status'] as String? ?? '';
      return ci == today && ['CONFIRMED', 'CHECKED_IN', 'ADVANCE_PAID'].contains(eff);
    }).length;

    // Checked-in today = status CHECKED_IN with check_in_date == today
    final checkInsToday = sessionBookings.where((b) {
      final ci  = b['check_in_date'] as String? ?? '';
      final eff = sessionStatusOverrides[b['id']] ?? b['status'] as String? ?? '';
      return ci == today && eff == 'CHECKED_IN';
    }).length;

    // Check-outs today = check_out_date == today with CHECKED_OUT or CHECKED_IN status
    final checkOutsToday = sessionBookings.where((b) {
      final co  = b['check_out_date'] as String? ?? '';
      final eff = sessionStatusOverrides[b['id']] ?? b['status'] as String? ?? '';
      return co == today && (eff == 'CHECKED_OUT' || eff == 'CHECKED_IN');
    }).length;

    // Today's session check-ins (for the check-in list)
    final sessionTodayCheckins = sessionBookings.where((b) {
      final ci  = b['check_in_date'] as String? ?? '';
      final eff = sessionStatusOverrides[b['id']] ?? b['status'] as String? ?? '';
      return ci == today && ['CONFIRMED', 'CHECKED_IN', 'ADVANCE_PAID'].contains(eff);
    }).toList();

    // Live badge counts for quick actions
    final pendingFoodOrders = allFoodOrders
        .where((o) => (o['status'] as String?) == 'PENDING').length;
    final activeActivities = allActivities
        .where((a) => (a['status'] as String?) != 'CANCELLED').length;
    final unpaidBills = billingState.values
        .where((b) => b['is_paid'] != true).length;
    final pendingCheckIns = sessionBookings.where((b) {
      final ci  = b['check_in_date'] as String? ?? '';
      final eff = sessionStatusOverrides[b['id']] ?? b['status'] as String? ?? '';
      return ci == today && eff == 'CONFIRMED';
    }).length;

    // Guests in-house = rooms currently occupied from sessionRoomBookings
    final guestsInHouse = sessionRoomBookings.values.where((b) {
      final bId = b['id'] as String? ?? '';
      final eff = sessionStatusOverrides[bId] ?? b['status'] as String? ?? '';
      return eff == 'CHECKED_IN';
    }).fold(0, (sum, b) => sum + ((b['num_adults'] as num?)?.toInt() ?? 1) + ((b['num_children'] as num?)?.toInt() ?? 0));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: AppTheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2E7D32), Color(0xFF388E3C)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Good ${_getGreeting()}, ${user?.fullName.split(' ').first ?? 'Owner'}! 👋',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Anjanvel Resort',
                              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.refresh_outlined, color: Colors.white),
                              tooltip: 'Refresh',
                              onPressed: () => ref.invalidate(dashboardStatsProvider),
                            ),
                            IconButton(
                              icon: const Icon(Icons.switch_account_rounded, color: Colors.white),
                              tooltip: 'Switch Role',
                              onPressed: () => context.go('/role-selection'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                              onPressed: () => context.push(AppRoutes.notifications),
                            ),
                            GestureDetector(
                              onTap: () => context.push(AppRoutes.profile),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.white24,
                                backgroundImage: user?.avatarUrl != null
                                    ? NetworkImage(user!.avatarUrl!)
                                    : null,
                                child: user?.avatarUrl == null
                                    ? Text(
                                        user?.fullName.substring(0, 1) ?? 'O',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(AppTheme.spaceMD),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                dashboardAsync.when(
                  loading: () => const _DashboardSkeleton(),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (stats) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Today's Stats
                      _TodayStatsGrid(
                        stats: stats,
                        paidRevenue: paidRevenue,
                        paidCount: paidCount,
                        liveArrivals: arrivalsToday,
                        liveCheckIns: checkInsToday,
                        liveCheckOuts: checkOutsToday,
                        liveGuestsInHouse: guestsInHouse,
                      ),
                      const SizedBox(height: AppTheme.spaceLG),

                      // Revenue Chart
                      const SectionHeader(title: 'Revenue (This Week)'),
                      const SizedBox(height: AppTheme.spaceMD),
                      _RevenueChart(data: stats.weeklyRevenue),
                      const SizedBox(height: AppTheme.spaceLG),

                      // Quick Actions
                      const SectionHeader(title: 'Quick Actions'),
                      const SizedBox(height: AppTheme.spaceMD),
                      _QuickActionsGrid(
                        pendingCheckIns:  pendingCheckIns,
                        pendingFood:      pendingFoodOrders,
                        activeActivities: activeActivities,
                        unpaidBills:      unpaidBills,
                        occupiedRooms:    guestsInHouse > 0 ? sessionRoomBookings.length : 0,
                      ),
                      const SizedBox(height: AppTheme.spaceLG),

                      // ── Revenue from Billing (live sync) ───────────────
                      const SectionHeader(title: 'Revenue Collected Today'),
                      const SizedBox(height: AppTheme.spaceMD),
                      _PaidBillsSummaryCard(
                        billingState: billingState,
                        paidRevenue: paidRevenue,
                        paidCount: paidCount,
                      ),
                      const SizedBox(height: AppTheme.spaceLG),

                      // ── Bill Card ──────────────────────────────────────
                      const SectionHeader(title: 'Current Bills'),
                      const SizedBox(height: AppTheme.spaceMD),
                      const _DashboardBillCard(),
                      const SizedBox(height: AppTheme.spaceLG),

                      // Room Status Panel
                      const _RoomStatusPanel(),
                      const SizedBox(height: AppTheme.spaceLG),

                      // ── Guest Requests (from QR) ─────────────────────────
                      const SizedBox(height: AppTheme.spaceLG),
                      _GuestRequestsPanel(),
                      const SizedBox(height: AppTheme.spaceLG),

                      // ── Housekeeping Status ──────────────────────────────
                      HousekeepingPanel(),
                      const SizedBox(height: AppTheme.spaceLG),

                      // ── Activities Panel ──────────────────────────────────
                      const ActivitiesPanel(),
                      const SizedBox(height: AppTheme.spaceLG),

                      // Today's Check-ins — merge session + Supabase, dedup by booking_number
                      SectionHeader(
                        title: "Today's Check-ins  (${sessionTodayCheckins.length + stats.todayCheckins.length})",
                        action: 'All Bookings',
                        onActionTap: () => context.push(AppRoutes.bookings),
                      ),
                      const SizedBox(height: AppTheme.spaceMD),
                      if (sessionTodayCheckins.isEmpty && stats.todayCheckins.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(children: [
                            const Icon(Icons.event_available_outlined, color: AppTheme.textHint, size: 20),
                            const SizedBox(width: 8),
                            Text('No check-ins scheduled for today',
                                style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
                          ]),
                        )
                      else ...[
                        ...sessionTodayCheckins.map((b) => _BookingTile(booking: b)),
                        ...stats.todayCheckins
                            .where((db) => !sessionTodayCheckins
                                .any((s) => s['booking_number'] == db['booking_number']))
                            .map((b) => _BookingTile(booking: b)),
                      ],

                      // Low Stock Alerts
                      if (stats.lowStockAlerts > 0) ...[
                        const SizedBox(height: AppTheme.spaceLG),
                        _AlertBanner(
                          icon: Icons.inventory_2_outlined,
                          message: '${stats.lowStockAlerts} inventory items below minimum stock',
                          color: AppTheme.warning,
                          onTap: () => context.push(AppRoutes.inventory),
                        ),
                      ],

                      // Maintenance Alerts
                      if (stats.maintenanceOpen > 0) ...[
                        const SizedBox(height: AppTheme.spaceSM),
                        _AlertBanner(
                          icon: Icons.build_outlined,
                          message: '${stats.maintenanceOpen} maintenance tickets open',
                          color: AppTheme.error,
                          onTap: () => context.push(AppRoutes.maintenance),
                        ),
                      ],

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _OwnerBottomNav(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.createBooking),
        icon: const Icon(Icons.add),
        label: const Text('New Booking'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

// ── Today's Stats ──────────────────────────────────────────────────────────────

class _TodayStatsGrid extends StatelessWidget {
  final DashboardStats stats;
  final double paidRevenue;
  final int    paidCount;
  final int    liveArrivals;
  final int    liveCheckIns;
  final int    liveCheckOuts;
  final int    liveGuestsInHouse;

  const _TodayStatsGrid({
    required this.stats,
    this.paidRevenue       = 0,
    this.paidCount         = 0,
    this.liveArrivals      = 0,
    this.liveCheckIns      = 0,
    this.liveCheckOuts     = 0,
    this.liveGuestsInHouse = 0,
  });

  @override
  Widget build(BuildContext context) {
    final totalRevenue = stats.revenueToday + paidRevenue;

    // Prefer live session counts; fall back to Supabase counts
    final guestsInHouse  = liveGuestsInHouse > 0 ? liveGuestsInHouse  : stats.guestsInhouse;
    final arrivalsToday  = liveArrivals  > 0 ? liveArrivals   : stats.checkinsToday;
    final checkInsToday  = liveCheckIns  > 0 ? liveCheckIns   : stats.checkinsToday;
    final checkOutsToday = liveCheckOuts > 0 ? liveCheckOuts  : stats.checkoutsToday;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        StatCard(
          label: "Today's Revenue",
          value: '₹${totalRevenue.toStringAsFixed(0)}',
          icon: Icons.currency_rupee_rounded,
          color: AppTheme.success,
          subtitle: paidRevenue > 0
              ? '$paidCount bill${paidCount > 1 ? "s" : ""} paid  •  ₹${paidRevenue.toStringAsFixed(0)}'
              : 'No bills paid yet',
          onTap: () {},
        ),
        StatCard(
          label: 'Guests In-House',
          value: '$guestsInHouse',
          icon: Icons.people_outline_rounded,
          color: AppTheme.primary,
          subtitle: '$arrivalsToday arriving today',
          onTap: () {},
        ),
        StatCard(
          label: 'Arrivals Today',
          value: '$arrivalsToday',
          icon: Icons.flight_land_rounded,
          color: const Color(0xFF00838F),
          subtitle: '$checkInsToday checked in',
          onTap: () {},
        ),
        StatCard(
          label: 'Check-ins Today',
          value: '$checkInsToday',
          icon: Icons.login_rounded,
          color: AppTheme.info,
          onTap: () {},
        ),
        StatCard(
          label: 'Check-outs Today',
          value: '$checkOutsToday',
          icon: Icons.logout_rounded,
          color: AppTheme.secondary,
          onTap: () {},
        ),
        StatCard(
          label: 'Pending Tasks',
          value: '${stats.hkPending}',
          icon: Icons.cleaning_services_outlined,
          color: AppTheme.warning,
          onTap: () {},
        ),
      ],
    );
  }
}

// ── Revenue Chart ───────────────────────────────────────────────────────────────

class _RevenueChart extends StatelessWidget {
  final List<double> data;
  const _RevenueChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final spots = data.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final maxVal = data.isEmpty ? 10000.0 : (data.reduce((a, b) => a > b ? a : b) * 1.2).clamp(1000.0, double.infinity);

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF1B5E20), const Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This Week',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxVal,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withOpacity(0.15),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, _) {
                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        final idx = v.toInt();
                        if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
                        return Text(
                          days[idx],
                          style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.white,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white.withOpacity(0.25), Colors.white.withOpacity(0)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Actions ───────────────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  final int pendingCheckIns;
  final int pendingFood;
  final int activeActivities;
  final int unpaidBills;
  final int occupiedRooms;

  const _QuickActionsGrid({
    this.pendingCheckIns  = 0,
    this.pendingFood      = 0,
    this.activeActivities = 0,
    this.unpaidBills      = 0,
    this.occupiedRooms    = 0,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _Action('New Booking', Icons.add_circle_outline_rounded, '/bookings/create',   AppTheme.primary,  0),
      _Action('Roadmap',     Icons.route_rounded,              '/bookings/roadmap',  const Color(0xFF7B61FF), 0),
      _Action('Check-in',    Icons.login_rounded,              '/checkin',           AppTheme.info,     pendingCheckIns),
      _Action('Rooms',       Icons.bed_outlined,               '/rooms',             AppTheme.secondary,occupiedRooms),
      _Action('Food Orders', Icons.restaurant_menu_outlined,   '/food',              AppTheme.warning,  pendingFood),
      _Action('Activities',  Icons.hiking_outlined,            '/activities/tracker',const Color(0xFF00695C), activeActivities),
      _Action('Billing',     Icons.receipt_long_rounded,       '/billing',           const Color(0xFF00838F), unpaidBills),
      _Action('Staff',       Icons.people_rounded,             '/staff',             const Color(0xFF1565C0), 0),
      _Action('Reports',     Icons.bar_chart_rounded,          '/reports',           AppTheme.accent,   0),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / 110).floor().clamp(3, 6);
        final tileW = (constraints.maxWidth - (cols - 1) * 10) / cols;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: actions.map((a) => SizedBox(
            width: tileW,
            height: 88,
            child: _QuickActionTile(action: a),
          )).toList(),
        );
      },
    );
  }
}

class _Action {
  final String label;
  final IconData icon;
  final String route;
  final Color color;
  final int badge;
  const _Action(this.label, this.icon, this.route, this.color, this.badge);
}

class _QuickActionTile extends StatelessWidget {
  final _Action action;
  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(action.route),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [action.color, action.color.withOpacity(0.75)],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              boxShadow: [
                BoxShadow(
                  color: action.color.withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(action.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    action.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
          // Live badge — only shown when count > 0
          if (action.badge > 0)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  '${action.badge}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Room Status Panel (HK/Activities style) ────────────────────────────────────

class _RoomStatusPanel extends ConsumerWidget {
  const _RoomStatusPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(allRoomsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Room Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
            Row(children: [
              TextButton(
                onPressed: () => context.push('/rooms'),
                child: const Text('View All', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: () => context.push('/rooms'),
                icon: const Icon(Icons.bed_outlined, size: 16),
                label: const Text('Manage', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ]),
          ],
        ),
        const SizedBox(height: 8),
        roomsAsync.when(
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(color: AppTheme.primary),
          )),
          error: (_, __) => _buildRoomsFromSession(context),
          data: (dbRooms) {
            // Merge DB rooms with session room assignments
            final allRooms = List<Map<String, dynamic>>.from(dbRooms);

            // Add session-assigned rooms not already in DB list
            for (final entry in sessionRoomBookings.entries) {
              final rno = entry.key;
              final booking = entry.value;
              final alreadyIn = allRooms.any((r) => r['room_number']?.toString() == rno);
              if (!alreadyIn) {
                final bId  = booking['id'] as String? ?? '';
                final bEff = sessionStatusOverrides[bId] ?? booking['status'] as String? ?? '';
                allRooms.add({
                  'id': rno,
                  'room_number': rno,
                  'room_type_name': booking['room_type_name'] ?? 'Room',
                  'type_name': booking['room_type_name'] ?? 'Room',
                  'status': bEff == 'CHECKED_IN' ? 'OCCUPIED' : 'RESERVED',
                  'current_guest': ((booking['guests'] as Map?)?['full_name']) ?? '',
                });
              }
            }

            final rooms = allRooms;
            final available   = rooms.where((r) => r['status'] == 'AVAILABLE').length;
            final occupied    = rooms.where((r) => r['status'] == 'OCCUPIED').length;
            final reserved    = rooms.where((r) => r['status'] == 'RESERVED').length;
            final cleaning    = rooms.where((r) => r['status'] == 'CLEANING').length;
            final maintenance = rooms.where((r) => r['status'] == 'MAINTENANCE').length;

            // Show occupied + reserved rooms first (up to 5)
            final activeRooms = rooms
                .where((r) => r['status'] == 'OCCUPIED' || r['status'] == 'RESERVED')
                .take(5)
                .toList();

            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Column(
                children: [
                  // Stats strip — green gradient
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)]),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      _RmStat('Available',   '$available',   const Color(0xFFA5D6A7)),
                      _RmDiv(),
                      _RmStat('Occupied',    '$occupied',    const Color(0xFFEF9A9A)),
                      _RmDiv(),
                      _RmStat('Reserved',    '$reserved',    const Color(0xFF90CAF9)),
                      _RmDiv(),
                      _RmStat('Cleaning',    '$cleaning',    const Color(0xFFFFE082)),
                      _RmDiv(),
                      _RmStat('Maint.',      '$maintenance', const Color(0xFFCFD8DC)),
                    ]),
                  ),

                  // Active room rows
                  if (activeRooms.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.check_circle_outline_rounded, color: Color(0xFF2E7D32), size: 20),
                        SizedBox(width: 8),
                        Text('No rooms currently occupied or reserved', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                      ]),
                    )
                  else
                    ...activeRooms.map((room) => _RoomRow(room: room)),

                  // Footer → Rooms Dashboard
                  InkWell(
                    onTap: () => context.push('/rooms'),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('Open Room Dashboard', style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.primary),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// Fallback: build room panel purely from session data (kBillableRooms + sessionRoomBookings)
  Widget _buildRoomsFromSession(BuildContext context) {
    final rooms = kBillableRooms.map((demo) {
      final rno     = demo['room_number'] as String;
      final booking = sessionRoomBookings[rno];
      String status = 'AVAILABLE';
      String? guest;
      if (booking != null) {
        final bId  = booking['id'] as String? ?? '';
        final bEff = sessionStatusOverrides[bId] ?? booking['status'] as String? ?? '';
        status = bEff == 'CHECKED_IN' ? 'OCCUPIED' : 'RESERVED';
        guest  = ((booking['guests'] as Map?)?['full_name']) as String?;
      }
      return {
        'id': rno,
        'room_number': rno,
        'room_type_name': demo['room_type'],
        'type_name': demo['room_type'],
        'status': status,
        'current_guest': guest ?? demo['guest_name'],
      };
    }).toList();

    final occupied  = rooms.where((r) => r['status'] == 'OCCUPIED').length;
    final reserved  = rooms.where((r) => r['status'] == 'RESERVED').length;
    final available = rooms.where((r) => r['status'] == 'AVAILABLE').length;
    final activeRooms = rooms
        .where((r) => r['status'] == 'OCCUPIED' || r['status'] == 'RESERVED')
        .take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)]),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            _RmStat('Available', '$available', const Color(0xFFA5D6A7)),
            _RmDiv(),
            _RmStat('Occupied',  '$occupied',  const Color(0xFFEF9A9A)),
            _RmDiv(),
            _RmStat('Reserved',  '$reserved',  const Color(0xFF90CAF9)),
          ]),
        ),
        if (activeRooms.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle_outline_rounded, color: Color(0xFF2E7D32), size: 20),
              SizedBox(width: 8),
              Text('No rooms currently occupied', style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
            ]),
          )
        else
          ...activeRooms.map((room) => _RoomRow(room: room)),
        InkWell(
          onTap: () => context.push('/rooms'),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Open Room Dashboard', style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.primary),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _RmStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _RmStat(this.label, this.value, this.color);
  @override Widget build(_) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9), textAlign: TextAlign.center),
  ]));
}

class _RmDiv extends StatelessWidget {
  const _RmDiv();
  @override Widget build(_) => Container(width: 1, height: 28, color: Colors.white24);
}

class _RoomRow extends StatelessWidget {
  final Map<String, dynamic> room;
  const _RoomRow({required this.room});

  @override
  Widget build(BuildContext context) {
    final status   = room['status'] as String? ?? 'AVAILABLE';
    final roomNo   = room['room_number'] as String? ?? '—';
    final typeName = room['room_type_name'] ?? room['type_name'] ?? 'Room';
    final guest    = room['current_guest'] as String?;

    final Color statusColor;
    switch (status) {
      case 'OCCUPIED':    statusColor = AppTheme.statusOccupied; break;
      case 'RESERVED':    statusColor = AppTheme.statusReserved; break;
      case 'CLEANING':    statusColor = AppTheme.statusCleaning; break;
      case 'MAINTENANCE': statusColor = AppTheme.statusMaintenance; break;
      default:            statusColor = AppTheme.statusAvailable;
    }

    return GestureDetector(
      onTap: () => context.push('/rooms/${room['id']}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text(roomNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primary))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(typeName.toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
            if (guest != null)
              Text(guest, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11))
            else
              const Text('No guest', style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(status.replaceAll('_', ' '), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

// ── Booking Tile ────────────────────────────────────────────────────────────────

class _BookingTile extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _BookingTile({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person_outline, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking['guest_name'] ?? 'Guest',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${booking['booking_number']} • ${booking['total_guests']} guests',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
          StatusBadge(
            label: booking['status'] ?? 'CONFIRMED',
            color: booking['status'] == 'CHECKED_IN' ? AppTheme.success : AppTheme.info,
          ),
        ],
      ),
    );
  }
}

// ── Alert Banner ────────────────────────────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  final VoidCallback? onTap;

  const _AlertBanner({required this.icon, required this.message, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500))),
            Icon(Icons.chevron_right, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Nav ──────────────────────────────────────────────────────────────────

class _OwnerBottomNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(Icons.dashboard_outlined, Icons.dashboard_rounded, 'Home', '/dashboard/owner'),
              _NavItem(Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Bookings', '/bookings'),
              _NavItem(Icons.login_rounded, Icons.login_rounded, 'Check-in', '/checkin'),
              _NavItem(Icons.bed_outlined, Icons.bed_rounded, 'Rooms', '/rooms'),
              _NavItem(Icons.people_outlined, Icons.people_rounded, 'Staff', '/staff'),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  const _NavItem(this.icon, this.activeIcon, this.label, this.route);

  @override
  Widget build(BuildContext context) {
    final isActive = GoRouterState.of(context).matchedLocation.startsWith(route);
    return GestureDetector(
      onTap: () => context.go(route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? AppTheme.primary.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppTheme.primary : AppTheme.textHint,
              size: 22,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? AppTheme.primary : AppTheme.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dashboard Skeleton ─────────────────────────────────────────────────────────

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: List.generate(6, (_) => Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            ),
          )),
        ),
      ],
    );
  }
}

// ── Paid Bills Summary Card (live revenue sync) ───────────────────────────────

class _PaidBillsSummaryCard extends StatelessWidget {
  final Map<String, Map<String, dynamic>> billingState;
  final double paidRevenue;
  final int paidCount;
  const _PaidBillsSummaryCard({
    required this.billingState,
    required this.paidRevenue,
    required this.paidCount,
  });

  @override
  Widget build(BuildContext context) {
    if (paidCount == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: const Row(children: [
          Icon(Icons.receipt_long_outlined, color: AppTheme.textHint, size: 22),
          SizedBox(width: 12),
          Text('No bills collected yet today',
              style: TextStyle(color: AppTheme.textHint, fontSize: 14)),
        ]),
      );
    }

    final paidRooms = billingState.entries.where((e) => e.value['is_paid'] == true).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: AppTheme.success.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.success.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMD)),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20),
            const SizedBox(width: 10),
            Text('$paidCount Bill${paidCount > 1 ? "s" : ""} Collected',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.success)),
            const Spacer(),
            Text('₹${paidRevenue.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.success)),
          ]),
        ),
        // Room rows
        ...paidRooms.map((entry) {
          final rno    = entry.key;
          final data   = entry.value;
          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          final paidAt = data['paid_at'] as String? ?? '';
          String timeStr = '';
          if (paidAt.isNotEmpty) {
            final dt = DateTime.tryParse(paidAt);
            if (dt != null) {
              final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
              final m = dt.minute.toString().padLeft(2, '0');
              timeStr = '$h:$m ${dt.hour >= 12 ? "PM" : "AM"}';
            }
          }
          final roomInfo = getRoomInfo(rno);
          final guest    = roomInfo['guest_name'] as String? ?? 'Room $rno';

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(rno,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.success)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(guest,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (timeStr.isNotEmpty)
                  Text('Paid at $timeStr',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
              ])),
              Text('₹${amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.success)),
            ]),
          );
        }),
        const SizedBox(height: 4),
      ]),
    );
  }
}

// ── Dashboard Bill Card ────────────────────────────────────────────────────────

class _DashboardBillCard extends ConsumerWidget {
  const _DashboardBillCard();

  static const _statusColors = {
    'CHECKED_IN':    Color(0xFF2E7D32),
    'BOOKED':        Color(0xFF1565C0),
    'ADVANCE_PAID':  Color(0xFFE65100),
  };

  static const _statusLabels = {
    'CHECKED_IN':   'Checked In',
    'BOOKED':       'Booked',
    'ADVANCE_PAID': 'Advance Paid',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billingState    = ref.watch(billingStateProvider);
    final activityAsync   = ref.watch(activityBookingsProvider);

    final allBookings = activityAsync.maybeWhen(
      data: (d) => d, orElse: () => <Map<String, dynamic>>[],
    );

    final paidCount = kBillableRooms
        .where((r) => billingState[r['room_number']]?['is_paid'] == true)
        .length;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            const Icon(Icons.receipt_long_rounded, color: Color(0xFF00838F), size: 20),
            const SizedBox(width: 8),
            const Text('Active Rooms',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
            const Spacer(),
            if (paidCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$paidCount/${kBillableRooms.length} Paid',
                    style: const TextStyle(
                        color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
          ]),
        ),
        const Divider(height: 0),

        // Room rows
        ...kBillableRooms.map((room) {
          final rno      = room['room_number'] as String;
          final isPaid   = billingState[rno]?['is_paid'] == true;
          final total    = calcRoomTotal(rno, allBookings);
          final status   = room['status'] as String;
          final stColor  = _statusColors[status] ?? AppTheme.textPrimary;
          final stLabel  = _statusLabels[status] ?? status;
          // Pull dates: session data takes priority, fall back to demo
          final roomInfo   = getRoomInfo(rno);
          final checkInStr  = roomInfo['check_in']  as String? ?? room['check_in']  as String? ?? '';
          final checkOutStr = roomInfo['check_out'] as String? ?? room['check_out'] as String? ?? '';

          return InkWell(
            onTap: () => context.push('/billing/room', extra: {
              'room_number':   rno,
              'check_in_date':  checkInStr,
              'check_out_date': checkOutStr,
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(children: [
                // Room badge
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: stColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(rno,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: stColor)),
                  ),
                ),
                const SizedBox(width: 12),
                // Guest + status
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(room['guest_name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary)),
                  Text('${room['room_type']} · $stLabel',
                      style: TextStyle(fontSize: 11, color: stColor)),
                ])),
                // Amount + paid
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₹${total.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isPaid ? AppTheme.success : AppTheme.textPrimary)),
                  Text(isPaid ? 'PAID ✓' : 'Pending',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isPaid ? AppTheme.success : AppTheme.warning)),
                ]),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    size: 18,
                    color: isPaid ? AppTheme.success : AppTheme.textPrimary),
              ]),
            ),
          );
        }),
        const SizedBox(height: 4),
      ]),
    );
  }
}

// ── Today's Activities Card ────────────────────────────────────────────────────

class _TodayActivitiesCard extends ConsumerWidget {
  const _TodayActivitiesCard();

  static const _statusColors = {
    'PENDING':     Color(0xFFF57C00),
    'ASSIGNED':    Color(0xFF1565C0),
    'IN_PROGRESS': Color(0xFF6A1B9A),
    'DONE':        AppTheme.success,
  };
  static const _statusLabels = {
    'PENDING':     'Pending',
    'ASSIGNED':    'Assigned',
    'IN_PROGRESS': 'Active',
    'DONE':        'Done ✓',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(activityBookingsProvider);

    return activityAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Text('Error: $e'),
      data: (allBookings) {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final todayBookings = allBookings
            .where((b) => b['date'] == today && b['status'] != 'CANCELLED')
            .toList()
          ..sort((a, b) =>
              (a['time'] as String? ?? '').compareTo(b['time'] as String? ?? ''));

        if (todayBookings.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
            ),
            child: Row(children: [
              const Text('🎯', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('No activities today',
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                TextButton(
                  onPressed: () => context.push('/activities/register'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                  child: const Text('+ Book an activity', style: TextStyle(fontSize: 12)),
                ),
              ]),
            ]),
          );
        }

        // Summary counts
        final done   = todayBookings.where((b) => b['tracker_status'] == 'DONE').length;
        final active = todayBookings.where((b) => b['tracker_status'] == 'IN_PROGRESS').length;

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
          ),
          child: Column(children: [
            // Header strip
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(children: [
                const Text('🎯', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text('${todayBookings.length} Activities Scheduled',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                        color: AppTheme.textPrimary)),
                const Spacer(),
                if (done > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$done done',
                        style: const TextStyle(color: AppTheme.success, fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                if (active > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A1B9A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$active active',
                        style: const TextStyle(color: Color(0xFF6A1B9A), fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ]),
            ),
            const Divider(height: 0),

            // Activity rows (max 5 shown)
            ...todayBookings.take(5).map((b) {
              final tStatus   = b['tracker_status'] as String? ?? 'PENDING';
              final stColor   = _statusColors[tStatus] ?? const Color(0xFFF57C00);
              final stLabel   = _statusLabels[tStatus] ?? tStatus;
              final coordinator = b['coordinator'] as String?;

              return InkWell(
                onTap: () => context.push('/activities/tracker'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    Text(b['activity_emoji'] as String? ?? '🎯',
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(b['activity_name'] as String? ?? 'Activity',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                              color: AppTheme.textPrimary)),
                      Row(children: [
                        Text(b['time'] as String? ?? '',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary)),
                        const Text(' · ', style: TextStyle(color: AppTheme.textPrimary)),
                        Text(coordinator ?? 'Unassigned',
                            style: TextStyle(
                                fontSize: 11,
                                color: coordinator != null
                                    ? const Color(0xFF1565C0)
                                    : Colors.grey.shade500,
                                fontWeight: coordinator != null
                                    ? FontWeight.w600
                                    : FontWeight.normal)),
                      ]),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: stColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(stLabel,
                          style: TextStyle(color: stColor, fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ),
              );
            }),

            if (todayBookings.length > 5)
              TextButton(
                onPressed: () => context.push('/activities/tracker'),
                child: Text('+${todayBookings.length - 5} more — View Tracker',
                    style: const TextStyle(fontSize: 12)),
              ),
            const SizedBox(height: 4),
          ]),
        );
      },
    );
  }
}

// ── Guest Requests Panel (from QR) ────────────────────────────────────────────

class _GuestRequestsPanel extends ConsumerWidget {
  const _GuestRequestsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allRequests = ref.watch(guestRequestsProvider);
    final dndMap      = ref.watch(dndProvider);

    final pending   = allRequests.where((r) => r['status'] == 'PENDING').toList();
    final hkCount   = pending.where((r) => r['type'] == 'HOUSEKEEPING').length;
    final maintCount= pending.where((r) => r['type'] == 'MAINTENANCE').length;
    final foodCount = pending.where((r) => r['type'] == 'FOOD').length;
    final actCount  = pending.where((r) => r['type'] == 'ACTIVITIES').length;
    final dndCount  = dndMap.values.where((v) => v).length;

    const amber = Color(0xFFFF8F00);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: amber.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color: amber.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
          ),
          child: Row(children: [
            const Icon(Icons.qr_code_scanner_rounded, color: amber, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Guest QR Requests',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
            ),
            if (pending.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${pending.length} pending',
                    style: const TextStyle(color: amber, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
          ]),
        ),

        if (pending.isEmpty && dndCount == 0)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: Text('No pending guest requests', style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (hkCount > 0)
                  _GuestReqChip(
                    icon: Icons.cleaning_services_rounded,
                    label: 'Housekeeping',
                    count: hkCount,
                    color: const Color(0xFF1565C0),
                    onTap: () => context.push('/housekeeping'),
                  ),
                if (maintCount > 0)
                  _GuestReqChip(
                    icon: Icons.build_rounded,
                    label: 'Maintenance',
                    count: maintCount,
                    color: const Color(0xFF6A1B9A),
                    onTap: () => context.push('/maintenance'),
                  ),
                if (foodCount > 0)
                  _GuestReqChip(
                    icon: Icons.restaurant_rounded,
                    label: 'Food Orders',
                    count: foodCount,
                    color: const Color(0xFFE65100),
                    onTap: () => context.push('/food'),
                  ),
                if (actCount > 0)
                  _GuestReqChip(
                    icon: Icons.hiking_rounded,
                    label: 'Activities',
                    count: actCount,
                    color: const Color(0xFF00695C),
                    onTap: () => context.push('/activities/tracker'),
                  ),
                if (dndCount > 0)
                  _GuestReqChip(
                    icon: Icons.do_not_disturb_rounded,
                    label: 'DND Rooms',
                    count: dndCount,
                    color: const Color(0xFFC62828),
                    onTap: () => context.push('/rooms'),
                  ),
              ],
            ),
          ),

        // Recent requests list (up to 3)
        if (pending.isNotEmpty) ...[
          const Divider(height: 0),
          ...pending.take(3).map((r) {
            final type  = r['type'] as String? ?? '';
            final room  = r['room_number'] as String? ?? '';
            final title = r['title'] as String? ?? '';
            final Color typeColor;
            final IconData typeIcon;
            switch (type) {
              case 'HOUSEKEEPING': typeColor = const Color(0xFF1565C0); typeIcon = Icons.cleaning_services_rounded; break;
              case 'MAINTENANCE':  typeColor = const Color(0xFF6A1B9A); typeIcon = Icons.build_rounded; break;
              case 'FOOD':         typeColor = const Color(0xFFE65100); typeIcon = Icons.restaurant_rounded; break;
              case 'ACTIVITIES':   typeColor = const Color(0xFF00695C); typeIcon = Icons.hiking_rounded; break;
              default:             typeColor = AppTheme.textHint;       typeIcon = Icons.help_outline_rounded;
            }
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
              child: Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(typeIcon, color: typeColor, size: 17),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: amber.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Center(child: Text(room, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: amber))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: amber.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: const Text('PENDING', style: TextStyle(fontSize: 9, color: amber, fontWeight: FontWeight.bold)),
                ),
              ]),
            );
          }),
          if (pending.length > 3)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text('+${pending.length - 3} more requests',
                  style: const TextStyle(fontSize: 12, color: amber, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 4),
        ],
      ]),
    );
  }
}

class _GuestReqChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;
  const _GuestReqChip({required this.icon, required this.label, required this.count, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }
}
