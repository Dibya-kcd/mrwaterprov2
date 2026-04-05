// ════════════════════════════════════════════════════════════════════════════
// staff_member.dart — Staff member model
// ════════════════════════════════════════════════════════════════════════════

import 'package:uuid/uuid.dart';
import '../models/user_role.dart';

const _uuid = Uuid();

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  final text = value.toString().trim().toLowerCase();
  if (text == 'true') return true;
  if (text == 'false') return false;
  return fallback;
}

class StaffMember {
  final String id;
  final String name;
  final String phone;
  final String pin;
  final bool isActive;
  final List<String> permissions;
  final UserRole role;

  /// SHA-256 hash of the PIN (salt:pin). Stored in Firestore — never plain text.
  /// Empty string means PIN has NOT been hashed yet (legacy plain-text pin field).
  final String pinHash;

  /// Per-user random salt used when hashing the PIN. Stored alongside pinHash.
  /// For new users this is set to the user's UID. For legacy records it is ''.
  final String pinSalt;

  const StaffMember({
    required this.id,
    required this.name,
    required this.phone,
    required this.pin,
    this.isActive = true,
    this.permissions = const [
      'dashboard','transactions','customers','inventory','load_unload',
      'payments','notifications','reports','settings','expenses','smart_entry',
    ],
    this.role = UserRole.staff,
    this.pinHash = '',
    this.pinSalt = '',
  });

  bool can(String perm) => permissions.contains(perm);

  bool get hasPinHash => pinHash.isNotEmpty && pinSalt.isNotEmpty;
  bool get isOwner => role == UserRole.owner;

  StaffMember copyWith({
    String? name,
    String? phone,
    String? pin,
    bool? isActive,
    List<String>? permissions,
    UserRole? role,
    String? pinHash,
    String? pinSalt,
  }) => StaffMember(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    pin: pin ?? this.pin,
    isActive: isActive ?? this.isActive,
    permissions: permissions ?? this.permissions,
    role: role ?? this.role,
    pinHash: pinHash ?? this.pinHash,
    pinSalt: pinSalt ?? this.pinSalt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'pin': pin,
    'isActive': isActive,
    'permissions': permissions,
    'role': role.value,
    'pinHash': pinHash,
    'pinSalt': pinSalt,
  };

  factory StaffMember.fromJson(Map<String, dynamic> j) => StaffMember(
    id: _asString(j['id'], fallback: _uuid.v4()),
    name: _asString(j['name'], fallback: 'Staff'),
    phone: _asString(j['phone']),
    pin: _asString(j['pin']),
    isActive: _asBool(j['isActive'], fallback: true),
    permissions: List<String>.from(j['permissions'] ?? [
      'dashboard','transactions','customers','inventory','load_unload',
      'payments','notifications','reports','settings','expenses','smart_entry',
    ]),
    role: UserRoleX.fromString(_asString(j['role'], fallback: 'STAFF')),
    pinHash: _asString(j['pinHash']),
    pinSalt: _asString(j['pinSalt']),
  );
}