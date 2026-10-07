import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final activitiesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    return await client.from('activities').select().order('name', ascending: true);
  } catch (_) {
    return _demoActivities;
  }
});

final activityRegistrationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  try {
    return await client
        .from('activity_registrations')
        .select('*, activities(name, category), bookings(booking_number), guests(full_name)')
        .gte('scheduled_date', today)
        .order('scheduled_date', ascending: true)
        .limit(50);
  } catch (_) {
    return [];
  }
});

// Demo data if table doesn't exist
const _demoActivities = [
  {'id': '1', 'name': 'Farm Tour', 'category': 'Nature', 'duration_hours': 2, 'max_capacity': 20, 'price_per_person': 500.0, 'is_active': true, 'description': 'Guided tour of organic farm and agriculture'},
  {'id': '2', 'name': 'Rappelling', 'category': 'Adventure', 'duration_hours': 3, 'max_capacity': 10, 'price_per_person': 800.0, 'is_active': true, 'description': 'Rock rappelling with certified instructors'},
  {'id': '3', 'name': 'Bonfire Night', 'category': 'Leisure', 'duration_hours': 2, 'max_capacity': 30, 'price_per_person': 300.0, 'is_active': true, 'description': 'Evening bonfire with music and snacks'},
  {'id': '4', 'name': 'Bird Watching', 'category': 'Nature', 'duration_hours': 2, 'max_capacity': 15, 'price_per_person': 400.0, 'is_active': true, 'description': 'Early morning bird watching with expert guide'},
  {'id': '5', 'name': 'Bullock Cart Ride', 'category': 'Cultural', 'duration_hours': 1, 'max_capacity': 8, 'price_per_person': 250.0, 'is_active': true, 'description': 'Traditional bullock cart ride through the village'},
  {'id': '6', 'name': 'Zip Line', 'category': 'Adventure', 'duration_hours': 1, 'max_capacity': 12, 'price_per_person': 600.0, 'is_active': true, 'description': 'Thrilling zip line over the valley'},
  {'id': '7', 'name': 'Cooking Class', 'category': 'Cultural', 'duration_hours': 3, 'max_capacity': 10, 'price_per_person': 700.0, 'is_active': true, 'description': 'Traditional Maharashtrian cooking with local chef'},
  {'id': '8', 'name': 'Nature Walk', 'category': 'Nature', 'duration_hours': 2, 'max_capacity': 25, 'price_per_person': 200.0, 'is_active': true, 'description': 'Guided nature trail through forest paths'},
];

// ── Category Config ───────────────────────────────────────────────────────────

const _categoryConfig = {
  'Adventure': {'color': Color(0xFFE53935), 'icon': Icons.paragliding_outlined},
  'Nature':    {'color': Color(0xFF2E7D32), 'icon': Icons.forest_outlined},
  'Cultural':  {'color': Color(0xFF6A1B9A), 'icon': Icons.temple_hindu_outlined},
  'Leisure':   {'color': Color(0xFF0277BD), 'icon': Icons.spa_outlined},
};

// ── Screen ────────────────────────────────────────────────────────────────────

class ActivityListScreen extends ConsumerStatefulWidget {
  const ActivityListScreen({super.key});

  @override
  ConsumerState<ActivityListScreen> createState() => _ActivityListScreenState();
}

class _ActivityListScreenState extends ConsumerState<ActivityListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(activitiesProvider);
    final registrationsAsync = ref.watch(activityRegistrationsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Activities'),
        backgroundColor: const Color(0xFF00838F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            tooltip: 'Home',
            onPressed: () => context.go('/dashboard/owner'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(activitiesProvider);
              ref.invalidate(activityRegistrationsProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Activities', icon: Icon(Icons.hiking_outlined, size: 18)),
            Tab(text: 'Registrations', icon: Icon(Icons.event_note_outlined, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Activities Tab ──
          activitiesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00838F))),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (activities) {
              final categories = activities
                  .map((a) => a['category'] as String? ?? 'Other')
                  .toSet()
                  .toList()
                ..sort();

              final filtered = _selectedCategory == null
                  ? activities
                  : activities.where((a) => a['category'] == _selectedCategory).toList();

              return Column(
                children: [
                  // Stats row
                  _ActivityStats(activities: activities),
                  // Category filter
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      children: [
                        _CategoryChip('All', null, _selectedCategory,
                            (v) => setState(() => _selectedCategory = v)),
                        ...categories.map((c) => _CategoryChip(
                              c, c, _selectedCategory,
                              (v) => setState(() => _selectedCategory = v),
                            )),
                      ],
                    ),
                  ),
                  // List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _ActivityCard(activity: filtered[i]),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Registrations Tab ──
          registrationsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00838F))),
            error: (e, _) => Center(child: _RegistrationsPlaceholder()),
            data: (regs) => regs.isEmpty
                ? _RegistrationsPlaceholder()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: regs.length,
                    itemBuilder: (_, i) => _RegistrationTile(reg: regs[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddActivitySheet(),
        icon: const Icon(Icons.add),
        label: const Text('Schedule Activity'),
        backgroundColor: const Color(0xFF00838F),
      ),
    );
  }

  void _showAddActivitySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Schedule Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Select an activity from the Activities tab and tap to schedule it for guests.',
                style: TextStyle(color: AppTheme.textHint)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00838F),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Activity Stats ────────────────────────────────────────────────────────────

class _ActivityStats extends StatelessWidget {
  final List<Map<String, dynamic>> activities;
  const _ActivityStats({required this.activities});

  @override
  Widget build(BuildContext context) {
    final active = activities.where((a) => a['is_active'] == true).length;
    final adventure = activities.where((a) => a['category'] == 'Adventure').length;
    final nature = activities.where((a) => a['category'] == 'Nature').length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00838F), Color(0xFF00ACC1)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: Row(
        children: [
          _Stat('Total', '${activities.length}', Icons.hiking_outlined),
          _VDiv(),
          _Stat('Active', '$active', Icons.check_circle_outline),
          _VDiv(),
          _Stat('Adventure', '$adventure', Icons.paragliding_outlined),
          _VDiv(),
          _Stat('Nature', '$nature', Icons.forest_outlined),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _Stat(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ]),
      );
}

class _VDiv extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: Colors.white24);
}

// ── Category Chip ─────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final String? value, selected;
  final ValueChanged<String?> onTap;
  const _CategoryChip(this.label, this.value, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    final cfg = _categoryConfig[value];
    final color = cfg?['color'] as Color? ?? const Color(0xFF00838F);
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : color.withOpacity(0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Activity Card ─────────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final category = activity['category'] as String? ?? 'Other';
    final cfg = _categoryConfig[category];
    final color = cfg?['color'] as Color? ?? AppTheme.primary;
    final icon = cfg?['icon'] as IconData? ?? Icons.star_outlined;
    final isActive = activity['is_active'] as bool? ?? true;
    final price = (activity['price_per_person'] as num?)?.toDouble() ?? 0;
    final duration = activity['duration_hours'] as int? ?? 1;
    final capacity = activity['max_capacity'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        border: isActive ? null : Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(activity['name'] as String? ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(category,
                            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(activity['description'] as String? ?? '',
                      style: const TextStyle(color: AppTheme.textHint, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _InfoChip(Icons.schedule_outlined, '${duration}h'),
                      const SizedBox(width: 8),
                      _InfoChip(Icons.people_outline, 'Max $capacity'),
                      const SizedBox(width: 8),
                      _InfoChip(Icons.currency_rupee, '₹${price.toStringAsFixed(0)}/person'),
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
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: AppTheme.textHint),
      const SizedBox(width: 3),
      Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
    ],
  );
}

// ── Registration Tile ─────────────────────────────────────────────────────────

class _RegistrationTile extends StatelessWidget {
  final Map<String, dynamic> reg;
  const _RegistrationTile({required this.reg});

  @override
  Widget build(BuildContext context) {
    final activity = reg['activities'] as Map<String, dynamic>? ?? {};
    final guest = reg['guests'] as Map<String, dynamic>? ?? {};
    final booking = reg['bookings'] as Map<String, dynamic>? ?? {};
    final date = reg['scheduled_date'] as String? ?? '';
    final status = reg['status'] as String? ?? 'SCHEDULED';
    final statusColor = status == 'COMPLETED' ? AppTheme.success
        : status == 'CANCELLED' ? AppTheme.error : AppTheme.info;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF00838F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.event_outlined, color: Color(0xFF00838F), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity['name'] as String? ?? 'Activity',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(guest['full_name'] as String? ?? 'Guest',
                    style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                Text('${booking['booking_number'] ?? ''} • $date',
                    style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
              ],
            ),
          ),
          StatusBadge(label: status, color: statusColor),
        ],
      ),
    );
  }
}

class _RegistrationsPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const EmptyState(
    title: 'No Upcoming Registrations',
    subtitle: 'Guest activity registrations will appear here',
    icon: Icons.event_note_outlined,
  );
}
