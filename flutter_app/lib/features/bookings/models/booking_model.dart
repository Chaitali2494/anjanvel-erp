import 'package:freezed_annotation/freezed_annotation.dart';

part 'booking_model.freezed.dart';
part 'booking_model.g.dart';

@freezed
class BookingModel with _$BookingModel {
  const factory BookingModel({
    required String id,
    required String bookingNumber,
    String? leadId,
    String? primaryGuestId,
    String? packageId,
    @Default('INQUIRY') String status,
    @Default('PENDING') String paymentStatus,
    required String checkInDate,
    String? checkOutDate,
    @Default(1) int numAdults,
    @Default(0) int numChildren,
    @Default(0) int numInfants,
    @Default(0) double baseAmount,
    @Default(0) double addonAmount,
    @Default(0) double discountAmount,
    @Default(0) double taxAmount,
    @Default(0) double totalAmount,
    @Default(0) double paidAmount,
    double? balanceAmount,
    String? specialRequests,
    String? internalNotes,
    @Default('PHONE') String source,
    String? confirmedBy,
    String? confirmedAt,
    String? cancelledAt,
    String? cancellationReason,
    String? createdBy,
    required DateTime createdAt,
    required DateTime updatedAt,
    // Joined fields
    Map<String, dynamic>? guest,
    Map<String, dynamic>? package,
    List<Map<String, dynamic>>? rooms,
    List<Map<String, dynamic>>? addons,
    List<Map<String, dynamic>>? payments,
    // View fields
    String? guestName,
    String? guestPhone,
    String? packageName,
    String? packageType,
    List<String>? roomNumbers,
    int? totalGuests,
  }) = _BookingModel;

  factory BookingModel.fromJson(Map<String, dynamic> json) => _$BookingModelFromJson(json);
}
