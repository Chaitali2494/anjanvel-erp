import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/activity_bookings_provider.dart';

// ── Per-activity selection state ──────────────────────────────────────────────

class _Sel {
  int persons;
  TimeOfDay time;
  DateTime date;
  _Sel({this.persons = 1, required this.time, required this.date});
}

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

  final _roomCtrl  = TextEditingController();
  final _guestCtrl = TextEditingController();

  // activityId → selection state
  final Map<String, _Sel> _selections = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.activityId.isNotEmpty) {
      _selections[widget.activityId] = _Sel(
        time: const TimeOfDay(hour: 9, minute: 0),
        date: DateTime.now(),
      );
    }
  }

  @override
  void dispose() {
    _roomCtrl.dispose();
    _guestCtrl.dispose();
    super.dispose();
  }

  double get _grandTotal => _selections.entries.fold(0.0, (sum, e) {
    final activity = kActivityCatalogue.firstWhere((a) => a['id'] == e.key);
    return sum + (activity['price'] as num).toDouble() * e.value.persons;
  });

  bool get _canSubmit =>
      _selections.isNotEmpty && _roomCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const AnjAppBar(title: 'Book Activities'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Room Number ──────────────────────────────────────────────
            _sectionLabel('Room Number'),
            const SizedBox(height: 6),
            _Field(
              controller: _roomCtrl,
              icon: Icons.bed_outlined,
              hint: 'e.g. 101, 205, Tent-3',
              onChanged: (_) => setState(() {}),
              formatters: [LengthLimitingTextInputFormatter(10)],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 6,
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
                    child: Text('Room $rno · ${r['guest_name']}',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500,
                          color: isActive ? Colors.white : _accent,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // ── Guest Name ───────────────────────────────────────────────
            _sectionLabel('Guest Name'),
            const SizedBox(height: 6),
            _Field(
              controller: _guestCtrl,
              icon: Icons.person_outline_rounded,
              hint: 'Auto-filled when selecting room above',
              capitalize: true,
            ),
            const SizedBox(height: 22),

            // ── Select Activities ────────────────────────────────────────
            Row(children: [
              _sectionLabel('Select Activities'),
              const Spacer(),
              if (_selections.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _accent, borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${_selections.length} selected',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ]),
            const SizedBox(height: 4),
            const Text('Tap to select · tap again to deselect · select multiple',
                style: TextStyle(fontSize: 11, color: AppTheme.textPrimary)),
            const SizedBox(height: 10),

            ...kActivityCatalogue.map((a) {
              final id         = a['id'] as String;
              final isSelected = _selections.containsKey(id);
              final sel        = _selections[id];

              return _MultiActivityCard(
                activity: a,
                isSelected: isSelected,
                sel: sel,
                onTap: () => setState(() {
                  if (isSelected) {
                    _selections.remove(id);
                  } else {
                    _selections[id] = _Sel(
                      time: const TimeOfDay(hour: 9, minute: 0),
                      date: DateTime.now(),
                    );
                  }
                }),
                onPersonsChanged: (v) => setState(() => _selections[id]!.persons = v),
                onTimePick: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: sel?.time ?? const TimeOfDay(hour: 9, minute: 0),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                          colorScheme: const ColorScheme.light(primary: _accent)),
                      child: child!,
                    ),
                  );
                  if (t != null) setState(() => _selections[id]!.time = t);
                },
                onDatePick: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: sel?.date ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                          colorScheme: const ColorScheme.light(primary: _accent)),
                      child: child!,
                    ),
                  );
                  if (d != null) setState(() => _selections[id]!.date = d);
                },
              );
            }),
            const SizedBox(height: 20),

            // ── Bill Summary ─────────────────────────────────────────────
            if (_selections.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  border: Border.all(color: _accent.withOpacity(0.25)),
                ),
                child: Column(children: [
                  Row(children: [
                    const Icon(Icons.receipt_long_rounded, color: _accent, size: 18),
                    const SizedBox(width: 8),
                    const Text('Bill Summary',
                        style: TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 14, color: _accent)),
                  ]),
                  const Divider(height: 16),
                  ..._selections.entries.map((e) {
                    final a     = kActivityCatalogue.firstWhere((x) => x['id'] == e.key);
                    final price = (a['price'] as num).toDouble();
                    final total = price * e.value.persons;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Text('${a['emoji']} ${a['name']} × ${e.value.persons}',
                            style: const TextStyle(fontSize: 13)),
                        const Spacer(),
                        Text('₹${total.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                    );
                  }),
                  const Divider(height: 16),
                  Row(children: [
                    const Text('Total',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Spacer(),
                    Text('₹${_grandTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 22, color: _accent)),
                  ]),
                  if (_roomCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.add_circle_outline_rounded, size: 14, color: _accent),
                      const SizedBox(width: 4),
                      Text('Will be added to Room ${_roomCtrl.text.trim()} bill',
                          style: const TextStyle(color: _accent, fontSize: 12)),
                    ]),
                  ],
                ]),
              ),
              const SizedBox(height: 20),
            ],

            // ── Add to Bill button ───────────────────────────────────────
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
                        _selections.isNotEmpty
                            ? 'Add to Bill  ·  ₹${_grandTotal.toStringAsFixed(0)}'
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
                  _selections.isEmpty
                      ? 'Please select at least one activity above'
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

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary));

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
      for (final entry in _selections.entries) {
        final a     = kActivityCatalogue.firstWhere((x) => x['id'] == entry.key);
        final price = (a['price'] as num).toDouble();
        final sel   = entry.value;

        await ref.read(activityBookingsProvider.notifier).addBooking({
          'room_number':      roomNo,
          'guest_name':       guestName,
          'activity_id':      a['id'],
          'activity_name':    a['name'],
          'activity_emoji':   a['emoji'],
          'category':         a['category'],
          'persons':          sel.persons,
          'price_per_person': price,
          'total_amount':     price * sel.persons,
          'date':             DateFormat('yyyy-MM-dd').format(sel.date),
          'time':             sel.time.format(context),
          'notes':            '',
          'tracker_status':   'PENDING',
          'coordinator':      null,
        });
      }

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              const Icon(Icons.check_circle_rounded, color: _accent, size: 28),
              const SizedBox(width: 10),
              Text('${_selections.length} ${_selections.length == 1 ? 'Activity' : 'Activities'} Booked'),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._selections.entries.map((e) {
                  final a = kActivityCatalogue.firstWhere((x) => x['id'] == e.key);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Text('${a['emoji']}  ${a['name']}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const Spacer(),
                      Text('${e.value.persons} person${e.value.persons > 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 12)),
                    ]),
                  );
                }),
                const Divider(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.receipt_rounded, color: _accent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '₹${_grandTotal.toStringAsFixed(0)} added to Room $roomNo bill\nActivities sent to coordinator dashboard.',
                        style: const TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
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
                    _selections.clear();
                    _roomCtrl.clear();
                    _guestCtrl.clear();
                  });
                },
                child: const Text('Book More'),
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

// ── Multi-select activity card with inline controls ────────────────────────────

class _MultiActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  final bool isSelected;
  final _Sel? sel;
  final VoidCallback onTap;
  final ValueChanged<int> onPersonsChanged;
  final VoidCallback onTimePick;
  final VoidCallback onDatePick;

  const _MultiActivityCard({
    required this.activity, required this.isSelected, required this.sel,
    required this.onTap, required this.onPersonsChanged,
    required this.onTimePick, required this.onDatePick,
  });

  static const _accent = Color(0xFF00838F);

  @override
  Widget build(BuildContext context) {
    final price = (activity['price'] as num).toDouble();
    final total = price * (sel?.persons ?? 1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? _accent.withOpacity(0.07) : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isSelected ? _accent : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [BoxShadow(
          color: isSelected ? _accent.withOpacity(0.12) : Colors.black.withOpacity(0.04),
          blurRadius: isSelected ? 8 : 4,
        )],
      ),
      child: Column(children: [
        // ── Card row ───────────────────────────────────────────────────
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: isSelected ? _accent.withOpacity(0.15) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(activity['emoji'] as String,
                    style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(activity['name'] as String,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                        color: isSelected ? _accent : AppTheme.textPrimary)),
                Text('${activity['category']} · ${activity['duration']}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₹${price.toStringAsFixed(0)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15,
                        color: isSelected ? _accent : AppTheme.textPrimary)),
                const Text('/person',
                    style: TextStyle(fontSize: 10, color: AppTheme.textPrimary)),
              ]),
              const SizedBox(width: 8),
              Icon(
                isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                color: isSelected ? _accent : Colors.grey.shade400,
                size: 22,
              ),
            ]),
          ),
        ),

        // ── Inline controls (persons + date + time) ────────────────────
        if (isSelected && sel != null) ...[
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
                _CircleBtn(
                  icon: Icons.remove_rounded,
                  enabled: sel!.persons > 1,
                  onTap: () => onPersonsChanged(sel!.persons - 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text('${sel!.persons}',
                      style: const TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 22, color: _accent)),
                ),
                _CircleBtn(
                  icon: Icons.add_rounded,
                  enabled: sel!.persons < 30,
                  onTap: () => onPersonsChanged(sel!.persons + 1),
                ),
                const SizedBox(width: 10),
                Text('= ₹${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: _accent, fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
              const SizedBox(height: 10),

              // Date + Time row side by side
              Row(children: [
                // Date
                Expanded(
                  child: GestureDetector(
                    onTap: onDatePick,
                    child: _InfoChip(
                      icon: Icons.calendar_today_rounded,
                      label: DateFormat('d MMM yyyy').format(sel!.date),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Time
                Expanded(
                  child: GestureDetector(
                    onTap: onTimePick,
                    child: _InfoChip(
                      icon: Icons.access_time_rounded,
                      label: sel!.time.format(context),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});
  static const _accent = Color(0xFF00838F);
  @override
  Widget build(_) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: _accent.withOpacity(0.06),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _accent.withOpacity(0.2)),
    ),
    child: Row(children: [
      Icon(icon, color: _accent, size: 15),
      const SizedBox(width: 6),
      Expanded(child: Text(label,
          style: const TextStyle(
              color: _accent, fontWeight: FontWeight.bold, fontSize: 12))),
      const Icon(Icons.edit_rounded, color: _accent, size: 12),
    ]),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? formatters;
  final bool capitalize;
  const _Field({required this.controller, required this.icon, required this.hint,
      this.onChanged, this.formatters, this.capitalize = false});
  @override
  Widget build(_) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
    ),
    child: TextField(
      controller: controller, onChanged: onChanged, inputFormatters: formatters,
      textCapitalization: capitalize ? TextCapitalization.words : TextCapitalization.none,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      decoration: InputDecoration(
        border: InputBorder.none, isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        prefixIcon: Icon(icon, color: const Color(0xFF00838F), size: 20),
        hintText: hint,
        hintStyle: const TextStyle(fontWeight: FontWeight.normal,
            fontSize: 14, color: Color(0xFF9E9E9E)),
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
        color: enabled ? const Color(0xFF00838F).withOpacity(0.12) : Colors.grey.shade100,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18,
          color: enabled ? const Color(0xFF00838F) : Colors.grey.shade400),
    ),
  );
}
