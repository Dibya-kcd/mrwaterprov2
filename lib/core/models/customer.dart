// ════════════════════════════════════════════════════════════════════════════
// customer.dart — Customer model
// FIX v2:
//   • copyWith uses sentinel pattern so nullable coolPriceOverride /
//     petPriceOverride can be explicitly cleared (set to null).
//     Old pattern: `coolPriceOverride ?? this.coolPriceOverride` made it
//     impossible to remove a per-customer price override once set.
// ════════════════════════════════════════════════════════════════════════════

import 'package:uuid/uuid.dart';

const _uuid = Uuid();
String _now() => DateTime.now().toIso8601String();

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  final text = value.toString().trim().toLowerCase();
  if (text == 'true') return true;
  if (text == 'false') return false;
  return fallback;
}

class Customer {
  final String id, name, phone, area, address, createdAt;
  final bool isActive;

  /// Ledger balance.
  /// Negative = customer owes you (dues).  Positive = customer has credit.
  final double balance;

  /// Jars currently with this customer (from owner's inventory — tracked)
  final int coolOut, petOut;

  /// Customer's own jars (not from owner's inventory — untracked, for info only)
  final int ownCoolJars, ownPetJars;

  /// Security deposit paid by this customer
  final double securityDeposit;

  /// Per-jar price overrides for this customer (null = use global settings price)
  final double? coolPriceOverride, petPriceOverride;

  /// Internal notes about customer
  final String notes;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.area = '',
    this.address = '',
    this.isActive = true,
    this.balance = 0,
    this.coolOut = 0,
    this.petOut = 0,
    this.ownCoolJars = 0,
    this.ownPetJars = 0,
    this.securityDeposit = 0,
    this.coolPriceOverride,
    this.petPriceOverride,
    this.notes = '',
    required this.createdAt,
  });

  String get initials {
    final safeName = name.trim();
    if (safeName.isEmpty) return 'CU';
    final parts =
        safeName.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return safeName.substring(0, safeName.length >= 2 ? 2 : 1).toUpperCase();
  }

  bool get hasJarsOut => coolOut > 0 || petOut > 0;
  bool get hasCredit => balance > 0;
  bool get hasAdvance => balance > 0; // kept for compatibility
  bool get hasDues => balance < 0;
  double get creditBalance => balance > 0 ? balance : 0;
  double get advanceBalance => creditBalance; // kept for compatibility
  double get ledgerBalance => balance < 0 ? balance : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'area': area,
        'address': address,
        'isActive': isActive,
        'balance': balance,
        'coolOut': coolOut,
        'petOut': petOut,
        'ownCoolJars': ownCoolJars,
        'ownPetJars': ownPetJars,
        'securityDeposit': securityDeposit,
        'coolPriceOverride': coolPriceOverride,
        'petPriceOverride': petPriceOverride,
        'notes': notes,
        'createdAt': createdAt,
      };

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: _asString(j['id'], fallback: _uuid.v4()),
        name: _asString(j['name'], fallback: 'Unnamed Customer'),
        phone: _asString(j['phone']),
        area: _asString(j['area']),
        address: _asString(j['address']),
        isActive: _asBool(j['isActive'], fallback: true),
        balance: _asDouble(j['balance']),
        coolOut: _asInt(j['coolOut']),
        petOut: _asInt(j['petOut']),
        ownCoolJars: _asInt(j['ownCoolJars']),
        ownPetJars: _asInt(j['ownPetJars']),
        securityDeposit: _asDouble(j['securityDeposit']),
        coolPriceOverride: j['coolPriceOverride'] == null
            ? null
            : _asDouble(j['coolPriceOverride']),
        petPriceOverride: j['petPriceOverride'] == null
            ? null
            : _asDouble(j['petPriceOverride']),
        notes: _asString(j['notes']),
        createdAt: _asString(j['createdAt'], fallback: _now()),
      );

  // FIX: Sentinel pattern for nullable overrides.
  // Passing `coolPriceOverride: null` now correctly clears the override.
  // Old `?? this.coolPriceOverride` pattern was broken — null was treated
  // as "not provided" so overrides could never be removed once set.
  static const _keep = Object();

  Customer copyWith({
    String? name,
    String? phone,
    String? area,
    String? address,
    bool? isActive,
    double? balance,
    int? coolOut,
    int? petOut,
    int? ownCoolJars,
    int? ownPetJars,
    double? securityDeposit,
    // Use Object? with _keep sentinel so callers can pass null to clear
    Object? coolPriceOverride = _keep,
    Object? petPriceOverride = _keep,
    String? notes,
  }) =>
      Customer(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        area: area ?? this.area,
        address: address ?? this.address,
        isActive: isActive ?? this.isActive,
        balance: balance ?? this.balance,
        coolOut: coolOut ?? this.coolOut,
        petOut: petOut ?? this.petOut,
        ownCoolJars: ownCoolJars ?? this.ownCoolJars,
        ownPetJars: ownPetJars ?? this.ownPetJars,
        securityDeposit: securityDeposit ?? this.securityDeposit,
        // If caller passed _keep (omitted), keep current value.
        // If caller passed null, clear the override.
        // If caller passed a double, set it.
        coolPriceOverride: coolPriceOverride == _keep
            ? this.coolPriceOverride
            : coolPriceOverride as double?,
        petPriceOverride: petPriceOverride == _keep
            ? this.petPriceOverride
            : petPriceOverride as double?,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}
