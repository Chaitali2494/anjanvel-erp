import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../activities/data/activity_bookings_provider.dart';
import '../../bookings/data/session_bookings_provider.dart';
import '../../food/data/food_orders_state_provider.dart';
import '../../guest/data/guest_requests_provider.dart';
import '../../housekeeping/data/housekeeping_provider.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

enum NotificationCategory { food, activity, housekeeping, maintenance, booking, guest, system }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final DateTime createdAt;
  final String? route;
  final bool urgent;
  final bool fromServer;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
    this.route,
    this.urgent = false,
    this.fromServer = false,
  });

  IconData get icon {
    switch (category) {
      case NotificationCategory.food:         return Icons.restaurant_rounded;
      case NotificationCategory.activity:     return Icons.hiking_rounded;
      case NotificationCategory.housekeeping: return Icons.cleaning_services_rounded;
      case NotificationCategory.maintenance:  return Icons.build_rounded;
      case NotificationCategory.booking:      return Icons.event_available_rounded;
      case NotificationCategory.guest:        return Icons.room_service_rounded;
      case NotificationCategory.system:       return Icons.notifications_rounded;
    }
  }

  Color get color {
    switch (category) {
      case NotificationCategory.food:         return const Color(0xFFF57C00);
      case NotificationCategory.activity:     return const Color(0xFF00897B);
      case NotificationCategory.housekeeping: return const Color(0xFF1E88E5);
      case NotificationCategory.maintenance:  return const Color(0xFF6D4C41);
      case NotificationCategory.booking:      return const Color(0xFF2E7D32);
      case NotificationCategory.guest:        return const Color(0xFF8E24AA);
      case NotificationCategory.system:       return const Color(0xFF546E7A);
    }
  }

  String get label {
    switch (category) {
      case NotificationCategory.food:         return 'Food';
      case NotificationCategory.activity:     return 'Activities';
      case NotificationCategory.housekeeping: return 'Housekeeping';
      case NotificationCategory.maintenance:  return 'Maintenance';
      case NotificationCategory.booking:      return 'Bookings';
      case NotificationCategory.guest:        return 'Guest';
      case NotificationCategory.system:       return 'System';
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

DateTime _parseTime(dynamic v, {DateTime? fallback}) {
  if (v is String && v.isNotEmpty) {
    final d = DateTime.tryParse(v);
    if (d != null) return d.toLocal();
  }
  return fallback ?? DateTime.now();
}

String _str(dynamic v, [String fallback = '']) {
  final s = v?.toString() ?? '';
  return s.isEmpty ? fallback : s;
}

String _pretty(String code) => code
    .toLowerCase()
    .split('_')
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');

/// Only keep events from the last few days so the list stays relevant.
const _maxAge = Duration(days: 3);

// ── Read state (persisted per browser) ────────────────────────────────────────

const _prefsKey = 'anj_notif_read_ids';

class ReadNotificationsNotifier extends StateNotifier<Set<String>> {
  ReadNotificationsNotifier() : super(<String>{}) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_prefsKey) ?? const <String>[];
      state = {...state, ...ids};
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Cap stored ids so storage doesn't grow forever
      final list = state.toList();
      await prefs.setStringList(
          _prefsKey, list.length > 500 ? list.sublist(list.length - 500) : list);
    } catch (_) {}
  }

  void markRead(String id) {
    if (state.contains(id)) return;
    state = {...state, id};
    _persist();
  }

  void markAllRead(Iterable<String> ids) {
    state = {...state, ...ids};
    _persist();
  }

  void markUnread(String id) {
    state = {...state}..remove(id);
    _persist();
  }
}

final readNotificationsProvider =
    StateNotifierProvider<ReadNotificationsNotifier, Set<String>>(
        (ref) => ReadNotificationsNotifier());

// ── Server notifications (Supabase `notifications` table) ─────────────────────

final serverNotificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser?.id;
  if (uid == null) return const [];
  try {
    final rows = await client
        .from('notifications')
        .select('*')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List).map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      final type = _str(m['type']).toUpperCase();
      final cat = type.contains('FOOD') || type.contains('ORDER')
          ? NotificationCategory.food
          : type.contains('ACTIVIT')
              ? NotificationCategory.activity
              : type.contains('HOUSE') || type.contains('CLEAN')
                  ? NotificationCategory.housekeeping
                  : type.contains('MAINT')
                      ? NotificationCategory.maintenance
                      : type.contains('BOOK') || type.contains('CHECK')
                          ? NotificationCategory.booking
                          : NotificationCategory.system;
      return AppNotification(
        id: 'srv_${m['id']}',
        title: _str(m['title'], 'Notification'),
        body: _str(m['body']),
        category: cat,
        createdAt: _parseTime(m['created_at']),
        fromServer: true,
      );
    }).toList();
  } catch (_) {
    return const [];
  }
});

// ── Live notifications derived from what's happening in the resort ────────────

final allNotificationsProvider = Provider<List<AppNotification>>((ref) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final out = <AppNotification>[];

  // Food orders
  for (final o in ref.watch(foodOrdersStateProvider)) {
    final status = _str(o['status']).toUpperCase();
    final room = _str((o['bookings'] as Map?)?['room_number'] ?? o['room_number'], '—');
    final guest = _str((o['guests'] as Map?)?['full_name'] ?? o['guest_name'], 'Guest');
    final orderNo = _str(o['order_number'], 'Order');
    final at = _parseTime(o['ordered_at'] ?? o['created_at'], fallback: todayStart);
    if (status == 'PENDING') {
      out.add(AppNotification(
        id: 'food_${o['id']}_new',
        title: 'New food order · Room $room',
        body: '$orderNo from $guest${o['source'] == 'GUEST_QR' ? ' (via guest QR)' : ''} is waiting for the kitchen.',
        category: NotificationCategory.food,
        createdAt: at,
        route: '/food',
        urgent: true,
      ));
    } else if (status == 'READY') {
      out.add(AppNotification(
        id: 'food_${o['id']}_ready',
        title: 'Order ready to serve · Room $room',
        body: '$orderNo for $guest is ready.',
        category: NotificationCategory.food,
        createdAt: at,
        route: '/food',
      ));
    }
  }

  // Activity bookings
  final activities = ref.watch(activityBookingsProvider).valueOrNull ?? const [];
  for (final a in activities) {
    final status = _str(a['status']).toUpperCase();
    if (status == 'CANCELLED') continue;
    final tracker = _str(a['tracker_status'], 'PENDING').toUpperCase();
    final room = _str(a['room_number'], '—');
    final name = _str(a['activity_name'], 'Activity');
    final emoji = _str(a['activity_emoji']);
    final persons = a['persons'] ?? 1;
    final when = [_str(a['date']), _str(a['time'])].where((s) => s.isNotEmpty).join(' · ');
    out.add(AppNotification(
      id: 'act_${a['id']}_$tracker',
      title: tracker == 'PENDING'
          ? 'Activity booked · Room $room'
          : 'Coordinator assigned · Room $room',
      body: tracker == 'PENDING'
          ? '${emoji.isNotEmpty ? '$emoji ' : ''}$name for $persons ${persons == 1 ? 'person' : 'people'}${when.isNotEmpty ? ' on $when' : ''}. Needs a coordinator.'
          : '${emoji.isNotEmpty ? '$emoji ' : ''}$name assigned to ${_str(a['coordinator'], 'a coordinator')}.',
      category: NotificationCategory.activity,
      createdAt: _parseTime(a['created_at'], fallback: todayStart),
      route: '/activities/tracker',
      urgent: tracker == 'PENDING',
    ));
  }

  // Guest requests (housekeeping / maintenance / general)
  for (final r in ref.watch(guestRequestsProvider)) {
    final status = _str(r['status']).toUpperCase();
    if (status == 'COMPLETED' || status == 'DONE' || status == 'CANCELLED') continue;
    final type = _str(r['type']).toUpperCase();
    final room = _str(r['room_number'], '—');
    final cat = type == 'MAINTENANCE'
        ? NotificationCategory.maintenance
        : type == 'HOUSEKEEPING'
            ? NotificationCategory.housekeeping
            : NotificationCategory.guest;
    final note = _str(r['note']);
    out.add(AppNotification(
      id: 'req_${r['id']}_$status',
      title: '${_str(r['title'], 'Guest request')} · Room $room',
      body: status == 'PENDING'
          ? 'New ${_pretty(type)} request${note.isNotEmpty ? ': $note' : '.'}'
          : 'Request is ${_pretty(status).toLowerCase()}${r['assigned_to'] != null ? ' (${r['assigned_to']})' : ''}.',
      category: cat,
      createdAt: _parseTime(r['requested_at'], fallback: todayStart),
      route: type == 'MAINTENANCE'
          ? '/maintenance'
          : type == 'HOUSEKEEPING'
              ? '/housekeeping'
              : null,
      urgent: status == 'PENDING',
    ));
  }

  // Housekeeping tasks — only high-priority pending ones
  final tasks = ref.watch(housekeepingTasksProvider).valueOrNull ?? const [];
  for (final t in tasks) {
    final status = _str(t['status']).toUpperCase();
    final priority = _str(t['priority']).toUpperCase();
    if (status != 'PENDING' || (priority != 'HIGH' && priority != 'URGENT')) continue;
    final notes = _str(t['notes']);
    out.add(AppNotification(
      id: 'hk_${t['id']}',
      title: 'High-priority cleaning · Room ${_str(t['room_number'], '—')}',
      body: '${_pretty(_str(t['task_type'], 'CLEANING'))}'
          '${t['assigned_to'] != null ? ' assigned to ${t['assigned_to']}' : ' not yet assigned'}'
          '${notes.isNotEmpty ? ' — $notes' : '.'}',
      category: NotificationCategory.housekeeping,
      createdAt: _parseTime(t['created_at'], fallback: todayStart),
      route: '/housekeeping',
      urgent: true,
    ));
  }

  // Bookings created / updated in this session
  for (final b in ref.watch(sessionBookingsProvider)) {
    final status = _str(b['status']).toUpperCase();
    final guest = _str((b['guests'] as Map?)?['full_name'] ?? b['guest_name'], 'Guest');
    final room = _str(b['room_number']);
    final roomTxt = room.isNotEmpty ? ' · Room $room' : '';
    String title;
    String body = '';
    switch (status) {
      case 'CHECKED_IN':
        title = 'Guest checked in$roomTxt';
        body = '$guest has checked in.';
        break;
      case 'CHECKED_OUT':
        title = 'Guest checked out$roomTxt';
        body = '$guest has checked out. Room needs cleaning.';
        break;
      case 'CANCELLED':
        title = 'Booking cancelled';
        body = 'Booking for $guest was cancelled.';
        break;
      case 'CONFIRMED':
        title = 'Booking confirmed';
        body = '$guest — ${_str(b['check_in_date'] ?? b['check_in'], 'date TBD')}.';
        break;
      default:
        title = 'New booking';
        body = '$guest — ${_str(b['check_in_date'] ?? b['check_in'], 'date TBD')}.';
    }
    out.add(AppNotification(
      id: 'bk_${b['id']}_$status',
      title: title,
      body: body,
      category: NotificationCategory.booking,
      createdAt: _parseTime(b['checked_in_at'] ?? b['updated_at'] ?? b['created_at'],
          fallback: todayStart),
      route: '/bookings/roadmap',
    ));
  }

  // Server-side notifications
  out.addAll(ref.watch(serverNotificationsProvider).valueOrNull ?? const []);

  final cutoff = now.subtract(_maxAge);
  final seen = <String>{};
  final list = out
      .where((n) => n.createdAt.isAfter(cutoff))
      .where((n) => seen.add(n.id))
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return list;
});

/// Notifications relevant to the dashboard the user is currently using.
final notificationsProvider = Provider<List<AppNotification>>((ref) {
  final all = ref.watch(allNotificationsProvider);
  final dashboard = ref.watch(activeRoleDashboardProvider);
  Set<NotificationCategory>? allowed;
  if (dashboard.contains('kitchen')) {
    allowed = {NotificationCategory.food, NotificationCategory.system};
  } else if (dashboard.contains('housekeeping')) {
    allowed = {
      NotificationCategory.housekeeping,
      NotificationCategory.maintenance,
      NotificationCategory.system,
    };
  } else if (dashboard.contains('activity')) {
    allowed = {NotificationCategory.activity, NotificationCategory.system};
  }
  if (allowed == null) return all; // owner / manager see everything
  return all.where((n) => allowed!.contains(n.category) || n.fromServer).toList();
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final read = ref.watch(readNotificationsProvider);
  return ref.watch(notificationsProvider).where((n) => !read.contains(n.id)).length;
});
