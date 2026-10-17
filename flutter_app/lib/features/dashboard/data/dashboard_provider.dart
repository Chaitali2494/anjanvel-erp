import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../bookings/data/booking_service.dart';

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
  final client  = ref.watch(supabaseClientProvider);
  final service = ref.watch(bookingServiceProvider);
  final today   = DateTime.now().toIso8601String().split('T')[0];

  // ── Session-based stats (local bookings, always available) ───────────────────
  final session = service.getSessionStats(today);
  final sCheckins   = session['checkinsToday']  as int;
  final sCheckouts  = session['checkoutsToday'] as int;
  final sInhouse    = session['guestsInhouse']  as int;
  final sRevenue    = (session['revenueToday']  as num).toDouble();
  final sOccupied   = session['sessionOccupied'] as int;
  final sReserved   = session['sessionReserved'] as int;
  final sTodayCI    = List<Map<String, dynamic>>.from(session['todayCheckins'] as List);

  // ── Supabase stats (may fail if offline / RLS) ────────────────────────────────
  int    dbCheckins   = 0, dbCheckouts = 0, dbInhouse = 0;
  double dbRevenue    = 0;
  int    available = 0, occupied = 0, cleaning = 0, maintenance = 0;
  int    hkPending = 0, maintOpen = 0, foodPending = 0, newLeads = 0;
  List<Map<String, dynamic>> dbTodayCI = [];

  try {
    final dashData = await client.from('v_todays_dashboard').select().maybeSingle() ?? {};
    dbCheckins   = (dashData['checkins_today']      as num?)?.toInt()    ?? 0;
    dbCheckouts  = (dashData['checkouts_today']     as num?)?.toInt()    ?? 0;
    dbInhouse    = (dashData['guests_inhouse']       as num?)?.toInt()    ?? 0;
    dbRevenue    = (dashData['revenue_today']        as num?)?.toDouble() ?? 0;
    newLeads     = (dashData['new_leads']            as num?)?.toInt()    ?? 0;
    hkPending    = (dashData['hk_pending']           as num?)?.toInt()    ?? 0;
    maintOpen    = (dashData['maintenance_open']     as num?)?.toInt()    ?? 0;
    foodPending  = (dashData['food_orders_pending']  as num?)?.toInt()    ?? 0;
  } catch (_) {}

  try {
    final roomStats = await client.from('rooms').select('status');
    available   = roomStats.where((r) => r['status'] == 'AVAILABLE').length;
    occupied    = roomStats.where((r) => r['status'] == 'OCCUPIED').length;
    cleaning    = roomStats.where((r) => r['status'] == 'CLEANING').length;
    maintenance = roomStats.where((r) => r['status'] == 'MAINTENANCE').length;
  } catch (_) {}

  try {
    final rows = await client
        .from('bookings')
        .select('*, guests:primary_guest_id(full_name, phone)')
        .eq('check_in_date', today)
        .inFilter('status', ['CONFIRMED', 'CHECKED_IN'])
        .limit(5);
    dbTodayCI = List<Map<String, dynamic>>.from(rows);
  } catch (_) {}

  // ── Merge: session + Supabase ─────────────────────────────────────────────────
  return DashboardStats(
    revenueToday:     dbRevenue    + sRevenue,
    checkinsToday:    dbCheckins   + sCheckins,
    checkoutsToday:   dbCheckouts  + sCheckouts,
    guestsInhouse:    dbInhouse    + sInhouse,
    newLeads:         newLeads,
    hkPending:        hkPending,
    maintenanceOpen:  maintOpen,
    foodOrdersPending: foodPending,
    roomsAvailable:   available,
    // Session-occupied rooms are added on top of DB count
    roomsOccupied:    occupied    + sOccupied,
    roomsCleaning:    cleaning,
    roomsMaintenance: maintenance,
    lowStockAlerts:   0,
    weeklyRevenue: const [12000, 18000, 8000, 24000, 15000, 31000, 22000],
    // Session check-ins first (newest), then DB ones
    todayCheckins: [...sTodayCI, ...dbTodayCI],
  );
});
