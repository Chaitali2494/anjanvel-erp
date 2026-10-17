import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../housekeeping/data/housekeeping_provider.dart';

class CleaningChecklistScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? task;
  const CleaningChecklistScreen({super.key, this.task});

  @override
  ConsumerState<CleaningChecklistScreen> createState() => _CleaningChecklistScreenState();
}

class _CleaningChecklistScreenState extends ConsumerState<CleaningChecklistScreen> {
  bool _isSaving = false;
  String? _beforePhotoNote;
  String? _afterPhotoNote;

  final List<_CheckItem> _items = [
    _CheckItem('Bed Made', 'Sheets changed, pillows arranged, bed spread neat', Icons.bed_rounded),
    _CheckItem('Bathroom Cleaned', 'Toilet, sink, shower scrubbed and disinfected', Icons.bathroom_rounded),
    _CheckItem('Towels Replaced', 'Fresh towels placed, used ones removed', Icons.dry_cleaning_rounded),
    _CheckItem('Dusting Done', 'Furniture, fan blades, windows, corners', Icons.cleaning_services_rounded),
    _CheckItem('Water Bottles Refilled', '2 sealed bottles placed on table', Icons.water_drop_rounded),
    _CheckItem('Floor Mopped', 'Swept and mopped, no stains remaining', Icons.do_not_step_rounded),
    _CheckItem('Trash Emptied', 'All bins emptied and lined with fresh bags', Icons.delete_outline_rounded),
    _CheckItem('AC/Lights Checked', 'AC filter clean, all switches functional', Icons.thermostat_rounded),
    _CheckItem('Amenities Restocked', 'Soap, shampoo, toothbrush kit topped up', Icons.soap_rounded),
    _CheckItem('Room Fragrance Applied', 'Light spray applied', Icons.spa_rounded),
  ];

  String get _roomNumber => (widget.task?['rooms'] as Map?)?['room_number']?.toString()
      ?? widget.task?['room_number']?.toString() ?? 'Room';

  int get _completedCount => _items.where((i) => i.checked).length;
  bool get _allDone => _completedCount == _items.length;

  @override
  Widget build(BuildContext context) {
    final pct = (_completedCount / _items.length * 100).round();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'Cleaning Checklist — $_roomNumber'),
      body: Column(
        children: [
          // Progress header
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surface,
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$_completedCount / ${_items.length} tasks completed',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(_allDone ? '✅ Room is ready!' : 'Keep going — almost there!',
                        style: TextStyle(color: _allDone ? AppTheme.success : AppTheme.textHint, fontSize: 12)),
                  ])),
                  Stack(alignment: Alignment.center, children: [
                    SizedBox(
                      width: 56, height: 56,
                      child: CircularProgressIndicator(
                        value: _completedCount / _items.length,
                        strokeWidth: 5,
                        backgroundColor: Colors.grey.shade200,
                        color: _allDone ? AppTheme.success : const Color(0xFF6A1B9A),
                      ),
                    ),
                    Text('$pct%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ]),
                ]),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: _completedCount / _items.length,
                  backgroundColor: Colors.grey.shade200,
                  color: _allDone ? AppTheme.success : const Color(0xFF6A1B9A),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ),

          // Checklist
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Checklist items
                ...List.generate(_items.length, (i) {
                  final item = _items[i];
                  return GestureDetector(
                    onTap: () => setState(() => item.checked = !item.checked),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: item.checked ? AppTheme.success.withOpacity(0.06) : AppTheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        border: Border.all(color: item.checked ? AppTheme.success.withOpacity(0.4) : Colors.grey.shade200),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)],
                      ),
                      child: Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: item.checked ? AppTheme.success : Colors.grey.shade100,
                            shape: BoxShape.circle,
                            border: Border.all(color: item.checked ? AppTheme.success : Colors.grey.shade300),
                          ),
                          child: item.checked
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                              : Icon(item.icon, color: AppTheme.textPrimary, size: 14),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.label, style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14,
                            decoration: item.checked ? TextDecoration.lineThrough : null,
                            color: item.checked ? AppTheme.textHint : AppTheme.textPrimary,
                          )),
                          Text(item.description, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
                        ])),
                      ]),
                    ),
                  );
                }),

                const SizedBox(height: 16),

                // Photo upload section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.camera_alt_outlined, size: 18, color: AppTheme.textPrimary),
                        SizedBox(width: 8),
                        Text('Photo Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _PhotoUploadBox(
                          label: 'Before Photo',
                          note: _beforePhotoNote,
                          icon: Icons.camera_rear_outlined,
                          color: const Color(0xFFE53935),
                          onTap: () => setState(() => _beforePhotoNote = 'Photo captured'),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _PhotoUploadBox(
                          label: 'After Photo',
                          note: _afterPhotoNote,
                          icon: Icons.camera_front_outlined,
                          color: AppTheme.success,
                          onTap: () => setState(() => _afterPhotoNote = 'Photo captured'),
                        )),
                      ]),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Quick mark all button
                OutlinedButton.icon(
                  onPressed: () => setState(() { for (final i in _items) i.checked = true; }),
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text('Mark All Complete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6A1B9A),
                    side: const BorderSide(color: Color(0xFF6A1B9A)),
                    minimumSize: const Size(double.infinity, 46),
                  ),
                ),
                const SizedBox(height: 10),

                // Submit
                ElevatedButton(
                  onPressed: _allDone && !_isSaving ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    minimumSize: const Size(double.infinity, 52),
                    disabledBackgroundColor: Colors.grey.shade200,
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_allDone ? '✅  Submit — Room Ready' : 'Complete all items to submit',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    try {
      final taskId = widget.task?['id'] as String?;
      if (taskId != null) {
        // Uses notifier — handles both local (timestamp) IDs and real Supabase UUIDs
        await ref.read(housekeepingTasksProvider.notifier).updateStatus(taskId, 'COMPLETED');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room marked as ready!'), backgroundColor: AppTheme.success),
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

class _CheckItem {
  final String label, description;
  final IconData icon;
  bool checked;
  _CheckItem(this.label, this.description, this.icon, {this.checked = false});
}

class _PhotoUploadBox extends StatelessWidget {
  final String label;
  final String? note;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _PhotoUploadBox({required this.label, this.note, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final uploaded = note != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: uploaded ? color.withOpacity(0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(
            color: uploaded ? color : Colors.grey.shade300,
            style: uploaded ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(uploaded ? Icons.check_circle_rounded : icon,
              color: uploaded ? color : Colors.grey.shade400, size: 28),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: uploaded ? color : Colors.grey.shade500)),
          if (uploaded)
            Text(note!, style: TextStyle(fontSize: 10, color: color)),
          if (!uploaded)
            Text('Tap to upload', style: TextStyle(fontSize: 10, color: AppTheme.textPrimary)),
        ]),
      ),
    );
  }
}
