import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/activity_bookings_provider.dart';

class ActivityRegistrationScreen extends ConsumerStatefulWidget {
  final String activityId;
  const ActivityRegistrationScreen({super.key, required this.activityId});

  @override
  ConsumerState<ActivityRegistrationScreen> createState() =>
      _ActivityRegistrationScreenState();
}

class _ActivityRegistrationScreenState
    extends ConsumerState<ActivityRegistrationScreen> {
  static const _accent = Color(0xFF00838F);

  // Top fields
  final _roomCtrl  = TextEditingController();
  final _guestCtrl = TextEditingController();

  // Selected activity + per-activity state
  Map<String, dynamic>? _selectedActivity;
  int _persons = 1;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.activityId.isNotEmpty) {
      try {
        _selectedActivity = kActivityCatalogue
            .firstWhere((a) => a['id'] == widget.activityId);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _roomCtrl.dispose();
    _guestCtrl.dispose();
    super.dispose();
  }

  double get _price => (_selectedActivity?['price'] as num?)?.toDouble() ?? 0;
  double get _total => _price * _persons;
  bool get _canSubmit =>
      _selectedActivity != null && _roomCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const AnjAppBar(title: 'Book Activity'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Room Number ────────────────────────────────────────────────
            _sectionLabel('Room Number'),
            const SizedBox(height: 6),
            _Field(
              controller: _roomCtrl,
              icon: Icons.bed_outlined,
              hint: 'e.g. 101, 205, Tent-3',
              onChanged: (_) => setState(() {}),
              inputFormatters: [LengthLimitingTextInputFormatter(10)],
            ),
            const SizedBox(height: 8),
            // Quick room chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: kCheckedInRooms.map((r) {
                final rno = r['room_number'] as String;
                final isActive = _roomCtrl.text.trim() == rno;
                return GestureDetector(
                  onTap: () => setState(() {
                    _roomCtrl.text = rno;
                    if (_guestCtrl.text.isEmpty) {
                      _guestCtrl.text = r['guest_name'] as String? ?? '';
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? _accent : _accent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Room $rno · ${r['guest_name']}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isActive ? Colors.white : _accent,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── Guest Name ─────────────────────────────────────────────────
            _sectionLabel('Guest Name'),
            const SizedBox(height: 6),
            _Field(
              controller: _guestCtrl,
              icon: Icons.person_outline_rounded,
              hint: 'Auto-filled when selecting room above',
              capitalize: true,
            ),
            const SizedBox(height: 24),

            // ── Select Activity ────────────────────────────────────────────
            _sectionLabel('Select Activity'),
            const SizedBox(height: 8),
            ...kActivityCatalogue.map((a) {
              final isSelected = _selectedActivity?['id'] == a['id'];
              return _ActivityTile(
                activity: a,
                isSelected: isSelected,
                persons: isSelected ? _persons : 1,
                time: isSelected ? _time : const TimeOfDay(hour: 9, minute: 0),
                onTap: () => setState(() {
                  if (isSelected) {
                    _selectedActivity = null;
                  } else {
                    _selectedActivity = a;
                    _persons = 1;
                    _time = const TimeOfDay(hour: 9, minute: 0);
                  }
                }),
                onPersonsChanged: (v) => setState(() => _persons = v),
                onTimePick: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: _time,
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                          colorScheme: const ColorScheme.light(primary: _accent)),
                      child: child!,
                    ),
                  );
                  if (t != null) setState(() => _time = t);
                },
              );
            }),
            const SizedBox(height: 24),

            // ── Bill summary ───────────────────────────────────────────────
            if (_selectedActivity != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  border: Border.all(color: _accent.withOpacity(0.25)),
                ),
                child: Column(children: [
                  _BillRow('Activity',       _selectedActivity!['name'] as String),
                  _BillRow('Duration',       _selectedActivity!['duration'] as String),
                  _BillRow('Rate',           '₹${_price.toStringAsFixed(0)} / person'),
                  _BillRow('Persons',        '$_persons'),
                  const Divider(height: 16),
                  Row(children: [
                    const Text('Total',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Spacer(),
                    Text('₹${_total.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 22, color: _accent)),
                  ]),
                  if (_roomCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.add_circle_outline_rounded, size: 14, color: _accent),
                      const SizedBox(width: 4),
                      Text(
                        'Will be added to Room ${_roomCtrl.text.trim()} bill',
                        style: const TextStyle(color: _accent, fontSize: 12),
                      ),
                    ]),
                  ],
                ]),
              ),
              const SizedBox(height: 20),
            ],

            // ── Add to Bill button ─────────────────────────────────────────
            ElevatedButton(
              onPressed: _canSubmit && !_isSaving ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _selectedActivity != null
                            ? 'Add to Bill  ·  ₹${_total.toStringAsFixed(0)}'
                            : 'Add to Bill',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                    ]),
            ),
            if (!_canSubmit)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _selectedActivity == null
                      ? 'Please select an activity above'
                      : 'Please enter a room number',
                  style: const TextStyle(color: AppTheme.error, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
      );

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    final roomNo    = _roomCtrl.text.trim();
    final guestName = _guestCtrl.text.trim().isEmpty
        ? (kCheckedInRooms
                .where((r) => r['room_number'] == roomNo)
                .map((r) => r['guest_name'] as String? ?? '')
                .firstOrNull ?? 'Guest')
        : _guestCtrl.text.trim();

    try {
      await ref.read(activityBookingsProvider.notifier).addBooking({
        'room_number':      roomNo,
        'guest_name':       guestName,
        'activity_id':      _selectedActivity!['id'],
        'activity_name':    _selectedActivity!['name'],
        'activity_emoji':   _selectedActivity!['emoji'],
        'category':         _selectedActivity!['category'],
        'persons':          _persons,
        'price_per_person': _price,
        'total_amount':     _total,
        'date':             DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'time':             _time.format(context),
        'notes':            '',
      });

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.check_circle_rounded, color: _accent, size: 28),
              SizedBox(width: 10),
              Text('Booking Confirmed'),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_selectedActivity!['emoji']}  ${_selectedActivity!['name']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text('Persons: $_persons'),
                Text('Time: ${_time.format(context)}'),
                Text('Room: $roomNo'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.receipt_rounded, color: _accent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '₹${_total.toStringAsFixed(0)} added to Room $roomNo bill',
                      style: const TextStyle(
                          color: _accent, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _selectedActivity = null;
                    _persons = 1;
                    _roomCtrl.clear();
                    _guestCtrl.clear();
                    _time = const TimeOfDay(hour: 9, minute: 0);
                  });
                },
                child: const Text('Add Another'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _accent),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.pop();
                },
                child: const Text('Done', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ── Activity Tile with inline expansion ───────────────────────────────────────

class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> activity;
  final bool isSelected;
  final int persons;
  final TimeOfDay time;
  final VoidCallback onTap;
  final ValueChanged<int> onPersonsChanged;
  final VoidCallback onTimePick;

  const _ActivityTile({
    required this.activity,
    required this.isSelected,
    required this.persons,
    required this.time,
    required this.onTap,
    required this.onPersonsChanged,
    required this.onTimePick,
  });

  static const _accent = Color(0xFF00838F);

  @override
  Widget build(BuildContext context) {
    final price = (activity['price'] as num).toDouble();
    final total = price * persons;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? _accent.withOpacity(0.07) : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(
            color: isSelected ? _accent : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? _accent.withOpacity(0.12)
                  : Colors.black.withOpacity(0.04),
              blurRadius: isSelected ? 8 : 4,
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Main row ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                // Emoji
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: isSelected ? _accent.withOpacity(0.15) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(activity['emoji'] as String,
                        style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 12),
                // Name + info
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      activity['name'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isSelected ? _accent : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${activity['category']} · ${activity['duration']}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                    ),
                  ]),
                ),
                // Price
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    '₹${price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isSelected ? _accent : AppTheme.textPrimary,
                    ),
                  ),
                  const Text('/person',
                      style: TextStyle(fontSize: 10, color: AppTheme.textPrimary)),
                ]),
                const SizedBox(width: 8),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? _accent : Colors.grey.shade400,
                  size: 22,
                ),
              ]),
            ),

            // ── Inline expansion: persons + time ─────────────────────────
            if (isSelected) ...[
              Divider(height: 0, color: _accent.withOpacity(0.2)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(children: [
                  // Persons row
                  Row(children: [
                    const Icon(Icons.group_rounded, color: _accent, size: 18),
                    const SizedBox(width: 8),
                    const Text('Persons',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const Spacer(),
                    // Decrease
                    _CircleBtn(
                      icon: Icons.remove_rounded,
                      enabled: persons > 1,
                      onTap: () => onPersonsChanged(persons - 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('$persons',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 22, color: _accent)),
                    ),
                    // Increase
                    _CircleBtn(
                      icon: Icons.add_rounded,
                      enabled: persons < 30,
                      onTap: () => onPersonsChanged(persons + 1),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '= ₹${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: _accent, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ]),
                  const SizedBox(height: 10),

                  // Time slot row
                  GestureDetector(
                    onTap: onTimePick,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _accent.withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.access_time_rounded, color: _accent, size: 18),
                        const SizedBox(width: 8),
                        const Text('Time Slot',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const Spacer(),
                        Text(
                          time.format(context),
                          style: const TextStyle(
                              color: _accent, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.edit_rounded, color: _accent, size: 14),
                      ]),
                    ),
                  ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final bool capitalize;

  const _Field({
    required this.controller,
    required this.icon,
    required this.hint,
    this.onChanged,
    this.inputFormatters,
    this.capitalize = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
    ),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      textCapitalization:
          capitalize ? TextCapitalization.words : TextCapitalization.none,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        prefixIcon: Icon(icon, color: const Color(0xFF00838F), size: 20),
        hintText: hint,
        hintStyle: const TextStyle(
            fontWeight: FontWeight.normal, fontSize: 14, color: Color(0xFF9E9E9E)),
      ),
    ),
  );
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(_) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
        color: enabled
            ? const Color(0xFF00838F).withOpacity(0.12)
            : Colors.grey.shade100,
        shape: BoxShape.circle,
      ),
      child: Icon(icon,
          size: 18,
          color: enabled ? const Color(0xFF00838F) : Colors.grey.shade400),
    ),
  );
}

class _BillRow extends StatelessWidget {
  final String label, value;
  const _BillRow(this.label, this.value);
  @override
  Widget build(_) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Text(label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
      const Spacer(),
      Text(value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    ]),
  );
}
