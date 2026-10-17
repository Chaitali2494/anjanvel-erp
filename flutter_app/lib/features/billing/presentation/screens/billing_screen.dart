import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../activities/data/activity_bookings_provider.dart';
import '../../../shop/data/shop_room_charges_provider.dart';
import '../../../food/data/food_orders_state_provider.dart';
import '../../data/billing_state_provider.dart';

class BillingScreen extends ConsumerStatefulWidget {
  final String? bookingId;
  final String? roomNumber;
  final String? checkInDate;
  final String? checkOutDate;
  const BillingScreen({super.key, this.bookingId, this.roomNumber, this.checkInDate, this.checkOutDate});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  double _discountPct   = 0;
  int    _extraMattress = 0;
  int?   _personsOverride; // null = use booking value; set when staff adjusts manually
  static const double _mattressRate = 200.0;

  final _discountCtrl = TextEditingController(text: '0');

  // Use '101' as fallback — matches kBillableRooms & sessionRoomBookings keys
  String get _roomNo => widget.roomNumber ?? '101';

  /// Actual nights from widget dates → session booking → demo fallback
  int _calcNights(int fallbackNights) {
    final ci = DateTime.tryParse(widget.checkInDate ?? '');
    final co = DateTime.tryParse(widget.checkOutDate ?? '');
    if (ci != null && co != null && co.isAfter(ci)) return co.difference(ci).inDays;
    return getActualNights(_roomNo) > 0 ? getActualNights(_roomNo) : fallbackNights;
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    super.dispose();
  }

  // Format a date string as dd/mm/yyyy for display
  static String _fmtDate(String d) {
    final dt = DateTime.tryParse(d);
    if (dt == null) return d;
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    // Never block rendering: use .valueOrNull so screen shows immediately
    final allActivities = ref.watch(activityBookingsProvider).valueOrNull
        ?? <Map<String, dynamic>>[];
    final billingState  = ref.watch(billingStateProvider);
    final shopCharges   = ref.watch(shopRoomChargesProvider);
    final allFoodOrders = ref.watch(foodOrdersStateProvider);
    final isPaid        = billingState[_roomNo]?['is_paid'] == true;

    // Room info — session data takes priority over demo data
    final roomInfo    = getRoomInfo(_roomNo);
    final guestName   = roomInfo['guest_name'] as String? ?? 'Guest';
    final roomType    = roomInfo['room_type']  as String? ?? 'Room';
    final baseNights  = (roomInfo['nights']    as num?)?.toInt() ?? 1;
    final nights      = _calcNights(baseNights);
    final rate        = (roomInfo['rate']      as num?)?.toDouble() ?? 3500.0;
    final basePersons = (roomInfo['persons']   as num?)?.toInt() ?? 1;
    final persons     = _personsOverride ?? basePersons;
    final checkIn     = widget.checkInDate  ?? (roomInfo['check_in']  as String?) ?? '';
    final checkOut    = widget.checkOutDate ?? (roomInfo['check_out'] as String?) ?? '';

    // ── 1. Residence charges ─────────────────────────────────────────────────
    final roomCharge    = rate * persons * nights;
    final mattressTotal = _extraMattress * _mattressRate * nights;
    final residenceCharges = <_Charge>[
      _Charge(
        '$roomType × $persons pax × $nights night${nights != 1 ? "s" : ""}'
        '  (₹${rate.toInt()}/pax/night)'
        '${checkIn.isNotEmpty && checkOut.isNotEmpty ? "\n${_fmtDate(checkIn)} – ${_fmtDate(checkOut)}" : ""}',
        roomCharge,
        Icons.bed_outlined,
        const Color(0xFF1565C0),
      ),
      if (_extraMattress > 0)
        _Charge(
          'Extra Mattress ×$_extraMattress × $nights night${nights != 1 ? "s" : ""}'
          ' (₹${_mattressRate.toInt()}/mattress/night)',
          mattressTotal,
          Icons.hotel_outlined,
          const Color(0xFF6A1B9A),
        ),
    ];

    // ── 2. Food charges ──────────────────────────────────────────────────────
    final roomFoodOrders = allFoodOrders
        .where((o) =>
            ((o['bookings'] as Map<String, dynamic>?)?['room_number'] as String? ?? '') == _roomNo
            && o['status'] != 'CANCELLED')
        .toList();
    final foodCharges = <_Charge>[];
    for (final order in roomFoodOrders) {
      final items = order['items'] as List<dynamic>? ?? [];
      if (items.isNotEmpty) {
        for (final item in items) {
          final nm  = item['name']  as String? ?? 'Item';
          final qty = (item['qty']  as num?)?.toInt()    ?? 1;
          final prc = (item['price'] as num?)?.toDouble() ?? 0.0;
          foodCharges.add(_Charge('$nm × $qty', prc * qty,
              Icons.restaurant_outlined, const Color(0xFFE64A19)));
        }
      } else {
        final amt  = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
        final meal = order['meal_type'] as String? ?? 'Food';
        final oNo  = order['order_number'] as String? ?? '';
        foodCharges.add(_Charge('$meal ($oNo)', amt,
            Icons.restaurant_outlined, const Color(0xFFE64A19)));
      }
    }

    // ── 3. Activity charges (actPax avoids shadowing outer `persons`) ────────
    final activityCharges = allActivities
        .where((b) => b['room_number'] == _roomNo && b['status'] != 'CANCELLED')
        .map((b) {
          final nm     = b['activity_name']  as String? ?? 'Activity';
          final emoji  = b['activity_emoji'] as String? ?? '🎯';
          final actPax = (b['persons'] as num?)?.toInt() ?? 1;
          final total  = (b['total_amount']  as num?)?.toDouble() ?? 0.0;
          return _Charge('$emoji $nm × $actPax pax', total,
              Icons.hiking_outlined, const Color(0xFF00838F));
        })
        .toList();

    // ── 4. Shop charges ──────────────────────────────────────────────────────
    final shopBillCharges = shopCharges
        .where((c) => c.roomNumber == _roomNo)
        .map((c) => _Charge('${c.product} × ${c.qty}', c.total,
            Icons.storefront_rounded, const Color(0xFF558B2F)))
        .toList();

    // ── Totals ───────────────────────────────────────────────────────────────
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
          appBar: AnjAppBar(
            title: 'Billing',
            actions: [
              IconButton(
                tooltip: 'Download Invoice',
                icon: const Icon(Icons.picture_as_pdf_rounded),
                onPressed: () => _downloadInvoice(
                  guestName: guestName,
                  roomNo: _roomNo,
                  roomType: roomType,
                  nights: nights,
                  persons: persons,
                  residenceCharges: residenceCharges,
                  foodCharges: foodCharges,
                  activityCharges: activityCharges,
                  shopCharges: shopBillCharges,
                  residenceTotal: residenceTotal,
                  kitchenTotal: kitchenTotal,
                  activityTotal: activityTotal,
                  shopTotal: shopTotal,
                  subtotal: subtotal,
                  gst: gst,
                  discount: discount,
                  discountPct: _discountPct,
                  grandTotal: grandTotal,
                ),
              ),
            ],
          ),
          // ── Persistent bottom bar: Download + Done when paid ─────────────
          bottomNavigationBar: isPaid
              ? SafeArea(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2)),
                      ],
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () => _downloadInvoice(
                            guestName: guestName,
                            roomNo: _roomNo,
                            roomType: roomType,
                            nights: nights,
                            persons: persons,
                            residenceCharges: residenceCharges,
                            foodCharges: foodCharges,
                            activityCharges: activityCharges,
                            shopCharges: shopBillCharges,
                            residenceTotal: residenceTotal,
                            kitchenTotal: kitchenTotal,
                            activityTotal: activityTotal,
                            shopTotal: shopTotal,
                            subtotal: subtotal,
                            gst: gst,
                            discount: discount,
                            discountPct: _discountPct,
                            grandTotal: grandTotal,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                          label: const Text(
                            'Download Invoice  •  PAID ✓',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: OutlinedButton.icon(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Done'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.success,
                            side: const BorderSide(color: AppTheme.success),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ]),
                  ),
                )
              : null,
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
                const SizedBox(height: 8),

                // ── Persons + Extra Mattress controls (always visible) ──────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.18)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                  ),
                  child: Column(children: [
                    // ── Persons row ──────────────────────────────────────
                    Row(children: [
                      const Icon(Icons.people_outline, color: Color(0xFF1565C0), size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Persons', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text('Adults staying (affects room charge)', style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                        ]),
                      ),
                      Row(children: [
                        IconButton(
                          onPressed: (!isPaid && persons > 1) ? () => setState(() => _personsOverride = persons - 1) : null,
                          icon: const Icon(Icons.remove_circle_outline),
                          color: const Color(0xFF1565C0),
                          iconSize: 22,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                        Container(
                          width: 36,
                          alignment: Alignment.center,
                          child: Text('$persons',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
                        ),
                        IconButton(
                          onPressed: !isPaid ? () => setState(() => _personsOverride = persons + 1) : null,
                          icon: const Icon(Icons.add_circle_outline),
                          color: const Color(0xFF1565C0),
                          iconSize: 22,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                      ]),
                    ]),
                    const Divider(height: 18, thickness: 0.5),
                    // ── Extra Mattress row ───────────────────────────────
                    Row(children: [
                      const Icon(Icons.hotel_outlined, color: Color(0xFF6A1B9A), size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Extra Mattress', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text('₹200/mattress/night — charged separately', style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                        ]),
                      ),
                      Row(children: [
                        IconButton(
                          onPressed: (!isPaid && _extraMattress > 0) ? () => setState(() => _extraMattress--) : null,
                          icon: const Icon(Icons.remove_circle_outline),
                          color: const Color(0xFF6A1B9A),
                          iconSize: 22,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                        Container(
                          width: 36,
                          alignment: Alignment.center,
                          child: Text('$_extraMattress',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A))),
                        ),
                        IconButton(
                          onPressed: !isPaid ? () => setState(() => _extraMattress++) : null,
                          icon: const Icon(Icons.add_circle_outline),
                          color: const Color(0xFF6A1B9A),
                          iconSize: 22,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                      ]),
                    ]),
                  ]),
                ),
                const SizedBox(height: 10),

                // ── Kitchen Bill ─────────────────────────────────────────
                _FoodBillSection(
                  orders: roomFoodOrders,
                  total: kitchenTotal,
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
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Discount',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        Text('Enter % to apply on subtotal',
                            style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                      ]),
                    ),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _discountCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        enabled: !isPaid,
                        onChanged: (v) => setState(() => _discountPct = double.tryParse(v) ?? 0),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          suffixText: '%',
                          hintText: '0',
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
                    // Stay detail header
                    if (checkIn.isNotEmpty && checkOut.isNotEmpty) ...[
                      Row(children: [
                        const Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.textHint),
                        const SizedBox(width: 6),
                        Text('${_fmtDate(checkIn)} → ${_fmtDate(checkOut)}  ·  $nights night${nights > 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
                      ]),
                      const SizedBox(height: 10),
                    ],
                    _SummaryRow(
                        '🏨 Room  $persons pax × ${nights}N × ₹${rate.toInt()}',
                        '₹${roomCharge.toStringAsFixed(0)}',
                        false, const Color(0xFF1565C0)),
                    if (_extraMattress > 0)
                      _SummaryRow('🛏️ Mattress ×$_extraMattress × ${nights}N × ₹${_mattressRate.toInt()}',
                          '₹${mattressTotal.toStringAsFixed(0)}', false, const Color(0xFF6A1B9A)),
                    if (kitchenTotal > 0)
                      _SummaryRow('🍽️ Kitchen',    '₹${kitchenTotal.toStringAsFixed(0)}', false, const Color(0xFFE64A19)),
                    if (activityTotal > 0)
                      _SummaryRow('🎯 Activities', '₹${activityTotal.toStringAsFixed(0)}', false, const Color(0xFF00838F)),
                    if (shopTotal > 0)
                      _SummaryRow('🏪 Shop',       '₹${shopTotal.toStringAsFixed(0)}', false, const Color(0xFF558B2F)),
                    const Divider(height: 16),
                    _SummaryRow('Subtotal',  '₹${subtotal.toStringAsFixed(0)}',  false, AppTheme.textPrimary),
                    _SummaryRow('GST (12%)', '₹${gst.toStringAsFixed(0)}',       false, AppTheme.textPrimary),
                    _SummaryRow(
                        _discountPct > 0
                            ? 'Discount (${_discountPct.toStringAsFixed(0)}%)'
                            : 'Discount',
                        _discountPct > 0
                            ? '−₹${discount.toStringAsFixed(0)}'
                            : '—',
                        false,
                        _discountPct > 0 ? AppTheme.success : AppTheme.textHint),
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
                        onPressed: () => _downloadInvoice(
                          guestName: guestName,
                          roomNo: _roomNo,
                          roomType: roomType,
                          nights: nights,
                          persons: persons,
                          residenceCharges: residenceCharges,
                          foodCharges: foodCharges,
                          activityCharges: activityCharges,
                          shopCharges: shopBillCharges,
                          residenceTotal: residenceTotal,
                          kitchenTotal: kitchenTotal,
                          activityTotal: activityTotal,
                          shopTotal: shopTotal,
                          subtotal: subtotal,
                          gst: gst,
                          discount: discount,
                          discountPct: _discountPct,
                          grandTotal: grandTotal,
                        ),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                        label: const Text('Download Invoice'),
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
                  Column(children: [
                    // Download invoice button (shown after payment)
                    ElevatedButton.icon(
                      onPressed: () => _downloadInvoice(
                        guestName: guestName,
                        roomNo: _roomNo,
                        roomType: roomType,
                        nights: nights,
                        persons: persons,
                        residenceCharges: residenceCharges,
                        foodCharges: foodCharges,
                        activityCharges: activityCharges,
                        shopCharges: shopBillCharges,
                        residenceTotal: residenceTotal,
                        kitchenTotal: kitchenTotal,
                        activityTotal: activityTotal,
                        shopTotal: shopTotal,
                        subtotal: subtotal,
                        gst: gst,
                        discount: discount,
                        discountPct: _discountPct,
                        grandTotal: grandTotal,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      icon: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                      label: const Text('Download Invoice',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Done'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.success,
                        side: const BorderSide(color: AppTheme.success),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ]),
              ],
            ),
          ),
        );
  }

  Future<void> _downloadInvoice({
    required String guestName,
    required String roomNo,
    required String roomType,
    required int nights,
    required int persons,
    required List<_Charge> residenceCharges,
    required List<_Charge> foodCharges,
    required List<_Charge> activityCharges,
    required List<_Charge> shopCharges,
    required double residenceTotal,
    required double kitchenTotal,
    required double activityTotal,
    required double shopTotal,
    required double subtotal,
    required double gst,
    required double discount,
    required double discountPct,
    required double grandTotal,
  }) async {
    final pdf = pw.Document();

    // Colors
    const headerColor  = PdfColor.fromInt(0xFF1A237E);
    const accentColor  = PdfColor.fromInt(0xFF1565C0);
    const greenColor   = PdfColor.fromInt(0xFF2E7D32);
    const lightGrey    = PdfColor.fromInt(0xFFF5F5F5);
    const borderColor  = PdfColor.fromInt(0xFFE0E0E0);

    pw.Widget sectionTitle(String title, PdfColor color) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Text(title, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11)),
    );

    pw.Widget chargeRow(String label, double amount) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text('₹${amount.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );

    pw.Widget totalRow(String label, double amount, {bool bold = false, PdfColor? color}) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: bold ? 12 : 10, fontWeight: bold ? pw.FontWeight.bold : null, color: color)),
        pw.Text('₹${amount.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: bold ? 14 : 10, fontWeight: bold ? pw.FontWeight.bold : null, color: color ?? accentColor)),
      ],
    );

    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final invoiceNo = 'ANJ-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$roomNo';

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [

          // ── Header ──────────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(color: headerColor, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('ANJANVEL AGRO TOURISM RESORT', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.SizedBox(height: 4),
                  pw.Text('Anjanvel, Ratnagiri, Maharashtra', style: pw.TextStyle(color: PdfColor(1, 1, 1, 0.7), fontSize: 9)),
                  pw.Text('+91 98765 43210  |  anjanvel@resort.com', style: pw.TextStyle(color: PdfColor(1, 1, 1, 0.7), fontSize: 9)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('TAX INVOICE', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 16)),
                  pw.SizedBox(height: 4),
                  pw.Text(invoiceNo, style: pw.TextStyle(color: PdfColor(1, 1, 1, 0.7), fontSize: 9)),
                  pw.Text('Date: $dateStr', style: pw.TextStyle(color: PdfColor(1, 1, 1, 0.7), fontSize: 9)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ── Guest info ───────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: lightGrey, borderRadius: pw.BorderRadius.circular(6), border: pw.Border.all(color: borderColor)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('BILL TO', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  pw.SizedBox(height: 2),
                  pw.Text(guestName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('Room $roomNo  •  $roomType', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text('$persons person${persons > 1 ? 's' : ''}  •  $nights night${nights > 1 ? 's' : ''}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // ── Charge sections ──────────────────────────────────────────────
          if (residenceCharges.isNotEmpty) ...[
            sectionTitle('🏨  Residence', accentColor),
            pw.SizedBox(height: 6),
            ...residenceCharges.map((c) => chargeRow(c.label, c.amount)),
            pw.Divider(color: borderColor),
            totalRow('Residence Total', residenceTotal),
            pw.SizedBox(height: 10),
          ],

          if (foodCharges.isNotEmpty) ...[
            sectionTitle('🍽️  Kitchen / Food', const PdfColor.fromInt(0xFFE64A19)),
            pw.SizedBox(height: 6),
            ...foodCharges.map((c) => chargeRow(c.label, c.amount)),
            pw.Divider(color: borderColor),
            totalRow('Kitchen Total', kitchenTotal),
            pw.SizedBox(height: 10),
          ],

          if (activityCharges.isNotEmpty) ...[
            sectionTitle('🎯  Activities', const PdfColor.fromInt(0xFF00838F)),
            pw.SizedBox(height: 6),
            ...activityCharges.map((c) => chargeRow(c.label, c.amount)),
            pw.Divider(color: borderColor),
            totalRow('Activities Total', activityTotal),
            pw.SizedBox(height: 10),
          ],

          if (shopCharges.isNotEmpty) ...[
            sectionTitle('🏪  SHG Shop', const PdfColor.fromInt(0xFF558B2F)),
            pw.SizedBox(height: 6),
            ...shopCharges.map((c) => chargeRow(c.label, c.amount)),
            pw.Divider(color: borderColor),
            totalRow('Shop Total', shopTotal),
            pw.SizedBox(height: 10),
          ],

          pw.Divider(thickness: 1.5, color: const PdfColor.fromInt(0xFF9E9E9E)),
          pw.SizedBox(height: 8),

          // ── Summary ──────────────────────────────────────────────────────
          totalRow('Subtotal', subtotal),
          pw.SizedBox(height: 4),
          totalRow('GST (12%)', gst, color: const PdfColor.fromInt(0xFFE64A19)),
          if (discount > 0) ...[
            pw.SizedBox(height: 4),
            totalRow('Discount (${discountPct.toStringAsFixed(0)}%)', -discount, color: greenColor),
          ],
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: greenColor, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('GRAND TOTAL', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 13)),
                pw.Text('₹${grandTotal.toStringAsFixed(0)}', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ── Footer ───────────────────────────────────────────────────────
          pw.Center(child: pw.Text('Thank you for staying at Anjanvel Agro Tourism Resort!',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text('GSTIN: 27XXXXX1234X1ZX  |  www.anjanvelresort.com',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey))),
        ],
      ),
    ));

    // Save and share/download
    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Invoice-$roomNo-$guestName.pdf',
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

// ── Food Bill Section (table format) ─────────────────────────────────────────

class _FoodBillSection extends StatefulWidget {
  final List<Map<String, dynamic>> orders;
  final double total;
  const _FoodBillSection({required this.orders, required this.total});

  @override
  State<_FoodBillSection> createState() => _FoodBillSectionState();
}

class _FoodBillSectionState extends State<_FoodBillSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    const foodColor = Color(0xFFE64A19);

    // Flatten all items across orders for the table
    final List<Map<String, dynamic>> tableRows = [];
    for (final order in widget.orders) {
      final items = order['items'] as List<dynamic>? ?? [];
      final orderedAt = order['ordered_at'] as String?;
      String dateStr = '';
      String timeStr = '';
      if (orderedAt != null) {
        final dt = DateTime.tryParse(orderedAt);
        if (dt != null) {
          dateStr = DateFormat('dd MMM').format(dt);
          timeStr = DateFormat('hh:mm a').format(dt);
        }
      }
      if (items.isNotEmpty) {
        for (final item in items) {
          tableRows.add({
            'name': item['name'] as String? ?? 'Item',
            'qty': (item['qty'] as num?)?.toInt() ?? 1,
            'price': (item['price'] as num?)?.toDouble() ?? 0.0,
            'date': dateStr,
            'time': timeStr,
          });
        }
      } else {
        final amount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
        final mealType = order['meal_type'] as String? ?? 'Food';
        tableRows.add({
          'name': '$mealType (${order['order_number'] ?? ''})',
          'qty': 1,
          'price': amount,
          'date': dateStr,
          'time': timeStr,
        });
      }
    }

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
              const Text('🍽️ Kitchen / Food',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: foodColor)),
              const Spacer(),
              if (widget.total > 0)
                Text('₹${widget.total.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: foodColor)),
              const SizedBox(width: 6),
              Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 18, color: AppTheme.textPrimary),
            ]),
          ),
        ),
        // Table
        if (_expanded) ...[
          if (tableRows.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text('No food orders for this room',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
            )
          else ...[
            // Table header
            Container(
              color: foodColor.withOpacity(0.07),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: const Row(children: [
                SizedBox(width: 26, child: Text('Sr', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary))),
                Expanded(flex: 3, child: Text('Food Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary))),
                SizedBox(width: 60, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary))),
                SizedBox(width: 28, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary))),
                SizedBox(width: 60, child: Text('Price', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary))),
              ]),
            ),
            ...tableRows.asMap().entries.map((entry) {
              final i = entry.key;
              final row = entry.value;
              final qty    = row['qty'] as int;
              final price  = row['price'] as double;
              final rowAmt = price * qty;
              return Container(
                color: i.isEven ? Colors.transparent : foodColor.withOpacity(0.03),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(children: [
                  SizedBox(width: 26, child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary))),
                  Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(row['name'] as String, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                    if ((row['time'] as String).isNotEmpty)
                      Text(row['time'] as String, style: TextStyle(fontSize: 10, color: AppTheme.textPrimary.withOpacity(0.55))),
                  ])),
                  SizedBox(width: 60, child: Text(row['date'] as String, style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary))),
                  SizedBox(width: 28, child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary))),
                  SizedBox(width: 60, child: Text('₹${rowAmt.toStringAsFixed(0)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
                ]),
              );
            }),
            // Total row
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: foodColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                const Spacer(),
                Text('₹${widget.total.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: foodColor)),
              ]),
            ),
          ],
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
