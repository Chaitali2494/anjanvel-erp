import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';

// Provider: all confirmed bookings ready for check-in
final confirmedBookingsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return await client
      .from('bookings')
      .select('*, guests:primary_guest_id(full_name, phone)')
      .eq('status', 'CONFIRMED')
      .lte('check_in_date', today)
      .order('check_in_date', ascending: true);
});

// Provider: today's checked-in guests
final checkedInTodayProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return await client
      .from('bookings')
      .select('*, guests:primary_guest_id(full_name, phone)')
      .eq('status', 'CHECKED_IN')
      .gte('updated_at', '${today}T00:00:00')
      .order('updated_at', ascending: false);
});

class CheckInScreen extends ConsumerStatefulWidget {
  final String? bookingId;
  const CheckInScreen({super.key, this.bookingId});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // If opened with a specific bookingId, show check-in dialog
    if (widget.bookingId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCheckInDialog(widget.bookingId!);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final confirmedAsync = ref.watch(confirmedBookingsProvider);
    final checkedInAsync = ref.watch(checkedInTodayProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(
        title: 'Check-in',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () {
              ref.invalidate(confirmedBookingsProvider);
              ref.invalidate(checkedInTodayProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            color: AppTheme.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textHint,
              indicatorColor: AppTheme.primary,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.login_rounded, size: 16),
                      const SizedBox(width: 6),
                      const Text('Pending Check-in'),
                      const SizedBox(width: 6),
                      confirmedAsync.when(
                        data: (list) => _Badge(list.length),
                        loading: () => const SizedBox(),
                        error: (_, __) => const SizedBox(),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_rounded, size: 16),
                      const SizedBox(width: 6),
                      const Text('Checked In Today'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Confirmed bookings pending check-in
                confirmedAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (bookings) => bookings.isEmpty
                      ? _EmptyState(
                          icon: Icons.check_circle_outline,
                          message: 'No pending check-ins',
                          sub: 'All confirmed bookings have been checked in',
                        )
                      : RefreshIndicator(
                          onRefresh: () async => ref.invalidate(confirmedBookingsProvider),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: bookings.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _BookingCheckInCard(
                              booking: bookings[i],
                              onCheckIn: () => _showCheckInDialog(bookings[i]['id'] as String),
                            ),
                          ),
                        ),
                ),

                // Tab 2: Checked in today
                checkedInAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (bookings) => bookings.isEmpty
                      ? _EmptyState(
                          icon: Icons.people_outline,
                          message: 'No check-ins today yet',
                          sub: 'Checked-in guests will appear here',
                        )
                      : RefreshIndicator(
                          onRefresh: () async => ref.invalidate(checkedInTodayProvider),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: bookings.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _CheckedInCard(booking: bookings[i]),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCheckInDialog(String bookingId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CheckInBottomSheet(
        bookingId: bookingId,
        onDone: () {
          ref.invalidate(confirmedBookingsProvider);
          ref.invalidate(checkedInTodayProvider);
        },
      ),
    );
  }
}

// ── Check-in Card ─────────────────────────────────────────────────────────────

class _BookingCheckInCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onCheckIn;
  const _BookingCheckInCard({required this.booking, required this.onCheckIn});

  @override
  Widget build(BuildContext context) {
    final guest = booking['guests'] as Map<String, dynamic>? ?? {};
    final guestName = guest['full_name'] as String? ?? 'Guest';
    final guestPhone = guest['phone'] as String? ?? '';
    final checkIn = booking['check_in_date'] as String? ?? '';
    final checkOut = booking['check_out_date'] as String?;
    final numAdults = booking['num_adults'] as int? ?? 1;
    final numChildren = booking['num_children'] as int? ?? 0;
    final totalAmount = (booking['total_amount'] as num?)?.toDouble() ?? 0;
    final paidAmount = (booking['paid_amount'] as num?)?.toDouble() ?? 0;
    final balance = totalAmount - paidAmount;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(guestName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        booking['booking_number'] as String? ?? '',
                        style: const TextStyle(fontSize: 11, color: AppTheme.info, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (guestPhone.isNotEmpty)
                  Text('+91 $guestPhone', style: const TextStyle(color: AppTheme.textHint, fontSize: 13)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _InfoChip(Icons.login_rounded, checkIn),
                    const SizedBox(width: 8),
                    if (checkOut != null) _InfoChip(Icons.logout_rounded, checkOut),
                    const SizedBox(width: 8),
                    _InfoChip(Icons.people_outline, '$numAdults A · $numChildren C'),
                  ],
                ),
                if (balance > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.warning),
                        const SizedBox(width: 6),
                        Text(
                          'Balance due: ₹${balance.toStringAsFixed(0)}',
                          style: const TextStyle(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => context.push('/bookings/${booking['id']}'),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View'),
                ),
              ),
              Container(width: 1, height: 36, color: const Color(0xFFEEEEEE)),
              Expanded(
                child: TextButton.icon(
                  onPressed: onCheckIn,
                  icon: const Icon(Icons.login_rounded, size: 16, color: AppTheme.primary),
                  label: const Text('Check In', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textHint),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}

// ── Checked-in Card ───────────────────────────────────────────────────────────

class _CheckedInCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _CheckedInCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final guest = booking['guests'] as Map<String, dynamic>? ?? {};
    final guestName = guest['full_name'] as String? ?? 'Guest';
    final numAdults = booking['num_adults'] as int? ?? 1;
    final numChildren = booking['num_children'] as int? ?? 0;
    final checkOut = booking['check_out_date'] as String?;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: AppTheme.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: AppTheme.success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(guestName, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '$numAdults adults · $numChildren children${checkOut != null ? ' · Out: $checkOut' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('IN', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ── Check-in Bottom Sheet ─────────────────────────────────────────────────────

class _CheckInBottomSheet extends ConsumerStatefulWidget {
  final String bookingId;
  final VoidCallback onDone;
  const _CheckInBottomSheet({required this.bookingId, required this.onDone});

  @override
  ConsumerState<_CheckInBottomSheet> createState() => _CheckInBottomSheetState();
}

class _CheckInBottomSheetState extends ConsumerState<_CheckInBottomSheet> {
  bool _isLoading = false;
  final _notesController = TextEditingController();

  Future<void> _processCheckIn() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('bookings').update({
        'status': 'CHECKED_IN',
        'actual_check_in': DateTime.now().toIso8601String(),
      }).eq('id', widget.bookingId);

      // Mark assigned rooms as OCCUPIED
      final rooms = await client
          .from('booking_rooms')
          .select('room_id')
          .eq('booking_id', widget.bookingId);

      for (final r in rooms) {
        await client.from('rooms')
            .update({'status': 'OCCUPIED'})
            .eq('id', r['room_id']);
      }

      widget.onDone();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guest checked in successfully! Rooms marked Occupied.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.login_rounded, color: AppTheme.success),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Process Check-in', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('This will mark the booking as Checked In', style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Checklist before check-in:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...[
            'ID proof verified',
            'Advance payment collected',
            'Room keys handed over',
            'Resort rules explained',
          ].map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.success),
                const SizedBox(width: 8),
                Text(item, style: const TextStyle(fontSize: 13)),
              ],
            ),
          )),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.notes_outlined),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _processCheckIn,
              icon: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.login_rounded),
              label: const Text('Confirm Check-in', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final int count;
  const _Badge(this.count);

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(10)),
      child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String sub;
  const _EmptyState({required this.icon, required this.message, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: AppTheme.textHint.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text(message, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(sub, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
