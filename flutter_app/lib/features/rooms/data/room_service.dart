import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';

// Client-side room name override map
// Maps room_number (String) → display label shown in the app
// This overrides whatever room_types.name the database returns
const _roomNameOverrides = <String, String>{
  '101': 'Tent Stay',
  '102': 'Dormitory (Small) Stay',
  '103': 'Dormitory (Large) Stay',
  '201': 'Anjanpushp Villa',
  '202': 'Deluxe/Cottage Room',
  '301': 'Premium Room - Tikona View',
  '302': 'Premium Room - Deck Bed',
};

final allRoomsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  List<Map<String, dynamic>> rooms = [];

  // Try JOIN query first so we get the room_types.name from the DB
  try {
    rooms = List<Map<String, dynamic>>.from(
      await client
          .from('rooms')
          .select('*, room_types(name)')
          .order('room_number', ascending: true),
    );
  } catch (_) {
    // Fall back to view
    try {
      rooms = List<Map<String, dynamic>>.from(
        await client
            .from('v_room_availability')
            .select()
            .order('room_number', ascending: true),
      );
    } catch (_) {}
  }

  // Apply display name overrides / enrich with correct room type names
  return rooms.map((r) {
    final num = r['room_number']?.toString() ?? '';
    final override = _roomNameOverrides[num];
    if (override != null) {
      return {
        ...r,
        'room_type_name': override,     // used by _RoomCard
        'type_name': override,           // fallback key
      };
    }
    // Use whatever the DB JOIN returned
    final dbName = (r['room_types'] as Map<String, dynamic>?)?['name'] as String?;
    if (dbName != null && dbName.isNotEmpty && dbName != 'Room') {
      return {...r, 'room_type_name': dbName, 'type_name': dbName};
    }
    return r;
  }).toList();
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
