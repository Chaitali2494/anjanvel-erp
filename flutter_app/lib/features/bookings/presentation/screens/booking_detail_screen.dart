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

                // Payment summary
                _PaymentSummaryCard(booking: b),
                const SizedBox(height: 12),

                // Record Payment button (show if balance > 0)
                if ((b.balanceAmount ?? b.totalAmount - b.paidAmount) > 0)
                  SizedBox(
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
                  ),
                const SizedBox(height: 12),

                // Payment history
                _PaymentHistoryCard(
                  payments: b.payments ?? [],
                  onRefresh: () => ref.invalidate(bookingDetailProvider(widget.bookingId)),
                ),
                const SizedBox(height: 12),

                // Room Assignment (show when confirmed)
                if (b.status == 'CONFIRMED' || b.status == 'INQUIRY') ...[
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

      // Insert payment record
      await client.from('payments').insert({
        'booking_id': bookingId,
        'amount': amount,
        'method': method,
        'status': 'COMPLETED',
      });

      // Update booking paid_amount
      final newPaid = paidAmount + amount;
      final newBalance = totalAmount - newPaid;
      final newPaymentStatus = newBalance <= 0 ? 'PAID' : 'PARTIAL';

      await client.from('bookings').update({
        'paid_amount': newPaid,
        'balance_amount': newBalance < 0 ? 0 : newBalance,
        'payment_status': newPaymentStatus,
      }).eq('id', bookingId);

      ref.invalidate(bookingDetailProvider(bookingId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('₹${amount.toStringAsFixed(0)} recorded via ${method.replaceAll('_', ' ')}'),
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
  const _PaymentSummaryCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final balance = booking.balanceAmount ?? (booking.totalAmount - booking.paidAmount);
    final paidPct = booking.totalAmount > 0 ? (booking.paidAmount / booking.totalAmount).clamp(0.0, 1.0) : 0.0;

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
          _InfoRow('Paid', '₹${booking.paidAmount.toStringAsFixed(0)}'),
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
          const Row(
            children: [
              Icon(Icons.receipt_long_outlined, size: 16, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('Payment History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const Divider(height: 16),
          if (payments.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No payments recorded yet', style: TextStyle(color: AppTheme.textHint)),
              ),
            )
          else
            ...payments.map((p) {
              final paidAt = p['created_at'] != null
                  ? DateFormat('d MMM yyyy, h:mm a').format(DateTime.parse(p['created_at'] as String))
                  : '—';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 16, color: AppTheme.success),
                ),
                title: Text(
                  '₹${(p['amount'] as num).toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${(p['method'] as String? ?? '').replaceAll('_', ' ')} · $paidAt',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (p['status'] as String? ?? '').toUpperCase(),
                    style: const TextStyle(fontSize: 10, color: AppTheme.success, fontWeight: FontWeight.bold),
                  ),
                ),
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

  Future<void> _load() async {
    final client = ref.read(supabaseClientProvider);
    try {
      // Get assigned rooms for this booking
      final assigned = await client
          .from('booking_rooms')
          .select('room_id, rooms(room_number, room_types(name))')
          .eq('booking_id', widget.bookingId);

      // Get all available rooms
      final available = await client
          .from('rooms')
          .select('id, room_number, status, room_types(name)')
          .eq('status', 'AVAILABLE')
          .order('room_number');

      if (mounted) {
        setState(() {
          _assignedRooms = List<Map<String, dynamic>>.from(assigned);
          _availableRooms = List<Map<String, dynamic>>.from(available);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assignRoom(String roomId, String roomNumber) async {
    final client = ref.read(supabaseClientProvider);
    try {
      await client.from('booking_rooms').insert({
        'booking_id': widget.bookingId,
        'room_id': roomId,
      });
      await client.from('rooms').update({'status': 'RESERVED'}).eq('id', roomId);
      widget.onAssigned();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Room $roomNumber assigned & marked Reserved'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
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
                    onTap: () => _assignRoom(r['id'] as String, r['room_number'] as String),
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
