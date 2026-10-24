import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<_Notif> _notifs = [
    _Notif(
      icon: Icons.login_rounded,
      color: Color(0xFF2E7D32),
      title: 'New Check-In',
      body: 'Priya Sharma checked into Room 101 (Tent Stay)',
      time: '10 min ago',
      tag: 'Check-In',
      tagColor: Color(0xFF2E7D32),
      read: false,
    ),
    _Notif(
      icon: Icons.receipt_long_rounded,
      color: Color(0xFFF59E0B),
      title: 'Bill Processed',
      body: 'Bill for Rajesh Kumar — Room 102 has been generated. Total: ₹8,532',
      time: '35 min ago',
      tag: 'Billing',
      tagColor: Color(0xFFF59E0B),
      read: false,
    ),
    _Notif(
      icon: Icons.cleaning_services_rounded,
      color: Color(0xFF0288D1),
      title: 'Housekeeping Request',
      body: 'Room 201 requested towel replacement and room cleaning',
      time: '1 hr ago',
      tag: 'Housekeeping',
      tagColor: Color(0xFF0288D1),
      read: false,
    ),
    _Notif(
      icon: Icons.restaurant_rounded,
      color: Color(0xFFE65100),
      title: 'Food Order Placed',
      body: 'Room 302 ordered Masala Chai × 2 and Poha × 1',
      time: '1.5 hr ago',
      tag: 'Food',
      tagColor: Color(0xFFE65100),
      read: true,
    ),
    _Notif(
      icon: Icons.build_rounded,
      color: Color(0xFF6D4C41),
      title: 'Maintenance Request',
      body: 'Room 103 reported a leaking tap in the bathroom',
      time: '2 hr ago',
      tag: 'Maintenance',
      tagColor: Color(0xFF6D4C41),
      read: true,
    ),
    _Notif(
      icon: Icons.event_available_rounded,
      color: Color(0xFF7B61FF),
      title: 'New Booking Created',
      body: 'Vikram Singh booked Room 201 (Anjanpushp Villa) for 4 nights',
      time: '3 hr ago',
      tag: 'Booking',
      tagColor: Color(0xFF7B61FF),
      read: true,
    ),
    _Notif(
      icon: Icons.storefront_rounded,
      color: Color(0xFF558B2F),
      title: 'SHG Shop Sale',
      body: 'Alphonso Mango × 2 kg sold. ₹160 charged to Room 101',
      time: '4 hr ago',
      tag: 'Shop',
      tagColor: Color(0xFF558B2F),
      read: true,
    ),
    _Notif(
      icon: Icons.star_rounded,
      color: Color(0xFFD32F2F),
      title: 'Guest Feedback',
      body: 'Meena Gupta rated her stay 5★ — "Beautiful resort, amazing experience!"',
      time: 'Yesterday',
      tag: 'Feedback',
      tagColor: Color(0xFFD32F2F),
      read: true,
    ),
    _Notif(
      icon: Icons.logout_rounded,
      color: Color(0xFF546E7A),
      title: 'Check-Out',
      body: 'Suresh Patil checked out from Room 301. Bill settled.',
      time: 'Yesterday',
      tag: 'Check-Out',
      tagColor: Color(0xFF546E7A),
      read: true,
    ),
  ];

  int get _unreadCount => _notifs.where((n) => !n.read).length;

  void _markAllRead() {
    setState(() {
      for (final n in _notifs) n.read = true;
    });
  }

  void _markRead(int index) {
    setState(() => _notifs[index].read = true);
  }

  void _delete(int index) {
    setState(() => _notifs.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFD32F2F), borderRadius: BorderRadius.circular(10)),
                child: Text('$_unreadCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read', style: TextStyle(color: Color(0xFF558B2F), fontSize: 13)),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: _notifs.isEmpty
          ? _emptyState()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _notifs.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, i) {
                final n = _notifs[i];
                return Dismissible(
                  key: Key('notif_$i\_${n.title}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: const Color(0xFFD32F2F),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                  ),
                  onDismissed: (_) => _delete(i),
                  child: InkWell(
                    onTap: () => _markRead(i),
                    child: Container(
                      color: n.read ? Colors.transparent : n.color.withOpacity(0.04),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon circle
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(color: n.color.withOpacity(0.12), shape: BoxShape.circle),
                            child: Icon(n.icon, color: n.color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: n.tagColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(n.tag, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: n.tagColor)),
                                    ),
                                    const Spacer(),
                                    Text(n.time, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                    if (!n.read) ...[
                                      const SizedBox(width: 6),
                                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFD32F2F), shape: BoxShape.circle)),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(n.title, style: TextStyle(fontSize: 14, fontWeight: n.read ? FontWeight.w500 : FontWeight.bold, color: AppTheme.textPrimary)),
                                const SizedBox(height: 3),
                                Text(n.body, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
          child: const Icon(Icons.notifications_none_rounded, size: 36, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),
        const Text('No notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 6),
        const Text('All caught up!', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      ],
    ),
  );
}

class _Notif {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String time;
  final String tag;
  final Color tagColor;
  bool read;

  _Notif({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.time,
    required this.tag,
    required this.tagColor,
    required this.read,
  });
}
