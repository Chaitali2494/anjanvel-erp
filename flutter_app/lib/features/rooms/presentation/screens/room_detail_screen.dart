import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../data/room_service.dart';
import '../../../bookings/data/booking_service.dart';
import '../../../activities/data/activity_bookings_provider.dart';
import '../../../shop/data/shop_room_charges_provider.dart';
import '../../../billing/data/billing_state_provider.dart';
import '../../../food/data/food_orders_state_provider.dart';

// ── Demo SHG shop charges keyed by room number ────────────────────────────────
final _demoShopByRoom = <String, List<Map<String, dynamic>>>{
  'TS-1': [
    {'product': 'Indrayani Rice',  'qty': 2, 'price': 180.0},
    {'product': 'Kurdai Papadi',   'qty': 1, 'price': 60.0},
  ],
  'AV-1': [
    {'product': 'Fresh Mangoes',   'qty': 2, 'price': 120.0},
    {'product': 'Warli Art Frame', 'qty': 1, 'price': 350.0},
  ],
  'DC-1': [
    {'product': 'Mixed Vegetables','qty': 1, 'price': 80.0},
  ],
};

// ── Provider ───────────────────────────────────────────────────────────────────
final roomDetailFullProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, roomId) async {
  final client = ref.watch(supabaseClientProvider);

  // roomId may be a real UUID or a room_number string (e.g. "101", "Villa")
  final isUuid = roomId.contains('-') && roomId.length > 20;

  Map<String, dynamic>? room;
  try {
    room = isUuid
        ? await client
            .from('rooms')
            .select('*, room_types(name, base_price, max_occupancy, amenities)')
            .eq('id', roomId)
            .maybeSingle()
        : await client
            .from('rooms')
            .select('*, room_types(name, base_price, max_occupancy, amenities)')
            .eq('room_number', roomId)
            .maybeSingle();
  } catch (_) {
    room = null;
  }

  // If UUID, hash to a demo room number; if already a room_number, use directly
  final _demoRoomNo = isUuid
      ? kBillableRooms[roomId.hashCode.abs() % kBillableRooms.length]['room_number'] as String
      : roomId;

  room ??= {
    'id': roomId,
    'room_number': _demoRoomNo,
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
    // booking_rooms uses UUID; only query if we have a UUID
    if (isUuid) {
      final bookingRooms = await client
          .from('booking_rooms')
          .select('booking_id, bookings(id, booking_number, status, check_in_date, check_out_date, num_adults, num_children, total_amount, paid_amount, primary_guest_id, guests:primary_guest_id(full_name, phone, email))')
          .eq('room_id', roomId)
          .inFilter('bookings.status', ['CONFIRMED', 'CHECKED_IN', 'RESERVED'])
          .order('created_at', ascending: false)
          .limit(1);
      room['current_booking'] = bookingRooms.isNotEmpty ? bookingRooms.first['bookings'] : null;
    } else {
      room['current_booking'] = null; // will show demo guest from kBillableRooms below
    }
  } catch (_) {
    room['current_booking'] = null;
  }

  // Use real session booking data if a room was assigned via the booking detail screen
  if (room['current_booking'] == null) {
    final sessionBooking = sessionRoomBookings[_demoRoomNo];
    if (sessionBooking != null) {
      room['current_booking'] = sessionBooking;
    }
    // No fallback to demo data — if no session booking, show "No current guest"
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
    final allShopCharges   = ref.watch(shopRoomChargesProvider);
    final allFoodOrders    = ref.watch(foodOrdersStateProvider);

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

          // Food orders for this room — live from session state
          final foodOrders = allFoodOrders
              .where((o) =>
                  ((o['bookings'] as Map<String, dynamic>?)?['room_number'] as String? ?? '') == roomNo &&
                  o['status'] != 'CANCELLED')
              .toList();

          // Shop charges for this room
          final roomShopCharges = allShopCharges.where((c) => c.roomNumber == roomNo).toList();

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

                // Food orders — always visible with "Order Food" button
                _FoodOrdersCard(orders: foodOrders, roomNo: roomNo),
                const SizedBox(height: 12),

                // SHG Shop charges
                if (roomShopCharges.isNotEmpty || _demoShopByRoom.containsKey(roomNo)) ...[
                  _ShopChargesCard(
                    charges: roomShopCharges,
                    demoCharges: _demoShopByRoom[roomNo] ?? [],
                    roomNo: roomNo,
                  ),
                  const SizedBox(height: 12),
                ],

                // Status actions
                _StatusActionsCard(
                  roomId: roomId,
                  currentStatus: status,
                  onChanged: () => ref.invalidate(roomDetailFullProvider(roomId)),
                ),
                const SizedBox(height: 12),

                // Guest QR Code
                _GuestQrCard(roomNo: roomNo),
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
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
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

// ── Food Menu items available to order ────────────────────────────────────────
const _kFoodMenu = [
  {'name': 'Veg Breakfast Thali', 'category': 'Breakfast', 'price': 160.0, 'emoji': '🍛'},
  {'name': 'Non-Veg Breakfast',   'category': 'Breakfast', 'price': 220.0, 'emoji': '🍳'},
  {'name': 'Masala Chai',         'category': 'Beverages', 'price': 40.0,  'emoji': '☕'},
  {'name': 'Mango Lassi',         'category': 'Beverages', 'price': 90.0,  'emoji': '🥭'},
  {'name': 'Fresh Juice',         'category': 'Beverages', 'price': 80.0,  'emoji': '🍹'},
  {'name': 'Veg Thali (Lunch)',   'category': 'Lunch',     'price': 180.0, 'emoji': '🍽️'},
  {'name': 'Non-Veg Thali',       'category': 'Lunch',     'price': 280.0, 'emoji': '🍗'},
  {'name': 'Veg Starter',         'category': 'Snacks',    'price': 120.0, 'emoji': '🥗'},
  {'name': 'Veg Dinner Thali',    'category': 'Dinner',    'price': 200.0, 'emoji': '🌙'},
  {'name': 'BBQ Chicken',         'category': 'Dinner',    'price': 380.0, 'emoji': '🍖'},
  {'name': 'Papad & Pickle',      'category': 'Snacks',    'price': 50.0,  'emoji': '🫙'},
  {'name': 'Buttermilk',          'category': 'Beverages', 'price': 30.0,  'emoji': '🥛'},
];

// ── Food Orders Card — always visible, with Order Food button ─────────────────

class _FoodOrdersCard extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> orders;
  final String roomNo;
  const _FoodOrdersCard({required this.orders, required this.roomNo});

  @override
  ConsumerState<_FoodOrdersCard> createState() => _FoodOrdersCardState();
}

class _FoodOrdersCardState extends ConsumerState<_FoodOrdersCard> {

  void _showOrderSheet() {
    final Map<String, int> cart = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final cartTotal = cart.entries.fold(0.0, (s, e) {
            final item = _kFoodMenu.firstWhere((m) => m['name'] == e.key, orElse: () => {});
            return s + ((item['price'] as double? ?? 0.0) * e.value);
          });

          return Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Header
              Row(children: [
                const Icon(Icons.restaurant_menu_rounded, color: Color(0xFFE64A19), size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Order Food',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Text('Room ${widget.roomNo}',
                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
              const SizedBox(height: 4),
              const Text('Select items and quantities',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
              const Divider(height: 20),

              // Menu list
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _kFoodMenu.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = _kFoodMenu[i];
                    final name  = item['name'] as String;
                    final price = item['price'] as double;
                    final emoji = item['emoji'] as String;
                    final qty   = cart[name] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Text(emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('₹${price.toStringAsFixed(0)}',
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                        ])),
                        // Qty control
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          if (qty > 0) ...[
                            GestureDetector(
                              onTap: () => setSheet(() {
                                if (qty == 1) cart.remove(name);
                                else cart[name] = qty - 1;
                              }),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.remove, size: 16, color: AppTheme.error),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text('$qty',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ],
                          GestureDetector(
                            onTap: () => setSheet(() => cart[name] = qty + 1),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add, size: 16, color: AppTheme.success),
                            ),
                          ),
                        ]),
                      ]),
                    );
                  },
                ),
              ),

              // Cart summary + Place Order
              if (cart.isNotEmpty) ...[
                const Divider(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE64A19).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Text('${cart.values.fold(0, (s, v) => s + v)} items',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const Spacer(),
                    Text('Total: ₹${cartTotal.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFE64A19))),
                  ]),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Build order items list
                      final items = cart.entries.map((e) {
                        final item = _kFoodMenu.firstWhere((m) => m['name'] == e.key);
                        return {'name': e.key, 'qty': e.value, 'price': item['price']};
                      }).toList();

                      final now = DateTime.now();
                      final orderId = 'FO-${now.millisecondsSinceEpoch}';
                      final order = {
                        'id': orderId,
                        'order_number': 'FO-${now.millisecondsSinceEpoch.toString().substring(7)}',
                        'status': 'PENDING',
                        'total_amount': cartTotal,
                        'meal_type': 'ROOM_ORDER',
                        'ordered_at': now.toIso8601String(),
                        'guests': {'full_name': 'Staff Order'},
                        'bookings': {'booking_number': '', 'room_number': widget.roomNo},
                        'items': items,
                        'source': 'STAFF',
                      };
                      ref.read(foodOrdersStateProvider.notifier).addOrder(order);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Order placed for Room ${widget.roomNo}'),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: const Text('Place Order', style: TextStyle(color: Colors.white, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE64A19),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
              ],
            ]),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = widget.orders;

    // Flatten all order items into table rows
    final List<Map<String, dynamic>> tableRows = [];
    for (final order in orders) {
      final items = order['items'] as List<dynamic>? ?? [];
      final orderedAt = order['ordered_at'] as String?;
      String timeStr = '';
      if (orderedAt != null) {
        final dt = DateTime.tryParse(orderedAt);
        if (dt != null) timeStr = DateFormat('hh:mm a').format(dt);
      }
      if (items.isNotEmpty) {
        for (final item in items) {
          tableRows.add({
            'name':   item['name']  as String? ?? 'Item',
            'qty':    (item['qty']  as num?)?.toInt() ?? 1,
            'price':  (item['price'] as num?)?.toDouble() ?? 0.0,
            'time':   timeStr,
            'status': order['status'] as String? ?? 'PENDING',
          });
        }
      }
    }

    final total = tableRows.fold(0.0, (s, r) => s + (r['price'] as double) * (r['qty'] as int));

    return _SectionCard(
      title: 'Food & Beverage',
      icon: Icons.restaurant_menu_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Order Food button — always visible
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showOrderSheet,
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 18, color: Color(0xFFE64A19)),
            label: const Text('Order Food',
                style: TextStyle(color: Color(0xFFE64A19), fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE64A19)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),

        if (tableRows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text('No orders yet — tap Order Food to place one',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
            ),
          )
        else ...[
          const SizedBox(height: 10),
          // Table header
          Container(
            color: const Color(0xFFE64A19).withOpacity(0.07),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: const Row(children: [
              SizedBox(width: 22, child: Text('#',    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppTheme.textPrimary))),
              Expanded(flex: 3, child: Text('Item',  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppTheme.textPrimary))),
              SizedBox(width: 52, child: Text('Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppTheme.textPrimary))),
              SizedBox(width: 24, child: Text('Qty',  textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppTheme.textPrimary))),
              SizedBox(width: 52, child: Text('Amt',  textAlign: TextAlign.right,  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppTheme.textPrimary))),
            ]),
          ),
          ...tableRows.asMap().entries.map((entry) {
            final i    = entry.key;
            final row  = entry.value;
            final qty    = row['qty']   as int;
            final price  = row['price'] as double;
            final status = row['status'] as String;
            final isPending = status == 'PENDING';
            final statusColors = {
              'PENDING':   AppTheme.warning,
              'PREPARING': const Color(0xFF1565C0),
              'SERVED':    AppTheme.success,
              'DELIVERED': AppTheme.success,
              'CANCELLED': AppTheme.error,
            };
            final sc = statusColors[status] ?? AppTheme.textPrimary;
            return Container(
              color: i.isEven ? Colors.transparent : const Color(0xFFE64A19).withOpacity(0.03),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(children: [
                SizedBox(width: 22, child: Text('${i + 1}', style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary))),
                Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(row['name'] as String, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: sc.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status.replaceAll('_', ' ').toLowerCase().split(' ')
                          .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w).join(' '),
                      style: TextStyle(fontSize: 9, color: sc, fontWeight: FontWeight.bold),
                    ),
                  ),
                ])),
                SizedBox(width: 52, child: Text(row['time'] as String, style: const TextStyle(fontSize: 10, color: AppTheme.textPrimary))),
                SizedBox(width: 24, child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary))),
                SizedBox(width: 52, child: Text('₹${(price * qty).toStringAsFixed(0)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
              ]),
            );
          }),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE64A19).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Text('Food & Bev Total',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
              const Spacer(),
              Text('₹${total.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFE64A19))),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ── Guest QR Card ─────────────────────────────────────────────────────────────

class _GuestQrCard extends StatelessWidget {
  final String roomNo;
  const _GuestQrCard({required this.roomNo});

  // The URL a guest will open when scanning — matches the Flutter route
  String get _portalUrl => 'https://chaitali2494.github.io/anjanvel-erp/#/guest/room/$roomNo';
  String get _portalPath => '/guest/room/$roomNo';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.qr_code_2_rounded, color: Color(0xFF2E7D32), size: 20),
          const SizedBox(width: 8),
          const Text('Guest Self-Service QR',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0D0D0D))),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Room Portal', style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 4),
        const Text('Print and place in room. Guest scans to order food, request housekeeping, book activities or report issues.',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 14),
        Row(children: [
          // QR Code
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(8),
            child: QrImageView(
              data: _portalUrl,
              version: QrVersions.auto,
              size: 120,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1B5E20)),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF2E7D32)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _QrInfoRow(Icons.restaurant_outlined,      'Order Food'),
            _QrInfoRow(Icons.cleaning_services_outlined,'Request Housekeeping'),
            _QrInfoRow(Icons.build_outlined,           'Report Maintenance'),
            _QrInfoRow(Icons.hiking_outlined,          'Book Activities'),
            _QrInfoRow(Icons.do_not_disturb_rounded,   'Do Not Disturb'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
              child: Text(_portalPath, style: const TextStyle(fontSize: 10, color: Colors.black54, fontFamily: 'monospace')),
            ),
          ])),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showFullQr(context),
            icon: const Icon(Icons.open_in_full_rounded, size: 16),
            label: const Text('View Full Size QR'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2E7D32),
              side: const BorderSide(color: Color(0xFF2E7D32)),
            ),
          ),
        ),
      ]),
    );
  }

  void _showFullQr(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Room $roomNo — Guest Portal', textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D0D0D))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          QrImageView(
            data: _portalUrl,
            version: QrVersions.auto,
            size: 220,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1B5E20)),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(height: 12),
          const Text('🍽️ Food  🧹 Housekeeping  🔧 Maintenance', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
          const Text('🎯 Activities  🚫 Do Not Disturb', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Text(_portalUrl, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.black45)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _QrInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _QrInfoRow(this.icon, this.label);
  @override
  Widget build(_) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(children: [
      Icon(icon, size: 13, color: const Color(0xFF2E7D32)),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF0D0D0D))),
    ]),
  );
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
          Text('Room $roomNumber', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
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

// ── SHG Shop Charges Card ─────────────────────────────────────────────────────

class _ShopChargesCard extends StatelessWidget {
  final List<ShopRoomCharge> charges;
  final List<Map<String, dynamic>> demoCharges;
  final String roomNo;
  const _ShopChargesCard({required this.charges, required this.demoCharges, required this.roomNo});

  @override
  Widget build(BuildContext context) {
    // Live session charges take priority; fall back to demo
    final useLive = charges.isNotEmpty;
    final liveTotal = charges.fold(0.0, (s, c) => s + c.total);
    final demoTotal = demoCharges.fold(0.0, (s, c) => s + ((c['price'] as double) * (c['qty'] as int)));
    final total = useLive ? liveTotal : demoTotal;

    return _SectionCard(
      title: '🏪 SHG Shop Charges',
      icon: Icons.storefront_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (useLive)
            ...charges.map((c) => _ShopRow('${c.product} × ${c.qty}', c.total))
          else
            ...demoCharges.map((c) => _ShopRow(
              '${c['product']} × ${c['qty']}',
              (c['price'] as double) * (c['qty'] as int),
            )),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Shop Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
              Text('₹${total.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF558B2F))),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShopRow extends StatelessWidget {
  final String label;
  final double amount;
  const _ShopRow(this.label, this.amount);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary))),
      Text('₹${amount.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
    ]),
  );
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
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
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
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: valueColor ?? AppTheme.textPrimary))),
    ]),
  );
}
