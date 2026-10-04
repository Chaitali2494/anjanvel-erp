import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/activity_bookings_provider.dart';

class ActivityRegistrationScreen extends ConsumerStatefulWidget {
  /// Pre-selected activity id (optional — from activity list tap)
  final String activityId;
  const ActivityRegistrationScreen({super.key, required this.activityId});

  @override
  ConsumerState<ActivityRegistrationScreen> createState() =>
      _ActivityRegistrationScreenState();
}

class _ActivityRegistrationScreenState
    extends ConsumerState<ActivityRegistrationScreen> {
  // ── Form state ──────────────────────────────────────────────────────────────

  Map<String, dynamic>? _selectedRoom;
  Map<String, dynamic>? _selectedActivity;
  int _persons = 1;
  DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  final _guestCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isSaving = false;

  static const _accentColor = Color(0xFF00838F);

  @override
  void initState() {
    super.initState();
    // Pre-select activity if id provided
    if (widget.activityId.isNotEmpty) {
      try {
        _selectedActivity = kActivityCatalogue.firstWhere(
          (a) => a['id'] == widget.activityId,
        );
      } catch (_) {
        _selectedActivity = kActivityCatalogue.first;
      }
    }
  }

  @override
  void dispose() {
    _guestCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _pricePerPerson =>
      (_selectedActivity?['price'] as num?)?.toDouble() ?? 0.0;
  double get _total => _pricePerPerson * _persons;

  String get _formattedDate => DateFormat('EEE, d MMM yyyy').format(_date);
  String get _formattedTime => _time.format(context);

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'Book Activity'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header card ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00838F), Color(0xFF00ACC1)],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              ),
              child: Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                  child: Center(
                    child: Text(
                      _selectedActivity?['emoji'] as String? ?? '🎯',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    _selectedActivity?['name'] as String? ?? 'Select an Activity',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (_selectedActivity != null)
                    Text(
                      '${_selectedActivity!['category']} · ${_selectedActivity!['duration']}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                ])),
                if (_total > 0)
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('Total', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    Text('₹${_total.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                  ]),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Activity selector ──────────────────────────────────────────
            _SectionLabel('Activity *'),
            _Card(
              child: DropdownButtonFormField<Map<String, dynamic>>(
                value: _selectedActivity,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.hiking_rounded, color: _accentColor, size: 20),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                hint: const Text('Select activity'),
                items: kActivityCatalogue.map((a) => DropdownMenuItem(
                  value: a,
                  child: Row(children: [
                    Text(a['emoji'] as String, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${a['name']} — ₹${(a['price'] as num).toStringAsFixed(0)}/person',
                        style: const TextStyle(fontSize: 13))),
                  ]),
                )).toList(),
                onChanged: (v) => setState(() => _selectedActivity = v),
              ),
            ),
            const SizedBox(height: 14),

            // ── Room (from check-in list) ──────────────────────────────────
            _SectionLabel('Room (Checked-In) *'),
            _Card(
              child: DropdownButtonFormField<Map<String, dynamic>>(
                value: _selectedRoom,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.bed_outlined, color: _accentColor, size: 20),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                hint: const Text('Select room'),
                items: kCheckedInRooms.map((r) => DropdownMenuItem(
                  value: r,
                  child: Text(
                    'Room ${r['room_number']} — ${r['guest_name']} (${r['room_type']})',
                    style: const TextStyle(fontSize: 13),
                  ),
                )).toList(),
                onChanged: (v) => setState(() {
                  _selectedRoom = v;
                  if (v != null && _guestCtrl.text.isEmpty) {
                    _guestCtrl.text = v['guest_name'] as String? ?? '';
                  }
                }),
              ),
            ),
            const SizedBox(height: 14),

            // ── Number of persons ──────────────────────────────────────────
            _SectionLabel('Number of Persons *'),
            _Card(
              child: Row(children: [
                const Icon(Icons.group_rounded, color: _accentColor, size: 20),
                const SizedBox(width: 12),
                const Text('Persons', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const Spacer(),
                IconButton(
                  onPressed: _persons > 1 ? () => setState(() => _persons--) : null,
                  icon: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _persons > 1 ? _accentColor.withOpacity(0.1) : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.remove_rounded, size: 18,
                        color: _persons > 1 ? _accentColor : Colors.grey),
                  ),
                  padding: EdgeInsets.zero,
                ),
                Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Text('$_persons',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: _accentColor)),
                ),
                IconButton(
                  onPressed: _persons < 20 ? () => setState(() => _persons++) : null,
                  icon: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_rounded, size: 18, color: _accentColor),
                  ),
                  padding: EdgeInsets.zero,
                ),
                if (_pricePerPerson > 0) ...[
                  const SizedBox(width: 8),
                  Text('= ₹${_total.toStringAsFixed(0)}',
                      style: const TextStyle(color: _accentColor, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ]),
            ),
            const SizedBox(height: 14),

            // ── Date & Time row ────────────────────────────────────────────
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SectionLabel('Date *'),
                _Card(
                  onTap: _pickDate,
                  child: Row(children: [
                    const Icon(Icons.calendar_today_rounded, color: _accentColor, size: 18),
                    const SizedBox(width: 10),
                    Text(_formattedDate, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SectionLabel('Time *'),
                _Card(
                  onTap: _pickTime,
                  child: Row(children: [
                    const Icon(Icons.access_time_rounded, color: _accentColor, size: 18),
                    const SizedBox(width: 10),
                    Text(_formattedTime, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ])),
            ]),
            const SizedBox(height: 14),

            // ── Guest name (auto-filled from room) ─────────────────────────
            _SectionLabel('Guest Name'),
            _Card(
              child: TextField(
                controller: _guestCtrl,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.person_outline_rounded, color: _accentColor, size: 20),
                  hintText: 'Auto-filled from room selection',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Special notes ──────────────────────────────────────────────
            _SectionLabel('Special Notes'),
            _Card(
              child: TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Icon(Icons.notes_rounded, color: _accentColor, size: 20),
                  ),
                  hintText: 'Any special requirements...',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Price summary ──────────────────────────────────────────────
            if (_selectedActivity != null)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(color: _accentColor.withOpacity(0.2)),
                ),
                child: Column(children: [
                  _PriceRow('Activity', _selectedActivity!['name'] as String),
                  _PriceRow('Price/Person', '₹${_pricePerPerson.toStringAsFixed(0)}'),
                  _PriceRow('Persons', '$_persons'),
                  const Divider(height: 16),
                  Row(children: [
                    const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Spacer(),
                    Text('₹${_total.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _accentColor)),
                  ]),
                  const SizedBox(height: 4),
                  Text('(will appear in Room ${_selectedRoom?['room_number'] ?? '—'} checkout bill)',
                      style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
                ]),
              ),

            // ── Submit ─────────────────────────────────────────────────────
            ElevatedButton(
              onPressed: _canSubmit && !_isSaving ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
                disabledBackgroundColor: Colors.grey.shade200,
              ),
              child: _isSaving
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm Booking',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  bool get _canSubmit => _selectedActivity != null && _selectedRoom != null;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _accentColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _accentColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(activityBookingsProvider.notifier).addBooking({
        'room_number':      _selectedRoom!['room_number'],
        'guest_name':       _guestCtrl.text.trim().isEmpty
                              ? (_selectedRoom!['guest_name'] ?? '')
                              : _guestCtrl.text.trim(),
        'activity_id':      _selectedActivity!['id'],
        'activity_name':    _selectedActivity!['name'],
        'activity_emoji':   _selectedActivity!['emoji'],
        'category':         _selectedActivity!['category'],
        'persons':          _persons,
        'price_per_person': _pricePerPerson,
        'total_amount':     _total,
        'date':             DateFormat('yyyy-MM-dd').format(_date),
        'time':             _time.format(context),
        'notes':            _notesCtrl.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '✅ ${_selectedActivity!['name']} booked for Room ${_selectedRoom!['room_number']} — '
            '₹${_total.toStringAsFixed(0)} added to bill',
          ),
          backgroundColor: _accentColor,
          duration: const Duration(seconds: 3),
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ── Small reusable widgets ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(
        fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
  );
}

class _Card extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _Card({required this.child, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: child,
    ),
  );
}

class _PriceRow extends StatelessWidget {
  final String label, value;
  const _PriceRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      const Spacer(),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    ]),
  );
}
