import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class StaffMember {
  final String id;
  final String fullName;
  final String role;
  final String? email;
  final String? phone;
  final String? department;
  final String? employeeId;
  final bool isActive;
  final String? avatarUrl;
  final DateTime? joinDate;

  const StaffMember({
    required this.id,
    required this.fullName,
    required this.role,
    this.email,
    this.phone,
    this.department,
    this.employeeId,
    required this.isActive,
    this.avatarUrl,
    this.joinDate,
  });

  factory StaffMember.fromJson(Map<String, dynamic> j) => StaffMember(
        id: j['id'] as String,
        fullName: j['full_name'] as String? ?? 'Unknown',
        role: j['role'] as String? ?? 'STAFF',
        email: j['email'] as String?,
        phone: j['phone'] as String?,
        department: j['department'] as String?,
        employeeId: j['employee_id'] as String?,
        isActive: j['is_active'] as bool? ?? true,
        avatarUrl: j['avatar_url'] as String?,
        joinDate: j['join_date'] != null
            ? DateTime.tryParse(j['join_date'] as String)
            : null,
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final staffListProvider = FutureProvider<List<StaffMember>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('users')
      .select('id, full_name, role, email, phone, department, employee_id, is_active, avatar_url, join_date')
      .neq('role', 'GUEST')
      .order('role', ascending: true);
  return (data as List).map((d) => StaffMember.fromJson(d)).toList();
});

// ── Department config ─────────────────────────────────────────────────────────

const _deptConfig = {
  'OWNER':               {'label': 'Owner',               'icon': Icons.star_rounded,               'color': Color(0xFFFFB300)},
  'MANAGER':             {'label': 'Manager',             'icon': Icons.manage_accounts_rounded,     'color': Color(0xFF1565C0)},
  'ACCOUNTANT':          {'label': 'Accounts',            'icon': Icons.account_balance_wallet_outlined, 'color': Color(0xFF00796B)},
  'CA':                  {'label': 'CA',                  'icon': Icons.receipt_long_outlined,       'color': Color(0xFF4527A0)},
  'CONSULTANT':          {'label': 'Consultant',          'icon': Icons.business_center_outlined,    'color': Color(0xFF37474F)},
  'HOUSEKEEPING':        {'label': 'Housekeeping',        'icon': Icons.cleaning_services_outlined,  'color': Color(0xFF2E7D32)},
  'KITCHEN':             {'label': 'Kitchen',             'icon': Icons.restaurant_menu_outlined,    'color': Color(0xFFE64A19)},
  'ACTIVITY_COORDINATOR':{'label': 'Activities',          'icon': Icons.hiking_outlined,             'color': Color(0xFF00838F)},
  'SHOP_OPERATOR':       {'label': 'Shop',                'icon': Icons.storefront_outlined,         'color': Color(0xFF6A1B9A)},
  'GUIDE':               {'label': 'Guide',               'icon': Icons.explore_outlined,            'color': Color(0xFF558B2F)},
};

const _deptOrder = [
  'OWNER', 'MANAGER', 'ACCOUNTANT', 'CA', 'CONSULTANT',
  'HOUSEKEEPING', 'KITCHEN', 'ACTIVITY_COORDINATOR', 'SHOP_OPERATOR', 'GUIDE',
];

// ── Screen ────────────────────────────────────────────────────────────────────

class StaffManagementScreen extends ConsumerStatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  ConsumerState<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends ConsumerState<StaffManagementScreen> {
  String _search = '';
  String? _filterRole;

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffListProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(
        title: 'Staff Management',
        actions: [
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: 'Attendance',
            onPressed: () => context.push('/staff/attendance'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(staffListProvider),
          ),
        ],
      ),
      body: staffAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
              const SizedBox(height: 12),
              Text('Failed to load staff: $e', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(staffListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (allStaff) {
          // Apply search
          final filtered = allStaff.where((s) {
            final matchSearch = _search.isEmpty ||
                s.fullName.toLowerCase().contains(_search.toLowerCase()) ||
                (s.email ?? '').toLowerCase().contains(_search.toLowerCase()) ||
                (s.phone ?? '').contains(_search);
            final matchRole = _filterRole == null || s.role == _filterRole;
            return matchSearch && matchRole;
          }).toList();

          // Group by role
          final grouped = <String, List<StaffMember>>{};
          for (final s in filtered) {
            grouped.putIfAbsent(s.role, () => []).add(s);
          }

          final totalActive = allStaff.where((s) => s.isActive).length;

          return Column(
            children: [
              // Stats bar
              _StatsBar(total: allStaff.length, active: totalActive, departments: grouped.length),

              // Search & Filter
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search staff...',
                          prefixIcon: Icon(Icons.search, size: 20),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoleFilterButton(
                      selected: _filterRole,
                      onSelected: (r) => setState(() => _filterRole = r),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Staff list grouped by dept
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                        title: 'No Staff Found',
                        subtitle: 'No staff members match your search',
                        icon: Icons.people_outline,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _deptOrder.length,
                        itemBuilder: (_, i) {
                          final role = _deptOrder[i];
                          final members = grouped[role];
                          if (members == null || members.isEmpty) return const SizedBox();
                          return _DepartmentSection(role: role, members: members);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Stats Bar ─────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final int total, active, departments;
  const _StatsBar({required this.total, required this.active, required this.departments});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          _StatItem('Total Staff', '$total', Icons.people_rounded),
          _Divider(),
          _StatItem('Active', '$active', Icons.check_circle_outline_rounded),
          _Divider(),
          _StatItem('Inactive', '${total - active}', Icons.do_not_disturb_alt_outlined),
          _Divider(),
          _StatItem('Departments', '$departments', Icons.business_outlined),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _StatItem(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 40, color: Colors.white24);
}

// ── Role Filter Button ────────────────────────────────────────────────────────

class _RoleFilterButton extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;
  const _RoleFilterButton({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected != null ? AppTheme.primary.withOpacity(0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected != null ? AppTheme.primary : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.filter_list_rounded,
                size: 18, color: selected != null ? AppTheme.primary : AppTheme.textHint),
            if (selected != null) ...[
              const SizedBox(width: 4),
              Text(
                _deptConfig[selected]?['label'] as String? ?? selected!,
                style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          const Text('Filter by Role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('All Roles'),
            leading: const Icon(Icons.people_rounded),
            trailing: selected == null ? const Icon(Icons.check, color: AppTheme.primary) : null,
            onTap: () { onSelected(null); Navigator.pop(context); },
          ),
          ..._deptOrder.map((role) {
            final cfg = _deptConfig[role];
            return ListTile(
              leading: Icon(cfg?['icon'] as IconData? ?? Icons.person,
                  color: cfg?['color'] as Color? ?? AppTheme.primary),
              title: Text(cfg?['label'] as String? ?? role),
              trailing: selected == role ? const Icon(Icons.check, color: AppTheme.primary) : null,
              onTap: () { onSelected(role); Navigator.pop(context); },
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Department Section ────────────────────────────────────────────────────────

class _DepartmentSection extends StatelessWidget {
  final String role;
  final List<StaffMember> members;
  const _DepartmentSection({required this.role, required this.members});

  @override
  Widget build(BuildContext context) {
    final cfg = _deptConfig[role];
    final color = cfg?['color'] as Color? ?? AppTheme.primary;
    final icon = cfg?['icon'] as IconData? ?? Icons.person;
    final label = cfg?['label'] as String? ?? role.replaceAll('_', ' ');
    final activeCount = members.where((m) => m.isActive).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        // Section header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$activeCount/${members.length} active',
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Staff cards
        ...members.map((m) => _StaffCard(member: m, color: color)),
      ],
    );
  }
}

// ── Staff Card ────────────────────────────────────────────────────────────────

class _StaffCard extends StatelessWidget {
  final StaffMember member;
  final Color color;
  const _StaffCard({required this.member, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        border: member.isActive ? null : Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: color.withOpacity(0.15),
                  backgroundImage: member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
                  child: member.avatarUrl == null
                      ? Text(
                          member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : '?',
                          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
                        )
                      : null,
                ),
                if (!member.isActive)
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: AppTheme.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  )
                else
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: AppTheme.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          member.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!member.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Inactive', style: TextStyle(color: AppTheme.error, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (member.email != null)
                    Text(member.email!, style: const TextStyle(color: AppTheme.textHint, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (member.phone != null)
                    Text('+91 ${member.phone}', style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                  if (member.employeeId != null || member.joinDate != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (member.employeeId != null)
                          _Chip(Icons.badge_outlined, member.employeeId!, color),
                        if (member.joinDate != null) ...[
                          const SizedBox(width: 6),
                          _Chip(Icons.calendar_today_outlined,
                              'Joined ${member.joinDate!.year}', color),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Actions
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.phone_outlined, size: 18, color: AppTheme.primary),
                  onPressed: member.phone != null ? () => _showContactSheet(context, member) : null,
                  tooltip: 'Call',
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.textHint),
                  onPressed: () => _showDetailSheet(context, member, color),
                  tooltip: 'Details',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showContactSheet(BuildContext context, StaffMember m) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(m.role.replaceAll('_', ' '),
                style: const TextStyle(color: AppTheme.textHint, fontSize: 13)),
            const SizedBox(height: 20),
            if (m.phone != null)
              _ContactRow(Icons.phone_rounded, 'Phone', '+91 ${m.phone!}'),
            if (m.email != null)
              _ContactRow(Icons.email_outlined, 'Email', m.email!),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context, StaffMember m, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: color.withOpacity(0.15),
                    backgroundImage: m.avatarUrl != null ? NetworkImage(m.avatarUrl!) : null,
                    child: m.avatarUrl == null
                        ? Text(m.fullName[0].toUpperCase(),
                            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22))
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.fullName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(m.role.replaceAll('_', ' '),
                            style: const TextStyle(color: AppTheme.textHint)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (m.isActive ? AppTheme.success : AppTheme.error).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(m.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                            color: m.isActive ? AppTheme.success : AppTheme.error,
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              if (m.employeeId != null) _DetailRow('Employee ID', m.employeeId!),
              if (m.department != null) _DetailRow('Department', m.department!),
              _DetailRow('Role', m.role.replaceAll('_', ' ')),
              if (m.email != null) _DetailRow('Email', m.email!),
              if (m.phone != null) _DetailRow('Phone', '+91 ${m.phone!}'),
              if (m.joinDate != null)
                _DetailRow('Join Date',
                    '${m.joinDate!.day}/${m.joinDate!.month}/${m.joinDate!.year}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _ContactRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 110,
              child: Text(label, style: const TextStyle(color: AppTheme.textHint, fontSize: 13))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }
}
