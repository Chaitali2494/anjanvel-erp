import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../activities/data/activity_bookings_provider.dart';
import '../../../shop/data/shop_room_charges_provider.dart';
import '../../data/billing_state_provider.dart';

class BillingScreen extends ConsumerStatefulWidget {
  final String? bookingId;
  final String? roomNumber;
  const BillingScreen({super.key, this.bookingId, this.roomNumber});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  double _discountPct = 0;
  final _discountCtrl = TextEditingController(text: '0');

  String get _roomNo => widget.roomNumber ?? '205';

  @override
  void dispose() {
    _discountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activityBookings = ref.watch(activityBookingsProvider);
    final billingState     = ref.watch(billingStateProvider);
    final shopCharges      = ref.watch(shopRoomChargesProvider);
    final isPaid           = billingState[_roomNo]?['is_paid'] == true;

    return activityBookings.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (allBookings) {
        // ── Find room info ───────────────────────────────────────────────
        final roomInfo = kBillableRooms.firstWhere(
          (r) => r['room_number'] == _roomNo,
          orElse: () => {
            'guest_name': 'Guest', 'room_type': 'Room',
            'nights': 1, 'rate': 3500.0, 'status': 'CHECKED_IN',
          },
        );
        final guestName = roomInfo['guest_name'] as String? ?? 'Guest';
        final roomType  = roomInfo['room_type']  as String? ?? 'Room';
        final nights    = roomInfo['nights']      as int?    ?? 1;
        final rate      = (roomInfo['rate']       as num?)?.toDouble() ?? 3500.0;

        // ── Charge categories ────────────────────────────────────────────
        // 1. Residence
        final residenceCharges = <_Charge>[
          _Charge('$roomType Room × $nights night${nights > 1 ? 's' : ''}',
              rate * nights, Icons.bed_outlined, const Color(0xFF1565C0)),
        ];

        // 2. Kitchen / Food
        final foodTotal = kDemoFoodCharges[_roomNo] ?? 0.0;
        final foodCharges = foodTotal > 0
            ? <_Charge>[
                _Charge('Breakfast × $nights', nights * 250.0, Icons.free_breakfast_outlined, const Color(0xFFE64A19)),
                _Charge('Dinner × ${nights - 1 > 0 ? nights - 1 : 1}',
                    (nights > 1 ? nights - 1 : 1) * 350.0, Icons.dinner_dining_outlined, const Color(0xFFE64A19)),
                _Charge('Room Service', foodTotal - (nights * 250.0) - ((nights > 1 ? nights - 1 : 1) * 350.0) + 0,
                    Icons.room_service_outlined, const Color(0xFFE64A19)),
              ]
            : <_Charge>[];

        // 3. Activities
        final activityCharges = allBookings
            .where((b) => b['room_number'] == _roomNo && b['status'] != 'CANCELLED')
            .map((b) {
              final name    = b['activity_name'] as String? ?? 'Activity';
              final emoji   = b['activity_emoji'] as String? ?? '🎯';
              final persons = b['persons'] as int? ?? 1;
              final total   = (b['total_amount'] as num?)?.toDouble() ?? 0.0;
              return _Charge(
                '$emoji $name × $persons person${persons > 1 ? 's' : ''}',
                total,
                Icons.hiking_outlined,
                const Color(0xFF00838F),
              );
            })
            .toList();

        // 4. SHG Shop charges for this room
        final roomShopCharges = shopCharges
            .where((c) => c.roomNumber == _roomNo)
            .toList();
        final shopBillCharges = roomShopCharges.map((c) => _Charge(
          '${c.product} × ${c.qty}',
          c.total,
          Icons.storefront_rounded,
          const Color(0xFF558B2F),
        )).toList();

        final residenceTotal = residenceCharges.fold(0.0, (s, c) => s + c.amount);
        final kitchenTotal   = foodCharges.fold(0.0, (s, c) => s + c.amount);
        final activityTotal  = activityCharges.fold(0.0, (s, c) => s + c.amount);
        final shopTotal      = shopBillCharges.fold(0.0, (s, c) => s + c.amount);
        final subtotal       = residenceTotal + kitchenTotal + activityTotal + shopTotal;
        final gst            = subtotal * 0.12;
        final discount       = subtotal * (_discountPct / 100);
        final grandTotal     = subtotal + gst - discount;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: const AnjAppBar(title: 'Billing'),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── PAID banner ──────────────────────────────────────────
                if (isPaid)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(color: AppTheme.success, width: 1.5),
                    ),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 24),
                      const SizedBox(width: 10),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('All Bills Paid',
                            style: TextStyle(
                                color: AppTheme.success,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        Text('₹${(billingState[_roomNo]?['amount'] as num?)?.toStringAsFixed(0) ?? grandTotal.toStringAsFixed(0)} received · Room $_roomNo',
                            style: const TextStyle(color: AppTheme.success, fontSize: 12)),
                      ]),
                    ]),
                  ),

                // ── Guest header ─────────────────────────────────────────
                _GuestHeader(
                  guestName: guestName,
                  roomNo: _roomNo,
                  roomType: roomType,
                  bookingId: widget.bookingId,
                  nights: nights,
                  isPaid: isPaid,
                ),
                const SizedBox(height: 16),

                // ── Residence Bill ───────────────────────────────────────
                _BillSection(
                  title: '🏨 Residence',
                  charges: residenceCharges,
                  total: residenceTotal,
                  color: const Color(0xFF1565C0),
                ),
                const SizedBox(height: 10),

                // ── Kitchen Bill ─────────────────────────────────────────
                _BillSection(
                  title: '🍽️ Kitchen / Food',
                  charges: foodCharges,
                  total: kitchenTotal,
                  color: const Color(0xFFE64A19),
                  emptyLabel: 'No food orders for this room',
                ),
                const SizedBox(height: 10),

                // ── Activity Bill ────────────────────────────────────────
                _BillSection(
                  title: '🎯 Activities',
                  charges: activityCharges,
                  total: activityTotal,
                  color: const Color(0xFF00838F),
                  emptyLabel: 'No activities booked',
                  emptyAction: TextButton(
                    onPressed: () => context.push('/activities/register'),
                    child: const Text('Add Activity', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(height: 10),

                // ── SHG Shop Bill ─────────────────────────────────────────
                _BillSection(
                  title: '🏪 SHG Shop',
                  charges: shopBillCharges,
                  total: shopTotal,
                  color: const Color(0xFF558B2F),
                  emptyLabel: 'No shop purchases for this room',
                  emptyAction: TextButton(
                    onPressed: () => context.push('/shop'),
                    child: const Text('Go to Shop', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Discount ─────────────────────────────────────────────
                if (!isPaid)
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
                      const Text('Discount (%)',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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

                // ── Summary ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A237E).withOpacity(0.04),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(color: const Color(0xFF1A237E).withOpacity(0.15)),
                  ),
                  child: Column(children: [
                    _SummaryRow('🏨 Residence',  '₹${residenceTotal.toStringAsFixed(0)}', false, const Color(0xFF1565C0)),
                    _SummaryRow('🍽️ Kitchen',    '₹${kitchenTotal.toStringAsFixed(0)}',   false, const Color(0xFFE64A19)),
                    _SummaryRow('🎯 Activities', '₹${activityTotal.toStringAsFixed(0)}',  false, const Color(0xFF00838F)),
                    const Divider(height: 16),
                    _SummaryRow('Subtotal',  '₹${subtotal.toStringAsFixed(0)}',    false, AppTheme.textPrimary),
                    _SummaryRow('GST (12%)', '₹${gst.toStringAsFixed(0)}',         false, AppTheme.textPrimary),
                    if (_discountPct > 0)
                      _SummaryRow(
                          'Discount (${_discountPct.toStringAsFixed(0)}%)',
                          '−₹${discount.toStringAsFixed(0)}',
                          false, AppTheme.success),
                    const Divider(height: 20),
                    Row(children: [
                      const Text('Grand Total',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const Spacer(),
                      Text('₹${grandTotal.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: isPaid ? AppTheme.success : AppTheme.primary)),
                      if (isPaid) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle_rounded,
                            color: AppTheme.success, size: 22),
                      ],
                    ]),
                  ]),
                ),
                const SizedBox(height: 24),

                // ── Actions ──────────────────────────────────────────────
                if (!isPaid)
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                        label: const Text('Invoice'),
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
                        onPressed: () => _takePayment(context, grandTotal),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        icon: const Icon(Icons.payment_rounded, color: Colors.white, size: 18),
                        label: const Text('Take Payment',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ])
                else
                  OutlinedButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Checkout Complete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.success,
                      side: const BorderSide(color: AppTheme.success),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _takePayment(BuildContext context, double grandTotal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.payment_rounded, color: AppTheme.success, size: 26),
          SizedBox(width: 10),
          Text('Confirm Payment'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Total amount for Room $_roomNo:',
              style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          Text('₹${grandTotal.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 28, color: AppTheme.success)),
          const SizedBox(height: 12),
          const Text('This will mark all bills (Residence + Kitchen + Activities) as PAID.',
              style: TextStyle(fontSize: 13), textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Paid',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(billingStateProvider.notifier).markPaid(_roomNo, grandTotal);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Room $_roomNo — All bills paid! ₹${grandTotal.toStringAsFixed(0)} received'),
          ]),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

// ── Guest Header ──────────────────────────────────────────────────────────────

class _GuestHeader extends StatelessWidget {
  final String guestName, roomNo, roomType;
  final String? bookingId;
  final int nights;
  final bool isPaid;
  const _GuestHeader({
    required this.guestName, required this.roomNo,
    required this.roomType, required this.nights,
    required this.isPaid, this.bookingId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: isPaid ? AppTheme.success : const Color(0xFF1565C0),
          child: Icon(
            isPaid ? Icons.check_rounded : Icons.person_rounded,
            color: Colors.white, size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(guestName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text('Room $roomNo ($roomType) · $nights night${nights > 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
          if (bookingId != null)
            Text('Booking #$bookingId',
                style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isPaid
                ? AppTheme.success.withOpacity(0.12)
                : AppTheme.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isPaid ? 'PAID ✓' : 'Checked In',
            style: TextStyle(
              color: isPaid ? AppTheme.success : AppTheme.info,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Bill Section ──────────────────────────────────────────────────────────────

class _BillSection extends StatefulWidget {
  final String title;
  final List<_Charge> charges;
  final double total;
  final Color color;
  final String? emptyLabel;
  final Widget? emptyAction;

  const _BillSection({
    required this.title, required this.charges,
    required this.total, required this.color,
    this.emptyLabel, this.emptyAction,
  });

  @override
  State<_BillSection> createState() => _BillSectionState();
}

class _BillSectionState extends State<_BillSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Column(children: [
        // Header
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Text(widget.title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14, color: widget.color)),
              const Spacer(),
              if (widget.total > 0)
                Text('₹${widget.total.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14, color: widget.color)),
              const SizedBox(width: 6),
              Icon(
                _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 18, color: AppTheme.textPrimary,
              ),
            ]),
          ),
        ),
        // Rows
        if (_expanded) ...[
          if (widget.charges.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(children: [
                Text(widget.emptyLabel ?? 'No charges',
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                if (widget.emptyAction != null) ...[
                  const Spacer(),
                  widget.emptyAction!,
                ],
              ]),
            )
          else
            ...widget.charges.map((c) => Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(children: [
                Icon(c.icon, size: 15, color: widget.color.withOpacity(0.7)),
                const SizedBox(width: 8),
                Expanded(child: Text(c.label,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
                Text('₹${c.amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            )),
        ],
      ]),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  final Color color;
  const _SummaryRow(this.label, this.value, this.bold, this.color);
  @override
  Widget build(_) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Text(label,
          style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 16 : 14,
              color: color)),
      const Spacer(),
      Text(value,
          style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: bold ? 18 : 14,
              color: color)),
    ]),
  );
}

class _Charge {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  const _Charge(this.label, this.amount, this.icon, this.color);
}
