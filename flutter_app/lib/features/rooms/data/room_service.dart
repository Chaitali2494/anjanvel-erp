import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';

final allRoomsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  return await client
      .from('v_room_availability')
      .select()
      .order('room_number', ascending: true);
});

final roomDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    final data = await client
        .from('rooms')
        .select('*, room_types(*), booking_rooms(*, bookings(*, guests(*)))')
        .eq('id', id)
        .maybeSingle();
    return data ?? {'id': id, 'room_number': id, 'status': 'AVAILABLE'};
  } catch (_) {
    return {'id': id, 'room_number': id, 'status': 'AVAILABLE'};
  }
});

final roomServiceProvider = Provider((ref) => RoomService(ref.watch(supabaseClientProvider)));

class RoomService {
  final client;
  RoomService(this.client);

  Future<void> updateRoomStatus(String roomId, String status) async {
    await client.from('rooms').update({'status': status}).eq('id', roomId);
    await client.from('room_history').insert({
      'room_id': roomId,
      'status': status,
    });
  }

  Future<List<Map<String, dynamic>>> getAvailableRooms(String checkIn, String checkOut) async {
    return await client.rpc('get_available_rooms', params: {
      'p_check_in': checkIn,
      'p_check_out': checkOut,
    });
  }
}
