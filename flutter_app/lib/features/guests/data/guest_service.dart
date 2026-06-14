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
    // Try find existing
    final existing = await client.from('guests').select().eq('phone', phone).maybeSingle();
    if (existing != null) return existing;
    // Create new
    return await client.from('guests').insert({
      'full_name': name,
      'phone': phone,
      'email': email,
    }).select().single();
  }
}
