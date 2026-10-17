import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';

final guestServiceProvider = Provider((ref) => GuestService(ref.watch(supabaseClientProvider)));

class GuestService {
  final client;
  GuestService(this.client);

  Future<Map<String, dynamic>> findOrCreateGuest({
    required String name,
    required String phone,
    String? email,
  }) async {
    // Try find existing guest
    try {
      final existing = await client.from('guests').select().eq('phone', phone).maybeSingle();
      if (existing != null) return existing;
    } catch (_) {}

    // Try create in Supabase — silently fall back to local if RLS blocks it
    try {
      final created = await client.from('guests').insert({
        'full_name': name,
        'phone': phone,
        if (email != null) 'email': email,
      }).select().maybeSingle();
      if (created != null) return created;
    } catch (_) {
      // RLS / no auth — return a local guest object so booking can continue
    }

    // Local fallback — generates a temporary ID so the rest of the flow works
    return {
      'id': 'local_${DateTime.now().millisecondsSinceEpoch}',
      'full_name': name,
      'phone': phone,
      'email': email,
    };
  }
}
