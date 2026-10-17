import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});
  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  String _search = '';
  int? _expandedIndex;

  static const _faqs = [
    _FAQ('How do I create a new booking?',
        'Go to Bookings → Create Booking. Fill in guest details, select room, dates, and package. Tap Save to confirm. The guest will receive a confirmation.'),
    _FAQ('How do I check in a guest?',
        'Go to Check-In from the dashboard or Bookings list. Search for the guest booking, verify ID, collect payment if pending, and tap Confirm Check-In.'),
    _FAQ('How do I mark a room as cleaned?',
        'Go to Housekeeping Dashboard → Task List. Find the room task and tap Mark Complete after finishing cleaning. Room status updates automatically.'),
    _FAQ('How do I add a food order for a guest?',
        'Go to Food Orders → tap the + button. Select the guest/room, choose menu items, and place the order. Kitchen gets notified immediately.'),
    _FAQ('How do I view revenue reports?',
        'Go to Reports from the Owner/Manager dashboard. Select the Revenue tab to see bookings revenue, payment methods, and trend graphs.'),
    _FAQ('How do I register a guest for an activity?',
        'Go to Activities → select the activity → tap Register. Choose the guest and date, set number of participants, and confirm.'),
    _FAQ('How do I raise a maintenance ticket?',
        'Go to Maintenance → tap the + button. Select the location/room, describe the issue, set priority, and assign to a staff member.'),
    _FAQ('How do I update inventory stock?',
        'Go to Inventory → tap any item to edit. Update the quantity and save. A low-stock alert shows when quantity falls below the minimum level.'),
    _FAQ('How do I mark attendance?',
        'Go to Staff → Attendance. Select today\'s date and tap each staff member to set their status (Present/Absent/Half Day/Late). Tap Save.'),
    _FAQ('How do I reset a staff member\'s password?',
        'Go to User Management (Settings → System Settings). Find the staff member and use Reset Password option. They will receive an email with a reset link.'),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? _faqs
        : _faqs.where((f) =>
            f.q.toLowerCase().contains(_search.toLowerCase()) ||
            f.a.toLowerCase().contains(_search.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const AnjAppBar(title: 'Help Center'),
      body: Column(
        children: [
          // Hero
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.support_agent_rounded, color: Colors.white, size: 40),
                const SizedBox(height: 10),
                const Text('How can we help?', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (v) => setState(() { _search = v; _expandedIndex = null; }),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search help articles...',
                    filled: true, fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textPrimary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMD), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),

          // Quick links
          if (_search.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(children: [
                _QuickLink(Icons.book_outlined, 'User Guide', () {}),
                const SizedBox(width: 10),
                _QuickLink(Icons.videocam_outlined, 'Video Tutorials', () {}),
                const SizedBox(width: 10),
                _QuickLink(Icons.chat_outlined, 'Contact Us', () => _showContact(context)),
              ]),
            ),

          // FAQ header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              const Icon(Icons.quiz_outlined, size: 18, color: AppTheme.textPrimary),
              const SizedBox(width: 6),
              Text(_search.isEmpty ? 'Frequently Asked Questions' : '${filtered.length} result(s)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
            ]),
          ),

          // FAQ list
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(title: 'No Results', subtitle: 'Try different search terms', icon: Icons.search_off_rounded)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final faq = filtered[i];
                      final expanded = _expandedIndex == i;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded: expanded,
                            onExpansionChanged: (v) => setState(() => _expandedIndex = v ? i : null),
                            title: Text(faq.q, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            trailing: Icon(expanded ? Icons.remove_circle_outline : Icons.add_circle_outline,
                                color: AppTheme.primary, size: 20),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Text(faq.a, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.5)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showContact(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Contact Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            _ContactRow(Icons.phone_rounded, 'Call Support', '+91 9876543210'),
            const SizedBox(height: 12),
            _ContactRow(Icons.email_rounded, 'Email Support', 'support@anjanvel.com'),
            const SizedBox(height: 12),
            _ContactRow(Icons.access_time_rounded, 'Hours', 'Mon–Sat, 9 AM – 6 PM'),
          ],
        ),
      ),
    );
  }
}

class _FAQ {
  final String q, a;
  const _FAQ(this.q, this.a);
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickLink(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
          ),
          child: Column(children: [
            Icon(icon, color: AppTheme.primary, size: 22),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textPrimary), textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _ContactRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: AppTheme.primary, size: 20),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
      ]),
    ]);
  }
}
