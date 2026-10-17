import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    // Request permissions
    await _fcm.requestPermission(
      alert: true, badge: true, sound: true,
      provisional: false,
    );

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channels (Android)
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'anjanvel_high', 'Anjanvel Important',
            description: 'Important notifications from Anjanvel ERP',
            importance: Importance.max,
          ),
        );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundTap);

    // Subscribe to topics
    await _fcm.subscribeToTopic('all_staff');
  }

  static Future<String?> getToken() => _fcm.getToken();

  static Future<void> subscribeToTopic(String topic) => _fcm.subscribeToTopic(topic);

  static Future<void> unsubscribeFromTopic(String topic) => _fcm.unsubscribeFromTopic(topic);

  static void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'anjanvel_high', 'Anjanvel Important',
          channelDescription: 'Important notifications',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      payload: message.data['route'],
    );
  }

  static void _handleBackgroundTap(RemoteMessage message) {
    // Navigate to the relevant screen based on message data
    // This would be handled by the router
  }

  static void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap - navigate to route
    if (response.payload != null) {
      // navigate to route
    }
  }
}
