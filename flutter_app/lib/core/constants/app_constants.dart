/// Anjanvel ERP - App Constants

class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Anjanvel ERP';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Agro Tourism Resort Management';

  // Supabase
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // Storage Buckets
  static const String bucketGuests = 'guest-documents';
  static const String bucketRooms = 'room-images';
  static const String bucketActivities = 'activity-images';
  static const String bucketArtisans = 'artisan-portfolio';
  static const String bucketInvoices = 'invoices';
  static const String bucketShop = 'shop-products';
  static const String bucketHousekeeping = 'housekeeping-photos';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Cache Duration
  static const Duration cacheDuration = Duration(minutes: 15);
  static const Duration sessionTimeout = Duration(hours: 8);

  // GST
  static const double defaultGstPercent = 18.0;
  static const double reducedGstPercent = 5.0;

  // Company Info
  static const String companyName = 'Anjanvel Agro Tourism Resort';
  static const String companyPhone = '+91 9876543210';
  static const String companyEmail = 'info@anjanvel.com';
  static const String companyAddress = 'Anjanvel Village, Maharashtra, India';
  static const String companyGstin = '27XXXXXXXXXXXZX';
  static const String companyWebsite = 'https://anjanvel.com';

  // WhatsApp
  static const String whatsappBusinessNumber = '+91XXXXXXXXXX';

  // Firebase
  static const String fcmTopicAll = 'all_staff';
  static const String fcmTopicHousekeeping = 'housekeeping';
  static const String fcmTopicKitchen = 'kitchen';
  static const String fcmTopicManagement = 'management';
}

class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/auth/login';
  static const String otp = '/auth/otp';
  static const String forgotPassword = '/auth/forgot-password';
  static const String ownerDashboard = '/dashboard/owner';
  static const String managerDashboard = '/dashboard/manager';
  static const String kitchenDashboard = '/dashboard/kitchen';
  static const String housekeepingDashboard = '/dashboard/housekeeping';
  static const String leads = '/leads';
  static const String bookings = '/bookings';
  static const String createBooking = '/bookings/create';
  static const String bookingCalendar = '/bookings/calendar';
  static const String guests = '/guests';
  static const String rooms = '/rooms';
  static const String roomAllocation = '/rooms/allocation';
  static const String food = '/food';
  static const String mealPlanning = '/food/meal-planning';
  static const String activities = '/activities';
  static const String heritage = '/heritage';
  static const String inventory = '/inventory';
  static const String shop = '/shop';
  static const String shopCart = '/shop/cart';
  static const String maintenance = '/maintenance';
  static const String reports = '/reports';
  static const String settings = '/settings';
  static const String notifications = '/notifications';
  static const String profile = '/profile';
  static const String staff = '/staff';
}

class UserRoles {
  static const String owner = 'OWNER';
  static const String manager = 'MANAGER';
  static const String housekeeping = 'HOUSEKEEPING';
  static const String kitchen = 'KITCHEN';
  static const String activityCoordinator = 'ACTIVITY_COORDINATOR';
  static const String shopOperator = 'SHOP_OPERATOR';
  static const String accountant = 'ACCOUNTANT';
  static const String guide = 'GUIDE';
}

class BookingStatus {
  static const String inquiry = 'INQUIRY';
  static const String confirmed = 'CONFIRMED';
  static const String checkedIn = 'CHECKED_IN';
  static const String checkedOut = 'CHECKED_OUT';
  static const String cancelled = 'CANCELLED';
  static const String noShow = 'NO_SHOW';
}

class RoomStatus {
  static const String available = 'AVAILABLE';
  static const String occupied = 'OCCUPIED';
  static const String reserved = 'RESERVED';
  static const String cleaning = 'CLEANING';
  static const String maintenance = 'MAINTENANCE';
}

class PaymentMethod {
  static const String cash = 'CASH';
  static const String upi = 'UPI';
  static const String card = 'CARD';
  static const String online = 'ONLINE';
  static const String bankTransfer = 'BANK_TRANSFER';
}
