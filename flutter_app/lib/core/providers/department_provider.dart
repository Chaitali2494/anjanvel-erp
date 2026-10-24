import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

// Which department's data a screen should show.
//
// Department keys: 'all' | 'kitchen' | 'housekeeping' | 'activity'
//   • Owner & Manager           → 'all' (see every department)
//   • Kitchen staff             → 'kitchen'
//   • Housekeeping staff        → 'housekeeping'
//   • Activity coordinator/guide → 'activity'

/// Department for a staff role. Null for Owner/Manager (= see everything).
String? departmentForRole(String? role) {
  switch ((role ?? '').toUpperCase()) {
    case 'KITCHEN':
      return 'kitchen';
    case 'HOUSEKEEPING':
      return 'housekeeping';
    case 'ACTIVITY_COORDINATOR':
    case 'GUIDE':
      return 'activity';
    default:
      return null;
  }
}

/// Department for a dashboard route, e.g. '/dashboard/kitchen' → 'kitchen'.
String departmentForLocation(String location) {
  if (location.contains('kitchen')) return 'kitchen';
  if (location.contains('housekeeping')) return 'housekeeping';
  if (location.contains('activity')) return 'activity';
  return 'all'; // owner / manager dashboards
}

/// Final department to show, given the dashboard the bell was opened from.
/// A logged-in user's role always wins:
///   • Owner/Manager accounts see everything, on any dashboard.
///   • Department staff only ever see their own department.
/// Without a login (demo / role-selection mode) the dashboard decides.
final effectiveDepartmentProvider = Provider.family<String, String?>((ref, fromDashboard) {
  final user = ref.watch(currentUserProvider);
  if (user != null) {
    final role = user.role.toUpperCase();
    if (role == 'OWNER' || role == 'MANAGER') return 'all';
    final dept = departmentForRole(role);
    if (dept != null) return dept;
  }
  return fromDashboard ??
      departmentForLocation(ref.watch(activeRoleDashboardProvider));
});


/// Human-readable name, e.g. 'kitchen' → 'Kitchen'.
String departmentLabel(String dept) => dept == 'all'
    ? 'All departments'
    : dept == 'activity'
        ? 'Activities'
        : '${dept[0].toUpperCase()}${dept.substring(1)}';

/// Dashboard route for a department (used by Home buttons).
String dashboardForDepartment(String dept, String fallback) {
  switch (dept) {
    case 'kitchen':
      return '/dashboard/kitchen';
    case 'housekeeping':
      return '/dashboard/housekeeping';
    case 'activity':
      return '/dashboard/activity-coordinator';
    default:
      return fallback;
  }
}
