import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/role_selection_screen.dart';
import '../../features/dashboard/presentation/screens/owner_dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/manager_dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/kitchen_dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/housekeeping_dashboard_screen.dart';
import '../../features/bookings/presentation/screens/booking_list_screen.dart';
import '../../features/bookings/presentation/screens/booking_detail_screen.dart';
import '../../features/bookings/presentation/screens/create_booking_screen.dart';
import '../../features/bookings/presentation/screens/booking_calendar_screen.dart';
import '../../features/guests/presentation/screens/guest_list_screen.dart';
import '../../features/guests/presentation/screens/guest_profile_screen.dart';
import '../../features/rooms/presentation/screens/room_dashboard_screen.dart';
import '../../features/rooms/presentation/screens/room_detail_screen.dart';
import '../../features/rooms/presentation/screens/room_allocation_screen.dart';
import '../../features/checkin/presentation/screens/check_in_screen.dart';
import '../../features/checkin/presentation/screens/check_out_screen.dart';
import '../../features/food/presentation/screens/food_orders_screen.dart';
import '../../features/food/presentation/screens/food_dashboard_screen.dart';
import '../../features/food/presentation/screens/order_detail_screen.dart';
import '../../features/food/presentation/screens/meal_planning_screen.dart';
import '../../features/activities/presentation/screens/activity_registration_screen.dart';
import '../../features/activities/presentation/screens/activities_dashboard_screen.dart';
import '../../features/heritage/presentation/screens/heritage_walk_screen.dart';
import '../../features/heritage/presentation/screens/guide_dashboard_screen.dart';
import '../../features/heritage/presentation/screens/guide_assignment_screen.dart';
import '../../features/inventory/presentation/screens/inventory_list_screen.dart';
import '../../features/inventory/presentation/screens/stock_movement_screen.dart';
import '../../features/shop/presentation/screens/shop_product_list_screen.dart';
import '../../features/shop/presentation/screens/shop_cart_screen.dart';
import '../../features/shop/presentation/screens/shop_checkout_screen.dart';
import '../../features/shop/presentation/screens/shop_dashboard_screen.dart';
import '../../features/shop/presentation/screens/product_detail_screen.dart';
import '../../features/billing/presentation/screens/billing_screen.dart';
import '../../features/billing/presentation/screens/payment_screen.dart';
import '../../features/feedback/presentation/screens/feedback_dashboard_screen.dart';
import '../../features/housekeeping/presentation/screens/housekeeping_task_list_screen.dart';
import '../../features/housekeeping/presentation/screens/cleaning_checklist_screen.dart';
import '../../features/maintenance/presentation/screens/maintenance_screen.dart';
import '../../features/maintenance/presentation/screens/create_ticket_screen.dart';
import '../../features/maintenance/presentation/screens/ticket_detail_screen.dart';
import '../../features/reports/presentation/screens/analytics_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/help_center_screen.dart';
import '../../features/settings/presentation/screens/user_management_screen.dart';
import '../../features/settings/presentation/screens/audit_log_screen.dart';
import '../../features/settings/presentation/screens/system_settings_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/staff/presentation/screens/staff_management_screen.dart';
import '../../features/staff/presentation/screens/staff_attendance_screen.dart';
import '../../features/staff/presentation/screens/staff_access_screen.dart';
import '../../features/staff/presentation/screens/staff_portal_screen.dart';
import '../../features/staff/presentation/screens/leave_management_screen.dart';
import '../../features/leads/presentation/screens/lead_list_screen.dart';
import '../../features/leads/presentation/screens/lead_detail_screen.dart';
import '../providers/auth_provider.dart';
import '../models/user_role.dart';


final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final loc = state.matchedLocation;

      // Allow splash to handle its own redirect
      if (loc == '/splash') return null;

      // Auth screens always accessible
      if (loc.startsWith('/auth')) return null;

      // These screens are accessible without login (demo / role-based access)
      const openRoutes = [
        '/role-selection', '/help',
        '/dashboard/owner', '/dashboard/manager',
        '/dashboard/kitchen', '/dashboard/housekeeping',
        '/bookings', '/guests', '/rooms', '/checkin', '/checkout',
        '/housekeeping', '/food', '/activities', '/heritage',
        '/inventory', '/shop', '/maintenance', '/billing', '/payment',
        '/feedback', '/reports', '/settings', '/notifications',
        '/profile', '/staff', '/leads', '/staff/portal', '/staff/access', '/staff/leaves',
      ];
      final isOpen = openRoutes.any((r) => loc == r || loc.startsWith('$r/'));
      if (isOpen) return null;

      // If logged in and hit an auth screen, go home
      if (isLoggedIn && loc.startsWith('/auth')) {
        return _getHomeRoute(authState.value?.role);
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),

      // Auth Routes
      GoRoute(
        path: '/auth',
        builder: (_, __) => const LoginScreen(),
        routes: [
          GoRoute(path: 'login',            builder: (_, __) => const LoginScreen()),
          GoRoute(path: 'role-selection',   builder: (_, __) => const RoleSelectionScreen()),
          GoRoute(path: 'otp',              builder: (_, state) => OtpScreen(phone: state.extra as String)),
          GoRoute(path: 'forgot-password',  builder: (_, __) => const ForgotPasswordScreen()),
        ],
      ),

      // Role Selection (standalone)
      GoRoute(path: '/role-selection', builder: (_, __) => const RoleSelectionScreen()),

      // Dashboard Routes (role-based)
      GoRoute(path: '/dashboard/owner',         builder: (_, __) => const OwnerDashboardScreen()),
      GoRoute(path: '/dashboard/manager',       builder: (_, __) => const ManagerDashboardScreen()),
      GoRoute(path: '/dashboard/kitchen',       builder: (_, __) => const KitchenDashboardScreen()),
      GoRoute(path: '/dashboard/housekeeping',  builder: (_, __) => const HousekeepingDashboardScreen()),

      // CRM Routes
      GoRoute(
        path: '/leads',
        builder: (_, __) => const LeadListScreen(),
        routes: [
          GoRoute(path: ':id', builder: (_, state) => LeadDetailScreen(leadId: state.pathParameters['id']!)),
        ],
      ),

      // Booking Routes
      GoRoute(
        path: '/bookings',
        builder: (_, __) => const BookingListScreen(),
        routes: [
          GoRoute(path: 'create',   builder: (_, __) => const CreateBookingScreen()),
          GoRoute(path: 'calendar', builder: (_, __) => const BookingCalendarScreen()),
          GoRoute(path: ':id',      builder: (_, state) => BookingDetailScreen(bookingId: state.pathParameters['id']!)),
        ],
      ),

      // Guest Routes
      GoRoute(
        path: '/guests',
        builder: (_, __) => const GuestListScreen(),
        routes: [
          GoRoute(path: ':id', builder: (_, state) => GuestProfileScreen(guestId: state.pathParameters['id']!)),
        ],
      ),

      // Room Routes
      GoRoute(
        path: '/rooms',
        builder: (_, __) => const RoomDashboardScreen(),
        routes: [
          GoRoute(path: 'allocation', builder: (_, __) => const RoomAllocationScreen()),
          GoRoute(path: ':id',        builder: (_, state) => RoomDetailScreen(roomId: state.pathParameters['id']!)),
        ],
      ),

      // Check-in / Check-out
      GoRoute(path: '/checkin', builder: (_, __) => const CheckInScreen()),
      GoRoute(path: '/checkin/:bookingId', builder: (_, state) => CheckInScreen(bookingId: state.pathParameters['bookingId'])),
      GoRoute(path: '/checkout/:bookingId', builder: (_, state) => CheckOutScreen(bookingId: state.pathParameters['bookingId']!)),

      // Housekeeping
      GoRoute(
        path: '/housekeeping',
        builder: (_, __) => const HousekeepingTaskListScreen(),
        routes: [
          GoRoute(
            path: 'checklist',
            builder: (_, state) => CleaningChecklistScreen(task: state.extra as Map<String, dynamic>?),
          ),
        ],
      ),

      // Food
      GoRoute(
        path: '/food',
        builder: (_, __) => const FoodOrdersScreen(),
        routes: [
          GoRoute(path: 'dashboard',    builder: (_, __) => const FoodDashboardScreen()),
          GoRoute(path: 'meal-planning',builder: (_, __) => const MealPlanningScreen()),
          GoRoute(path: ':id',          builder: (_, state) => OrderDetailScreen(orderId: state.pathParameters['id']!, initialData: state.extra as Map<String, dynamic>?)),
        ],
      ),

      // Activities — go straight to booking form
      GoRoute(
        path: '/activities',
        builder: (_, __) => const ActivityRegistrationScreen(activityId: ''),
        routes: [
          GoRoute(path: 'dashboard', builder: (_, __) => const ActivitiesDashboardScreen()),
          GoRoute(path: 'register', builder: (_, __) => const ActivityRegistrationScreen(activityId: '')),
        ],
      ),

      // Heritage Walk
      GoRoute(
        path: '/heritage',
        builder: (_, __) => const HeritageWalkScreen(),
        routes: [
          GoRoute(path: 'guide',      builder: (_, __) => const GuideDashboardScreen()),
          GoRoute(path: 'assignment', builder: (_, __) => const GuideAssignmentScreen()),
        ],
      ),

      // Inventory
      GoRoute(
        path: '/inventory',
        builder: (_, __) => const InventoryListScreen(),
        routes: [
          GoRoute(path: 'movement', builder: (_, __) => const StockMovementScreen()),
        ],
      ),

      // Shop
      GoRoute(
        path: '/shop',
        builder: (_, __) => const ShopProductListScreen(),
        routes: [
          GoRoute(path: 'dashboard', builder: (_, __) => const ShopDashboardScreen()),
          GoRoute(path: 'cart',      builder: (_, __) => const ShopCartScreen()),
          GoRoute(path: 'checkout',  builder: (_, __) => const ShopCheckoutScreen()),
          GoRoute(path: ':id',       builder: (_, state) => ProductDetailScreen(productId: state.pathParameters['id']!, initialData: state.extra as Map<String, dynamic>?)),
        ],
      ),

      // Maintenance
      GoRoute(
        path: '/maintenance',
        builder: (_, __) => const MaintenanceScreen(),
        routes: [
          GoRoute(path: 'create', builder: (_, __) => const CreateTicketScreen()),
          GoRoute(path: ':id',    builder: (_, state) => TicketDetailScreen(ticketId: state.pathParameters['id']!, initialData: state.extra as Map<String, dynamic>?)),
        ],
      ),

      // Billing & Payment
      GoRoute(
        path: '/billing',
        builder: (_, state) {
          final extra = state.extra is Map ? state.extra as Map : null;
          return BillingScreen(
            bookingId:  extra?['booking_id']  as String?,
            roomNumber: extra?['room_number'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/payment',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return PaymentScreen(
            amount:    (extra?['amount'] as num?)?.toDouble() ?? 0,
            bookingId: extra?['booking_id'] as String?,
          );
        },
      ),

      // Feedback
      GoRoute(path: '/feedback', builder: (_, __) => const FeedbackDashboardScreen()),

      // Reports
      GoRoute(path: '/reports', builder: (_, __) => const AnalyticsScreen()),

      // Settings
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
        routes: [
          GoRoute(path: 'help',      builder: (_, __) => const HelpCenterScreen()),
          GoRoute(path: 'users',     builder: (_, __) => const UserManagementScreen()),
          GoRoute(path: 'audit-log', builder: (_, __) => const AuditLogScreen()),
          GoRoute(path: 'system',    builder: (_, __) => const SystemSettingsScreen()),
        ],
      ),

      // Help (also accessible from nav)
      GoRoute(path: '/help', builder: (_, __) => const HelpCenterScreen()),

      // Notifications
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),

      // Profile
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),

      // Staff Management
      GoRoute(
        path: '/staff',
        builder: (_, __) => const StaffManagementScreen(),
        routes: [
          GoRoute(path: 'attendance', builder: (_, __) => const StaffAttendanceScreen()),
          GoRoute(path: 'access',    builder: (_, __) => const StaffAccessScreen()),
          GoRoute(path: 'portal',    builder: (_, __) => const StaffPortalScreen()),
          GoRoute(path: 'leaves',    builder: (_, __) => const LeaveManagementScreen()),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});

String _getHomeRoute(String? role) {
  switch (role) {
    case 'OWNER':         return '/dashboard/owner';
    case 'MANAGER':       return '/dashboard/manager';
    case 'KITCHEN':       return '/dashboard/kitchen';
    case 'HOUSEKEEPING':  return '/dashboard/housekeeping';
    case 'GUIDE':
    case 'ACTIVITY_COORDINATOR': return '/activities';
    case 'SHOP_OPERATOR': return '/shop';
    case 'ACCOUNTANT':    return '/reports';
    default:              return '/dashboard/manager';
  }
}
