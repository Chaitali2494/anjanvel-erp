import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/room_service.dart';

final roomDetailFullProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, roomId) async {
  final client = ref.watch(supabaseClientProvider);

  Map<String, dynamic>? room;
  try {
    // Use maybeSingle() — returns null instead of throwing when no row found
    room = await client
        .from('rooms')
        .select('*, room_types(name, base_price, max_occupancy, amenities)')
        .eq('id', roomId)
        .maybeSingle();
  } catch (_) {
    room = null;
  }

  // If room not in Supabase, show demo data so the screen never crashes
  room ??= {
    'id': roomId,
    'room_number': roomId.length > 6 ? '101' : roomId,
    'status': 'AVAILABLE',
    'floor': 1,
    'description': 'Demo room — not yet in database',
    'room_types': {
      'name': 'Deluxe Room',
      'base_price': 3500,
      'max_occupancy': 2,
      'amenities': ['AC', 'Wi-Fi', 'Hot Water', 'TV'],
    },
  };

  // Get current/active booking for this room (ignore errors — demo rooms have none)
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

class RoomDetailScreen extends ConsumerWidget {
  final String roomId;
  const RoomDetailScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomDetailFullProvider(roomId));

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
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (room) {
          final type = room['room_types'] as Map<String, dynamic>? ?? {};
          final booking = room['current_booking'] as Map<String, dynamic>?;
          final guest = booking?['guests'] as Map<String, dynamic>?;
          final status = room['status'] as String? ?? 'AVAILABLE';
          final amenities = (room['amenities'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Room header
                _RoomHeader(
                  roomNumber: room['room_number'] as String? ?? '—',
                  typeName: type['name'] as String? ?? 'Room',
                  status: status,
                  floor: room['floor'] as int? ?? 0,
                ),
                const SizedBox(height: 16),

                // Room info card
                _SectionCard(
                  title: 'Room Info',
                  icon: Icons.bed_outlined,
                  child: Column(
                    children: [
                      _InfoRow('Type', type['name'] as String? ?? '—'),
                      _InfoRow('Base Price', '₹${(type['base_price'] as num?)?.toStringAsFixed(0) ?? '—'} per person'),
                      _InfoRow('Max Occupancy', '${type['max_occupancy'] ?? '—'} guests'),
                      _InfoRow('Floor', '${room['floor'] ?? 0}'),
                      if (room['description'] != null)
                        _InfoRow('Description', room['description'] as String),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Amenities
                if (amenities.isNotEmpty) ...[
                  _SectionCard(
                    title: 'Amenities',
                    icon: Icons.star_outline,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
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

                // Current Guest / Booking
                if (booking != null && guest != null) ...[
                  _GuestBookingCard(booking: booking, guest: guest),
                  const SizedBox(height: 12),
                ] else ...[
                  _SectionCard(
                    title: 'Current Guest',
                    icon: Icons.person_outline,
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.person_off_outlined, size: 40, color: AppTheme.textHint),
                            SizedBox(height: 8),
                            Text('No guest assigned', style: TextStyle(color: AppTheme.textHint)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

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

// ── Room Header ───────────────────────────────────────────────────────────────

class _RoomHeader extends StatelessWidget {
  final String roomNumber, typeName, status;
  final int floor;
  const _RoomHeader({required this.roomNumber, required this.typeName, required this.status, required this.floor});

  Color get _statusColor {
    switch (status) {
      case 'AVAILABLE': return AppTheme.statusAvailable;
      case 'OCCUPIED': return AppTheme.statusOccupied;
      case 'RESERVED': return AppTheme.statusReserved;
      case 'CLEANING': return AppTheme.statusCleaning;
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: _statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(roomNumber, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _statusColor)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Room $roomNumber', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(typeName, style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.replaceAll('_', ' '),
                    style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Guest Booking Card ────────────────────────────────────────────────────────

class _GuestBookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Map<String, dynamic> guest;
  const _GuestBookingCard({required this.booking, required this.guest});

  @override
  Widget build(BuildContext context) {
    final guestName = guest['full_name'] as String? ?? '—';
    final phone = guest['phone'] as String? ?? '—';
    final email = guest['email'] as String?;
    final bookingNum = booking['booking_number'] as String? ?? '—';
    final status = booking['status'] as String? ?? '';
    final checkIn = booking['check_in_date'] as String? ?? '—';
    final checkOut = booking['check_out_date'] as String?;
    final adults = booking['num_adults'] as int? ?? 0;
    final children = booking['num_children'] as int? ?? 0;
    final total = (booking['total_amount'] as num?)?.toDouble() ?? 0;
    final paid = (booking['paid_amount'] as num?)?.toDouble() ?? 0;
    final balance = total - paid;

    Color statusColor = AppTheme.warning;
    if (status == 'CHECKED_IN') statusColor = AppTheme.success;
    if (status == 'CONFIRMED') statusColor = AppTheme.info;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        children: [
          // Guest info header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.15),
                  child: Text(
                    guestName.isNotEmpty ? guestName[0].toUpperCase() : 'G',
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(guestName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('+91 $phone', style: const TextStyle(color: AppTheme.textHint, fontSize: 13)),
                      if (email != null) Text(email, style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.replaceAll('_', ' '),
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Booking details
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _InfoRow('Booking #', bookingNum),
                _InfoRow('Check-in', checkIn),
                _InfoRow('Check-out', checkOut ?? 'Day Visit'),
                _InfoRow('Guests', '$adults adults · $children children'),
                const Divider(height: 16),
                _InfoRow('Total', '₹${total.toStringAsFixed(0)}'),
                _InfoRow('Paid', '₹${paid.toStringAsFixed(0)}'),
                if (balance > 0)
                  _InfoRow('Balance Due', '₹${balance.toStringAsFixed(0)}',
                      valueColor: AppTheme.error),
              ],
            ),
          ),

          // View booking button
          const Divider(height: 1),
          TextButton.icon(
            onPressed: () => context.push('/bookings/${booking['id']}'),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('View Full Booking'),
          ),
        ],
      ),
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
        spacing: 8,
        runSpacing: 8,
        children: [
          ('AVAILABLE', AppTheme.statusAvailable, Icons.check_circle_outline),
          ('CLEANING', AppTheme.statusCleaning, Icons.cleaning_services_outlined),
          ('MAINTENANCE', AppTheme.statusMaintenance, Icons.build_outlined),
          ('OCCUPIED', AppTheme.statusOccupied, Icons.person_rounded),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(s.$3, size: 14, color: isActive ? Colors.white : s.$2),
                  const SizedBox(width: 6),
                  Text(
                    s.$1.replaceAll('_', ' '),
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive ? Colors.white : s.$2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

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
          Row(children: [
            Icon(icon, size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const Divider(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _InfoRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: AppTheme.textHint, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
