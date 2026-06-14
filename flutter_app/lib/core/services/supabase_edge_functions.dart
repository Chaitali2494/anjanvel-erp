import 'package:supabase_flutter/supabase_flutter.dart';

/// Wrapper for Supabase Edge Functions
class EdgeFunctions {
  final SupabaseClient _client;
  EdgeFunctions(this._client);

  /// Send WhatsApp message
  Future<void> sendWhatsApp({
    required String phone,
    required String templateName,
    required Map<String, String> variables,
  }) async {
    await _client.functions.invoke('send-whatsapp', body: {
      'phone': phone,
      'template_name': templateName,
      'variables': variables,
    });
  }

  /// Generate invoice PDF
  Future<String> generateInvoice(String bookingId) async {
    final response = await _client.functions.invoke('generate-invoice', body: {
      'booking_id': bookingId,
    });
    return response.data['pdf_url'] as String;
  }

  /// Send push notification to a user
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    String? type,
    String? referenceId,
  }) async {
    await _client.functions.invoke('send-notification', body: {
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type ?? 'GENERAL',
      'reference_id': referenceId,
    });
  }

  /// Generate QR pass for check-in
  Future<String> generateQrPass(String checkinId) async {
    final response = await _client.functions.invoke('generate-qr-pass', body: {
      'checkin_id': checkinId,
    });
    return response.data['qr_url'] as String;
  }
}
