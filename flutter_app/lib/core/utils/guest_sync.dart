// ignore_for_file: avoid_web_libraries_in_flutter
/// Cross-tab sync for guest orders and requests.
///
/// Uses localStorage (same-origin persistence) + BroadcastChannel (cross-tab
/// push notifications) so that:
///   • Orders placed in the guest portal tab appear instantly in the
///     management app's Food Orders screen (same browser, different tab).
///   • Data survives page refresh within the same browser session.
///
/// Everything is wrapped in try/catch — the app degrades gracefully to
/// in-memory-only behaviour if the APIs are unavailable.

import 'dart:convert';
import 'dart:html' as html;

class GuestSync {
  GuestSync._();

  static const _ordersKey   = 'anjanvel_guest_orders';
  static const _requestsKey = 'anjanvel_guest_requests';
  static const _channelName = 'anjanvel_sync';

  // ── Public write API ─────────────────────────────────────────────────────────

  /// Call from guest portal when a food order is placed.
  static void saveOrder(Map<String, dynamic> order) {
    _upsert(_ordersKey, order);
    _broadcast({'type': 'ORDER', 'data': order});
  }

  /// Call from guest portal when a HK / maintenance request is placed.
  static void saveRequest(Map<String, dynamic> request) {
    _upsert(_requestsKey, request);
    _broadcast({'type': 'REQUEST', 'data': request});
  }

  /// Call from management screens when an order status changes.
  static void updateOrderStatus(String id, String newStatus) {
    try {
      final list = _load(_ordersKey);
      final idx  = list.indexWhere((o) => o['id'] == id);
      if (idx >= 0) {
        list[idx] = {...list[idx], 'status': newStatus};
        _save(_ordersKey, list);
        _broadcast({'type': 'ORDER_STATUS', 'id': id, 'status': newStatus});
      }
    } catch (_) {}
  }

  // ── Public read API ──────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> loadOrders()   => _load(_ordersKey);
  static List<Map<String, dynamic>> loadRequests() => _load(_requestsKey);

  // ── Listener API ─────────────────────────────────────────────────────────────
  //
  // Returns a cancel callback. Call it from StateNotifier.dispose() to close
  // the BroadcastChannel and avoid memory leaks.

  /// Fires [onNew] when another tab broadcasts a new guest food order.
  static void Function() listenForOrders(
      void Function(Map<String, dynamic> order) onNew) {
    return _listen((msg) {
      if (msg['type'] == 'ORDER') {
        final d = msg['data'];
        if (d is Map<String, dynamic>) onNew(d);
      }
    });
  }

  /// Fires [onNew] when another tab broadcasts a new guest request.
  static void Function() listenForRequests(
      void Function(Map<String, dynamic> request) onNew) {
    return _listen((msg) {
      if (msg['type'] == 'REQUEST') {
        final d = msg['data'];
        if (d is Map<String, dynamic>) onNew(d);
      }
    });
  }

  /// Fires [onUpdate] when another tab updates an order status.
  static void Function() listenForStatusUpdates(
      void Function(String id, String status) onUpdate) {
    return _listen((msg) {
      if (msg['type'] == 'ORDER_STATUS') {
        final id     = msg['id']     as String?;
        final status = msg['status'] as String?;
        if (id != null && status != null) onUpdate(id, status);
      }
    });
  }

  // ── Internals ────────────────────────────────────────────────────────────────

  static void _upsert(String key, Map<String, dynamic> item) {
    try {
      final list = _load(key);
      list.removeWhere((e) => e['id'] == item['id']);
      list.insert(0, item);
      _save(key, list);
    } catch (_) {}
  }

  static List<Map<String, dynamic>> _load(String key) {
    try {
      final raw = html.window.localStorage[key];
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static void _save(String key, List<Map<String, dynamic>> list) {
    try {
      html.window.localStorage[key] = jsonEncode(list);
    } catch (_) {}
  }

  static void _broadcast(Map<String, dynamic> msg) {
    try {
      final bc = html.BroadcastChannel(_channelName);
      bc.postMessage(jsonEncode(msg));
      bc.close();
    } catch (_) {}
  }

  static void Function() _listen(void Function(Map<String, dynamic>) handler) {
    try {
      final bc = html.BroadcastChannel(_channelName);
      bc.onMessage.listen((event) {
        try {
          final raw = event.data as String?;
          if (raw == null) return;
          final msg = jsonDecode(raw);
          if (msg is Map<String, dynamic>) handler(msg);
        } catch (_) {}
      });
      return () {
        try { bc.close(); } catch (_) {}
      };
    } catch (_) {
      return () {};
    }
  }
}
