enum UserRole {
  OWNER,
  MANAGER,
  HOUSEKEEPING,
  KITCHEN,
  ACTIVITY_COORDINATOR,
  SHOP_OPERATOR,
  ACCOUNTANT,
  GUIDE;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (e) => e.name == value.toUpperCase(),
      orElse: () => UserRole.MANAGER,
    );
  }
}
