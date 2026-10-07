import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/models/app_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';

// Demo user shown when not logged in
final _demoUser = AppUser(
  id: 'demo',
  fullName: 'Demo Staff',
  email: 'demo@anjanvel.com',
  phone: '9876543210',
  role: 'MANAGER',
  isActive: true,
  employeeId: 'ANJ-001',
  department: 'Operations',
  joinDate: DateTime(2024, 1, 15),
  createdAt: DateTime(2024, 1, 15),
  updatedAt: DateTime.now(),
);

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    // Demo user when not logged in
    final displayUser = user ?? _demoUser;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'My Profile'),
      body: user == null && displayUser == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (user == null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFFFFB300), size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: GestureDetector(
                          onTap: () => context.push('/auth/login'),
                          child: const Text.rich(TextSpan(children: [
                            TextSpan(text: 'Demo mode — ', style: TextStyle(color: Color(0xFFFFB300), fontSize: 12)),
                            TextSpan(text: 'Sign in', style: TextStyle(color: Color(0xFF1565C0), fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                            TextSpan(text: ' to see your real profile.', style: TextStyle(color: Color(0xFFFFB300), fontSize: 12)),
                          ])),
                        )),
                      ]),
                    ),

                  // Avatar & name
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E7D32), Color(0xFF388E3C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white24,
                          backgroundImage: displayUser!.avatarUrl != null
                              ? NetworkImage(displayUser.avatarUrl!)
                              : null,
                          child: displayUser.avatarUrl == null
                              ? Text(
                                  displayUser.fullName.isNotEmpty
                                      ? displayUser.fullName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                      fontSize: 32,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(displayUser.fullName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            displayUser.role.replaceAll('_', ' '),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (displayUser.email != null) ...[
                          const SizedBox(height: 6),
                          Text(displayUser.email!,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ],
                        if (displayUser.phone != null) ...[
                          const SizedBox(height: 2),
                          Text('+91 ${displayUser.phone}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Staff details
                  _SectionCard(
                    title: 'Staff Details',
                    icon: Icons.badge_outlined,
                    children: [
                      if (displayUser.employeeId != null)
                        _InfoRow('Employee ID', displayUser.employeeId!),
                      if (displayUser.department != null)
                        _InfoRow('Department', displayUser.department!),
                      _InfoRow('Role', displayUser.role.replaceAll('_', ' ')),
                      _InfoRow('Status', displayUser.isActive ? 'Active' : 'Inactive',
                          valueColor: displayUser.isActive
                              ? AppTheme.success
                              : AppTheme.error),
                      if (displayUser.joinDate != null)
                        _InfoRow('Joined',
                            '${displayUser.joinDate!.day}/${displayUser.joinDate!.month}/${displayUser.joinDate!.year}'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Change password
                  _SectionCard(
                    title: 'Security',
                    icon: Icons.lock_outline,
                    children: [
                      _ActionRow(
                        icon: Icons.key_outlined,
                        label: 'Change Password',
                        onTap: () => _showChangePassword(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // About
                  _SectionCard(
                    title: 'About',
                    icon: Icons.info_outline,
                    children: [
                      _InfoRow('App', 'Anjanvel ERP'),
                      _InfoRow('Resort', 'Anjanvel Agro Tourism Resort'),
                      _InfoRow('Version', '1.0.0'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Sign out
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signOut,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppTheme.error))
                          : const Icon(Icons.logout_rounded,
                              color: AppTheme.error),
                      label: const Text('Sign Out',
                          style: TextStyle(
                              color: AppTheme.error, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.error),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  void _showChangePassword() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureNew = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Change Password',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: newCtrl,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscureNew
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setModal(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (newCtrl.text != confirmCtrl.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Passwords do not match'),
                            backgroundColor: AppTheme.error),
                      );
                      return;
                    }
                    if (newCtrl.text.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Password must be at least 6 characters'),
                            backgroundColor: AppTheme.error),
                      );
                      return;
                    }
                    try {
                      await ref
                          .read(supabaseClientProvider)
                          .auth
                          .updateUser(UserAttributes(password: newCtrl.text));
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Password changed successfully'),
                              backgroundColor: AppTheme.success),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: AppTheme.error),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48)),
                  child: const Text('Update Password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final user = ref.read(currentUserProvider);
    // In demo mode, just go to role selection
    if (user == null) {
      context.go('/role-selection');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (mounted) context.go('/role-selection');
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard(
      {required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const Divider(height: 16),
          ...children,
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13))),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: valueColor)),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionRow(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.primary),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500))),
            const Icon(Icons.chevron_right, color: AppTheme.textPrimary),
          ],
        ),
      ),
    );
  }
}
