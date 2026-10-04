import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../activities/data/activity_bookings_provider.dart';

class BillingScreen extends ConsumerStatefulWidget {
  final String? bookingId;
  /// Room number used to pull activity charges. Defaults to '205' for demo.
  final String? roomNumber;
  const BillingScreen({super.key, this.bookingId, this.roomNumber});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  double _discountPct = 0;
  final _discountCtrl = TextEditingController(text: '0');

  // Demo charges — in real app, loaded from Supabase
  final List<_Charge> _roomCharges = [
    _Charge('Deluxe Room × 3 nights', 3 * 3500, 'room'),
  ];
  final List<_Charge> _foodCharges = [
    _Charge('Breakfast × 3', 3 * 250, 'food'),
    _Charge('Dinner × 2',    2 * 350, 'food'),
    _Charge('Room Service',  180,     'food'),
  ];
  final List<_Charge> _shopCharges = [
    _Charge('Organic Honey × 2', 2 * 350, 'shop'),
    _Charge('Masala Mix × 1',    150,     'shop'),
  ];

  String get _roomNo => widget.roomNumber ?? '205';

  /// Build live activity charges from the provider filtered by room
  List<_Charge> _buildActivityCharges(List<Map<String, dynamic>> bookings) {
    return bookings
        .where((b) =>
            b['room_number'] == _roomNo && b['status'] != 'CANCELLED')
        .map((b) {
          final name    = b['activity_name'] as String? ?? 'Activity';
          final emoji   = b['activity_emoji'] as String? ?? '🎯';
          final persons = b['persons'] as int? ?? 1;
          final total   = (b['total_amount'] as num?)?.toDouble() ?? 0.0;
          return _Charge(
            '$emoji $name × $persons person${persons > 1 ? 's' : ''}',
            total,
            'activity',
          );
        })
        .toList();
  }

  double get _roomTotal  => _roomCharges.fold(0, (s, c) => s + c.amount);
  double get _foodTotal  => _foodCharges.fold(0, (s, c) => s + c.amount);
  double get _shopTotal  => _shopCharges.fold(0, (s, c) => s + c.amount);

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(activityBookingsProvider);

    return bookingsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:   (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (allBookings) {
        final activityCharges  = _buildActivityCharges(allBookings);
        final activityTotal    = activityCharges.fold(0.0, (s, c) => s + c.amount);
        final subtotal         = _roomTotal + _foodTotal + activityTotal + _shopTotal;
        final gst              = subtotal * 0.12;
        final discount         = subtotal * (_discountPct / 100);
        final grandTotal       = subtotal + gst - discount;

        // Find guest name from checked-in rooms list
        final guestRoom = kCheckedInRooms.firstWhere(
          (r) => r['room_number'] == _roomNo,
          orElse: () => {'guest_name': 'Guest', 'room_type': 'Room'},
        );
        final guestName = guestRoom['guest_name'] as String? ?? 'Guest';
        final roomType  = guestRoom['room_type']  as String? ?? 'Room';

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: const AnjAppBar(title: 'Billing'),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Guest header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                  ),
                  child: Row(children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0xFF1565C0),
                      child: Icon(Icons.person_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(guestName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Room $_roomNo ($roomType) · Check-out: Today',
                          style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                      Text(widget.bookingId != null ? 'Booking #${widget.bookingId}' : 'Booking #ANJ-2024-001',
                          style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Checked In',
                          style: TextStyle(color: AppTheme.info, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                // Charge sections
                _ChargeSection('🏨 Room Charges', _roomCharges, _roomTotal, const Color(0xFF1565C0)),
                const SizedBox(height: 10),
                _ChargeSection('🍽️ Food & Beverage', _foodCharges, _foodTotal, const Color(0xFFE64A19)),
                const SizedBox(height: 10),

                // Activities — live from provider
                if (activityCharges.isNotEmpty)
                  _ChargeSection('🎯 Activities', activityCharges, activityTotal, const Color(0xFF00838F))
                else
                  _EmptyActivityTile(roomNo: _roomNo),
                const SizedBox(height: 10),

                _ChargeSection('🛍️ Shop', _shopCharges, _shopTotal, const Color(0xFF558B2F)),
                const SizedBox(height: 16),

                // Discount
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                  ),
                  child: Row(children: [
                    const Icon(Icons.local_offer_outlined, color: Color(0xFF6A1B9A), size: 20),
                    const SizedBox(width: 10),
                    const Text('Discount (%)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const Spacer(),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _discountCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        onChanged: (v) => setState(() => _discountPct = double.tryParse(v) ?? 0),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          suffixText: '%',
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                // Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A237E).withOpacity(0.04),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(color: const Color(0xFF1A237E).withOpacity(0.15)),
                  ),
                  child: Column(children: [
                    _SumRow('Room',        '₹${_roomTotal.toStringAsFixed(0)}',     false),
                    _SumRow('Food & Bev',  '₹${_foodTotal.toStringAsFixed(0)}',     false),
                    _SumRow('Activities',  '₹${activityTotal.toStringAsFixed(0)}',  false),
                    _SumRow('Shop',        '₹${_shopTotal.toStringAsFixed(0)}',     false),
                    const Divider(height: 12),
                    _SumRow('Subtotal',    '₹${subtotal.toStringAsFixed(0)}',       false),
                    _SumRow('GST (12%)',   '₹${gst.toStringAsFixed(0)}',            false),
                    if (_discountPct > 0)
                      _SumRow('Discount (${_discountPct.toStringAsFixed(0)}%)',
                          '−₹${discount.toStringAsFixed(0)}', false, isDiscount: true),
                    const Divider(height: 20),
                    _SumRow('Grand Total', '₹${grandTotal.toStringAsFixed(0)}', true),
                  ]),
                ),
                const SizedBox(height: 24),

                // Actions
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: const Text('Generate Invoice'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1565C0),
                        side: const BorderSide(color: Color(0xFF1565C0)),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/payment', extra: {
                        'amount': grandTotal,
                        'booking_id': widget.bookingId,
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      icon: const Icon(Icons.payment_rounded, color: Colors.white, size: 18),
                      label: const Text('Take Payment',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Empty activities placeholder ───────────────────────────────────────────────

class _EmptyActivityTile extends StatelessWidget {
  final String roomNo;
  const _EmptyActivityTile({required this.roomNo});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(children: [
        const Text('🎯', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        const Expanded(child: Text('No activities booked for this room',
            style: TextStyle(color: AppTheme.textHint, fontSize: 13))),
        TextButton(
          onPressed: () => context.push('/activities/register'),
          child: const Text('Add', style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }
}

// ── Supporting classes ─────────────────────────────────────────────────────────

class _Charge {
  final String label; final double amount; final String type;
  const _Charge(this.label, this.amount, this.type);
}

class _ChargeSection extends StatefulWidget {
  final String title;
  final List<_Charge> charges;
  final double total;
  final Color color;
  const _ChargeSection(this.title, this.charges, this.total, this.color);
  @override State<_ChargeSection> createState() => _ChargeSectionState();
}

class _ChargeSectionState extends State<_ChargeSection> {
  bool _expanded = true;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
    ),
    child: Column(children: [
      GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Text(widget.title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: widget.color)),
            const Spacer(),
            Text('₹${widget.total.toStringAsFixed(0)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: widget.color)),
            const SizedBox(width: 6),
            Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 18, color: AppTheme.textHint),
          ]),
        ),
      ),
      if (_expanded) ...widget.charges.map((c) => Container(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Row(children: [
          const SizedBox(width: 12),
          Expanded(child: Text(c.label,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
          Text('₹${c.amount.toStringAsFixed(0)}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ]),
      )),
    ]),
  );
}

class _SumRow extends StatelessWidget {
  final String label, value; final bool bold; final bool isDiscount;
  const _SumRow(this.label, this.value, this.bold, {this.isDiscount = false});
  @override Widget build(_) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text(label, style: TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontSize: bold ? 16 : 14,
        color: isDiscount ? AppTheme.success : AppTheme.textPrimary,
      )),
      const Spacer(),
      Text(value, style: TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontSize: bold ? 18 : 14,
        color: isDiscount ? AppTheme.success : (bold ? AppTheme.primary : AppTheme.textPrimary),
      )),
    ]),
  );
}
