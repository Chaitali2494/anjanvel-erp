import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  static const _roles = [
    _RoleItem('Owner',               'Full resort management & analytics', Icons.business_center_rounded,  Color(0xFF2E7D32), '/dashboard/owner'),
    _RoleItem('Manager',             'Operations & staff coordination',    Icons.manage_accounts_rounded,  Color(0xFF1565C0), '/dashboard/manager'),
    _RoleItem('Housekeeping',        'Room cleaning & task management',    Icons.cleaning_services_rounded, Color(0xFF6A1B9A), '/dashboard/housekeeping'),
    _RoleItem('Kitchen',             'Food orders & meal planning',        Icons.restaurant_rounded,       Color(0xFFE64A19), '/dashboard/kitchen'),
    _RoleItem('Activity Coordinator','Schedule & manage activities',       Icons.hiking_rounded,           Color(0xFF00838F), '/activities'),
    _RoleItem('Shop Operator',       'Manage products & sales',            Icons.storefront_rounded,       Color(0xFF558B2F), '/shop'),
    _RoleItem('Accountant',          'Reports & financial management',     Icons.account_balance_rounded,  Color(0xFF00796B), '/reports'),
    _RoleItem('Guide',               'Heritage walks & guest tours',       Icons.map_rounded,              Color(0xFF4527A0), '/heritage/guide'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.how_to_reg_rounded, color: AppTheme.primary, size: 36),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Your Role', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('Choose your role to access the right dashboard', style: TextStyle(color: AppTheme.textHint, fontSize: 14), textAlign: TextAlign.center),
                ],
              ),
            ),

            // Role list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _roles.length,
                itemBuilder: (_, i) {
                  final role = _roles[i];
                  return _RoleCard(role: role);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final _RoleItem role;
  const _RoleCard({required this.role});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(role.route),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: role.color.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: role.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: Icon(role.icon, color: role.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(role.description, style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: role.color),
          ],
        ),
      ),
    );
  }
}

class _RoleItem {
  final String label, description, route;
  final IconData icon;
  final Color color;
  const _RoleItem(this.label, this.description, this.icon, this.color, this.route);
}
