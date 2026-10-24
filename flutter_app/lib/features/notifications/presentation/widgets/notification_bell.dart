import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/notifications_provider.dart';

/// Bell icon with a live unread-count badge. Opens the notifications screen.
class NotificationBell extends ConsumerWidget {
  final Color color;
  const NotificationBell({super.key, this.color = Colors.white});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    return IconButton(
      tooltip: unread > 0 ? '$unread unread notifications' : 'Notifications',
      onPressed: () => context.push('/notifications'),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            unread > 0 ? Icons.notifications_rounded : Icons.notifications_outlined,
            color: color,
          ),
          if (unread > 0)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
