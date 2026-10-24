import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../activities/data/activity_bookings_provider.dart';
import '../../../housekeeping/data/housekeeping_provider.dart';
import '../../data/notifications_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _unreadOnly = false;
  NotificationCategory? _category;

  Future<void> _refresh() async {
    ref.invalidate(serverNotificationsProvider);
    await Future.wait([
      ref.read(activityBookingsProvider.notifier).refresh(),
    ]);
    ref.invalidate(housekeepingTasksProvider);
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(notificationsProvider);
    final read = ref.watch(readNotificationsProvider);
    final unreadCount = all.where((n) => !read.contains(n.id)).length;

    final categories = all.map((n) => n.category).toSet().toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    final visible = all.where((n) {
      if (_unreadOnly && read.contains(n.id)) return false;
      if (_category != null && n.category != _category) return false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(
        title: 'Notifications',
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: () => ref
                  .read(readNotificationsProvider.notifier)
                  .markAllRead(all.map((n) => n.id)),
              icon: const Icon(Icons.done_all_rounded, size: 18, color: AppTheme.primary),
              label: const Text('Mark all read', style: TextStyle(color: AppTheme.primary)),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Filters ─────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _SegmentChip(
                      label: 'All',
                      count: all.length,
                      selected: !_unreadOnly,
                      onTap: () => setState(() => _unreadOnly = false),
                    ),
                    const SizedBox(width: 8),
                    _SegmentChip(
                      label: 'Unread',
                      count: unreadCount,
                      selected: _unreadOnly,
                      onTap: () => setState(() => _unreadOnly = true),
                    ),
                  ],
                ),
                if (categories.length > 1) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _CategoryChip(
                          label: 'Everything',
                          color: AppTheme.primary,
                          selected: _category == null,
                          onTap: () => setState(() => _category = null),
                        ),
                        for (final c in categories)
                          _CategoryChip(
                            label: all.firstWhere((n) => n.category == c).label,
                            color: all.firstWhere((n) => n.category == c).color,
                            selected: _category == c,
                            onTap: () => setState(() => _category = _category == c ? null : c),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // ── List ────────────────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: visible.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        EmptyState(
                          title: _unreadOnly ? 'All caught up' : 'No notifications',
                          subtitle: _unreadOnly
                              ? 'You have read everything. New alerts will show up here.'
                              : 'New orders, bookings and requests will appear here.',
                          icon: Icons.notifications_none_rounded,
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: _buildGrouped(visible, read),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGrouped(List<AppNotification> items, Set<String> read) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String groupOf(DateTime d) {
      final day = DateTime(d.year, d.month, d.day);
      if (!day.isBefore(today)) return 'Today';
      if (day == yesterday) return 'Yesterday';
      return DateFormat('EEE, d MMM').format(d);
    }

    final widgets = <Widget>[];
    String? current;
    for (final n in items) {
      final g = groupOf(n.createdAt);
      if (g != current) {
        current = g;
        widgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(
            g.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.textHint,
            ),
          ),
        ));
      }
      widgets.add(_NotificationTile(
        n: n,
        isRead: read.contains(n.id),
        onTap: () {
          ref.read(readNotificationsProvider.notifier).markRead(n.id);
          if (n.route != null) context.push(n.route!);
        },
        onToggleRead: () {
          final notifier = ref.read(readNotificationsProvider.notifier);
          if (read.contains(n.id)) {
            notifier.markUnread(n.id);
          } else {
            notifier.markRead(n.id);
          }
        },
      ));
    }
    return widgets;
  }
}

// ─── Tile ─────────────────────────────────────────────────────────────────────

String _relativeTime(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  return DateFormat('d MMM, h:mm a').format(t);
}

class _NotificationTile extends StatelessWidget {
  final AppNotification n;
  final bool isRead;
  final VoidCallback onTap;
  final VoidCallback onToggleRead;

  const _NotificationTile({
    required this.n,
    required this.isRead,
    required this.onTap,
    required this.onToggleRead,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isRead ? Colors.white : const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onLongPress: onToggleRead,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isRead ? const Color(0xFFE6E2DA) : AppTheme.primaryLight.withOpacity(0.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: n.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(n.icon, color: n.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.body,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textHint, height: 1.35),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: n.color.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              n.label,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: n.color),
                            ),
                          ),
                          if (n.urgent && !isRead) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Action needed',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFC62828)),
                              ),
                            ),
                          ],
                          const Spacer(),
                          Text(
                            _relativeTime(n.createdAt),
                            style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                          ),
                          if (n.route != null) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.textHint),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Filter chips ─────────────────────────────────────────────────────────────

class _SegmentChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _SegmentChip({required this.label, required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.primary : const Color(0xFFDDD8CE)),
        ),
        child: Text(
          '$label  $count',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? color : const Color(0xFFDDD8CE)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? color : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
