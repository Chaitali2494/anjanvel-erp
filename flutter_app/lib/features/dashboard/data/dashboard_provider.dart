import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';

class DashboardStats {
  final double revenueToday;
  final int checkinsToday;
  final int checkoutsToday;
  final int guestsInhouse;
  final int newLeads;
  final int hkPending;
  final int maintenanceOpen;
  final int foodOrdersPending;
  final int roomsAvailable;
  final int roomsOccupied;
  final int roomsCleaning;
  final int roomsMaintenance;
  final int lowStockAlerts;
  final List<double> weeklyRevenue;
  final List<Map<String, dynamic>> todayCheckins;

  const DashboardStats({
    this.revenueToday = 0,
    this.checkinsToday = 0,
    this.checkoutsToday = 0,
    this.guestsInhouse = 0,
    this.newLeads = 0,
    this.hkPending = 0,
    this.maintenanceOpen = 0,
    this.foodOrdersPending = 0,
    this.roomsAvailable = 0,
    this.roomsOccupied = 0,
    this.roomsCleaning = 0,
    this.roomsMaintenance = 0,
    this.lowStockAlerts = 0,
    this.weeklyRevenue = const [12000, 18000, 8000, 24000, 15000, 31000, 22000],
    this.todayCheckins = const [],
  });
}

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final today = DateTime.now().toIso8601String().split('T')[0];

  try {
    // Fetch from v_todays_dashboard view
    final dashData = await client.from('v_todays_dashboard').select().maybeSingle() ?? {};
    final todayCheckins = await client
        .from('v_booking_summary')
        .select()
        .eq('check_in_date', today)
        .inFilter('status', ['CONFIRMED', 'CHECKED_IN'])
        .limit(5);

    // Room status counts
    final roomStats = await client.from('rooms').select('status');
    final available = roomStats.where((r) => r['status'] == 'AVAILABLE').length;
    final occupied = roomStats.where((r) => r['status'] == 'OCCUPIED').length;
    final cleaning = roomStats.where((r) => r['status'] == 'CLEANING').length;
    final maintenance = roomStats.where((r) => r['status'] == 'MAINTENANCE').length;

    return DashboardStats(
      revenueToday: (dashData['revenue_today'] as num?)?.toDouble() ?? 0,
      checkinsToday: (dashData['checkins_today'] as num?)?.toInt() ?? 0,
      checkoutsToday: (dashData['checkouts_today'] as num?)?.toInt() ?? 0,
      guestsInhouse: (dashData['guests_inhouse'] as num?)?.toInt() ?? 0,
      newLeads: (dashData['new_leads'] as num?)?.toInt() ?? 0,
      hkPending: (dashData['hk_pending'] as num?)?.toInt() ?? 0,
      maintenanceOpen: (dashData['maintenance_open'] as num?)?.toInt() ?? 0,
      foodOrdersPending: (dashData['food_orders_pending'] as num?)?.toInt() ?? 0,
      roomsAvailable: available,
      roomsOccupied: occupied,
      roomsCleaning: cleaning,
      roomsMaintenance: maintenance,
      lowStockAlerts: 0,
      weeklyRevenue: const [12000, 18000, 8000, 24000, 15000, 31000, 22000],
      todayCheckins: List<Map<String, dynamic>>.from(todayCheckins),
    );
  } catch (e) {
    return const DashboardStats();
  }
});
