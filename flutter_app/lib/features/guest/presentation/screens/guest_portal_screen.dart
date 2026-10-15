import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../food/data/food_orders_state_provider.dart';
import '../../../activities/data/activity_bookings_provider.dart';
import '../../data/guest_requests_provider.dart';

// ── Demo menu items for guest ordering ───────────────────────────────────────

const _guestMenu = [
  // Breakfast
  {'name': 'Breakfast Plate',    'price': 250.0, 'category': 'Breakfast', 'emoji': '🍳', 'veg': true},
  {'name': 'Poha',               'price': 120.0, 'category': 'Breakfast', 'emoji': '🥣', 'veg': true},
  {'name': 'Upma',               'price': 100.0, 'category': 'Breakfast', 'emoji': '🫕', 'veg': true},
  // Main Course
  {'name': 'Veg Thali',          'price': 350.0, 'category': 'Main Course', 'emoji': '🍛', 'veg': true},
  {'name': 'Non-Veg Thali',      'price': 450.0, 'category': 'Main Course', 'emoji': '🍗', 'veg': false},
  {'name': 'Dal Rice',           'price': 200.0, 'category': 'Main Course', 'emoji': '🍚', 'veg': true},
  // Snacks
  {'name': 'Veg Starter',        'price': 220.0, 'category': 'Snacks', 'emoji': '🥗', 'veg': true},
  {'name': 'BBQ Chicken',        'price': 380.0, 'category': 'Snacks', 'emoji': '🍖', 'veg': false},
  {'name': 'Bhajiya',            'price': 120.0, 'category': 'Snacks', 'emoji': '🥜', 'veg': true},
  // Beverages
  {'name': 'Masala Chai',        'price': 40.0,  'category': 'Beverages', 'emoji': '☕', 'veg': true},
  {'name': 'Fresh Juice',        'price': 80.0,  'category': 'Beverages', 'emoji': '🧃', 'veg': true},
  {'name': 'Coconut Water',      'price': 60.0,  'category': 'Beverages', 'emoji': '🥥', 'veg': true},
  {'name': 'Mango Lassi',        'price': 90.0,  'category': 'Beverages', 'emoji': '🥛', 'veg': true},
];

// ── Activities for guest booking ──────────────────────────────────────────────

const _guestActivities = [
  {'name': 'Farm Tour',         'emoji': '🌾', 'duration': '2 hrs', 'price': 500.0,  'desc': 'Explore our organic farm with a guide'},
  {'name': 'Nature Walk',       'emoji': '🥾', 'duration': '1.5 hrs','price': 300.0, 'desc': 'Guided walk through the agro-forest trail'},
  {'name': 'Bullock Cart Ride', 'emoji': '🐄', 'duration': '45 min', 'price': 200.0, 'desc': 'Traditional bullock cart experience'},
  {'name': 'Bird Watching',     'emoji': '🦅', 'duration': '2 hrs', 'price': 400.0,  'desc': 'Spot local birds with binoculars & expert guide'},
  {'name': 'Cooking Class',     'emoji': '👩‍🍳','duration': '3 hrs',  'price': 800.0, 'desc': 'Learn authentic Konkan cuisine'},
  {'name': 'Cycling Tour',      'emoji': '🚲', 'duration': '2 hrs', 'price': 350.0,  'desc': 'Explore the village on cycles'},
  {'name': 'Yoga & Meditation', 'emoji': '🧘', 'duration': '1 hr',  'price': 250.0,  'desc': 'Morning session at the open pavilion'},
  {'name': 'Fishing',           'emoji': '🎣', 'duration': '2 hrs', 'price': 450.0,  'desc': 'Traditional fishing at the pond'},
];

// ── Housekeeping options ──────────────────────────────────────────────────────

const _hkOptions = [
  {'title': 'Room Cleaning',    'sub': 'CLEAN_ROOM',    'emoji': '🧹', 'desc': 'Full room clean & tidy'},
  {'title': 'Fresh Towels',     'sub': 'TOWELS',         'emoji': '🛁', 'desc': 'Replace bath & hand towels'},
  {'title': 'Change Bed Linen', 'sub': 'LINEN',          'emoji': '🛏️', 'desc': 'Fresh bedsheets & pillowcases'},
  {'title': 'Extra Pillows',    'sub': 'PILLOWS',        'emoji': '😴', 'desc': 'Bring additional pillows'},
  {'title': 'Toiletries',       'sub': 'TOILETRIES',     'emoji': '🧴', 'desc': 'Soap, shampoo, toothbrush, etc.'},
  {'title': 'Dustbin Empty',    'sub': 'DUSTBIN',        'emoji': '🗑️', 'desc': 'Empty waste bins'},
];

// ── Maintenance options ───────────────────────────────────────────────────────

const _maintOptions = [
  {'title': 'AC / Fan Issue',   'sub': 'AC_ISSUE',       'emoji': '❄️', 'desc': 'AC not cooling or fan not working'},
  {'title': 'Water Issue',      'sub': 'WATER_ISSUE',    'emoji': '🚿', 'desc': 'Hot water, low pressure, tap leak'},
  {'title': 'Electrical',       'sub': 'ELECTRICAL',     'emoji': '💡', 'desc': 'Light fused, switch not working'},
  {'title': 'TV / WiFi',        'sub': 'TECH_ISSUE',     'emoji': '📺', 'desc': 'TV not working or WiFi issues'},
  {'title': 'Furniture',        'sub': 'FURNITURE',      'emoji': '🪑', 'desc': 'Broken chair, table, door, etc.'},
  {'title': 'Other Issue',      'sub': 'OTHER',          'emoji': '🔧', 'desc': 'Something else needs attention'},
];

// ─────────────────────────────────────────────────────────────────────────────
// Guest Portal Screen
// ─────────────────────────────────────────────────────────────────────────────

class GuestPortalScreen extends ConsumerWidget {
  final String roomNumber;
  const GuestPortalScreen({super.key, required this.roomNumber});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDnd = ref.watch(dndProvider)[roomNumber] ?? false;
    final requests = ref.watch(guestRequestsProvider);
    final pendingCount = requests.where((r) => r['room_number'] == roomNumber && r['status'] == 'PENDING').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      body: CustomScrollView(
        slivers: [
          // ── Resort header ───────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFF2E7D32),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🌿', style: TextStyle(fontSize: 36)),
                      const SizedBox(height: 6),
                      const Text(
                        'ANJANVEL AGRO TOURISM',
                        style: TextStyle(color: Colors.white, fontSize: 13, letterSpacing: 2, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Room $roomNumber',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Pending requests badge ────────────────────────────
                  if (pendingCount > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.pending_actions_rounded, color: AppTheme.warning, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '$pendingCount request${pendingCount > 1 ? 's' : ''} in progress',
                          style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ]),
                    ),

                  // ── DND banner ────────────────────────────────────────
                  _DndBanner(roomNumber: roomNumber, isDnd: isDnd),
                  const SizedBox(height: 20),

                  // ── "How can we help?" ────────────────────────────────
                  const Text('How can we help you?',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                  const SizedBox(height: 4),
                  const Text('Choose a service below',
                      style: TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 16),

                  // ── Service grid ──────────────────────────────────────
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.05,
                    children: [
                      _ServiceTile(
                        emoji: '🍽️',
                        title: 'Order Food',
                        subtitle: 'Food & beverages',
                        gradient: const [Color(0xFFE64A19), Color(0xFFFF7043)],
                        onTap: () => _showFoodOrder(context, ref),
                      ),
                      _ServiceTile(
                        emoji: '🧹',
                        title: 'Housekeeping',
                        subtitle: 'Room & amenities',
                        gradient: const [Color(0xFF0277BD), Color(0xFF29B6F6)],
                        onTap: () => _showHousekeeping(context, ref),
                      ),
                      _ServiceTile(
                        emoji: '🔧',
                        title: 'Maintenance',
                        subtitle: 'Report an issue',
                        gradient: const [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
                        onTap: () => _showMaintenance(context, ref),
                      ),
                      _ServiceTile(
                        emoji: '🎯',
                        title: 'Activities',
                        subtitle: 'Book experiences',
                        gradient: const [Color(0xFF00838F), Color(0xFF26C6DA)],
                        onTap: () => _showActivities(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── DND full card ──────────────────────────────────────
                  _DndCard(roomNumber: roomNumber, isDnd: isDnd),
                  const SizedBox(height: 24),

                  // ── Quick info ────────────────────────────────────────
                  _QuickInfoRow(),
                  const SizedBox(height: 20),

                  // ── My Requests ───────────────────────────────────────
                  _MyRequests(roomNumber: roomNumber),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Food Order Sheet ────────────────────────────────────────────────────────

  void _showFoodOrder(BuildContext context, WidgetRef ref) {
    final Map<String, int> cart = {};
    String mealType = 'ANYTIME';
    int counter = DateTime.now().millisecondsSinceEpoch;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setM) {
          final total = cart.entries.fold<double>(0, (s, e) {
            final item = _guestMenu.firstWhere((m) => m['name'] == e.key, orElse: () => {'price': 0.0});
            return s + ((item['price'] as num?)?.toDouble() ?? 0) * e.value;
          });
          final categories = _guestMenu.map((m) => m['category'] as String).toSet().toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder: (_, scroll) => Column(children: [
              // Handle + header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 14),
                  Row(children: [
                    const Text('🍽️', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    const Text('Order Food', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D0D0D))),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ]),
                  const Divider(),
                ]),
              ),
              // Menu
              Expanded(
                child: ListView(controller: scroll, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                  ...categories.map((cat) {
                    final catItems = _guestMenu.where((m) => m['category'] == cat).toList();
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(cat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFE64A19))),
                      ),
                      ...catItems.map((item) {
                        final name  = item['name'] as String;
                        final price = (item['price'] as num).toDouble();
                        final emoji = item['emoji'] as String;
                        final isVeg = item['veg'] as bool;
                        final qty   = cart[name] ?? 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: qty > 0 ? const Color(0xFFE64A19).withOpacity(0.06) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: qty > 0 ? const Color(0xFFE64A19).withOpacity(0.3) : Colors.grey.shade200),
                          ),
                          child: Row(children: [
                            Text(emoji, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Container(
                                  width: 10, height: 10,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: isVeg ? Colors.green : Colors.red, width: 1.2),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Center(child: Container(
                                    width: 4, height: 4,
                                    decoration: BoxDecoration(color: isVeg ? Colors.green : Colors.red, shape: BoxShape.circle),
                                  )),
                                ),
                                const SizedBox(width: 5),
                                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0D0D0D))),
                              ]),
                              Text('₹${price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Color(0xFF0D0D0D))),
                            ])),
                            if (qty == 0)
                              GestureDetector(
                                onTap: () => setM(() => cart[name] = 1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(color: const Color(0xFFE64A19), borderRadius: BorderRadius.circular(8)),
                                  child: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              )
                            else
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                GestureDetector(
                                  onTap: () => setM(() { if (qty > 1) cart[name] = qty - 1; else cart.remove(name); }),
                                  child: const Icon(Icons.remove_circle_outline, color: Color(0xFFE64A19), size: 24),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D0D0D))),
                                ),
                                GestureDetector(
                                  onTap: () => setM(() => cart[name] = qty + 1),
                                  child: const Icon(Icons.add_circle_outline, color: Color(0xFFE64A19), size: 24),
                                ),
                              ]),
                          ]),
                        );
                      }),
                    ]);
                  }),
                  const SizedBox(height: 80),
                ]),
              ),
              // Bottom bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -2))],
                ),
                child: ElevatedButton(
                  onPressed: cart.isEmpty ? null : () {
                    final newOrder = {
                      'id': '${++counter}',
                      'order_number': 'FO-G${(DateTime.now().millisecondsSinceEpoch % 9000 + 1000)}',
                      'status': 'PENDING',
                      'total_amount': total,
                      'meal_type': mealType,
                      'ordered_at': DateTime.now().toIso8601String(),
                      'guests': {'full_name': 'Room $roomNumber (Guest)'},
                      'bookings': {'booking_number': 'GUEST', 'room_number': roomNumber},
                      'items': cart.entries.map((e) {
                        final item = _guestMenu.firstWhere((m) => m['name'] == e.key, orElse: () => {'price': 0.0});
                        return {'name': e.key, 'qty': e.value, 'price': (item['price'] as num?)?.toDouble() ?? 0.0};
                      }).toList(),
                    };
                    ref.read(foodOrdersStateProvider.notifier).addOrder(newOrder);
                    Navigator.pop(ctx);
                    _showSuccess(context, '🍽️ Order Placed!', 'Your food order is confirmed. We\'ll bring it to Room $roomNumber shortly.');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE64A19),
                    minimumSize: const Size(double.infinity, 54),
                    disabledBackgroundColor: Colors.grey.shade200,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    cart.isEmpty ? 'Add items to order' : 'Place Order  •  ₹${total.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  // ── Housekeeping Sheet ──────────────────────────────────────────────────────

  void _showHousekeeping(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _RequestSheet(
        emoji: '🧹',
        title: 'Housekeeping',
        subtitle: 'What do you need?',
        color: const Color(0xFF0277BD),
        options: _hkOptions,
        onSubmit: (sub, title, note) {
          ref.read(guestRequestsProvider.notifier).addRequest(
            roomNumber: roomNumber,
            type: 'HOUSEKEEPING',
            subType: sub,
            title: title,
            note: note,
          );
          Navigator.pop(context);
          _showSuccess(context, '🧹 Request Sent!', 'Our housekeeping team will attend to Room $roomNumber shortly.');
        },
      ),
    );
  }

  // ── Maintenance Sheet ───────────────────────────────────────────────────────

  void _showMaintenance(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _RequestSheet(
        emoji: '🔧',
        title: 'Maintenance',
        subtitle: 'What issue are you facing?',
        color: const Color(0xFF6A1B9A),
        options: _maintOptions,
        onSubmit: (sub, title, note) {
          ref.read(guestRequestsProvider.notifier).addRequest(
            roomNumber: roomNumber,
            type: 'MAINTENANCE',
            subType: sub,
            title: title,
            note: note,
          );
          Navigator.pop(context);
          _showSuccess(context, '🔧 Issue Reported!', 'Our maintenance team will fix the issue in Room $roomNumber as soon as possible.');
        },
      ),
    );
  }

  // ── Activities Sheet ────────────────────────────────────────────────────────

  void _showActivities(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ActivitiesSheet(roomNumber: roomNumber),
    );
  }

  // ── Success dialog ──────────────────────────────────────────────────────────

  void _showSuccess(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Text(title.split(' ')[0], style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(title.substring(title.indexOf(' ') + 1),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D0D0D))),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('OK, Thank you!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }
}

// ── DND Banner ────────────────────────────────────────────────────────────────

class _DndBanner extends ConsumerWidget {
  final String roomNumber;
  final bool isDnd;
  const _DndBanner({required this.roomNumber, required this.isDnd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isDnd) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFB71C1C).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB71C1C).withOpacity(0.3)),
      ),
      child: Row(children: [
        const Text('🚫', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Do Not Disturb is ON', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB71C1C), fontSize: 14)),
            Text('Staff will not enter your room', style: TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
        ),
        TextButton(
          onPressed: () => ref.read(dndProvider.notifier).toggle(roomNumber),
          child: const Text('Turn Off', style: TextStyle(color: Color(0xFFB71C1C), fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

// ── DND Card ──────────────────────────────────────────────────────────────────

class _DndCard extends ConsumerWidget {
  final String roomNumber;
  final bool isDnd;
  const _DndCard({required this.roomNumber, required this.isDnd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(dndProvider.notifier).toggle(roomNumber),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: isDnd
              ? const LinearGradient(colors: [Color(0xFFB71C1C), Color(0xFFE53935)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight)
              : const LinearGradient(colors: [Color(0xFF37474F), Color(0xFF546E7A)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          const Text('🚫', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Do Not Disturb',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              isDnd ? 'ON — Staff will not enter your room' : 'OFF — Tap to enable',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
            ),
          ])),
          Switch(
            value: isDnd,
            onChanged: (_) => ref.read(dndProvider.notifier).toggle(roomNumber),
            activeColor: Colors.white,
            activeTrackColor: Colors.white.withOpacity(0.3),
          ),
        ]),
      ),
    );
  }
}

// ── Service Tile ──────────────────────────────────────────────────────────────

class _ServiceTile extends StatelessWidget {
  final String emoji, title, subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _ServiceTile({required this.emoji, required this.title, required this.subtitle, required this.gradient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: gradient[0].withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(emoji, style: const TextStyle(fontSize: 34)),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
          ]),
        ]),
      ),
    );
  }
}

// ── Quick Info Row ────────────────────────────────────────────────────────────

class _QuickInfoRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _InfoChip(icon: Icons.phone_rounded, label: 'Front Desk', sub: 'Ext. 100'),
      const SizedBox(width: 10),
      _InfoChip(icon: Icons.wifi_rounded, label: 'WiFi', sub: 'Anjanvel_Guest'),
      const SizedBox(width: 10),
      _InfoChip(icon: Icons.schedule_rounded, label: 'Checkout', sub: '11:00 AM'),
    ]);
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  const _InfoChip({required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
      ),
      child: Column(children: [
        Icon(icon, size: 20, color: const Color(0xFF2E7D32)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF0D0D0D))),
        Text(sub, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ]),
    ),
  );
}

// ── My Requests ───────────────────────────────────────────────────────────────

class _MyRequests extends ConsumerWidget {
  final String roomNumber;
  const _MyRequests({required this.roomNumber});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(guestRequestsProvider);
    final roomReqs = all.where((r) => r['room_number'] == roomNumber).take(5).toList();
    if (roomReqs.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('My Requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
      const SizedBox(height: 10),
      ...roomReqs.map((r) => _RequestTile(request: r)),
    ]);
  }
}

class _RequestTile extends StatelessWidget {
  final Map<String, dynamic> request;
  const _RequestTile({required this.request});

  Color get _statusColor {
    switch (request['status']) {
      case 'PENDING': return AppTheme.warning;
      case 'IN_PROGRESS': return AppTheme.info;
      case 'DONE': return AppTheme.success;
      default: return AppTheme.textHint;
    }
  }

  String get _statusLabel {
    switch (request['status']) {
      case 'PENDING': return 'Pending';
      case 'IN_PROGRESS': return 'In Progress';
      case 'DONE': return 'Done';
      default: return 'Unknown';
    }
  }

  String get _typeEmoji {
    switch (request['type']) {
      case 'HOUSEKEEPING': return '🧹';
      case 'MAINTENANCE': return '🔧';
      case 'ACTIVITY': return '🎯';
      default: return '📋';
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestedAt = request['requested_at'] as String?;
    String timeStr = '';
    if (requestedAt != null) {
      final dt = DateTime.tryParse(requestedAt);
      if (dt != null) timeStr = DateFormat('hh:mm a').format(dt);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _statusColor.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(children: [
        Text(_typeEmoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(request['title'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0D0D0D))),
          Text(timeStr, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_statusLabel, style: TextStyle(fontSize: 11, color: _statusColor, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

// ── Generic Request Sheet ─────────────────────────────────────────────────────

class _RequestSheet extends StatefulWidget {
  final String emoji, title, subtitle;
  final Color color;
  final List<Map<String, dynamic>> options;
  final void Function(String sub, String title, String note) onSubmit;
  const _RequestSheet({required this.emoji, required this.title, required this.subtitle, required this.color, required this.options, required this.onSubmit});

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  int? _selectedIdx;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Row(children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D0D0D))),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
            Text(widget.subtitle, style: const TextStyle(color: Colors.black54, fontSize: 13)),
            const SizedBox(height: 16),

            // Options grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.3,
              ),
              itemCount: widget.options.length,
              itemBuilder: (_, i) {
                final opt = widget.options[i];
                final selected = _selectedIdx == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIdx = i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected ? widget.color : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? widget.color : Colors.grey.shade200, width: selected ? 1.5 : 1),
                      boxShadow: selected ? [BoxShadow(color: widget.color.withOpacity(0.25), blurRadius: 8)] : [],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(children: [
                      Text(opt['emoji'] as String, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(opt['title'] as String,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : const Color(0xFF0D0D0D)))),
                    ]),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            // Note
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Add a note (optional)',
                prefixIcon: const Icon(Icons.note_outlined, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _selectedIdx == null ? null : () {
                final opt = widget.options[_selectedIdx!];
                widget.onSubmit(opt['sub'] as String, opt['title'] as String, _noteCtrl.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.color,
                minimumSize: const Size(double.infinity, 52),
                disabledBackgroundColor: Colors.grey.shade200,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                _selectedIdx == null ? 'Select an option above' : 'Send Request',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Activities Sheet ──────────────────────────────────────────────────────────

class _ActivitiesSheet extends ConsumerStatefulWidget {
  final String roomNumber;
  const _ActivitiesSheet({required this.roomNumber});

  @override
  ConsumerState<_ActivitiesSheet> createState() => _ActivitiesSheetState();
}

class _ActivitiesSheetState extends ConsumerState<_ActivitiesSheet> {
  int? _selectedIdx;
  int _persons = 1;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scroll) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Row(children: [
              const Text('🎯', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              const Text('Book Activities', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D0D0D))),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
            const Divider(),
          ]),
        ),
        Expanded(
          child: ListView(controller: scroll, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            ..._guestActivities.asMap().entries.map((entry) {
              final i = entry.key;
              final act = entry.value;
              final selected = _selectedIdx == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedIdx = i),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF00838F).withOpacity(0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? const Color(0xFF00838F) : Colors.grey.shade200,
                      width: selected ? 1.5 : 1,
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                  ),
                  child: Row(children: [
                    Text(act['emoji'] as String, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(act['name'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0D0D0D))),
                      Text(act['desc'] as String, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.schedule, size: 12, color: Colors.black45),
                        const SizedBox(width: 3),
                        Text(act['duration'] as String, style: const TextStyle(fontSize: 11, color: Colors.black45)),
                        const SizedBox(width: 10),
                        Text('₹${(act['price'] as num).toStringAsFixed(0)}/person',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF00838F))),
                      ]),
                    ])),
                    if (selected) const Icon(Icons.check_circle_rounded, color: Color(0xFF00838F)),
                  ]),
                ),
              );
            }),
            if (_selectedIdx != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                child: Row(children: [
                  const Text('Number of persons', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0D0D0D))),
                  const Spacer(),
                  IconButton(
                    onPressed: _persons > 1 ? () => setState(() => _persons--) : null,
                    icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF00838F)),
                  ),
                  Text('$_persons', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D0D0D))),
                  IconButton(
                    onPressed: _persons < 10 ? () => setState(() => _persons++) : null,
                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00838F)),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 80),
          ]),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -2))],
          ),
          child: Builder(builder: (ctx) {
            final act = _selectedIdx != null ? _guestActivities[_selectedIdx!] : null;
            final total = act != null ? (act['price'] as num).toDouble() * _persons : 0.0;
            return ElevatedButton(
              onPressed: act == null ? null : () {
                final booking = {
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'booking_number': 'ACT-G${(DateTime.now().millisecondsSinceEpoch % 9000 + 1000)}',
                  'activity_name': act['name'] as String,
                  'activity_emoji': act['emoji'] as String,
                  'room_number': widget.roomNumber,
                  'persons': _persons,
                  'total_amount': total,
                  'status': 'CONFIRMED',
                  'booked_at': DateTime.now().toIso8601String(),
                  'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                  'time': '10:00 AM',
                  'guest_name': 'Room ${widget.roomNumber} (Guest)',
                };
                ref.read(activityBookingsProvider.notifier).addBooking(booking);
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(act['emoji'] as String, style: const TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text('${act['name']} Booked!',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D0D0D))),
                      const SizedBox(height: 8),
                      Text('$_persons person${_persons > 1 ? 's' : ''}  •  ₹${total.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 14, color: Color(0xFF00838F), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      const Text('Our team will confirm and share the timing with you.',
                          textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.black54)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00838F),
                          minimumSize: const Size(double.infinity, 46),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Great!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00838F),
                minimumSize: const Size(double.infinity, 54),
                disabledBackgroundColor: Colors.grey.shade200,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                act == null
                    ? 'Select an activity'
                    : 'Book ${act['name']}  •  ₹${total.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            );
          }),
        ),
      ]),
    );
  }
}
