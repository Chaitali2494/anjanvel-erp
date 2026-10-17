import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class PaymentScreen extends StatefulWidget {
  final double amount;
  final String? bookingId;
  const PaymentScreen({super.key, required this.amount, this.bookingId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _method = 'UPI';
  bool _isSaving = false;

  static const _methods = [
    {'id': 'UPI',           'label': 'UPI / QR',        'icon': Icons.qr_code_rounded,        'color': Color(0xFF6A1B9A)},
    {'id': 'CASH',          'label': 'Cash',            'icon': Icons.payments_rounded,        'color': Color(0xFF2E7D32)},
    {'id': 'CARD',          'label': 'Card',            'icon': Icons.credit_card_rounded,     'color': Color(0xFF1565C0)},
    {'id': 'BANK_TRANSFER', 'label': 'Bank Transfer',   'icon': Icons.account_balance_rounded, 'color': Color(0xFF00796B)},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const AnjAppBar(title: 'Take Payment'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF43A047)]),
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              ),
              child: Column(children: [
                const Text('Amount Due', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text('₹${widget.amount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 42)),
                if (widget.bookingId != null)
                  Text('Booking #${widget.bookingId}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 24),

            // Payment method
            const Text('Select Payment Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _methods.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.5,
              ),
              itemBuilder: (_, i) {
                final m = _methods[i];
                final selected = _method == m['id'];
                final color = m['color'] as Color;
                return GestureDetector(
                  onTap: () => setState(() => _method = m['id'] as String),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? color : color.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(color: selected ? color : color.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      Icon(m['icon'] as IconData, color: selected ? Colors.white : color, size: 20),
                      const SizedBox(width: 8),
                      Text(m['label'] as String, style: TextStyle(color: selected ? Colors.white : color, fontWeight: FontWeight.w600, fontSize: 13)),
                    ]),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Method-specific UI
            if (_method == 'UPI') _UpiSection(amount: widget.amount),
            if (_method == 'CASH') _CashSection(amount: widget.amount),
            if (_method == 'CARD') _CardSection(),
            if (_method == 'BANK_TRANSFER') _BankSection(),

            const SizedBox(height: 24),

            // Confirm button
            ElevatedButton(
              onPressed: _isSaving ? null : _confirmPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                minimumSize: const Size(double.infinity, 54),
              ),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Confirm Payment · ₹${widget.amount.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmPayment() async {
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isSaving = false);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Payment Confirmed!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text('₹${widget.amount.toStringAsFixed(0)} received via $_method', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13), textAlign: TextAlign.center),
          ]),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () { Navigator.pop(context); context.go('/bookings'); },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
  }
}

class _UpiSection extends StatelessWidget {
  final double amount;
  const _UpiSection({required this.amount});
  @override Widget build(_) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(AppTheme.radiusMD), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
    child: Column(children: [
      Container(
        width: 120, height: 120,
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.qr_code_rounded, size: 80, color: Colors.black87),
      ),
      const SizedBox(height: 12),
      const Text('Scan QR to Pay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 4),
      const Text('UPI ID: anjanvel@upi', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
    ]),
  );
}

class _CashSection extends StatefulWidget {
  final double amount; const _CashSection({required this.amount});
  @override State<_CashSection> createState() => _CashSectionState();
}
class _CashSectionState extends State<_CashSection> {
  final _ctrl = TextEditingController();
  double get _received => double.tryParse(_ctrl.text) ?? 0;
  double get _change   => (_received - widget.amount).clamp(0, double.infinity);

  @override Widget build(_) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(AppTheme.radiusMD), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Cash Received', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(height: 8),
      TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          prefixText: '₹ ',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
          hintText: '0',
        ),
      ),
      if (_received >= widget.amount) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.change_circle_outlined, color: AppTheme.success, size: 20),
            const SizedBox(width: 8),
            Text('Change: ₹${_change.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
        ),
      ],
    ]),
  );
}

class _CardSection extends StatelessWidget {
  @override Widget build(_) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(AppTheme.radiusMD), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
    child: const Column(children: [
      Icon(Icons.credit_card_rounded, size: 48, color: Color(0xFF1565C0)),
      SizedBox(height: 8),
      Text('Swipe/Tap Card on POS Machine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      SizedBox(height: 4),
      Text('Connect POS terminal and confirm', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
    ]),
  );
}

class _BankSection extends StatelessWidget {
  @override Widget build(_) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _BR('Account Name', 'Anjanvel Agro Tourism Pvt Ltd'),
      _BR('Account No.',  '1234 5678 9012'),
      _BR('IFSC',         'SBIN0001234'),
      _BR('Bank',         'State Bank of India'),
    ]),
  );
}
class _BR extends StatelessWidget {
  final String l, v; const _BR(this.l, this.v);
  @override Widget build(_) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      SizedBox(width: 110, child: Text('$l:', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
      Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    ]),
  );
}
