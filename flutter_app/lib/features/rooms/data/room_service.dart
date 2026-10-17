import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../bookings/data/booking_service.dart';

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

  // Use v_room_availability as primary — this view was working before and
  // already has the right columns. The JOIN on rooms+room_types can fail due
  // to RLS so we keep it only as a last-resort fallback.
  try {
    rooms = List<Map<String, dynamic>>.from(
      await client
          .from('v_room_availability')
          .select()
          .order('room_number', ascending: true),
    );
  } catch (_) {
    // Last-resort: direct table (may be blocked by RLS)
    try {
      rooms = List<Map<String, dynamic>>.from(
        await client
            .from('rooms')
            .select()
            .order('room_number', ascending: true),
      );
    } catch (_) {}
  }

  // Apply display name overrides + session-based status overrides
  return rooms.map((r) {
    final num = r['room_number']?.toString() ?? '';
    Map<String, dynamic> enriched = Map<String, dynamic>.from(r);

    // Room type display name
    final nameOverride = _roomNameOverrides[num];
    if (nameOverride != null) {
      enriched['room_type_name'] = nameOverride;
      enriched['type_name']      = nameOverride;
    } else {
      final dbName = (r['room_types'] as Map<String, dynamic>?)?['name'] as String?;
      if (dbName != null && dbName.isNotEmpty && dbName != 'Room') {
        enriched['room_type_name'] = dbName;
        enriched['type_name']      = dbName;
      }
    }

    // Session status override — so local check-ins show room as OCCUPIED/RESERVED
    final sessionBooking = sessionRoomBookings[num];
    if (sessionBooking != null) {
      final bId     = sessionBooking['id'] as String? ?? '';
      final bStatus = sessionStatusOverrides[bId] ?? sessionBooking['status'] as String? ?? '';
      final roomStatus = () {
        switch (bStatus) {
          case 'CHECKED_IN': return 'OCCUPIED';
          case 'CONFIRMED':  return 'RESERVED';
          default:           return null;
        }
      }();
      if (roomStatus != null) enriched['status'] = roomStatus;
      // Expose guest name for room cards
      final guestName = (sessionBooking['guests'] as Map<String,dynamic>?)?['full_name'] as String?;
      if (guestName != null && guestName.isNotEmpty) {
        enriched['current_guest'] = guestName;
      }
    }

    return enriched;
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
