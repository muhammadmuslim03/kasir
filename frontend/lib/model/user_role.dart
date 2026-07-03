enum UserRole { owner, cashier }

extension UserRoleX on UserRole {
  String get apiValue => switch (this) {
    UserRole.owner => 'owner',
    UserRole.cashier => 'cashier',
  };

  String get label => switch (this) {
    UserRole.owner => 'Pemilik',
    UserRole.cashier => 'Kasir',
  };

  bool get canManageProducts => true;
  bool get canCreateProducts => true;
  bool get canEditProducts => true;
  bool get canDeleteProducts => this == UserRole.owner;
  bool get canViewReports => this == UserRole.owner;
  bool get canViewHistory => true;
}

UserRole userRoleFromApi(String value) {
  return switch (value) {
    'cashier' => UserRole.cashier,
    _ => UserRole.owner,
  };
}
