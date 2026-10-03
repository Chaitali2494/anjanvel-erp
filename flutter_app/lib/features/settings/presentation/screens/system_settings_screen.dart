import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});
  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  bool _maintenanceMode = false;
  bool _autoBackup      = true;
  bool _emailNotifs     = true;
  bool _smsAlerts       = false;
  String _currency      = 'INR';
  String _taxRate       = '12';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const AnjAppBar(title: 'System Settings'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // General section
          _SectionHeader('General'),
          _SettingsTile(
            icon: Icons.business_rounded,
            color: const Color(0xFF1565C0),
            title: 'Resort Name',
            subtitle: 'Anjanvel Agro Tourism Resort',
            onTap: () => _editText(context, 'Resort Name', 'Anjanvel Agro Tourism Resort'),
          ),
          _SettingsTile(
            icon: Icons.phone_rounded,
            color: const Color(0xFF2E7D32),
            title: 'Contact Number',
            subtitle: '+91 9876543210',
            onTap: () => _editText(context, 'Contact Number', '+91 9876543210'),
          ),
          _SettingsTile(
            icon: Icons.email_rounded,
            color: const Color(0xFF00838F),
            title: 'Email Address',
            subtitle: 'info@anjanvel.com',
            onTap: () => _editText(context, 'Email', 'info@anjanvel.com'),
          ),
          _SettingsTile(
            icon: Icons.location_on_rounded,
            color: const Color(0xFF6A1B9A),
            title: 'Address',
            subtitle: 'Anjanvel Village, Maharashtra',
            onTap: () => _editText(context, 'Address', 'Anjanvel Village, Maharashtra, India'),
          ),
          const SizedBox(height: 20),

          // Finance
          _SectionHeader('Finance & Tax'),
          _SettingsTile(
            icon: Icons.currency_rupee_rounded,
            color: const Color(0xFF558B2F),
            title: 'Currency',
            subtitle: _currency,
            onTap: () => _showPicker(context, 'Currency', ['INR', 'USD', 'EUR'], _currency, (v) => setState(() => _currency = v)),
          ),
          _SettingsTile(
            icon: Icons.percent_rounded,
            color: const Color(0xFF00796B),
            title: 'Default Tax Rate (%)',
            subtitle: '$_taxRate%',
            onTap: () => _editText(context, 'Tax Rate (%)', _taxRate),
          ),
          _SettingsTile(
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF4527A0),
            title: 'GST Number',
            subtitle: '27XXXXXXXXXXXZX',
            onTap: () => _editText(context, 'GST Number', '27XXXXXXXXXXXZX'),
          ),
          const SizedBox(height: 20),

          // Notifications
          _SectionHeader('Notifications'),
          _SwitchTile(
            icon: Icons.email_outlined,
            color: const Color(0xFF1565C0),
            title: 'Email Notifications',
            subtitle: 'Booking confirmations and alerts',
            value: _emailNotifs,
            onChanged: (v) => setState(() => _emailNotifs = v),
          ),
          _SwitchTile(
            icon: Icons.sms_rounded,
            color: const Color(0xFF2E7D32),
            title: 'SMS Alerts',
            subtitle: 'Staff and guest SMS notifications',
            value: _smsAlerts,
            onChanged: (v) => setState(() => _smsAlerts = v),
          ),
          const SizedBox(height: 20),

          // System
          _SectionHeader('System'),
          _SwitchTile(
            icon: Icons.backup_rounded,
            color: const Color(0xFF00796B),
            title: 'Auto Backup',
            subtitle: 'Daily backup to cloud storage',
            value: _autoBackup,
            onChanged: (v) => setState(() => _autoBackup = v),
          ),
          _SwitchTile(
            icon: Icons.construction_rounded,
            color: const Color(0xFFE53935),
            title: 'Maintenance Mode',
            subtitle: 'Block access for all non-admin users',
            value: _maintenanceMode,
            onChanged: (v) => _confirmMaintenanceMode(context, v),
          ),
          const SizedBox(height: 16),

          // Admin links
          _SectionHeader('Admin'),
          _SettingsTile(
            icon: Icons.people_rounded,
            color: const Color(0xFF37474F),
            title: 'User Management',
            subtitle: 'Manage staff accounts and permissions',
            onTap: () => context.push('/settings/users'),
          ),
          _SettingsTile(
            icon: Icons.history_rounded,
            color: const Color(0xFF37474F),
            title: 'Audit Log',
            subtitle: 'View all system activity',
            onTap: () => context.push('/settings/audit-log'),
          ),
          const SizedBox(height: 24),

          // Save
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings saved'), backgroundColor: AppTheme.success),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF37474F),
              minimumSize: const Size(double.infinity, 52),
            ),
            child: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _editText(BuildContext context, String label, String current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final ctrl = TextEditingController(text: current);
        return Padding(
          padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit $label', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              TextField(controller: ctrl, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF37474F), minimumSize: const Size(double.infinity, 48)),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPicker(BuildContext context, String label, List<String> options, String current, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select $label', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            ...options.map((o) => ListTile(
              title: Text(o),
              trailing: o == current ? const Icon(Icons.check_rounded, color: AppTheme.success) : null,
              onTap: () { onSelect(o); Navigator.pop(context); },
            )),
          ],
        ),
      ),
    );
  }

  void _confirmMaintenanceMode(BuildContext context, bool enable) {
    if (!enable) { setState(() => _maintenanceMode = false); return; }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enable Maintenance Mode?'),
        content: const Text('This will block all non-admin users from accessing the system. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { setState(() => _maintenanceMode = true); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override Widget build(_) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textHint, letterSpacing: 0.5)),
  );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon; final Color color; final String title, subtitle; final VoidCallback onTap;
  const _SettingsTile({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});
  @override Widget build(_) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(AppTheme.radiusMD), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)]),
      child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text(subtitle, style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
        ])),
        const Icon(Icons.chevron_right_rounded, color: AppTheme.textHint, size: 20),
      ]),
    ),
  );
}

class _SwitchTile extends StatelessWidget {
  final IconData icon; final Color color; final String title, subtitle; final bool value; final ValueChanged<bool> onChanged;
  const _SwitchTile({required this.icon, required this.color, required this.title, required this.subtitle, required this.value, required this.onChanged});
  @override Widget build(_) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(AppTheme.radiusMD), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)]),
    child: Row(children: [
      Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        Text(subtitle, style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
      ])),
      Switch(value: value, onChanged: onChanged, activeColor: color),
    ]),
  );
}
