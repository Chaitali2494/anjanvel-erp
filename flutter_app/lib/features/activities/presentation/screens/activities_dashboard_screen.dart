import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final activitiesDashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    final activities  = await client.from('activities').select('id, name, category, price, max_capacity');
    final regs        = await client.from('activity_registrations').select('activity_id, participants, status, scheduled_date')
        .gte('scheduled_date', DateTime.now().toIso8601String().substring(0, 10));
    final totalParticipants = regs.fold<int>(0, (s, r) => s + ((r['participants'] as int?) ?? 1));
    final upcoming = regs.where((r) => r['status'] != 'CANCELLED').length;
    return {
      'activities': activities,
      'registrations': regs,
      'total_activities': activities.length,
      'upcoming_sessions': upcoming,
      'total_participants': totalParticipants,
    };
  } catch (_) {
    return {
      'activities': _demoActivities,
      'registrations': [],
      'total_activities': 8,
      'upcoming_sessions': 5,
      'total_participants': 23,
    };
  }
});

const _demoActivities = [
  {'id': '1', 'name': 'Heritage Walk',    'category': 'Cultural',   'price': 500,  'registrations': 12, 'emoji': '🏛️'},
  {'id': '2', 'name': 'Pottery Class',    'category': 'Cultural',   'price': 400,  'registrations': 8,  'emoji': '🏺'},
  {'id': '3', 'name': 'Farm Tour',        'category': 'Nature',     'price': 300,  'registrations': 15, 'emoji': '🚜'},
  {'id': '4', 'name': 'Bonfire Evening',  'category': 'Leisure',    'price': 200,  'registrations': 20, 'emoji': '🔥'},
  {'id': '5', 'name': 'Village Tour',     'category': 'Cultural',   'price': 350,  'registrations': 10, 'emoji': '🏘️'},
  {'id': '6', 'name': 'Bullock Cart Ride','category': 'Adventure',  'price': 250,  'registrations': 18, 'emoji': '🐂'},
  {'id': '7', 'name': 'Bird Watching',    'category': 'Nature',     'price': 300,  'registrations': 7,  'emoji': '🦜'},
  {'id': '8', 'name': 'Cooking Class',    'category': 'Cultural',   'price': 600,  'registrations': 9,  'emoji': '👨‍🍳'},
];

// ── Screen ────────────────────────────────────────────────────────────────────

class ActivitiesDashboardScreen extends ConsumerWidget {
  const ActivitiesDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(activitiesDashboardProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(
        title: 'Activities Dashboard',
        actions: [
          IconButton(icon: const Icon(Icons.list_alt_rounded), onPressed: () => context.push('/activities')),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => ref.invalidate(activitiesDashboardProvider)),
        ],
      ),
      body: dashAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00838F))),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final activities = (data['activities'] as List?) ?? _demoActivities;

          return CustomScrollView(
            slivers: [
              // KPI stats
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF00838F), Color(0xFF00ACC1)]),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Today\'s Overview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      Row(children: [
                        _KPI('Activities',    '${data['total_activities']}',    Icons.hiking_rounded),
                        _KPI('Upcoming',      '${data['upcoming_sessions']}',   Icons.event_rounded),
                        _KPI('Participants',  '${data['total_participants']}',  Icons.group_rounded),
                      ]),
                    ],
                  ),
                ),
              ),

              // Activities grid
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: const Text('All Activities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.2,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _ActivityCard(activity: activities[i]),
                    childCount: activities.length,
                  ),
                ),
              ),

              // Quick register button area
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/activities'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00838F),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
                    label: const Text('View All & Register', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KPI extends StatelessWidget {
  final String label, value; final IconData icon;
  const _KPI(this.label, this.value, this.icon);
  @override Widget build(_) => Expanded(
    child: Column(children: [
      Icon(icon, color: Colors.white70, size: 22),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
    ]),
  );
}

class _ActivityCard extends StatelessWidget {
  final dynamic activity;
  const _ActivityCard({required this.activity});

  static const _catColors = {
    'Cultural':  Color(0xFF6A1B9A),
    'Nature':    Color(0xFF2E7D32),
    'Adventure': Color(0xFFE64A19),
    'Leisure':   Color(0xFF1565C0),
  };

  @override
  Widget build(BuildContext context) {
    final name     = activity['name']?.toString() ?? '';
    final category = activity['category']?.toString() ?? '';
    final price    = activity['price'];
    final regs     = activity['registrations'] ?? 0;
    final emoji    = activity['emoji'] ?? '🎯';
    final color    = _catColors[category] ?? const Color(0xFF00838F);

    return GestureDetector(
      onTap: () {
        final id = activity['id']?.toString() ?? '';
        if (id.isNotEmpty) context.push('/activities/$id');
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(category, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ]),
            const Spacer(),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.people_outline_rounded, size: 12, color: AppTheme.textPrimary),
              const SizedBox(width: 3),
              Text('$regs', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
              const Spacer(),
              if (price != null)
                Text('₹$price', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
          ],
        ),
      ),
    );
  }
}
