import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';

final usersManagementProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    return await client.from('users').select('id, full_name, email, role, is_active, created_at, phone').order('role').order('full_name');
  } catch (_) {
    return _demoUsers;
  }
});

const _demoUsers = [
  {'id': '1', 'full_name': 'Anjanvel Owner',     'email': 'owner@anjanvel.com',     'role': 'OWNER',               'is_active': true,  'phone': '+91 9876540001'},
  {'id': '2', 'full_name': 'Rahul Manager',      'email': 'manager@anjanvel.com',   'role': 'MANAGER',             'is_active': true,  'phone': '+91 9876540002'},
  {'id': '3', 'full_name': 'Savita Housekeep',   'email': 'hk@anjanvel.com',        'role': 'HOUSEKEEPING',        'is_active': true,  'phone': '+91 9876540003'},
  {'id': '4', 'full_name': 'Chef Arun',          'email': 'kitchen@anjanvel.com',   'role': 'KITCHEN',             'is_active': true,  'phone': '+91 9876540004'},
  {'id': '5', 'full_name': 'Kiran Guide',        'email': 'guide@anjanvel.com',     'role': 'GUIDE',               'is_active': true,  'phone': '+91 9876540005'},
  {'id': '6', 'full_name': 'Priya Activity',     'email': 'activity@anjanvel.com',  'role': 'ACTIVITY_COORDINATOR','is_active': false, 'phone': '+91 9876540006'},
  {'id': '7', 'full_name': 'Ramesh Shop',        'email': 'shop@anjanvel.com',      'role': 'SHOP_OPERATOR',       'is_active': true,  'phone': '+91 9876540007'},
  {'id': '8', 'full_name': 'Accountant Dev',     'email': 'accounts@anjanvel.com',  'role': 'ACCOUNTANT',          'is_active': true,  'phone': '+91 9876540008'},
];

const _roleColors = {
  'OWNER':               Color(0xFF2E7D32),
  'MANAGER':             Color(0xFF1565C0),
  'HOUSEKEEPING':        Color(0xFF6A1B9A),
  'KITCHEN':             Color(0xFFE64A19),
  'GUIDE':               Color(0xFF4527A0),
  'ACTIVITY_COORDINATOR':Color(0xFF00838F),
  'SHOP_OPERATOR':       Color(0xFF558B2F),
  'ACCOUNTANT':          Color(0xFF00796B),
  'CA':                  Color(0xFF4527A0),
  'CONSULTANT':          Color(0xFF37474F),
};

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});
  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersManagementProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(
        title: 'User Management',
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => ref.invalidate(usersManagementProvider)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateUser(context),
        backgroundColor: const Color(0xFF37474F),
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Add User', style: TextStyle(color: Colors.white)),
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (users) {
          final filtered = _search.isEmpty ? users : users.where((u) =>
            (u['full_name'] as String? ?? '').toLowerCase().contains(_search.toLowerCase()) ||
            (u['email'] as String? ?? '').toLowerCase().contains(_search.toLowerCase()) ||
            (u['role'] as String? ?? '').toLowerCase().contains(_search.toLowerCase())
          ).toList();

          return Column(children: [
            // Search
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search by name, email or role...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textPrimary),
                  filled: true, fillColor: AppTheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMD), borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMD), borderSide: BorderSide(color: Colors.grey.shade200)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

            // Stats bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(children: [
                _StatChip('Total', '${users.length}', const Color(0xFF37474F)),
                const SizedBox(width: 8),
                _StatChip('Active', '${users.where((u) => u['is_active'] == true).length}', AppTheme.success),
                const SizedBox(width: 8),
                _StatChip('Inactive', '${users.where((u) => u['is_active'] != true).length}', Colors.grey),
              ]),
            ),

            // User list
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(title: 'No Users', subtitle: 'No matching users found', icon: Icons.people_outline)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final u = filtered[i];
                        final role    = u['role'] as String? ?? '';
                        final active  = u['is_active'] as bool? ?? true;
                        final color   = _roleColors[role] ?? const Color(0xFF37474F);
                        final name    = u['full_name'] as String? ?? '';
                        final email   = u['email'] as String? ?? '';
                        final phone   = u['phone'] as String? ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            border: Border.all(color: active ? color.withOpacity(0.2) : Colors.grey.shade200),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                          ),
                          child: Row(children: [
                            // Avatar
                            Stack(children: [
                              CircleAvatar(
                                radius: 22, backgroundColor: color.withOpacity(0.12),
                                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
                              ),
                              Positioned(bottom: 0, right: 0, child: Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(color: active ? AppTheme.success : Colors.grey, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                              )),
                            ]),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(email, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                  child: Text(role.replaceAll('_', ' '), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ]),
                            ])),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textPrimary, size: 20),
                              onSelected: (action) => _handleAction(context, action, u),
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'edit',   child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')])),
                                const PopupMenuItem(value: 'reset',  child: Row(children: [Icon(Icons.lock_reset_rounded, size: 18), SizedBox(width: 8), Text('Reset Password')])),
                                PopupMenuItem(
                                  value: active ? 'deactivate' : 'activate',
                                  child: Row(children: [
                                    Icon(active ? Icons.person_off_rounded : Icons.person_rounded, size: 18, color: active ? AppTheme.error : AppTheme.success),
                                    const SizedBox(width: 8),
                                    Text(active ? 'Deactivate' : 'Activate', style: TextStyle(color: active ? AppTheme.error : AppTheme.success)),
                                  ]),
                                ),
                              ],
                            ),
                          ]),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }

  void _handleAction(BuildContext context, String action, Map<String, dynamic> user) {
    if (action == 'reset') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to ${user['email']}'), backgroundColor: AppTheme.info),
      );
    } else if (action == 'deactivate' || action == 'activate') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user['full_name']} ${action}d'), backgroundColor: AppTheme.success),
      );
    }
  }

  void _showCreateUser(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create New User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            const TextField(decoration: InputDecoration(labelText: 'Email *',     border: OutlineInputBorder())),
            const SizedBox(height: 12),
            const TextField(decoration: InputDecoration(labelText: 'Phone',       border: OutlineInputBorder())),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF37474F), minimumSize: const Size(double.infinity, 48)),
              child: const Text('Create User'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value; final Color color;
  const _StatChip(this.label, this.value, this.color);
  @override Widget build(_) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
    child: Row(children: [
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
    ]),
  );
}
