enum UserRole { owner, staff }

extension UserRoleX on UserRole {
  String get value {
    switch (this) {
      case UserRole.owner:
        return 'OWNER';
      case UserRole.staff:
        return 'STAFF';
    }
  }

  bool get isOwner => this == UserRole.owner;
  bool get isStaff => this == UserRole.staff;

  static UserRole fromString(String value) {
    return value.toUpperCase() == 'OWNER' ? UserRole.owner : UserRole.staff;
  }
}
