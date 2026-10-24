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

/// Final department to show, given the dashboard the screen was opened from.
///
///   • Department staff (Kitchen / Housekeeping / Activity accounts) are
///     always locked to their own department, whatever page they open.
///   • Owner & Manager see the department of the dashboard they're on:
///     from the Housekeeping dashboard → housekeeping only; from the Owner or
///     Manager dashboard → everything.
final effectiveDepartmentProvider = Provider.family<String, String?>((ref, fromDashboard) {
  final staffDept = departmentForRole(ref.watch(currentUserProvider)?.role);
  if (staffDept != null) return staffDept;
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
