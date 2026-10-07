import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/booking_service.dart';
import '../../models/booking_model.dart';

final _filterProvider = StateProvider<BookingFilter>((ref) => const BookingFilter());
final _searchProvider = StateProvider<String>((ref) => '');

class BookingListScreen extends ConsumerStatefulWidget {
  const BookingListScreen({super.key});

  @override
  ConsumerState<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends ConsumerState<BookingListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  final _tabs = ['All', 'Inquiry', 'Confirmed', 'Checked In', 'Checked Out', 'Cancelled'];
  final _tabStatuses = [null, 'INQUIRY', 'CONFIRMED', 'CHECKED_IN', 'CHECKED_OUT', 'CANCELLED'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final current = ref.read(_filterProvider);
        ref.read(_filterProvider.notifier).state = BookingFilter(
          status: _tabStatuses[_tabController.index],
          search: current.search,
          from: current.from,
          to: current.to,
        );
      }
    });
  }

  // Invalidate provider when screen becomes active so newly-created bookings appear
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final filter = ref.read(_filterProvider);
    ref.invalidate(bookingsProvider(filter));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(_filterProvider);
    final bookingsAsync = ref.watch(bookingsProvider(filter));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Bookings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            tooltip: 'Home',
            onPressed: () => context.go('/dashboard/owner'),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => context.push(AppRoutes.bookingCalendar),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterSheet,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48 + 60),
          child: Column(
            children: [
              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, number, phone...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(_filterProvider.notifier).update((f) => f.copyWith(search: ''));
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onChanged: (v) => ref.read(_filterProvider.notifier).update((f) => f.copyWith(search: v)),
                ),
              ),
              // Tabs
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textHint,
                indicatorColor: AppTheme.primary,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
              ),
            ],
          ),
        ),
      ),
      body: bookingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (bookings) {
          if (bookings.isEmpty) {
            return EmptyState(
              title: 'No Bookings Found',
              subtitle: 'Create your first booking by tapping the button below',
              icon: Icons.calendar_month_outlined,
              buttonLabel: 'New Booking',
              onButtonTap: () => context.push(AppRoutes.createBooking),
            );
          }
          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async {
              ref.invalidate(bookingsProvider(filter));
              await ref.read(bookingsProvider(filter).future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (_, i) => BookingCard(booking: bookings[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.createBooking),
        icon: const Icon(Icons.add),
        label: const Text('New Booking'),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
      ),
      builder: (ctx) => _FilterSheet(),
    );
  }
}

// ── Booking Card ────────────────────────────────────────────────────────────────

class BookingCard extends StatelessWidget {
  final BookingModel booking;
  const BookingCard({super.key, required this.booking});

  Color get _statusColor {
    switch (booking.status) {
      case 'CONFIRMED': return AppTheme.info;
      case 'CHECKED_IN': return AppTheme.success;
      case 'CHECKED_OUT': return AppTheme.secondary;
      case 'CANCELLED': return AppTheme.error;
      case 'NO_SHOW': return AppTheme.textHint;
      default: return AppTheme.textHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/bookings/${booking.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
              ),
              child: Row(
                children: [
                  Text(
                    booking.bookingNumber,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(color: _statusColor),
                  ),
                  const Spacer(),
                  StatusBadge(label: booking.status, color: _statusColor),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 18, color: AppTheme.textPrimary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          booking.guestName ?? 'Guest',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${booking.totalGuests ?? booking.numAdults} guests',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.textPrimary),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(booking.checkInDate),
                        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                      ),
                      if (booking.checkOutDate != null) ...[
                        const Text(' → ', style: TextStyle(color: AppTheme.textPrimary)),
                        Text(
                          _formatDate(booking.checkOutDate!),
                          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                        ),
                      ],
                    ],
                  ),
                  if (booking.packageName != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.spa_outlined, size: 16, color: AppTheme.textPrimary),
                        const SizedBox(width: 8),
                        Text(booking.packageName!,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total',
                              style: TextStyle(fontSize: 11, color: AppTheme.textPrimary)),
                          RupeeAmount(amount: booking.totalAmount,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Balance',
                              style: TextStyle(fontSize: 11, color: AppTheme.textPrimary)),
                          RupeeAmount(
                            amount: booking.balanceAmount ?? (booking.totalAmount - booking.paidAmount),
                            style: TextStyle(
                              fontSize: 13,
                              color: (booking.balanceAmount ?? 0) > 0 ? AppTheme.error : AppTheme.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      // Payment Status
                      StatusBadge(
                        label: booking.paymentStatus,
                        color: booking.paymentStatus == 'PAID' ? AppTheme.success
                            : booking.paymentStatus == 'PARTIAL' ? AppTheme.warning
                            : AppTheme.error,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    return DateFormat('d MMM yyyy').format(date);
  }
}

// ── Filter Sheet ────────────────────────────────────────────────────────────────

class _FilterSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  DateTime? _from;
  DateTime? _to;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filter Bookings', style: Theme.of(context).textTheme.titleLarge),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Date Range', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setState(() => _from = date);
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_from != null ? DateFormat('d MMM').format(_from!) : 'From'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setState(() => _to = date);
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_to != null ? DateFormat('d MMM').format(_to!) : 'To'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              ref.read(_filterProvider.notifier).update((f) => BookingFilter(from: _from, to: _to));
              Navigator.pop(context);
            },
            child: const Text('Apply Filter'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              ref.read(_filterProvider.notifier).state = const BookingFilter();
              Navigator.pop(context);
            },
            child: const Text('Clear Filter'),
          ),
        ],
      ),
    );
  }
}
