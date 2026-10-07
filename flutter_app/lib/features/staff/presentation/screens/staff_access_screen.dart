import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/staff_access_provider.dart';

class StaffAccessScreen extends ConsumerWidget {
  const StaffAccessScreen({super.key});

  static const _deptColors = {
    'Housekeeping':  Color(0xFF6A1B9A),
    'Kitchen':       Color(0xFFE64A19),
    'Reception':     Color(0xFF1565C0),
    'Activities':    Color(0xFF00838F),
    'Tour Guide':    Color(0xFF2E7D32),
    'Security':      Color(0xFF37474F),
    'Maintenance':   Color(0xFFF57C00),
    'Shop':          Color(0xFF558B2F),
    'Management':    Color(0xFF880E4F),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffList = ref.watch(staffAccessProvider);
    final active   = staffList.where((s) => s['is_active'] == true).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const AnjAppBar(title: 'Staff Access'),
      body: Column(children: [
        // Summary strip
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            _Strip('Total', '${staffList.length}', AppTheme.primary),
            _Strip('Active', '$active', AppTheme.success),
            _Strip('Signed In',
                '${staffList.where((s) => s['is_signed_in'] == true).length}',
                AppTheme.info),
            _Strip('On Leave',
                '${staffList.where((s) => s['is_active'] == false).length}',
                AppTheme.warning),
          ]),
        ),
        const Divider(height: 0),

        // Staff list
        Expanded(
          child: staffList.isEmpty
              ? const Center(child: Text('No staff added yet. Tap + to add.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: staffList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final s = staffList[i];
                    final isActive   = s['is_active'] as bool;
                    final isSignedIn = s['is_signed_in'] as bool;
                    final dept       = s['department'] as String;
                    final dColor     = _deptColors[dept] ?? AppTheme.primary;

                    return Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                      ),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: dColor.withOpacity(0.15),
                          child: Text(
                            (s['name'] as String).substring(0, 1).toUpperCase(),
                            style: TextStyle(
                                color: dColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                        ),
                        title: Text(s['name'] as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: dColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(dept,
                                    style: TextStyle(
                                        color: dColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 6),
                              if (isSignedIn)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text('Signed In',
                                      style: TextStyle(
                                          color: AppTheme.success,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                ),
                            ]),
                            const SizedBox(height: 2),
                            Text('📱 ${s['mobile']}  ·  PIN: ${s['pin']}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textPrimary)),
                          ],
                        ),
                        trailing: Switch(
                          value: isActive,
                          activeColor: AppTheme.success,
                          onChanged: (_) =>
                              ref.read(staffAccessProvider.notifier)
                                  .toggleActive(s['id'] as String),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Staff'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    final nameCtrl   = TextEditingController();
    final mobileCtrl = TextEditingController();
    final pinCtrl    = TextEditingController();
    String dept      = kDepartments.first;
    String role      = 'HOUSEKEEPING';

    final deptToRole = {
      'Housekeeping': 'HOUSEKEEPING',
      'Kitchen':      'KITCHEN',
      'Reception':    'RECEPTION',
      'Activities':   'ACTIVITY_COORDINATOR',
      'Tour Guide':   'TOUR_GUIDE',
      'Security':     'SECURITY',
      'Maintenance':  'MAINTENANCE',
      'Shop':         'SHOP_OPERATOR',
      'Management':   'MANAGER',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle bar
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Add Staff Member',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),

            _SheetField(ctrl: nameCtrl, label: 'Full Name', icon: Icons.person_outline),
            const SizedBox(height: 12),
            _SheetField(
              ctrl: mobileCtrl, label: 'Mobile Number', icon: Icons.phone_outlined,
              keyboard: TextInputType.phone,
              formatters: [FilteringTextInputFormatter.digitsOnly,
                           LengthLimitingTextInputFormatter(10)],
            ),
            const SizedBox(height: 12),
            _SheetField(
              ctrl: pinCtrl, label: '4-digit PIN', icon: Icons.lock_outline,
              keyboard: TextInputType.number, obscure: true,
              formatters: [FilteringTextInputFormatter.digitsOnly,
                           LengthLimitingTextInputFormatter(4)],
            ),
            const SizedBox(height: 12),

            // Department dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: dept,
                  isExpanded: true,
                  hint: const Text('Department'),
                  items: kDepartments.map((d) => DropdownMenuItem(
                    value: d,
                    child: Text(d),
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setSheetState(() {
                        dept = v;
                        role = deptToRole[v] ?? 'STAFF';
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty ||
                    mobileCtrl.text.trim().length < 10 ||
                    pinCtrl.text.trim().length < 4) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Fill all fields correctly')));
                  return;
                }
                ref.read(staffAccessProvider.notifier).addStaff(
                  name:       nameCtrl.text.trim(),
                  mobile:     mobileCtrl.text.trim(),
                  pin:        pinCtrl.text.trim(),
                  department: dept,
                  role:       role,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${nameCtrl.text.trim()} added successfully'),
                    backgroundColor: AppTheme.success));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Add Staff Member',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Strip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Strip(this.label, this.value, this.color);
  @override
  Widget build(_) => Expanded(
    child: Column(children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textPrimary)),
    ]),
  );
}

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType keyboard;
  final List<TextInputFormatter>? formatters;
  final bool obscure;

  const _SheetField({
    required this.ctrl, required this.label, required this.icon,
    this.keyboard = TextInputType.text,
    this.formatters, this.obscure = false,
  });

  @override
  Widget build(_) => TextField(
    controller: ctrl,
    keyboardType: keyboard,
    inputFormatters: formatters,
    obscureText: obscure,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
  );
}
