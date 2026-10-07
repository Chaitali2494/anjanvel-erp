import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';

class TicketDetailScreen extends ConsumerStatefulWidget {
  final String ticketId;
  final Map<String, dynamic>? initialData;
  const TicketDetailScreen({super.key, required this.ticketId, this.initialData});

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  Map<String, dynamic>? _ticket;
  bool _isLoading = true;

  static const _statusCfg = {
    'OPEN':        {'label': 'Open',        'color': Color(0xFFE53935), 'next': 'IN_PROGRESS', 'nextLabel': 'Start Work'},
    'IN_PROGRESS': {'label': 'In Progress', 'color': Color(0xFF1565C0), 'next': 'RESOLVED',    'nextLabel': 'Mark Resolved'},
    'RESOLVED':    {'label': 'Resolved',    'color': Color(0xFF2E7D32), 'next': 'CLOSED',       'nextLabel': 'Close Ticket'},
    'CLOSED':      {'label': 'Closed',      'color': Color(0xFF9E9E9E), 'next': null,            'nextLabel': null},
  };

  static const _priorityCfg = {
    'HIGH':   {'label': 'High',   'color': Color(0xFFE53935)},
    'MEDIUM': {'label': 'Medium', 'color': Color(0xFFFFB300)},
    'LOW':    {'label': 'Low',    'color': Color(0xFF9E9E9E)},
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _ticket = widget.initialData;
      _isLoading = false;
    } else {
      _loadTicket();
    }
  }

  Future<void> _loadTicket() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final data = await client.from('maintenance_tickets').select().eq('id', widget.ticketId).maybeSingle();
      if (mounted) setState(() { _ticket = data; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    if (_ticket == null) return Scaffold(appBar: AppBar(title: const Text('Ticket')), body: const Center(child: Text('Ticket not found')));

    final status   = _ticket!['status'] as String? ?? 'OPEN';
    final priority = _ticket!['priority'] as String? ?? 'LOW';
    final category = _ticket!['category'] as String? ?? 'OTHER';
    final title    = _ticket!['title'] as String? ?? '';
    final location = _ticket!['location'] as String? ?? '';
    final assigned = _ticket!['assigned_to'] as String? ?? 'Unassigned';
    final notes    = _ticket!['notes'] as String? ?? '';
    final createdAt= _ticket!['created_at'] as String?;

    final statusColor = (_statusCfg[status]?['color'] as Color?) ?? Colors.grey;
    final statusLabel = (_statusCfg[status]?['label'] as String?) ?? status;
    final nextStatus  = _statusCfg[status]?['next'] as String?;
    final nextLabel   = _statusCfg[status]?['nextLabel'] as String?;
    final priColor    = (_priorityCfg[priority]?['color'] as Color?) ?? Colors.grey;
    final priLabel    = (_priorityCfg[priority]?['label'] as String?) ?? priority;

    String? formattedDate;
    if (createdAt != null) {
      try { formattedDate = DateFormat('d MMM yyyy, h:mm a').format(DateTime.parse(createdAt)); } catch (_) {}
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Ticket Details', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF37474F),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            tooltip: 'Home',
            onPressed: () => context.go('/dashboard/owner'),
          ),
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Row(children: [
                Icon(Icons.circle, color: statusColor, size: 12),
                const SizedBox(width: 8),
                Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: priColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: priColor.withOpacity(0.4))),
                  child: Text('$priLabel Priority', style: TextStyle(color: priColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.textPrimary)),
            const SizedBox(height: 16),

            // Details card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(AppTheme.radiusMD), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
              child: Column(children: [
                _DetailRow(Icons.location_on_outlined, 'Location', location),
                _DetailRow(Icons.category_outlined, 'Category', category.replaceAll('_', ' ')),
                _DetailRow(Icons.person_outline_rounded, 'Assigned To', assigned),
                if (formattedDate != null)
                  _DetailRow(Icons.access_time_rounded, 'Reported', formattedDate),
              ]),
            ),
            const SizedBox(height: 16),

            if (notes.isNotEmpty) ...[
              const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(AppTheme.radiusMD), border: Border.all(color: Colors.grey.shade200)),
                child: Text(notes, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5)),
              ),
              const SizedBox(height: 20),
            ],

            // Action button
            if (nextStatus != null && nextLabel != null)
              ElevatedButton(
                onPressed: () => _updateStatus(nextStatus),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF37474F),
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: Text(nextLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('maintenance_tickets').update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.ticketId);
      setState(() => _ticket = {...?_ticket, 'status': newStatus});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status updated'), backgroundColor: AppTheme.success),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon; final String label, value;
  const _DetailRow(this.icon, this.label, this.value);
  @override Widget build(_) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Icon(icon, size: 18, color: AppTheme.textHint),
      const SizedBox(width: 10),
      Text('$label:', style: const TextStyle(color: AppTheme.textHint, fontSize: 13)),
      const SizedBox(width: 8),
      Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
    ]),
  );
}
