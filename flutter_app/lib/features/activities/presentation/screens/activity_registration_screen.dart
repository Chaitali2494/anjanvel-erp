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

  Map<String, dynamic>? _selectedActivity;
  final _roomCtrl  = TextEditingController();
  final _guestCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  int _persons = 1;
  DateTime _date = DateTime.now();
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
    _notesCtrl.dispose();
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
      appBar: AnjAppBar(title: 'Book Activity'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header summary card ────────────────────────────────────────
            _HeaderCard(
              activity: _selectedActivity,
              persons: _persons,
              total: _total,
            ),
            const SizedBox(height: 20),

            // ── 1. Select Activity ─────────────────────────────────────────
            _Label('1. Select Activity *'),
            const SizedBox(height: 8),
            ...kActivityCatalogue.map((a) => _ActivityCard(
              activity: a,
              isSelected: _selectedActivity?['id'] == a['id'],
              onTap: () => setState(() {
                _selectedActivity =
                    _selectedActivity?['id'] == a['id'] ? null : a;
              }),
            )),
            const SizedBox(height: 20),

            // ── 2. Number of Persons ───────────────────────────────────────
            _Label('2. Number of Persons *'),
            const SizedBox(height: 8),
            _SurfaceCard(
              child: Row(children: [
                const Icon(Icons.group_rounded, color: _accent, size: 22),
                const SizedBox(width: 12),
                const Text('Persons',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const Spacer(),
                // Decrease
                _CircleBtn(
                  icon: Icons.remove_rounded,
                  enabled: _persons > 1,
                  onTap: () => setState(() => _persons--),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('$_persons',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: _accent)),
                ),
                // Increase
                _CircleBtn(
                  icon: Icons.add_rounded,
                  enabled: _persons < 30,
                  onTap: () => setState(() => _persons++),
                ),
                if (_price > 0) ...[
                  const SizedBox(width: 12),
                  Text('₹${_total.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: _accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ],
              ]),
            ),
            const SizedBox(height: 16),

            // ── 3. Date & Time ─────────────────────────────────────────────
            _Label('3. Date & Time *'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: _SurfaceCard(
                    child: Row(children: [
                      const Icon(Icons.calendar_today_rounded,
                          color: _accent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          DateFormat('d MMM yyyy').format(_date),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _pickTime,
                  child: _SurfaceCard(
                    child: Row(children: [
                      const Icon(Icons.access_time_rounded,
                          color: _accent, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _time.format(context),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // ── 4. Room Number ─────────────────────────────────────────────
            _Label('4. Room Number *'),
            const SizedBox(height: 8),
            _SurfaceCard(
              child: TextField(
                controller: _roomCtrl,
                keyboardType: TextInputType.text,
                inputFormatters: [LengthLimitingTextInputFormatter(10)],
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  prefixIcon: Icon(Icons.bed_outlined, color: _accent, size: 20),
                  hintText: 'e.g. 101, 205, Tent-3',
                  hintStyle: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 14,
                      color: Color(0xFF9E9E9E)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Quick room chips from checked-in list
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: kCheckedInRooms.map((r) {
                final rno = r['room_number'] as String;
                final isActive = _roomCtrl.text.trim() == rno;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _roomCtrl.text = rno;
                      if (_guestCtrl.text.isEmpty) {
                        _guestCtrl.text =
                            r['guest_name'] as String? ?? '';
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? _accent
                          : _accent.withOpacity(0.08),
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

            // ── 5. Guest Name ──────────────────────────────────────────────
            _Label('5. Guest Name'),
            const SizedBox(height: 8),
            _SurfaceCard(
              child: TextField(
                controller: _guestCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  prefixIcon: Icon(Icons.person_outline_rounded,
                      color: _accent, size: 20),
                  hintText: 'Auto-filled when selecting a room above',
                  hintStyle: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── 6. Special Notes ───────────────────────────────────────────
            _Label('6. Special Notes'),
            const SizedBox(height: 8),
            _SurfaceCard(
              child: TextField(
                controller: _notesCtrl,
                maxLines: 2,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Icon(Icons.notes_rounded, color: _accent, size: 20),
                  ),
                  hintText: 'Any special requirements...',
                  hintStyle: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Bill summary ───────────────────────────────────────────────
            if (_selectedActivity != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  border: Border.all(color: _accent.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.receipt_long_rounded,
                          color: _accent, size: 18),
                      const SizedBox(width: 8),
                      const Text('Bill Summary',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _accent)),
                    ]),
                    const Divider(height: 16),
                    _BillRow('Activity',
                        _selectedActivity!['name'] as String),
                    _BillRow('Category',
                        _selectedActivity!['category'] as String),
                    _BillRow('Duration',
                        _selectedActivity!['duration'] as String),
                    _BillRow('Price / Person',
                        '₹${_price.toStringAsFixed(0)}'),
                    _BillRow('Persons', '$_persons'),
                    const Divider(height: 16),
                    Row(children: [
                      const Text('Total Amount',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const Spacer(),
                      Text('₹${_total.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: _accent)),
                    ]),
                    if (_roomCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.add_circle_outline_rounded,
                            size: 14, color: _accent),
                        const SizedBox(width: 4),
                        Text(
                          'Will be added to Room ${_roomCtrl.text.trim()} bill',
                          style: const TextStyle(
                              color: _accent, fontSize: 12),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Confirm button ─────────────────────────────────────────────
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
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm & Add to Bill',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white)),
            ),

            if (!_canSubmit)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _selectedActivity == null
                      ? 'Please select an activity above'
                      : 'Please enter a room number',
                  style: const TextStyle(
                      color: AppTheme.error, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx)
            .copyWith(colorScheme: const ColorScheme.light(primary: _accent)),
        child: child!,
      ),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx)
            .copyWith(colorScheme: const ColorScheme.light(primary: _accent)),
        child: child!,
      ),
    );
    if (t != null) setState(() => _time = t);
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    final roomNo    = _roomCtrl.text.trim();
    final guestName = _guestCtrl.text.trim().isEmpty
        ? (kCheckedInRooms
                .where((r) => r['room_number'] == roomNo)
                .map((r) => r['guest_name'] as String? ?? '')
                .firstOrNull ??
            'Guest')
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
        'date':             DateFormat('yyyy-MM-dd').format(_date),
        'time':             _time.format(context),
        'notes':            _notesCtrl.text.trim(),
      });

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
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
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Text('Persons: $_persons'),
                Text(
                    'Date: ${DateFormat('d MMM yyyy').format(_date)} at ${_time.format(context)}'),
                Text('Room: $roomNo'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.receipt_rounded,
                        color: _accent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '₹${_total.toStringAsFixed(0)} added to Room $roomNo bill',
                      style: const TextStyle(
                          color: _accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Reset form for another booking
                  setState(() {
                    _selectedActivity = null;
                    _persons = 1;
                    _roomCtrl.clear();
                    _guestCtrl.clear();
                    _notesCtrl.clear();
                    _date = DateTime.now();
                    _time = const TimeOfDay(hour: 9, minute: 0);
                  });
                },
                child: const Text('Add Another'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _accent),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.pop();
                },
                child: const Text('Done',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ── Header card ───────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final Map<String, dynamic>? activity;
  final int persons;
  final double total;
  const _HeaderCard(
      {required this.activity, required this.persons, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF006064), Color(0xFF00838F), Color(0xFF00ACC1)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: Row(children: [
        Text(
          activity?['emoji'] as String? ?? '🎯',
          style: const TextStyle(fontSize: 36),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              activity?['name'] as String? ?? 'Select an activity below',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
            if (activity != null)
              Text(
                '${activity!['category']} · ${activity!['duration']} · ₹${(activity!['price'] as num).toStringAsFixed(0)}/person',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              )
            else
              const Text(
                'Tap a card below to choose',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
          ]),
        ),
        if (total > 0)
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Total',
                style: TextStyle(color: Colors.white60, fontSize: 11)),
            Text('₹${total.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22)),
          ]),
      ]),
    );
  }
}

// ── Activity selection card ────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  final bool isSelected;
  final VoidCallback onTap;
  const _ActivityCard(
      {required this.activity, required this.isSelected, required this.onTap});

  static const _accent = Color(0xFF00838F);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _accent.withOpacity(0.08) : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(
            color: isSelected ? _accent : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: _accent.withOpacity(0.15), blurRadius: 8)]
              : [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04), blurRadius: 4)
                ],
        ),
        child: Row(children: [
          // Emoji icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? _accent.withOpacity(0.15)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                activity['emoji'] as String,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
          // Price + check
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              '₹${(activity['price'] as num).toStringAsFixed(0)}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isSelected ? _accent : AppTheme.textPrimary),
            ),
            const Text('/person',
                style: TextStyle(fontSize: 10, color: AppTheme.textPrimary)),
          ]),
          const SizedBox(width: 10),
          Icon(
            isSelected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: isSelected ? _accent : Colors.grey.shade400,
            size: 22,
          ),
        ]),
      ),
    );
  }
}

// ── Small reusable widgets ─────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(_) => Text(text,
      style: const TextStyle(
          fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary));
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  const _SurfaceCard({required this.child});
  @override
  Widget build(_) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)
      ],
    ),
    child: child,
  );
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _CircleBtn(
      {required this.icon, required this.enabled, required this.onTap});

  static const _accent = Color(0xFF00838F);

  @override
  Widget build(_) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: enabled ? _accent.withOpacity(0.12) : Colors.grey.shade100,
        shape: BoxShape.circle,
      ),
      child: Icon(icon,
          size: 20, color: enabled ? _accent : Colors.grey.shade400),
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
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600)),
    ]),
  );
}
