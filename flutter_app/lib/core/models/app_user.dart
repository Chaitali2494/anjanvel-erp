class AppUser {
  final String id;
  final String fullName;
  final String? phone;
  final String? email;
  final String role;
  final String? avatarUrl;
  final bool isActive;
  final String? employeeId;
  final String? department;
  final DateTime? joinDate;
  final DateTime? lastLogin;
  final Map<String, dynamic> meta;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppUser({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    required this.role,
    this.avatarUrl,
    this.isActive = true,
    this.employeeId,
    this.department,
    this.joinDate,
    this.lastLogin,
    this.meta = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'User',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String? ?? 'MANAGER',
      avatarUrl: json['avatar_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      employeeId: json['employee_id'] as String?,
      department: json['department'] as String?,
      joinDate: json['join_date'] != null ? DateTime.parse(json['join_date']) : null,
      lastLogin: json['last_login'] != null ? DateTime.parse(json['last_login']) : null,
      meta: json['meta'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  AppUser copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? email,
    String? role,
    String? avatarUrl,
    bool? isActive,
    String? employeeId,
    String? department,
    DateTime? joinDate,
    DateTime? lastLogin,
    Map<String, dynamic>? meta,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActive: isActive ?? this.isActive,
      employeeId: employeeId ?? this.employeeId,
      department: department ?? this.department,
      joinDate: joinDate ?? this.joinDate,
      lastLogin: lastLogin ?? this.lastLogin,
      meta: meta ?? this.meta,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
