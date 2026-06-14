import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/booking_service.dart';

class BookingDetailScreen extends ConsumerWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(bookingDetailProvider(bookingId));
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'Booking Detail'),
      body: bookingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (b) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoCard(title: 'Booking Number', value: b.bookingNumber, icon: Icons.confirmation_number_outlined),
              const SizedBox(height: 10),
              InfoCard(title: 'Status', value: b.status, icon: Icons.info_outline),
              const SizedBox(height: 10),
              InfoCard(title: 'Total Amount', value: '₹${b.totalAmount}', icon: Icons.currency_rupee_rounded),
              const SizedBox(height: 10),
              InfoCard(title: 'Balance', value: '₹${b.balanceAmount ?? 0}', icon: Icons.account_balance_wallet_outlined),
            ],
          ),
        ),
      ),
    );
  }
}
