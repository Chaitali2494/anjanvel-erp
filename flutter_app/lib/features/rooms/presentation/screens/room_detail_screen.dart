import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/room_service.dart';
import '../../../activities/data/activity_bookings_provider.dart';

// ── Demo food orders keyed by room number ──────────────────────────────────────
final _demoFoodByRoom = <String, List<Map<String, dynamic>>>{
  '101': [
    {'item': 'Masala Chai × 2',       'amount': 80,  'time': '07:30 AM', 'status': 'DELIVERED'},
    {'item': 'Veg Breakfast Thali × 2','amount': 320, 'time': '08:00 AM', 'status': 'DELIVERED'},
    {'item': 'Mango Lassi × 1',        'amount': 80,  'time': '12:30 PM', 'status': 'DELIVERED'},
  ],
  '102': [
    {'item': 'Filter Coffee × 2',      'amount': 100, 'time': '06:45 AM', 'status': 'DELIVERED'},
    {'item': 'Paneer Butter Masala',   'amount': 280, 'time': '01:00 PM', 'status': 'DELIVERED'},
  ],
  '205': [
    {'item': 'Welcome Drink × 4',      'amount': 200, 'time': '03:00 PM', 'status': 'DELIVERED'},
    {'item': 'Non-Veg Dinner Thali × 2','amount': 580,'time': '07:30 PM', 'status': 'DELIVERED'},
    {'item': 'Masala Chai × 2',        'amount': 80,  'time': '06:00 AM', 'status': 'PENDING'},
  ],
  '301': [
    {'item': 'Veg Thali × 2',          'amount': 360, 'time': '12:30 PM', 'status': 'DELIVERED'},
  ],
};

// ── Provider ───────────────────────────────────────────────────────────────────
final roomDetailFullProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, roomId) async {
  final client = ref.watch(supabaseClientProvider);

  Map<String, dynamic>? room;
  try {
    room = await client
        .from('rooms')
        .select('*, room_types(name, base_price, max_occupancy, amenities)')
        .eq('id', roomId)
        .maybeSingle();
  } catch (_) {
    room = null;
  }

  room ??= {
    'id': roomId,
    'room_number': roomId.length > 6 ? '101' : roomId,
    'status': 'AVAILABLE',
    'floor': 1,
    'description': 'Demo room',
    'room_types': {
      'name': 'Deluxe Room',
      'base_price': 3500,
      'max_occupancy': 2,
      'amenities': ['AC', 'Wi-Fi', 'Hot Water', 'TV'],
    },
  };

  try {
    final bookingRooms = await client
        .from('booking_rooms')
        .select('booking_id, bookings(id, booking_number, status, check_in_date, check_out_date, num_adults, num_children, total_amount, paid_amount, primary_guest_id, guests:primary_guest_id(full_name, phone, email))')
        .eq('room_id', roomId)
        .inFilter('bookings.status', ['CONFIRMED', 'CHECKED_IN', 'RESERVED'])
        .order('created_at', ascending: false)
        .limit(1);
    room['current_booking'] = bookingRooms.isNotEmpty ? bookingRooms.first['bookings'] : null;
  } catch (_) {
    room['current_booking'] = null;
  }

  return room;
});

// ── Screen ─────────────────────────────────────────────────────────────────────
class RoomDetailScreen extends ConsumerWidget {
  final String roomId;
  const RoomDetailScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync        = ref.watch(roomDetailFullProvider(roomId));
    final bookingsAsync    = ref.watch(activityBookingsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(
        title: 'Room Detail',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(roomDetailFullProvider(roomId)),
          ),
        ],
      ),
      body: roomAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (room) {
          final type      = room['room_types'] as Map<String, dynamic>? ?? {};
          final booking   = room['current_booking'] as Map<String, dynamic>?;
          final guest     = booking?['guests'] as Map<String, dynamic>?;
          final status    = room['status'] as String? ?? 'AVAILABLE';
          final roomNo    = room['room_number'] as String? ?? '—';
          final amenities = (type['amenities'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

          // Activities for this room
          final allBookings = bookingsAsync.valueOrNull ?? [];
          final roomActivities = allBookings
              .where((b) => b['room_number'] == roomNo && b['status'] != 'CANCELLED')
              .toList();

          // Food orders for this room
          final foodOrders = _demoFoodByRoom[roomNo] ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Room header
                _RoomHeader(
                  roomNumber: roomNo,
                  typeName: type['name'] as String? ?? 'Room',
                  status: status,
                  floor: room['floor'] as int? ?? 0,
                ),
                const SizedBox(height: 16),

                // Current guest card (always show)
                _GuestSummaryCard(booking: booking, guest: guest, roomNo: roomNo),
                const SizedBox(height: 12),

                // Room info
                _SectionCard(
                  title: 'Room Info',
                  icon: Icons.bed_outlined,
                  child: Column(children: [
                    _InfoRow('Type',          type['name'] as String? ?? '—'),
                    _InfoRow('Base Price',    '₹${(type['base_price'] as num?)?.toStringAsFixed(0) ?? '—'}/night'),
                    _InfoRow('Max Occupancy', '${type['max_occupancy'] ?? '—'} guests'),
                    _InfoRow('Floor',         '${room['floor'] ?? 0}'),
                    if (room['description'] != null && room['description'] != 'Demo room')
                      _InfoRow('Notes', room['description'] as String),
                  ]),
                ),
                const SizedBox(height: 12),

                // Amenities
                if (amenities.isNotEmpty) ...[
                  _SectionCard(
                    title: 'Amenities',
                    icon: Icons.star_outline,
                    child: Wrap(
                      spacing: 8, runSpacing: 8,
                      children: amenities.map((a) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                        ),
                        child: Text(a, style: const TextStyle(fontSize: 12, color: AppTheme.primary)),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Activities taken
                _ActivitiesCard(activities: roomActivities, roomNo: roomNo),
                const SizedBox(height: 12),

                // Food orders
                _FoodOrdersCard(orders: foodOrders, roomNo: roomNo),
                const SizedBox(height: 12),

                // Status actions
                _StatusActionsCard(
                  roomId: roomId,
                  currentStatus: status,
                  onChanged: () => ref.invalidate(roomDetailFullProvider(roomId)),
                ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Guest Summary Card ─────────────────────────────────────────────────────────

class _GuestSummaryCard extends StatelessWidget {
  final Map<String, dynamic>? booking;
  final Map<String, dynamic>? guest;
  final String roomNo;

  const _GuestSummaryCard({this.booking, this.guest, required this.roomNo});

  @override
  Widget build(BuildContext context) {
    if (booking == null || guest == null) {
      return _SectionCard(
        title: 'Current Guest',
        icon: Icons.person_outline,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: Column(children: [
            Icon(Icons.person_off_outlined, size: 36, color: AppTheme.textPrimary),
            SizedBox(height: 8),
            Text('No guest checked in', style: TextStyle(color: AppTheme.textPrimary)),
          ])),
        ),
      );
    }

    final guestName  = guest!['full_name'] as String? ?? '—';
    final phone      = guest!['phone'] as String? ?? '—';
    final email      = guest!['email'] as String?;
    final bookingNum = booking!['booking_number'] as String? ?? '—';
    final bStatus    = booking!['status'] as String? ?? '';
    final checkIn    = booking!['check_in_date'] as String? ?? '—';
    final checkOut   = booking!['check_out_date'] as String?;
    final adults     = booking!['num_adults'] as int? ?? 0;
    final children   = booking!['num_children'] as int? ?? 0;
    final total      = (booking!['total_amount'] as num?)?.toDouble() ?? 0;
    final paid       = (booking!['paid_amount']  as num?)?.toDouble() ?? 0;
    final balance    = total - paid;

    // Demo male/female split (in real app, stored per booking)
    final males   = (adults / 2).ceil();
    final females = adults - males;

    Color statusColor = AppTheme.warning;
    if (bStatus == 'CHECKED_IN') statusColor = AppTheme.success;
    if (bStatus == 'CONFIRMED')  statusColor = AppTheme.info;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(children: [
        // Header with guest name
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: statusColor.withOpacity(0.15),
              child: Text(
                guestName.isNotEmpty ? guestName[0].toUpperCase() : 'G',
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(guestName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              Text('📞 $phone',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
              if (email != null)
                Text('✉️ $email',
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(bStatus.replaceAll('_', ' '),
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            // Guest count — male/female breakdown
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.people_rounded, size: 18, color: AppTheme.textPrimary),
                const SizedBox(width: 8),
                const Text('Guests:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(width: 12),
                _GuestChip('👨 $males Male',    const Color(0xFF1565C0)),
                const SizedBox(width: 8),
                _GuestChip('👩 $females Female', const Color(0xFFAD1457)),
                if (children > 0) ...[
                  const SizedBox(width: 8),
                  _GuestChip('🧒 $children Child', const Color(0xFF558B2F)),
                ],
              ]),
            ),

            _InfoRow('Booking #',  bookingNum),
            _InfoRow('Check-in',   checkIn),
            _InfoRow('Check-out',  checkOut ?? 'Day Visit'),
            _InfoRow('Total Stay', '$adults adult${adults != 1 ? 's' : ''}${children > 0 ? ' · $children child' : ''}'),
            const Divider(height: 16),
            _InfoRow('Total Amount', '₹${total.toStringAsFixed(0)}'),
            _InfoRow('Paid',         '₹${paid.toStringAsFixed(0)}'),
            if (balance > 0)
              _InfoRow('Balance Due', '₹${balance.toStringAsFixed(0)}', valueColor: AppTheme.error),
          ]),
        ),

        const Divider(height: 1),
        TextButton.icon(
          onPressed: () => context.push('/bookings/${booking!['id']}'),
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('View Full Booking'),
        ),
      ]),
    );
  }
}

class _GuestChip extends StatelessWidget {
  final String label;
  final Color color;
  const _GuestChip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
  );
}

// ── Activities Card ────────────────────────────────────────────────────────────

class _ActivitiesCard extends StatelessWidget {
  final List<Map<String, dynamic>> activities;
  final String roomNo;
  const _ActivitiesCard({required this.activities, required this.roomNo});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Activities Booked',
      icon: Icons.hiking_rounded,
      child: activities.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                const Text('No activities booked yet',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/activities/register'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00838F),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  child: const Text('+ Book Activity', style: TextStyle(fontSize: 12)),
                ),
              ]),
            )
          : Column(children: [
              ...activities.map((a) {
                final name    = a['activity_name'] as String? ?? 'Activity';
                final emoji   = a['activity_emoji'] as String? ?? '🎯';
                final persons = a['persons'] as int? ?? 1;
                final total   = (a['total_amount'] as num?)?.toDouble() ?? 0.0;
                final date    = a['date'] as String? ?? '';
                final time    = a['time'] as String? ?? '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00838F).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00838F).withOpacity(0.15)),
                  ),
                  child: Row(children: [
                    Text(emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('$persons person${persons > 1 ? 's' : ''} · $date $time',
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
                    ])),
                    Text('₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00838F), fontSize: 14)),
                  ]),
                );
              }),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/activities/register'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00838F),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  ),
                  child: const Text('+ Add More', style: TextStyle(fontSize: 12)),
                ),
              ),
              // Total
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00838F).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Text('Activities Total',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const Spacer(),
                  Text(
                    '₹${activities.fold(0.0, (s, a) => s + ((a['total_amount'] as num?)?.toDouble() ?? 0.0)).toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF00838F)),
                  ),
                ]),
              ),
            ]),
    );
  }
}

// ── Food Orders Card ───────────────────────────────────────────────────────────

class _FoodOrdersCard extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final String roomNo;
  const _FoodOrdersCard({required this.orders, required this.roomNo});

  @override
  Widget build(BuildContext context) {
    final delivered = orders.where((o) => o['status'] == 'DELIVERED').toList();
    final pending   = orders.where((o) => o['status'] == 'PENDING').toList();
    final total     = orders.fold(0.0, (s, o) => s + ((o['amount'] as num?)?.toDouble() ?? 0.0));

    return _SectionCard(
      title: 'Food & Beverage Orders',
      icon: Icons.restaurant_menu_rounded,
      child: orders.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No food orders yet', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
            )
          : Column(children: [
              if (pending.isNotEmpty) ...[
                _FoodStatusHeader('Pending', AppTheme.warning),
                ...pending.map((o) => _FoodRow(o)),
                const SizedBox(height: 8),
              ],
              if (delivered.isNotEmpty) ...[
                _FoodStatusHeader('Delivered', AppTheme.success),
                ...delivered.map((o) => _FoodRow(o)),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE64A19).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Text('Food & Bev Total',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const Spacer(),
                  Text('₹${total.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFE64A19))),
                ]),
              ),
            ]),
    );
  }
}

class _FoodStatusHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _FoodStatusHeader(this.label, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    ]),
  );
}

class _FoodRow extends StatelessWidget {
  final Map<String, dynamic> order;
  const _FoodRow(this.order);
  @override
  Widget build(BuildContext context) {
    final isPending = order['status'] == 'PENDING';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isPending
            ? AppTheme.warning.withOpacity(0.05)
            : const Color(0xFFE64A19).withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPending
              ? AppTheme.warning.withOpacity(0.2)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(children: [
        Text(isPending ? '⏳' : '✅', style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(order['item'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text(order['time'] as String, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
        ])),
        Text('₹${(order['amount'] as num).toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Room Header ───────────────────────────────────────────────────────────────

class _RoomHeader extends StatelessWidget {
  final String roomNumber, typeName, status;
  final int floor;
  const _RoomHeader({required this.roomNumber, required this.typeName, required this.status, required this.floor});

  Color get _statusColor {
    switch (status) {
      case 'AVAILABLE':   return AppTheme.statusAvailable;
      case 'OCCUPIED':    return AppTheme.statusOccupied;
      case 'RESERVED':    return AppTheme.statusReserved;
      case 'CLEANING':    return AppTheme.statusCleaning;
      case 'MAINTENANCE': return AppTheme.statusMaintenance;
      default: return AppTheme.textHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_statusColor.withOpacity(0.15), _statusColor.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: _statusColor.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(color: _statusColor.withOpacity(0.15), shape: BoxShape.circle),
          child: Center(
            child: Text(roomNumber,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _statusColor)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Room $roomNumber', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(typeName, style: const TextStyle(color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(status.replaceAll('_', ' '),
                style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ])),
      ]),
    );
  }
}

// ── Status Actions ────────────────────────────────────────────────────────────

class _StatusActionsCard extends ConsumerWidget {
  final String roomId, currentStatus;
  final VoidCallback onChanged;
  const _StatusActionsCard({required this.roomId, required this.currentStatus, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(roomServiceProvider);
    return _SectionCard(
      title: 'Update Status',
      icon: Icons.swap_horiz_rounded,
      child: Wrap(
        spacing: 8, runSpacing: 8,
        children: [
          ('AVAILABLE',   AppTheme.statusAvailable,   Icons.check_circle_outline),
          ('CLEANING',    AppTheme.statusCleaning,    Icons.cleaning_services_outlined),
          ('MAINTENANCE', AppTheme.statusMaintenance, Icons.build_outlined),
          ('OCCUPIED',    AppTheme.statusOccupied,    Icons.person_rounded),
        ].map((s) {
          final isActive = currentStatus == s.$1;
          return GestureDetector(
            onTap: isActive ? null : () async {
              await service.updateRoomStatus(roomId, s.$1);
              onChanged();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? s.$2 : s.$2.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: s.$2.withOpacity(isActive ? 1 : 0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(s.$3, size: 14, color: isActive ? Colors.white : s.$2),
                const SizedBox(width: 6),
                Text(s.$1.replaceAll('_', ' '),
                    style: TextStyle(fontSize: 12, color: isActive ? Colors.white : s.$2, fontWeight: FontWeight.w600)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ]),
      const Divider(height: 16),
      child,
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _InfoRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 110,
          child: Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
      Expanded(child: Text(value,
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: valueColor))),
    ]),
  );
}
