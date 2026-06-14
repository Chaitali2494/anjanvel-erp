import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String fullName,
    String? phone,
    String? email,
    required String role,
    String? avatarUrl,
    @Default(true) bool isActive,
    String? employeeId,
    String? department,
    DateTime? joinDate,
    DateTime? lastLogin,
    @Default({}) Map<String, dynamic> meta,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) => _$AppUserFromJson(json);
}
