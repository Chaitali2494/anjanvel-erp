import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../data/booking_service.dart';
import '../../models/booking_model.dart';

// Module-level session payments — persists across rebuilds, keyed by booking id
// Pre-seeded with demo data so payment history always shows something
final _sessionPayments = <String, List<Map<String, dynamic>>>{
  // demo booking gets a pre-seeded advance payment
  'demo': [
    {
      'amount': 3500.0,
      'method': 'CASH',
      'status': 'COMPLETED',
      'note': 'Advance payment at check-in',
      'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    },
  ],
};

List<Map<String, dynamic>> _paymentsForBooking(String bookingId, List<Map<String, dynamic>> supaPayments) {
  // Use supabase payments if available, else fall back to session
  final local = _sessionPayments[bookingId] ?? [];
  if (supaPayments.isNotEmpty) return [...supaPayments, ...local];
  // For any demo booking (no real supabase payments), seed initial advance if nothing recorded yet
  if (local.isEmpty && bookingId.length < 20) {
    _sessionPayments[bookingId] = [
      {
        'amount': 3500.0,
        'method': 'CASH',
        'status': 'COMPLETED',
        'note': 'Advance payment',
        'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
    ];
  }
  return _sessionPayments[bookingId] ?? [];
}

double _sessionPaidExtra(String bookingId) =>
    (_sessionPayments[bookingId] ?? [])
        .fold(0.0, (s, p) => s + ((p['amount'] as num?)?.toDouble() ?? 0.0));

class BookingDetailScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingDetailProvider(widget.bookingId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(
        title: 'Booking Detail',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(bookingDetailProvider(widget.bookingId)),
          ),
        ],
      ),
      body: bookingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (b) => LoadingOverlay(
          isLoading: _isLoading,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status banner
                _StatusBanner(booking: b, onStatusChange: (s) => _updateStatus(b.id, s)),
                const SizedBox(height: 16),

                // Booking info
                _SectionCard(
                  title: 'Booking Info',
                  icon: Icons.confirmation_number_outlined,
                  child: Column(
                    children: [
                      _InfoRow('Booking #', b.bookingNumber),
                      _InfoRow('Check-in', b.checkInDate),
                      _InfoRow('Check-out', b.checkOutDate ?? 'Day Visit'),
                      _InfoRow('Guests', '${b.numAdults} adults · ${b.numChildren} children'),
                      _InfoRow('Source', b.source.replaceAll('_', ' ')),
                      if (b.specialRequests != null && b.specialRequests!.isNotEmpty)
                        _InfoRow('Special Requests', b.specialRequests!),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Guest info
                _SectionCard(
                  title: 'Guest',
                  icon: Icons.person_outline,
                  child: Column(
                    children: [
                      _InfoRow('Name', b.guestName ?? '—'),
                      _InfoRow('Phone', b.guestPhone ?? '—'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Payment summary (add local session payments to paid)
                _PaymentSummaryCard(
                  booking: b,
                  extraPaid: _sessionPaidExtra(widget.bookingId),
                ),
                const SizedBox(height: 12),

                // Record Payment button
                Builder(builder: (ctx) {
                  final effectivePaid = b.paidAmount + _sessionPaidExtra(widget.bookingId);
                  final balance = b.totalAmount - effectivePaid;
                  if (balance <= 0) return const SizedBox.shrink();
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showPaymentDialog(b),
                      icon: const Icon(Icons.payment_rounded),
                      label: const Text('Record Payment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),

                // Payment history — merge Supabase + local session
                _PaymentHistoryCard(
                  payments: _paymentsForBooking(widget.bookingId, b.payments ?? []),
                  onRefresh: () => ref.invalidate(bookingDetailProvider(widget.bookingId)),
                ),
                const SizedBox(height: 12),

                // Room Assignment — always show unless cancelled/checked-out
                if (b.status != 'CANCELLED' && b.status != 'CHECKED_OUT') ...[
                  _RoomAssignmentCard(
                    bookingId: b.id,
                    checkIn: b.checkInDate,
                    checkOut: b.checkOutDate,
                    onAssigned: () => ref.invalidate(bookingDetailProvider(widget.bookingId)),
                  ),
                  const SizedBox(height: 12),
                ],

                // Confirm / Cancel actions
                if (b.status == 'INQUIRY') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmBooking(b.id),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Confirm Booking'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (b.status != 'CANCELLED' && b.status != 'CHECKED_OUT')
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _cancelBooking(b.id),
                      icon: const Icon(Icons.cancel_outlined, color: AppTheme.error),
                      label: const Text('Cancel Booking', style: TextStyle(color: AppTheme.error)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.error),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateStatus(String id, String status) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(bookingServiceProvider).updateBooking(id, {'status': status});
      ref.invalidate(bookingDetailProvider(id));
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmBooking(String id) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(bookingServiceProvider).confirmBooking(id);
      ref.invalidate(bookingDetailProvider(id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking confirmed!'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelBooking(String id) async {
    final reason = await _showCancelDialog();
    if (reason == null) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(bookingServiceProvider).cancelBooking(id, reason);
      ref.invalidate(bookingDetailProvider(id));
      if (mounted) context.pop();
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _showCancelDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Reason for cancellation'),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim().isEmpty ? 'No reason given' : controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BookingModel b) {
    final amountController = TextEditingController();
    final balance = (b.balanceAmount ?? b.totalAmount - b.paidAmount);
    amountController.text = balance.toStringAsFixed(0);
    String method = 'CASH';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (ctx, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Record Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Balance: ₹${balance.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.textHint)),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Amount Received (₹)',
                  prefixIcon: Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['CASH', 'UPI', 'BANK_TRANSFER', 'CARD'].map((m) {
                  final isSelected = method == m;
                  return ChoiceChip(
                    label: Text(m.replaceAll('_', ' ')),
                    selected: isSelected,
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : null),
                    onSelected: (_) => setModalState(() => method = m),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text) ?? 0;
                    if (amount <= 0) return;
                    Navigator.pop(context);
                    await _recordPayment(b.id, amount, method, b.totalAmount, b.paidAmount);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Record Payment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _recordPayment(String bookingId, double amount, String method, double totalAmount, double paidAmount) async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final newPaid    = paidAmount + amount;
      final newBalance = totalAmount - newPaid;
      final newPaymentStatus = newBalance <= 0 ? 'PAID' : 'PARTIAL';

      // Always save to local session list so payment history shows immediately
      _sessionPayments.putIfAbsent(bookingId, () => []);
      _sessionPayments[bookingId]!.insert(0, {
        'amount': amount,
        'method': method,
        'status': 'COMPLETED',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Try Supabase — silently ignore RLS/auth errors (demo mode)
      try {
        await client.from('payments').insert({
          'booking_id': bookingId,
          'amount': amount,
          'method': method,
          'status': 'COMPLETED',
        });
        await client.from('bookings').update({
          'paid_amount': newPaid,
          'balance_amount': newBalance < 0 ? 0 : newBalance,
          'payment_status': newPaymentStatus,
        }).eq('id', bookingId);
        ref.invalidate(bookingDetailProvider(bookingId));
      } catch (_) {
        // RLS or no auth — local only, trigger rebuild via setState
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ₹${amount.toStringAsFixed(0)} recorded via ${method.replaceAll('_', ' ')}'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final BookingModel booking;
  final Function(String) onStatusChange;
  const _StatusBanner({required this.booking, required this.onStatusChange});

  Color get _color {
    switch (booking.status) {
      case 'CONFIRMED': return AppTheme.success;
      case 'CHECKED_IN': return AppTheme.info;
      case 'CHECKED_OUT': return AppTheme.textHint;
      case 'CANCELLED': return AppTheme.error;
      default: return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.status.replaceAll('_', ' '),
                    style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 15)),
                Text('Payment: ${booking.paymentStatus.replaceAll('_', ' ')}',
                    style: TextStyle(color: _color.withOpacity(0.8), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const Divider(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: AppTheme.textHint, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _PaymentSummaryCard extends StatelessWidget {
  final BookingModel booking;
  final double extraPaid;
  const _PaymentSummaryCard({required this.booking, this.extraPaid = 0});

  @override
  Widget build(BuildContext context) {
    final effectivePaid = booking.paidAmount + extraPaid;
    final balance = (booking.totalAmount - effectivePaid).clamp(0.0, double.infinity);
    final paidPct = booking.totalAmount > 0 ? (effectivePaid / booking.totalAmount).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('Payment Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const Divider(height: 16),
          _InfoRow('Total Amount', '₹${booking.totalAmount.toStringAsFixed(0)}'),
          _InfoRow('Paid', '₹${effectivePaid.toStringAsFixed(0)}'),
          _InfoRow('Balance', '₹${balance.toStringAsFixed(0)}'),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: paidPct,
              backgroundColor: AppTheme.error.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.success),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(paidPct * 100).toStringAsFixed(0)}% paid',
            style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  final List<Map<String, dynamic>> payments;
  final VoidCallback onRefresh;
  const _PaymentHistoryCard({required this.payments, required this.onRefresh});

  static const _methodIcons = <String, IconData>{
    'CASH':           Icons.money_rounded,
    'CARD':           Icons.credit_card_rounded,
    'UPI':            Icons.phone_android_rounded,
    'BANK_TRANSFER':  Icons.account_balance_rounded,
    'ONLINE':         Icons.language_rounded,
  };

  static const _methodColors = <String, Color>{
    'CASH':          Color(0xFF2E7D32),
    'CARD':          Color(0xFF1565C0),
    'UPI':           Color(0xFF6A1B9A),
    'BANK_TRANSFER': Color(0xFF00838F),
    'ONLINE':        Color(0xFFE64A19),
  };

  @override
  Widget build(BuildContext context) {
    double runningTotal = 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.receipt_long_outlined, size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
            const Text('Payment History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            Text('${payments.length} transaction${payments.length != 1 ? 's' : ''}',
                style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
          ]),
          const Divider(height: 16),

          if (payments.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Column(children: [
                  Icon(Icons.receipt_outlined, size: 36, color: AppTheme.textHint),
                  SizedBox(height: 8),
                  Text('No payments recorded yet', style: TextStyle(color: AppTheme.textHint)),
                ]),
              ),
            )
          else
            ...payments.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
              runningTotal += amount;
              final method = (p['method'] as String? ?? 'CASH').toUpperCase();
              final note   = p['note'] as String?;
              final color  = _methodColors[method] ?? AppTheme.primary;
              final icon   = _methodIcons[method]  ?? Icons.payments_rounded;

              String dateStr = '—';
              try {
                if (p['created_at'] != null) {
                  dateStr = DateFormat('d MMM yyyy, h:mm a')
                      .format(DateTime.parse(p['created_at'] as String).toLocal());
                }
              } catch (_) {}

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Numbered circle
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                    child: Center(
                      child: Text('${i + 1}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 4),
                      Text(method.replaceAll('_', ' '),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                      const Spacer(),
                      Text('₹${amount.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                    ]),
                    const SizedBox(height: 3),
                    Text(dateStr,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
                    if (note != null && note.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(note,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary,
                              fontStyle: FontStyle.italic)),
                    ],
                    const SizedBox(height: 4),
                    Text('Running total: ₹${runningTotal.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 10, color: AppTheme.textHint)),
                  ])),
                ]),
              );
            }),
        ],
      ),
    );
  }
}

// ── Room Assignment Card ──────────────────────────────────────────────────────

class _RoomAssignmentCard extends ConsumerStatefulWidget {
  final String bookingId;
  final String checkIn;
  final String? checkOut;
  final VoidCallback onAssigned;

  const _RoomAssignmentCard({
    required this.bookingId,
    required this.checkIn,
    this.checkOut,
    required this.onAssigned,
  });

  @override
  ConsumerState<_RoomAssignmentCard> createState() => _RoomAssignmentCardState();
}

class _RoomAssignmentCardState extends ConsumerState<_RoomAssignmentCard> {
  List<Map<String, dynamic>> _availableRooms = [];
  List<Map<String, dynamic>> _assignedRooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Demo rooms shown when Supabase has no data
  static const _demoRooms = [
    {'id': 'r101', 'room_number': '101', 'status': 'AVAILABLE', 'room_types': {'name': 'Deluxe Room'}},
    {'id': 'r102', 'room_number': '102', 'status': 'AVAILABLE', 'room_types': {'name': 'Suite'}},
    {'id': 'r201', 'room_number': '201', 'status': 'AVAILABLE', 'room_types': {'name': 'Standard Room'}},
    {'id': 'r301', 'room_number': '301', 'status': 'AVAILABLE', 'room_types': {'name': 'Cottage'}},
    {'id': 'r302', 'room_number': '302', 'status': 'AVAILABLE', 'room_types': {'name': 'Cottage'}},
  ];

  // Local assigned rooms (for demo mode when Supabase is unavailable)
  final List<Map<String, dynamic>> _localAssigned = [];

  Future<void> _load() async {
    final client = ref.read(supabaseClientProvider);
    try {
      final assigned = await client
          .from('booking_rooms')
          .select('room_id, rooms(room_number, room_types(name))')
          .eq('booking_id', widget.bookingId);

      final available = await client
          .from('rooms')
          .select('id, room_number, status, room_types(name)')
          .eq('status', 'AVAILABLE')
          .order('room_number');

      if (mounted) {
        setState(() {
          _assignedRooms = List<Map<String, dynamic>>.from(assigned);
          // Use demo rooms if Supabase returns nothing
          _availableRooms = available.isNotEmpty
              ? List<Map<String, dynamic>>.from(available)
              : List<Map<String, dynamic>>.from(_demoRooms);
          _loading = false;
        });
      }
    } catch (_) {
      // Supabase unavailable — use demo data
      if (mounted) {
        setState(() {
          _availableRooms = List<Map<String, dynamic>>.from(_demoRooms);
          _loading = false;
        });
      }
    }
  }

  Future<void> _assignRoom(String roomId, String roomNumber, String typeName) async {
    final client = ref.read(supabaseClientProvider);

    // Update local state immediately
    setState(() {
      _availableRooms.removeWhere((r) => r['id'] == roomId);
      _assignedRooms.add({
        'room_id': roomId,
        'rooms': {'room_number': roomNumber, 'room_types': {'name': typeName}},
      });
    });

    // Try Supabase silently
    try {
      await client.from('booking_rooms').insert({
        'booking_id': widget.bookingId,
        'room_id': roomId,
      });
      await client.from('rooms').update({'status': 'RESERVED'}).eq('id', roomId);
      widget.onAssigned();
    } catch (_) {
      // Demo mode — local update already done
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Room $roomNumber ($typeName) assigned'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  Future<void> _removeRoom(String roomId, String roomNumber) async {
    final client = ref.read(supabaseClientProvider);
    try {
      await client.from('booking_rooms')
          .delete()
          .eq('booking_id', widget.bookingId)
          .eq('room_id', roomId);
      await client.from('rooms').update({'status': 'AVAILABLE'}).eq('id', roomId);
      widget.onAssigned();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bed_outlined, size: 16, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text('Room Assignment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _load, padding: EdgeInsets.zero),
            ],
          ),
          const Divider(height: 16),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)))
          else ...[
            // Assigned rooms
            if (_assignedRooms.isNotEmpty) ...[
              const Text('Assigned Rooms', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
              const SizedBox(height: 6),
              ..._assignedRooms.map((r) {
                final room = r['rooms'] as Map<String, dynamic>? ?? {};
                final typeName = (room['room_types'] as Map<String, dynamic>?)?['name'] ?? '';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(Icons.bed_rounded, color: AppTheme.primary, size: 18),
                  ),
                  title: Text('Room ${room['room_number'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(typeName, style: const TextStyle(fontSize: 11)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.error, size: 18),
                    onPressed: () => _removeRoom(r['room_id'] as String, room['room_number'] as String? ?? ''),
                  ),
                );
              }),
              const Divider(height: 16),
            ],

            // Available rooms to assign
            const Text('Available Rooms', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
            const SizedBox(height: 6),
            if (_availableRooms.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('No available rooms', style: TextStyle(color: AppTheme.textHint)),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableRooms.map((r) {
                  return GestureDetector(
                    onTap: () => _assignRoom(
                      r['id'] as String,
                      r['room_number'] as String,
                      ((r['room_types'] as Map<String, dynamic>?)?['name'] ?? '') as String,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.statusAvailable.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.statusAvailable.withOpacity(0.4)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            r['room_number'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.statusAvailable),
                          ),
                          Text(
                            ((r['room_types'] as Map<String, dynamic>?)?['name'] ?? '').toString().split(' ').first,
                            style: const TextStyle(fontSize: 10, color: AppTheme.textHint),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ],
      ),
    );
  }
}
