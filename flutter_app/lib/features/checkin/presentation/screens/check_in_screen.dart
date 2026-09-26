import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final pendingCheckInProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return await client
      .from('bookings')
      .select('*, guests:primary_guest_id(full_name, phone)')
      .eq('status', 'CONFIRMED')
      .lte('check_in_date', today)
      .order('check_in_date', ascending: true);
});

final inHouseProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return await client
      .from('bookings')
      .select('*, guests:primary_guest_id(full_name, phone)')
      .eq('status', 'CHECKED_IN')
      .order('check_in_date', ascending: false);
});

final checkedOutProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return await client
      .from('bookings')
      .select('*, guests:primary_guest_id(full_name, phone)')
      .eq('status', 'CHECKED_OUT')
      .order('updated_at', ascending: false)
      .limit(30);
});

final cancelledProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return await client
      .from('bookings')
      .select('*, guests:primary_guest_id(full_name, phone)')
      .eq('status', 'CANCELLED')
      .order('cancelled_at', ascending: false)
      .limit(30);
});

// ── Screen ────────────────────────────────────────────────────────────────────

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
    _tabController = TabController(length: 4, vsync: this);
    if (widget.bookingId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCheckInSheet(widget.bookingId!);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(pendingCheckInProvider);
    ref.invalidate(inHouseProvider);
    ref.invalidate(checkedOutProvider);
    ref.invalidate(cancelledProvider);
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingCheckInProvider);
    final inHouse = ref.watch(inHouseProvider);
    final checkedOut = ref.watch(checkedOutProvider);
    final cancelled = ref.watch(cancelledProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(
        title: 'Front Desk',
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _refresh),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppTheme.surface,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textHint,
              indicatorColor: AppTheme.primary,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: [
                _TabLabel('Check-in', pending, Colors.orange),
                _TabLabel('In House', inHouse, AppTheme.success),
                _TabLabel('Checked Out', checkedOut, AppTheme.info),
                _TabLabel('Cancelled', cancelled, AppTheme.error),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1 — Pending Check-in
                _BookingTab(
                  asyncData: pending,
                  emptyIcon: Icons.login_outlined,
                  emptyMessage: 'No pending check-ins',
                  emptySub: 'Confirmed bookings due for check-in will appear here',
                  onRefresh: _refresh,
                  cardBuilder: (b) => _FrontDeskCard(
                    booking: b,
                    actionLabel: 'Check In',
                    actionColor: AppTheme.success,
                    actionIcon: Icons.login_rounded,
                    onAction: () => _showCheckInSheet(b['id'] as String),
                  ),
                ),

                // Tab 2 — In House
                _BookingTab(
                  asyncData: inHouse,
                  emptyIcon: Icons.people_outline,
                  emptyMessage: 'No guests in house',
                  emptySub: 'Checked-in guests will appear here',
                  onRefresh: _refresh,
                  cardBuilder: (b) => _FrontDeskCard(
                    booking: b,
                    actionLabel: 'Check Out',
                    actionColor: AppTheme.info,
                    actionIcon: Icons.logout_rounded,
                    onAction: () => _showCheckOutSheet(b['id'] as String, b),
                  ),
                ),

                // Tab 3 — Checked Out
                _BookingTab(
                  asyncData: checkedOut,
                  emptyIcon: Icons.check_circle_outline,
                  emptyMessage: 'No checked-out guests yet',
                  emptySub: 'Completed stays will appear here',
                  onRefresh: _refresh,
                  cardBuilder: (b) => _FrontDeskCard(
                    booking: b,
                    showAction: false,
                  ),
                ),

                // Tab 4 — Cancelled
                _BookingTab(
                  asyncData: cancelled,
                  emptyIcon: Icons.cancel_outlined,
                  emptyMessage: 'No cancellations',
                  emptySub: 'Cancelled bookings will appear here',
                  onRefresh: _refresh,
                  cardBuilder: (b) => _FrontDeskCard(
                    booking: b,
                    showAction: false,
                    showCancelReason: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Check-in Sheet ──────────────────────────────────────────────────────────

  void _showCheckInSheet(String bookingId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ActionSheet(
        title: 'Confirm Check-in',
        subtitle: 'Mark this guest as checked in',
        icon: Icons.login_rounded,
        iconColor: AppTheme.success,
        checklist: const [
          'ID proof verified',
          'Advance payment collected',
          'Room keys handed over',
          'Resort rules explained (no smoking/alcohol)',
        ],
        confirmLabel: 'Confirm Check-in',
        confirmColor: AppTheme.success,
        onConfirm: (notes) async {
          final client = ref.read(supabaseClientProvider);
          await client.from('bookings').update({
            'status': 'CHECKED_IN',
          }).eq('id', bookingId);

          // Mark assigned rooms as OCCUPIED
          final rooms = await client
              .from('booking_rooms')
              .select('room_id')
              .eq('booking_id', bookingId);
          for (final r in rooms) {
            await client.from('rooms')
                .update({'status': 'OCCUPIED'}).eq('id', r['room_id']);
          }
          _refresh();
        },
        successMessage: 'Guest checked in! Rooms marked Occupied.',
      ),
    );
  }

  // ── Check-out Sheet ─────────────────────────────────────────────────────────

  void _showCheckOutSheet(String bookingId, Map<String, dynamic> booking) {
    final guest = booking['guests'] as Map<String, dynamic>? ?? {};
    final balance = ((booking['total_amount'] as num?)?.toDouble() ?? 0) -
        ((booking['paid_amount'] as num?)?.toDouble() ?? 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ActionSheet(
        title: 'Confirm Check-out',
        subtitle: 'Guest: ${guest['full_name'] ?? ''}',
        icon: Icons.logout_rounded,
        iconColor: AppTheme.info,
        warningMessage: balance > 0
            ? '⚠️ Balance due: ₹${balance.toStringAsFixed(0)} — collect before check-out'
            : null,
        checklist: const [
          'Room keys returned',
          'Room inspection done',
          'All dues cleared',
          'Feedback collected',
        ],
        confirmLabel: 'Confirm Check-out',
        confirmColor: AppTheme.info,
        onConfirm: (notes) async {
          final client = ref.read(supabaseClientProvider);
          await client.from('bookings').update({
            'status': 'CHECKED_OUT',
          }).eq('id', bookingId);

          // Free up the rooms
          final rooms = await client
              .from('booking_rooms')
              .select('room_id')
              .eq('booking_id', bookingId);
          for (final r in rooms) {
            await client.from('rooms')
                .update({'status': 'CLEANING'}).eq('id', r['room_id']);
          }
          _refresh();
        },
        successMessage: 'Check-out done! Rooms moved to Cleaning.',
      ),
    );
  }
}

// ── Tab Label with Badge ──────────────────────────────────────────────────────

class _TabLabel extends StatelessWidget {
  final String label;
  final AsyncValue asyncData;
  final Color badgeColor;
  const _TabLabel(this.label, this.asyncData, this.badgeColor);

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          asyncData.when(
            data: (list) {
              final count = (list as List).length;
              if (count == 0) return const SizedBox();
              return Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              );
            },
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
    );
  }
}

// ── Generic Tab ───────────────────────────────────────────────────────────────

class _BookingTab extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> asyncData;
  final IconData emptyIcon;
  final String emptyMessage, emptySub;
  final VoidCallback onRefresh;
  final Widget Function(Map<String, dynamic>) cardBuilder;

  const _BookingTab({
    required this.asyncData,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.emptySub,
    required this.onRefresh,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (bookings) => bookings.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(emptyIcon, size: 56, color: AppTheme.textHint.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    Text(emptyMessage,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(emptySub,
                        style: const TextStyle(color: AppTheme.textHint, fontSize: 12),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => onRefresh(),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: bookings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => cardBuilder(bookings[i]),
              ),
            ),
    );
  }
}

// ── Front Desk Card ───────────────────────────────────────────────────────────

class _FrontDeskCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final String? actionLabel;
  final Color? actionColor;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool showAction;
  final bool showCancelReason;

  const _FrontDeskCard({
    required this.booking,
    this.actionLabel,
    this.actionColor,
    this.actionIcon,
    this.onAction,
    this.showAction = true,
    this.showCancelReason = false,
  });

  @override
  Widget build(BuildContext context) {
    final guest = booking['guests'] as Map<String, dynamic>? ?? {};
    final guestName = guest['full_name'] as String? ?? 'Guest';
    final phone = guest['phone'] as String? ?? '';
    final checkIn = booking['check_in_date'] as String? ?? '';
    final checkOut = booking['check_out_date'] as String?;
    final adults = booking['num_adults'] as int? ?? 0;
    final children = booking['num_children'] as int? ?? 0;
    final total = (booking['total_amount'] as num?)?.toDouble() ?? 0;
    final paid = (booking['paid_amount'] as num?)?.toDouble() ?? 0;
    final balance = total - paid;
    final bookingNum = booking['booking_number'] as String? ?? '';
    final cancelReason = booking['cancellation_reason'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        children: [
          // Guest info
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      child: Text(
                        guestName.isNotEmpty ? guestName[0].toUpperCase() : 'G',
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(guestName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          if (phone.isNotEmpty)
                            Text('+91 $phone',
                                style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(bookingNum,
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                // Dates row
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _MiniStat(Icons.login_rounded, 'Check-in', checkIn),
                      Container(width: 1, height: 30, color: Colors.grey.shade300),
                      _MiniStat(Icons.logout_rounded, 'Check-out', checkOut ?? 'Day Visit'),
                      Container(width: 1, height: 30, color: Colors.grey.shade300),
                      _MiniStat(Icons.people_outline, 'Guests',
                          '$adults A · $children C'),
                    ],
                  ),
                ),
                if (balance > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 14, color: AppTheme.error),
                        const SizedBox(width: 6),
                        Text(
                          'Balance: ₹${balance.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: AppTheme.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
                if (showCancelReason && cancelReason != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: AppTheme.textHint),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Reason: $cancelReason',
                            style: const TextStyle(
                                color: AppTheme.textHint, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Action row
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => context.push('/bookings/${booking['id']}'),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View Booking'),
                ),
              ),
              if (showAction && actionLabel != null) ...[
                Container(width: 1, height: 36, color: const Color(0xFFEEEEEE)),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onAction,
                    icon: Icon(actionIcon ?? Icons.check, size: 16, color: actionColor),
                    label: Text(actionLabel!,
                        style: TextStyle(
                            color: actionColor, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _MiniStat(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppTheme.textHint),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(fontSize: 10, color: AppTheme.textHint)),
          ],
        ),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Reusable Action Sheet ─────────────────────────────────────────────────────

class _ActionSheet extends ConsumerStatefulWidget {
  final String title, subtitle, confirmLabel, successMessage;
  final IconData icon;
  final Color iconColor, confirmColor;
  final List<String> checklist;
  final String? warningMessage;
  final Future<void> Function(String notes) onConfirm;

  const _ActionSheet({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.checklist,
    required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,
    required this.successMessage,
    this.warningMessage,
  });

  @override
  ConsumerState<_ActionSheet> createState() => _ActionSheetState();
}

class _ActionSheetState extends ConsumerState<_ActionSheet> {
  bool _isLoading = false;
  final _notesController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: widget.iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(widget.subtitle,
                          style: const TextStyle(
                              color: AppTheme.textHint, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),

            if (widget.warningMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                ),
                child: Text(widget.warningMessage!,
                    style: const TextStyle(
                        color: AppTheme.warning,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ),
            ],

            const SizedBox(height: 16),
            const Text('Checklist:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            ...widget.checklist.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 16, color: widget.iconColor),
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
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(widget.icon),
                label: Text(widget.confirmLabel,
                    style: const TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.confirmColor,
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      await widget.onConfirm(_notesController.text.trim());
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.successMessage),
          backgroundColor: widget.confirmColor,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppTheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
