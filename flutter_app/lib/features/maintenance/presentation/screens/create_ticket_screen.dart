import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';

class CreateTicketScreen extends ConsumerStatefulWidget {
  const CreateTicketScreen({super.key});
  @override
  ConsumerState<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends ConsumerState<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl    = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl    = TextEditingController();
  String _category = 'ELECTRICAL';
  String _priority = 'MEDIUM';
  bool _isSaving = false;

  static const _categories = ['ELECTRICAL', 'PLUMBING', 'FURNITURE', 'EQUIPMENT', 'CIVIL', 'OTHER'];
  static const _priorities = ['HIGH', 'MEDIUM', 'LOW'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const AnjAppBar(title: 'Create Maintenance Ticket'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Title
            _Label('Issue Title *'),
            TextFormField(
              controller: _titleCtrl,
              decoration: _dec('Brief description of the issue', Icons.title_rounded),
              validator: (v) => (v?.isEmpty ?? true) ? 'Title required' : null,
            ),
            const SizedBox(height: 16),

            // Location
            _Label('Location / Room *'),
            TextFormField(
              controller: _locationCtrl,
              decoration: _dec('e.g. Room 205, Restaurant, Pool Area', Icons.location_on_outlined),
              validator: (v) => (v?.isEmpty ?? true) ? 'Location required' : null,
            ),
            const SizedBox(height: 16),

            // Category
            _Label('Category *'),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: _dec('Select category', Icons.category_outlined),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c.replaceAll('_', ' '), style: const TextStyle(fontSize: 14)))).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 16),

            // Priority
            _Label('Priority'),
            Row(children: _priorities.map((p) {
              final selected = _priority == p;
              final color = p == 'HIGH' ? const Color(0xFFE53935) : p == 'MEDIUM' ? const Color(0xFFFFB300) : const Color(0xFF9E9E9E);
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _priority = p),
                  child: Container(
                    margin: EdgeInsets.only(right: p != 'LOW' ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? color : color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(color: selected ? color : color.withOpacity(0.3)),
                    ),
                    child: Text(p, style: TextStyle(color: selected ? Colors.white : color, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
                  ),
                ),
              );
            }).toList()),
            const SizedBox(height: 16),

            // Notes
            _Label('Additional Notes'),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: _dec('Describe the issue in detail...', Icons.note_outlined),
            ),
            const SizedBox(height: 32),

            // Submit
            ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF37474F),
                minimumSize: const Size(double.infinity, 52),
              ),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create Ticket', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, size: 20, color: AppTheme.textHint),
    filled: true, fillColor: AppTheme.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMD), borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMD), borderSide: BorderSide(color: Colors.grey.shade200)),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('maintenance_tickets').insert({
        'title': _titleCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'category': _category,
        'priority': _priority,
        'status': 'OPEN',
        'notes': _notesCtrl.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket created successfully'), backgroundColor: AppTheme.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override Widget build(_) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
  );
}
