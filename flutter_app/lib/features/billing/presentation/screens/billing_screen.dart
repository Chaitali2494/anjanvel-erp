import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class BillingScreen extends ConsumerStatefulWidget {
  final String? bookingId;
  const BillingScreen({super.key, this.bookingId});

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
  final List<_Charge> _activityCharges = [
    _Charge('Heritage Walk × 2', 2 * 500, 'activity'),
    _Charge('Pottery Class × 1', 400,     'activity'),
  ];
  final List<_Charge> _shopCharges = [
    _Charge('Organic Honey × 2', 2 * 350, 'shop'),
    _Charge('Masala Mix × 1',    150,     'shop'),
  ];

  double get _roomTotal     => _roomCharges.fold(0, (s, c) => s + c.amount);
  double get _foodTotal     => _foodCharges.fold(0, (s, c) => s + c.amount);
  double get _activityTotal => _activityCharges.fold(0, (s, c) => s + c.amount);
  double get _shopTotal     => _shopCharges.fold(0, (s, c) => s + c.amount);
  double get _subtotal      => _roomTotal + _foodTotal + _activityTotal + _shopTotal;
  double get _gst           => _subtotal * 0.12;
  double get _discount      => _subtotal * (_discountPct / 100);
  double get _grandTotal    => _subtotal + _gst - _discount;

  @override
  Widget build(BuildContext context) {
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
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(AppTheme.radiusMD), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
              child: Row(children: [
                const CircleAvatar(radius: 24, backgroundColor: Color(0xFF1565C0), child: Icon(Icons.person_rounded, color: Colors.white, size: 26)),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Priya Sharma', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Room 205 · Check-out: Today', style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
                  Text('Booking #ANJ-2024-001', style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: AppTheme.info.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Text('Checked In', style: TextStyle(color: AppTheme.info, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Charge sections
            _ChargeSection('🏨 Room Charges', _roomCharges, _roomTotal, const Color(0xFF1565C0)),
            const SizedBox(height: 10),
            _ChargeSection('🍽️ Food & Beverage', _foodCharges, _foodTotal, const Color(0xFFE64A19)),
            const SizedBox(height: 10),
            _ChargeSection('🎯 Activities', _activityCharges, _activityTotal, const Color(0xFF00838F)),
            const SizedBox(height: 10),
            _ChargeSection('🛍️ Shop', _shopCharges, _shopTotal, const Color(0xFF558B2F)),
            const SizedBox(height: 16),

            // Discount
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(AppTheme.radiusMD), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
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
                _SumRow('Subtotal',     '₹${_subtotal.toStringAsFixed(0)}', false),
                _SumRow('GST (12%)',    '₹${_gst.toStringAsFixed(0)}',      false),
                if (_discountPct > 0)
                  _SumRow('Discount (${_discountPct.toStringAsFixed(0)}%)', '−₹${_discount.toStringAsFixed(0)}', false, isDiscount: true),
                const Divider(height: 20),
                _SumRow('Grand Total',  '₹${_grandTotal.toStringAsFixed(0)}', true),
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
                  onPressed: () => context.push('/payment', extra: {'amount': _grandTotal, 'booking_id': widget.bookingId}),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  icon: const Icon(Icons.payment_rounded, color: Colors.white, size: 18),
                  label: const Text('Take Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

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
  @override Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(AppTheme.radiusMD), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
    child: Column(children: [
      GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Text(widget.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: widget.color)),
            const Spacer(),
            Text('₹${widget.total.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: widget.color)),
            const SizedBox(width: 6),
            Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: AppTheme.textHint),
          ]),
        ),
      ),
      if (_expanded) ...widget.charges.map((c) => Container(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Row(children: [
          const SizedBox(width: 12),
          Expanded(child: Text(c.label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
          Text('₹${c.amount.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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
      Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 16 : 14, color: isDiscount ? AppTheme.success : AppTheme.textPrimary)),
      const Spacer(),
      Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 18 : 14, color: isDiscount ? AppTheme.success : (bold ? AppTheme.primary : AppTheme.textPrimary))),
    ]),
  );
}
