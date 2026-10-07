import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final maintenanceTicketsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    return await client
        .from('maintenance_tickets')
        .select()
        .order('priority', ascending: false)
        .order('created_at', ascending: false);
  } catch (_) {
    return _demoTickets;
  }
});

const _demoTickets = [
  {'id': '1', 'title': 'AC not cooling in Room 205', 'location': 'Room 205', 'category': 'ELECTRICAL', 'priority': 'HIGH',   'status': 'OPEN',        'assigned_to': 'Ravi M.', 'reported_by': 'Meena S.', 'created_at': '2026-10-01T09:00:00'},
  {'id': '2', 'title': 'Leaking tap in Room 103',    'location': 'Room 103', 'category': 'PLUMBING',   'priority': 'MEDIUM', 'status': 'IN_PROGRESS', 'assigned_to': 'Suresh P.','reported_by': 'Priya T.', 'created_at': '2026-10-01T10:30:00'},
  {'id': '3', 'title': 'Broken chair in restaurant', 'location': 'Restaurant','category': 'FURNITURE', 'priority': 'LOW',    'status': 'OPEN',        'assigned_to': '',         'reported_by': 'Chef A.',  'created_at': '2026-10-02T08:00:00'},
  {'id': '4', 'title': 'Generator fuel refill',      'location': 'Generator Room','category': 'ELECTRICAL','priority': 'HIGH','status': 'RESOLVED', 'assigned_to': 'Ravi M.', 'reported_by': 'Manager', 'created_at': '2026-09-30T16:00:00'},
  {'id': '5', 'title': 'Pool pump maintenance',      'location': 'Pool Area','category': 'EQUIPMENT',  'priority': 'MEDIUM', 'status': 'OPEN',        'assigned_to': 'Suresh P.','reported_by': 'Guide K.', 'created_at': '2026-10-02T11:00:00'},
];

// ── Screen ────────────────────────────────────────────────────────────────────

class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key});
  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  String _filterStatus = 'ALL';

  static const _statusCfg = {
    'OPEN':        {'label': 'Open',        'color': Color(0xFFE53935)},
    'IN_PROGRESS': {'label': 'In Progress', 'color': Color(0xFF1565C0)},
    'RESOLVED':    {'label': 'Resolved',    'color': Color(0xFF2E7D32)},
    'CLOSED':      {'label': 'Closed',      'color': Color(0xFF9E9E9E)},
  };

  static const _priorityCfg = {
    'HIGH':   {'label': 'High',   'color': Color(0xFFE53935)},
    'MEDIUM': {'label': 'Medium', 'color': Color(0xFFFFB300)},
    'LOW':    {'label': 'Low',    'color': Color(0xFF9E9E9E)},
  };

  static const _categoryCfg = {
    'ELECTRICAL': {'icon': Icons.electrical_services_rounded, 'color': Color(0xFFFFB300)},
    'PLUMBING':   {'icon': Icons.plumbing_rounded,            'color': Color(0xFF1565C0)},
    'FURNITURE':  {'icon': Icons.chair_rounded,               'color': Color(0xFF8D6E63)},
    'EQUIPMENT':  {'icon': Icons.build_rounded,               'color': Color(0xFF00796B)},
    'CIVIL':      {'icon': Icons.construction_rounded,        'color': Color(0xFF6A1B9A)},
    'OTHER':      {'icon': Icons.handyman_rounded,            'color': Color(0xFF37474F)},
  };

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(maintenanceTicketsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(
        title: 'Maintenance Tickets',
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => ref.invalidate(maintenanceTicketsProvider)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/maintenance/create'),
        backgroundColor: const Color(0xFF37474F),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Ticket', style: TextStyle(color: Colors.white)),
      ),
      body: ticketsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tickets) {
          final open       = tickets.where((t) => t['status'] == 'OPEN').length;
          final inProgress = tickets.where((t) => t['status'] == 'IN_PROGRESS').length;
          final resolved   = tickets.where((t) => t['status'] == 'RESOLVED').length;
          final filtered   = _filterStatus == 'ALL' ? tickets : tickets.where((t) => t['status'] == _filterStatus).toList();

          return Column(children: [
            // Stats
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF37474F), Color(0xFF546E7A)]),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: Row(children: [
                _S('Total',       '${tickets.length}', const Color(0xFFFFB300)),
                _D(), _S('Open',  '$open',             const Color(0xFFEF9A9A)),
                _D(), _S('Active','$inProgress',        const Color(0xFF90CAF9)),
                _D(), _S('Resolved','$resolved',        const Color(0xFFA5D6A7)),
              ]),
            ),

            // Filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: ['ALL', 'OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'].map((s) {
                final selected = _filterStatus == s;
                final label = s == 'ALL' ? 'All' : (_statusCfg[s]?['label'] as String? ?? s);
                final color = s == 'ALL' ? const Color(0xFF37474F) : (_statusCfg[s]?['color'] as Color? ?? Colors.grey);
                return GestureDetector(
                  onTap: () => setState(() => _filterStatus = s),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8, bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected ? color : color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? color : color.withOpacity(0.3)),
                    ),
                    child: Text(label, style: TextStyle(color: selected ? Colors.white : color, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList()),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(title: 'No Tickets', subtitle: 'No maintenance tickets found', icon: Icons.build_circle_outlined)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _TicketCard(
                        ticket: filtered[i],
                        statusCfg: _statusCfg,
                        priorityCfg: _priorityCfg,
                        categoryCfg: _categoryCfg,
                        onTap: () => context.push('/maintenance/${filtered[i]['id']}', extra: filtered[i]),
                      ),
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final Map<String, dynamic> statusCfg, priorityCfg, categoryCfg;
  final VoidCallback onTap;
  const _TicketCard({required this.ticket, required this.statusCfg, required this.priorityCfg, required this.categoryCfg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status   = ticket['status'] as String? ?? 'OPEN';
    final priority = ticket['priority'] as String? ?? 'LOW';
    final category = ticket['category'] as String? ?? 'OTHER';
    final title    = ticket['title'] as String? ?? '';
    final location = ticket['location'] as String? ?? '';
    final assigned = ticket['assigned_to'] as String? ?? '';

    final statusColor = (statusCfg[status]?['color'] as Color?) ?? Colors.grey;
    final statusLabel = (statusCfg[status]?['label'] as String?) ?? status;
    final priColor    = (priorityCfg[priority]?['color'] as Color?) ?? Colors.grey;
    final priLabel    = (priorityCfg[priority]?['label'] as String?) ?? priority;
    final catIcon     = (categoryCfg[category]?['icon'] as IconData?) ?? Icons.handyman_rounded;
    final catColor    = (categoryCfg[category]?['color'] as Color?) ?? Colors.grey;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: statusColor.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: catColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(catIcon, color: catColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: priColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: priColor.withOpacity(0.4))),
              child: Text(priLabel, style: TextStyle(color: priColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textPrimary),
            const SizedBox(width: 3),
            Text(location, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
            if (assigned.isNotEmpty) ...[
              const SizedBox(width: 12),
              const Icon(Icons.person_outline_rounded, size: 13, color: AppTheme.textPrimary),
              const SizedBox(width: 3),
              Text(assigned, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
            ],
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor.withOpacity(0.3))),
              child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _S extends StatelessWidget {
  final String l, v; final Color c;
  const _S(this.l, this.v, this.c);
  @override Widget build(_) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 18)),
    Text(l, style: const TextStyle(color: Colors.white60, fontSize: 10)),
  ]));
}
class _D extends StatelessWidget {
  @override Widget build(_) => Container(width: 1, height: 30, color: Colors.white24);
}
