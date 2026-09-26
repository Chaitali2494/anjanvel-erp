class BookingModel {
  final String id;
  final String bookingNumber;
  final String? leadId;
  final String? primaryGuestId;
  final String? packageId;
  final String status;
  final String paymentStatus;
  final String checkInDate;
  final String? checkOutDate;
  final int numAdults;
  final int numChildren;
  final int numInfants;
  final double baseAmount;
  final double addonAmount;
  final double discountAmount;
  final double taxAmount;
  final double totalAmount;
  final double paidAmount;
  final double? balanceAmount;
  final String? specialRequests;
  final String? internalNotes;
  final String source;
  final String? confirmedBy;
  final String? confirmedAt;
  final String? cancelledAt;
  final String? cancellationReason;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? guest;
  final Map<String, dynamic>? package;
  final List<Map<String, dynamic>>? rooms;
  final List<Map<String, dynamic>>? addons;
  final List<Map<String, dynamic>>? payments;
  final String? guestName;
  final String? guestPhone;
  final String? packageName;
  final String? packageType;
  final List<String>? roomNumbers;
  final int? totalGuests;

  const BookingModel({
    required this.id,
    required this.bookingNumber,
    this.leadId,
    this.primaryGuestId,
    this.packageId,
    this.status = 'INQUIRY',
    this.paymentStatus = 'PENDING',
    required this.checkInDate,
    this.checkOutDate,
    this.numAdults = 1,
    this.numChildren = 0,
    this.numInfants = 0,
    this.baseAmount = 0,
    this.addonAmount = 0,
    this.discountAmount = 0,
    this.taxAmount = 0,
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.balanceAmount,
    this.specialRequests,
    this.internalNotes,
    this.source = 'PHONE',
    this.confirmedBy,
    this.confirmedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.guest,
    this.package,
    this.rooms,
    this.addons,
    this.payments,
    this.guestName,
    this.guestPhone,
    this.packageName,
    this.packageType,
    this.roomNumbers,
    this.totalGuests,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] as String,
      bookingNumber: json['booking_number'] as String? ?? '',
      leadId: json['lead_id'] as String?,
      primaryGuestId: json['primary_guest_id'] as String?,
      packageId: json['package_id'] as String?,
      status: json['status'] as String? ?? 'INQUIRY',
      paymentStatus: json['payment_status'] as String? ?? 'PENDING',
      checkInDate: json['check_in_date'] as String? ?? '',
      checkOutDate: json['check_out_date'] as String?,
      numAdults: (json['num_adults'] as num?)?.toInt() ?? 1,
      numChildren: (json['num_children'] as num?)?.toInt() ?? 0,
      numInfants: (json['num_infants'] as num?)?.toInt() ?? 0,
      baseAmount: (json['base_amount'] as num?)?.toDouble() ?? 0,
      addonAmount: (json['addon_amount'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
      balanceAmount: (json['balance_amount'] as num?)?.toDouble(),
      specialRequests: json['special_requests'] as String?,
      internalNotes: json['internal_notes'] as String?,
      source: json['source'] as String? ?? 'PHONE',
      confirmedBy: json['confirmed_by'] as String?,
      confirmedAt: json['confirmed_at'] as String?,
      cancelledAt: json['cancelled_at'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      guest: json['guests'] as Map<String, dynamic>?,
      package: json['packages'] as Map<String, dynamic>?,
      rooms: (json['booking_rooms'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      addons: (json['booking_addons'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      payments: (json['payments'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      guestName: json['guest_name'] as String?,
      guestPhone: json['guest_phone'] as String?,
      packageName: json['package_name'] as String?,
      packageType: json['package_type'] as String?,
      roomNumbers: (json['room_numbers'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      totalGuests: (json['total_guests'] as num?)?.toInt(),
    );
  }
}
