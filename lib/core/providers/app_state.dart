import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_role.dart';
import '../services/company_session.dart';
import '../services/rtdb_user_datasource.dart';
import '../services/firebase_service.dart';
import '../services/firebase_config.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

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

/// Deep-cast a Firebase snapshot value to Map<String, dynamic>.
/// Flutter Web Firebase SDK returns LinkedMap<Object?, Object?> at every level.
/// Map<String, dynamic>.from() only converts the outer keys — nested maps and
/// lists still contain LinkedMap entries, causing fromJson() to throw.
/// This recursive helper converts the entire tree.
Map<String, dynamic> _deepCast(dynamic data) {
  if (data is Map) {
    return Map<String, dynamic>.fromEntries(
      data.entries.map((e) => MapEntry(e.key.toString(), _deepCastValue(e.value))),
    );
  }
  return {};
}

dynamic _deepCastValue(dynamic v) {
  if (v is Map)  return _deepCast(v);
  if (v is List) return v.map(_deepCastValue).toList();
  return v;
}

// ── Safe deep-cast for Firebase data (works on web LinkedMap<Object?, Object?>) ─
Map<String, dynamic> _castMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), _castMapValue(v)));
  }
  return {};
}
dynamic _castMapValue(dynamic v) {
  if (v is Map)  return _castMap(v);
  if (v is List) return v.map(_castMapValue).toList();
  return v;
}

// Node path constants live in FirebaseConfig — see firebase_config.dart

// ══════════════════════════════════════════════════════════════════════════════
// MODELS
// ══════════════════════════════════════════════════════════════════════════════

class AppSettings {
  final String appName, businessName, ownerName, phone, address;
  final String gstin, themeMode, accentColor, currency, dateFormat, invoicePrefix;
  final bool gstEnabled, paymentAutoSync, auditLogEnabled;
  final double coolPrice, petPrice, transportFee, damageChargePerJar;
  final int lowStockThreshold, overdueDays;
  /// Dynamic logo: URL (Firebase Storage / HTTPS) — takes priority over local path + default asset
  final String logoUrl;
  /// Dynamic logo: local device file path (picked via image_picker)
  final String logoLocalPath;

  const AppSettings({
    this.appName = 'MrWater', this.businessName = 'Water Supply Co.',
    this.ownerName = 'Owner', this.phone = '',
    this.address = '', this.gstin = '',
    this.gstEnabled = false, this.coolPrice = 60.0, this.petPrice = 40.0,
    this.transportFee = 500.0, this.damageChargePerJar = 200.0,
    this.lowStockThreshold = 10, this.overdueDays = 7,
    this.themeMode = 'system', this.accentColor = '1A6BFF',
    this.paymentAutoSync = true, this.auditLogEnabled = true,
    this.currency = '₹', this.dateFormat = 'dd MMM yyyy', this.invoicePrefix = 'MRW',
    this.logoUrl = '', this.logoLocalPath = '',
  });

  Map<String, dynamic> toJson() => {
    'appName': appName, 'businessName': businessName, 'ownerName': ownerName,
    'phone': phone, 'address': address, 'gstin': gstin, 'gstEnabled': gstEnabled,
    'coolPrice': coolPrice, 'petPrice': petPrice, 'transportFee': transportFee,
    'damageChargePerJar': damageChargePerJar, 'lowStockThreshold': lowStockThreshold,
    'overdueDays': overdueDays, 'themeMode': themeMode, 'accentColor': accentColor,
    'paymentAutoSync': paymentAutoSync, 'auditLogEnabled': auditLogEnabled,
    'currency': currency, 'dateFormat': dateFormat, 'invoicePrefix': invoicePrefix,
    'logoUrl': logoUrl, 'logoLocalPath': logoLocalPath,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    appName: j['appName'] ?? 'MrWater', businessName: j['businessName'] ?? '',
    ownerName: j['ownerName'] ?? '', phone: j['phone'] ?? '',
    address: j['address'] ?? '', gstin: j['gstin'] ?? '',
    gstEnabled: j['gstEnabled'] ?? false, coolPrice: (j['coolPrice'] ?? 60.0).toDouble(),
    petPrice: (j['petPrice'] ?? 40.0).toDouble(), transportFee: (j['transportFee'] ?? 0.0).toDouble(),
    damageChargePerJar: (j['damageChargePerJar'] ?? 200.0).toDouble(),
    lowStockThreshold: j['lowStockThreshold'] ?? 10, overdueDays: j['overdueDays'] ?? 7,
    themeMode: j['themeMode'] ?? 'system', accentColor: j['accentColor'] ?? '1A6BFF',
    paymentAutoSync: j['paymentAutoSync'] ?? true, auditLogEnabled: j['auditLogEnabled'] ?? true,
    currency: j['currency'] ?? '₹', dateFormat: j['dateFormat'] ?? 'dd MMM yyyy',
    invoicePrefix: j['invoicePrefix'] ?? 'MRW',
    logoUrl: j['logoUrl'] ?? '', logoLocalPath: j['logoLocalPath'] ?? '',
  );

  AppSettings copyWith({
    String? appName, String? businessName, String? ownerName, String? phone,
    String? address, String? gstin, bool? gstEnabled, double? coolPrice,
    double? petPrice, double? transportFee, double? damageChargePerJar,
    int? lowStockThreshold, int? overdueDays, String? themeMode,
    String? accentColor, bool? paymentAutoSync, bool? auditLogEnabled,
    String? currency, String? dateFormat, String? invoicePrefix,
    String? logoUrl, String? logoLocalPath,
  }) => AppSettings(
    appName: appName ?? this.appName, businessName: businessName ?? this.businessName,
    ownerName: ownerName ?? this.ownerName, phone: phone ?? this.phone,
    address: address ?? this.address, gstin: gstin ?? this.gstin,
    gstEnabled: gstEnabled ?? this.gstEnabled, coolPrice: coolPrice ?? this.coolPrice,
    petPrice: petPrice ?? this.petPrice, transportFee: transportFee ?? this.transportFee,
    damageChargePerJar: damageChargePerJar ?? this.damageChargePerJar,
    lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    overdueDays: overdueDays ?? this.overdueDays, themeMode: themeMode ?? this.themeMode,
    accentColor: accentColor ?? this.accentColor, paymentAutoSync: paymentAutoSync ?? this.paymentAutoSync,
    auditLogEnabled: auditLogEnabled ?? this.auditLogEnabled, currency: currency ?? this.currency,
    dateFormat: dateFormat ?? this.dateFormat, invoicePrefix: invoicePrefix ?? this.invoicePrefix,
    logoUrl: logoUrl ?? this.logoUrl, logoLocalPath: logoLocalPath ?? this.logoLocalPath,
  );
}

class Customer {
  final String id, name, phone, area, address, createdAt;
  final bool isActive;
  /// Ledger: Negative = customer owes you (dues), Positive = customer has credit (overpaid)
  final double balance;
  /// Jars currently with this customer (from owner's inventory — tracked)
  final int coolOut, petOut;
  /// Customer's own jars (not from owner's inventory — untracked, for info only)
  final int ownCoolJars, ownPetJars;
  /// Security deposit paid by this customer
  final double securityDeposit;
  /// Per-jar price overrides for this customer
  final double? coolPriceOverride, petPriceOverride;
  /// Internal notes about customer
  final String notes;

  const Customer({
    required this.id, required this.name, required this.phone,
    this.area = '', this.address = '', this.isActive = true,
    this.balance = 0,
    this.coolOut = 0, this.petOut = 0,
    this.ownCoolJars = 0, this.ownPetJars = 0,
    this.securityDeposit = 0,
    this.coolPriceOverride, this.petPriceOverride,
    this.notes = '',
    required this.createdAt,
  });

  String get initials {
    final safeName = name.trim();
    if (safeName.isEmpty) return 'CU';
    final parts = safeName.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return safeName.substring(0, safeName.length >= 2 ? 2 : 1).toUpperCase();
  }
  bool get hasJarsOut => coolOut > 0 || petOut > 0;
  bool get hasCredit  => balance > 0;
  bool get hasAdvance => balance > 0; // kept for compatibility
  bool get hasDues => balance < 0;
  double get creditBalance  => balance > 0 ? balance : 0;
  double get advanceBalance => creditBalance; // kept for compatibility
  double get ledgerBalance => balance < 0 ? balance : 0;

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'phone': phone, 'area': area, 'address': address,
    'isActive': isActive, 'balance': balance, 'coolOut': coolOut, 'petOut': petOut,
    'ownCoolJars': ownCoolJars, 'ownPetJars': ownPetJars, 'securityDeposit': securityDeposit,
    'coolPriceOverride': coolPriceOverride, 'petPriceOverride': petPriceOverride,
    'notes': notes, 'createdAt': createdAt,
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
    coolPriceOverride: j['coolPriceOverride'] == null ? null : _asDouble(j['coolPriceOverride']),
    petPriceOverride: j['petPriceOverride'] == null ? null : _asDouble(j['petPriceOverride']),
    notes: _asString(j['notes']),
    createdAt: _asString(j['createdAt'], fallback: _now()),
  );

  Customer copyWith({
    String? name, String? phone, String? area, String? address,
    bool? isActive, double? balance,
    int? coolOut, int? petOut,
    int? ownCoolJars, int? ownPetJars,
    double? securityDeposit,
    double? coolPriceOverride, double? petPriceOverride,
    String? notes,
  }) => Customer(
    id: id, name: name ?? this.name, phone: phone ?? this.phone,
    area: area ?? this.area, address: address ?? this.address,
    isActive: isActive ?? this.isActive,
    balance: balance ?? this.balance,
    coolOut: coolOut ?? this.coolOut, petOut: petOut ?? this.petOut,
    ownCoolJars: ownCoolJars ?? this.ownCoolJars,
    ownPetJars: ownPetJars ?? this.ownPetJars,
    securityDeposit: securityDeposit ?? this.securityDeposit,
    coolPriceOverride: coolPriceOverride ?? this.coolPriceOverride,
    petPriceOverride: petPriceOverride ?? this.petPriceOverride,
    notes: notes ?? this.notes,
    createdAt: createdAt,
  );
}

class JarTransaction {
  final String id, customerId, customerName, date, createdAt, paymentMode, note, createdBy;
  final int coolDelivered, petDelivered, coolReturned, petReturned, coolDamaged, petDamaged;
  final double coolPrice, petPrice, billedAmount, amountCollected, damageCharge;
  /// Transport / logistics fee — mandatory for event deliveries, optional for daily
  final double transportFee;
  final String? updatedAt;
  /// 'daily' (regular door-to-door) or 'event' (bulk / one-off event delivery)
  final String? deliveryType;
  /// Only populated when deliveryType == 'event'
  final String? eventName;
  /// Event lifecycle: 'scheduled' | 'active' | 'completed' — only for events
  final String? eventStatus;

  /// Immutable edit history — newest first. Each entry is a snapshot of the
  /// transaction BEFORE that edit was applied.
  final List<TxEditHistory> editHistory;

  const JarTransaction({
    required this.id, required this.customerId, required this.customerName,
    required this.date, required this.createdAt,
    this.coolDelivered = 0, this.petDelivered = 0,
    this.coolReturned = 0, this.petReturned = 0,
    this.coolDamaged = 0, this.petDamaged = 0,
    this.coolPrice = 0.0, this.petPrice = 0.0,
    required this.billedAmount, this.amountCollected = 0,
    this.damageCharge = 0, this.transportFee = 0,
    this.paymentMode = 'cash',
    this.note = '', this.createdBy = 'Admin', this.updatedAt,
    this.deliveryType = 'daily',
    this.eventName,
    this.eventStatus,
    this.editHistory = const [],
  });

  double get balance => billedAmount - amountCollected;
  bool get hasCool => coolDelivered > 0 || coolReturned > 0;
  bool get hasPet  => petDelivered > 0 || petReturned > 0;
  bool get isReturn => coolDelivered == 0 && petDelivered == 0 && (coolReturned > 0 || petReturned > 0);

  Map<String, dynamic> toJson() => {
    'id': id, 'customerId': customerId, 'customerName': customerName,
    'date': date, 'createdAt': createdAt, 'updatedAt': updatedAt,
    'note': note, 'createdBy': createdBy,
    'coolDelivered': coolDelivered, 'petDelivered': petDelivered,
    'coolReturned': coolReturned, 'petReturned': petReturned,
    'coolDamaged': coolDamaged, 'petDamaged': petDamaged,
    'coolPrice': coolPrice, 'petPrice': petPrice,
    'billedAmount': billedAmount, 'amountCollected': amountCollected,
    'damageCharge': damageCharge, 'transportFee': transportFee,
    'paymentMode': paymentMode, 'deliveryType': deliveryType,
    'eventName': eventName, 'eventStatus': eventStatus,
    'editHistory': editHistory.map((e) => e.toJson()).toList(),
  };

  factory JarTransaction.fromJson(Map<String, dynamic> j) => JarTransaction(
    id: j['id']?.toString() ?? '',
    customerId: j['customerId']?.toString() ?? '',
    customerName: j['customerName']?.toString() ?? 'Unknown',
    date: j['date']?.toString() ?? '',
    createdAt: j['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
    updatedAt: j['updatedAt']?.toString(),
    note: j['note'] ?? '', createdBy: j['createdBy'] ?? 'Admin',
    coolDelivered: j['coolDelivered'] ?? 0, petDelivered: j['petDelivered'] ?? 0,
    coolReturned: j['coolReturned'] ?? 0, petReturned: j['petReturned'] ?? 0,
    coolDamaged: j['coolDamaged'] ?? 0, petDamaged: j['petDamaged'] ?? 0,
    coolPrice: (j['coolPrice'] ?? 0.0).toDouble(),
    petPrice: (j['petPrice'] ?? 0.0).toDouble(),
    billedAmount: (j['billedAmount'] ?? 0.0).toDouble(),
    amountCollected: (j['amountCollected'] ?? 0.0).toDouble(),
    damageCharge: (j['damageCharge'] ?? 0.0).toDouble(),
    transportFee: (j['transportFee'] ?? 0.0).toDouble(),
    paymentMode: j['paymentMode'] ?? 'cash',
    deliveryType: j['deliveryType'] ?? 'daily',
    eventName: j['eventName'], eventStatus: j['eventStatus'],
    editHistory: (j['editHistory'] as List?)?.map((e) => TxEditHistory.fromJson(e)).toList() ?? [],
  );

  JarTransaction copyWith({
    int? coolDelivered, int? petDelivered, int? coolReturned, int? petReturned,
    int? coolDamaged, int? petDamaged, double? coolPrice, double? petPrice,
    double? billedAmount, double? amountCollected, double? damageCharge,
    String? paymentMode, String? note, String? updatedAt,
    String? deliveryType, String? eventName, double? transportFee, String? eventStatus,
    List<TxEditHistory>? editHistory,
  }) => JarTransaction(
    id: id, customerId: customerId, customerName: customerName,
    date: date, createdAt: createdAt,
    coolDelivered: coolDelivered ?? this.coolDelivered,
    petDelivered: petDelivered ?? this.petDelivered,
    coolReturned: coolReturned ?? this.coolReturned,
    petReturned: petReturned ?? this.petReturned,
    coolDamaged: coolDamaged ?? this.coolDamaged,
    petDamaged: petDamaged ?? this.petDamaged,
    coolPrice: coolPrice ?? this.coolPrice,
    petPrice: petPrice ?? this.petPrice,
    billedAmount: billedAmount ?? this.billedAmount,
    amountCollected: amountCollected ?? this.amountCollected,
    damageCharge: damageCharge ?? this.damageCharge,
    transportFee: transportFee ?? this.transportFee,
    paymentMode: paymentMode ?? this.paymentMode,
    note: note ?? this.note, createdBy: createdBy,
    updatedAt: updatedAt ?? this.updatedAt,
    deliveryType: deliveryType ?? this.deliveryType,
    eventName: eventName ?? this.eventName,
    eventStatus: eventStatus ?? this.eventStatus,
    editHistory: editHistory ?? this.editHistory,
  );
}

class InventoryState {
  final int coolTotal, coolStock, petTotal, petStock;
  const InventoryState({this.coolTotal=0, this.coolStock=0, this.petTotal=0, this.petStock=0});

  int get coolOut => coolTotal - coolStock;
  int get petOut  => petTotal  - petStock;
  double get coolPct => coolTotal > 0 ? coolStock / coolTotal : 0;
  double get petPct  => petTotal  > 0 ? petStock  / petTotal  : 0;

  InventoryState copyWith({int? coolTotal, int? coolStock, int? petTotal, int? petStock}) =>
    InventoryState(
      coolTotal: coolTotal ?? this.coolTotal, coolStock: coolStock ?? this.coolStock,
      petTotal: petTotal ?? this.petTotal, petStock: petStock ?? this.petStock,
    );
}

class AuditEntry {
  final String id, type, description, entityId, before, after, performedBy, createdAt;

  const AuditEntry({
    required this.id, required this.type, required this.description,
    required this.entityId, this.before = '', this.after = '',
    required this.performedBy, required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'type': type, 'description': description, 'entityId': entityId,
    'before': before, 'after': after, 'performedBy': performedBy, 'createdAt': createdAt,
  };

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
    id:          _asString(j['id'],          fallback: _uuid.v4()),
    type:        _asString(j['type'],        fallback: 'unknown'),
    description: _asString(j['description'], fallback: ''),
    entityId:    _asString(j['entityId'],    fallback: ''),
    before:      _asString(j['before']),
    after:       _asString(j['after']),
    performedBy: _asString(j['performedBy'], fallback: 'Admin'),
    createdAt:   _asString(j['createdAt'],   fallback: _now()),
  );
}
// ══════════════════════════════════════════════════════════════════════════════
// LEDGER ENTRY MODEL
// Mirrors the Firebase ledgerEntries node.
// Created automatically when a transaction is added / edited / deleted.
// ══════════════════════════════════════════════════════════════════════════════
class LedgerEntry {
  final String id;
  final String customerId;
  final String txId;          // links back to the JarTransaction
  final String date;          // yyyy-MM-dd
  final String createdAt;
  final String? updatedAt;
  final String type;          // 'delivery' | 'return' | 'payment' | 'damage' | 'credit'
  final String description;   // human-readable one-liner
  final double debit;         // amount billed (DR side)
  final double credit;        // amount collected (CR side)
  final double balance;       // customer running balance AFTER this entry
  final String paymentMode;
  final String createdBy;

  const LedgerEntry({
    required this.id, required this.customerId, required this.txId,
    required this.date, required this.createdAt, this.updatedAt,
    required this.type, required this.description,
    required this.debit, required this.credit, required this.balance,
    required this.paymentMode, required this.createdBy,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'customerId': customerId, 'txId': txId,
    'date': date, 'createdAt': createdAt, 'updatedAt': updatedAt,
    'type': type, 'description': description,
    'debit': debit, 'credit': credit, 'balance': balance,
    'paymentMode': paymentMode, 'createdBy': createdBy,
  };

  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(
    id:          _asString(j['id'],          fallback: _uuid.v4()),
    customerId:  _asString(j['customerId'],  fallback: ''),
    txId:        _asString(j['txId'],        fallback: ''),
    date:        _asString(j['date'],        fallback: ''),
    createdAt:   _asString(j['createdAt'],   fallback: _now()),
    updatedAt:   j['updatedAt']?.toString(),
    type:        _asString(j['type'],        fallback: 'delivery'),
    description: _asString(j['description'], fallback: ''),
    debit:       _asDouble(j['debit']),
    credit:      _asDouble(j['credit']),
    balance:     _asDouble(j['balance']),
    paymentMode: _asString(j['paymentMode'], fallback: 'cash'),
    createdBy:   _asString(j['createdBy'],   fallback: 'Admin'),
  );

  /// Auto-build a LedgerEntry from a JarTransaction + current customer balance.
  factory LedgerEntry.fromTransaction(JarTransaction tx, double customerBalanceAfter) {
    final isPaymentOnly = tx.billedAmount == 0 && tx.amountCollected > 0 &&
        tx.coolDelivered == 0 && tx.petDelivered == 0 &&
        tx.coolReturned == 0 && tx.petReturned == 0;
    final isReturn = tx.coolDelivered == 0 && tx.petDelivered == 0 &&
        (tx.coolReturned > 0 || tx.petReturned > 0);
    final hasDamage = tx.coolDamaged > 0 || tx.petDamaged > 0;

    String type;
    String desc;

    if (isPaymentOnly) {
      type = 'payment';
      desc = 'Payment received ₹${tx.amountCollected.toInt()}';
    } else if (isReturn) {
      type = 'return';
      final parts = <String>[];
      if (tx.coolReturned > 0) parts.add('${tx.coolReturned} Cool');
      if (tx.petReturned  > 0) parts.add('${tx.petReturned} PET');
      desc = '${parts.join(' + ')} returned';
    } else if (hasDamage && tx.coolDelivered == 0 && tx.petDelivered == 0) {
      type = 'damage';
      desc = 'Damage charge – ${tx.coolDamaged + tx.petDamaged} jar(s)';
    } else {
      type = tx.deliveryType == 'event' ? 'event' : 'delivery';
      final parts = <String>[];
      if (tx.coolDelivered > 0) parts.add('${tx.coolDelivered} Cool');
      if (tx.petDelivered  > 0) parts.add('${tx.petDelivered} PET');
      if (tx.coolReturned  > 0) parts.add('${tx.coolReturned} Cool returned');
      if (tx.petReturned   > 0) parts.add('${tx.petReturned} PET returned');
      desc = parts.isNotEmpty ? parts.join(', ') : 'Transaction';
      if (tx.deliveryType == 'event' && tx.eventName != null && tx.eventName!.isNotEmpty) {
        desc = '${tx.eventName}: $desc';
      }
    }

    // Append payment info to description
    if (tx.amountCollected > 0 && !isPaymentOnly) {
      if (tx.amountCollected >= tx.billedAmount) {
        desc += ' – fully paid';
      } else {
        desc += ' – partial ₹${tx.amountCollected.toInt()} paid';
      }
    }

    return LedgerEntry(
      id: 'le_${tx.id}',
      customerId: tx.customerId,
      txId: tx.id,
      date: tx.date,
      createdAt: tx.createdAt,
      updatedAt: tx.updatedAt,
      type: type,
      description: desc,
      debit: tx.billedAmount,
      credit: tx.amountCollected,
      balance: customerBalanceAfter,
      paymentMode: tx.paymentMode,
      createdBy: tx.createdBy,
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// TRANSACTION REVISION MODEL
// Every create/edit appends an immutable revision record to Firebase at
//   transactionRevisions/{revId}
// The base JarTransaction document (transactions/{txId}) is still updated for
// fast screen reads, but revisions are NEVER overwritten — only appended.
// FK chain:  TransactionRevision.txId → JarTransaction.id (stable primary key)
// ══════════════════════════════════════════════════════════════════════════════

class TransactionRevision {
  final String revId;       // uuid — stable primary key for this revision
  final String txId;        // FK → JarTransaction.id — never changes
  final int    revNumber;   // 1 = original create, 2+ = edits
  final bool   isLatest;    // true only for the most recent revision
  final String createdAt;   // when this revision was written
  final String editedBy;
  final String editNote;

  // Full snapshot of all mutable fields at this revision
  final int    coolDelivered, petDelivered, coolReturned, petReturned;
  final int    coolDamaged, petDamaged;
  final double coolPrice, petPrice, billedAmount, amountCollected;
  final double damageCharge, transportFee;
  final String paymentMode;
  final String? eventStatus, eventName;
  final String  deliveryType;

  const TransactionRevision({
    required this.revId, required this.txId, required this.revNumber,
    required this.isLatest, required this.createdAt,
    required this.editedBy, this.editNote = '',
    required this.coolDelivered, required this.petDelivered,
    required this.coolReturned, required this.petReturned,
    required this.coolDamaged, required this.petDamaged,
    required this.coolPrice, required this.petPrice,
    required this.billedAmount, required this.amountCollected,
    required this.damageCharge, required this.transportFee,
    required this.paymentMode, required this.deliveryType,
    this.eventStatus, this.eventName,
  });

  /// Build a revision from a JarTransaction (create = rev 1, edit = rev N).
  factory TransactionRevision.fromTransaction(
    JarTransaction tx, {
    required int revNumber,
    required bool isLatest,
    String editedBy = 'Admin',
    String editNote = '',
  }) => TransactionRevision(
    revId: _uuid.v4(),
    txId: tx.id,
    revNumber: revNumber,
    isLatest: isLatest,
    createdAt: _now(),
    editedBy: editedBy,
    editNote: editNote,
    coolDelivered: tx.coolDelivered, petDelivered: tx.petDelivered,
    coolReturned:  tx.coolReturned,  petReturned:  tx.petReturned,
    coolDamaged:   tx.coolDamaged,   petDamaged:   tx.petDamaged,
    coolPrice: tx.coolPrice, petPrice: tx.petPrice,
    billedAmount: tx.billedAmount, amountCollected: tx.amountCollected,
    damageCharge: tx.damageCharge, transportFee: tx.transportFee,
    paymentMode: tx.paymentMode, deliveryType: tx.deliveryType ?? 'daily',
    eventStatus: tx.eventStatus, eventName: tx.eventName,
  );

  Map<String, dynamic> toJson() => {
    'revId': revId, 'txId': txId, 'revNumber': revNumber,
    'isLatest': isLatest, 'createdAt': createdAt,
    'editedBy': editedBy, 'editNote': editNote,
    'coolDelivered': coolDelivered, 'petDelivered': petDelivered,
    'coolReturned':  coolReturned,  'petReturned':  petReturned,
    'coolDamaged':   coolDamaged,   'petDamaged':   petDamaged,
    'coolPrice': coolPrice, 'petPrice': petPrice,
    'billedAmount': billedAmount, 'amountCollected': amountCollected,
    'damageCharge': damageCharge, 'transportFee': transportFee,
    'paymentMode': paymentMode, 'deliveryType': deliveryType,
    'eventStatus': eventStatus, 'eventName': eventName,
  };

  factory TransactionRevision.fromJson(Map<String, dynamic> j) =>
      TransactionRevision(
    revId: j['revId'] ?? '', txId: j['txId'] ?? '',
    revNumber: j['revNumber'] ?? 1, isLatest: j['isLatest'] ?? true,
    createdAt: j['createdAt'] ?? _now(),
    editedBy: j['editedBy'] ?? 'Admin', editNote: j['editNote'] ?? '',
    coolDelivered: j['coolDelivered'] ?? 0, petDelivered: j['petDelivered'] ?? 0,
    coolReturned:  j['coolReturned']  ?? 0, petReturned:  j['petReturned']  ?? 0,
    coolDamaged:   j['coolDamaged']   ?? 0, petDamaged:   j['petDamaged']   ?? 0,
    coolPrice: (j['coolPrice'] ?? 0.0).toDouble(),
    petPrice:  (j['petPrice']  ?? 0.0).toDouble(),
    billedAmount:   (j['billedAmount']   ?? 0.0).toDouble(),
    amountCollected:(j['amountCollected']?? 0.0).toDouble(),
    damageCharge:   (j['damageCharge']   ?? 0.0).toDouble(),
    transportFee:   (j['transportFee']   ?? 0.0).toDouble(),
    paymentMode:  j['paymentMode']  ?? 'cash',
    deliveryType: j['deliveryType'] ?? 'daily',
    eventStatus: j['eventStatus'], eventName: j['eventName'],
  );
}


// ══════════════════════════════════════════════════════════════════════════════
// INVENTORY MOVEMENT MODEL
// Every stock change writes an InventoryMovement to inventoryMovements/{invId}.
// The cached coolStock/coolTotal on the inventory node is updated alongside
// for fast reads. On inconsistency, stock can be reconstructed by replaying
// all movements in createdAt order.
//
// FK chain: InventoryMovement.txId → JarTransaction.id (null for manual ops)
// Types:
//   delivery       tx coolDelta < 0  (jars leave warehouse)
//   customer_return tx coolDelta > 0  (jars return from customer)
//   damage         tx coolTotalDelta < 0 (permanent write-off)
//   add_stock      manual, coolDelta > 0, coolTotalDelta > 0
//   record_loss    manual, coolDelta < 0, coolTotalDelta < 0
//   edit_delta     net delta from a transaction edit
//   delete_revert  full reversal on transaction delete
// ══════════════════════════════════════════════════════════════════════════════

class InventoryMovement {
  final String invId;          // uuid — stable primary key
  final String? txId;          // FK → JarTransaction.id (null for manual ops)
  final String? revId;         // FK → TransactionRevision.revId
  final String  type;          // see type list above
  final int     coolDelta;     // signed: +ve = stock up, -ve = stock down
  final int     petDelta;
  final int     coolTotalDelta;// for permanent changes (damage / add_stock / loss)
  final int     petTotalDelta;
  final String  createdAt;
  final String  note;

  const InventoryMovement({
    required this.invId, this.txId, this.revId,
    required this.type,
    required this.coolDelta, required this.petDelta,
    required this.coolTotalDelta, required this.petTotalDelta,
    required this.createdAt, this.note = '',
  });

  /// Build from a transaction apply (new delivery).
  factory InventoryMovement.fromApply(JarTransaction tx, {String? revId}) =>
      InventoryMovement(
    invId: _uuid.v4(), txId: tx.id, revId: revId,
    type: 'delivery',
    coolDelta: -tx.coolDelivered + tx.coolReturned - tx.coolDamaged,
    petDelta:  -tx.petDelivered  + tx.petReturned  - tx.petDamaged,
    coolTotalDelta: -tx.coolDamaged,
    petTotalDelta:  -tx.petDamaged,
    createdAt: _now(),
    note: 'Tx ${tx.id} applied',
  );

  /// Build from a transaction revert (delete or pre-edit rollback).
  factory InventoryMovement.fromRevert(JarTransaction tx, {String type = 'delete_revert'}) =>
      InventoryMovement(
    invId: _uuid.v4(), txId: tx.id,
    type: type,
    coolDelta: tx.coolDelivered - tx.coolReturned + tx.coolDamaged,
    petDelta:  tx.petDelivered  - tx.petReturned  + tx.petDamaged,
    coolTotalDelta: tx.coolDamaged,
    petTotalDelta:  tx.petDamaged,
    createdAt: _now(),
    note: 'Tx ${tx.id} reverted',
  );

  /// Build net-delta movement for an edit (old → new).
  factory InventoryMovement.fromEditDelta(
      JarTransaction oldTx, JarTransaction newTx, {String? revId}) {
    final coolStockDelta =
        (-newTx.coolDelivered + newTx.coolReturned - newTx.coolDamaged) -
        (-oldTx.coolDelivered + oldTx.coolReturned - oldTx.coolDamaged);
    final petStockDelta =
        (-newTx.petDelivered  + newTx.petReturned  - newTx.petDamaged) -
        (-oldTx.petDelivered  + oldTx.petReturned  - oldTx.petDamaged);
    return InventoryMovement(
      invId: _uuid.v4(), txId: newTx.id, revId: revId,
      type: 'edit_delta',
      coolDelta: coolStockDelta, petDelta: petStockDelta,
      coolTotalDelta: oldTx.coolDamaged - newTx.coolDamaged,
      petTotalDelta:  oldTx.petDamaged  - newTx.petDamaged,
      createdAt: _now(),
      note: 'Edit delta for tx ${newTx.id}',
    );
  }

  Map<String, dynamic> toJson() => {
    'invId': invId, 'txId': txId, 'revId': revId, 'type': type,
    'coolDelta': coolDelta, 'petDelta': petDelta,
    'coolTotalDelta': coolTotalDelta, 'petTotalDelta': petTotalDelta,
    'createdAt': createdAt, 'note': note,
  };
}


// ══════════════════════════════════════════════════════════════════════════════
// PAYMENT RECORD MODEL
// Every transaction that has amountCollected > 0 mirrors that payment to
//   payments/{paymentId}
// This gives the Payments table its own stable primary key (paymentId) while
// keeping the existing balance/ledger logic intact.
// FK chain: PaymentRecord.txId → JarTransaction.id
// ══════════════════════════════════════════════════════════════════════════════

class PaymentRecord {
  final String paymentId;   // uuid — stable primary key
  final String txId;        // FK → JarTransaction.id
  final String customerId;  // FK → Customer.id (denormalised for fast queries)
  final String customerName;
  final double amount;
  final String mode;        // cash | upi | bank | advance
  final String date;
  final String createdAt;
  final String note;
  final String type;        // 'settlement' | 'advance' | 'partial' | 'with_delivery'
  final bool   isActive;    // false if parent tx was deleted

  const PaymentRecord({
    required this.paymentId, required this.txId,
    required this.customerId, required this.customerName,
    required this.amount, required this.mode,
    required this.date, required this.createdAt,
    this.note = '', required this.type, this.isActive = true,
  });

  factory PaymentRecord.fromTransaction(JarTransaction tx) {
    final bool isDelivery = tx.billedAmount > 0;
    final String type = tx.paymentMode == 'advance'
        ? 'advance'
        : isDelivery
            ? (tx.amountCollected >= tx.billedAmount ? 'with_delivery' : 'partial')
            : 'settlement';
    return PaymentRecord(
      paymentId: _uuid.v4(),
      txId: tx.id, customerId: tx.customerId, customerName: tx.customerName,
      amount: tx.amountCollected, mode: tx.paymentMode,
      date: tx.date, createdAt: _now(),
      note: tx.note, type: type,
    );
  }

  PaymentRecord copyWith({bool? isActive}) => PaymentRecord(
    paymentId: paymentId, txId: txId, customerId: customerId,
    customerName: customerName, amount: amount, mode: mode,
    date: date, createdAt: createdAt, note: note, type: type,
    isActive: isActive ?? this.isActive,
  );

  Map<String, dynamic> toJson() => {
    'paymentId': paymentId, 'txId': txId,
    'customerId': customerId, 'customerName': customerName,
    'amount': amount, 'mode': mode, 'date': date, 'createdAt': createdAt,
    'note': note, 'type': type, 'isActive': isActive,
  };
}

// ── Transaction Edit History ─────────────────────────────────────────────────
/// One snapshot of a JarTransaction before it was edited.
/// Stored as a list inside each JarTransaction — immutable audit trail.
class TxEditHistory {
  final String editedAt;     // ISO timestamp of when this edit was made
  final String editedBy;     // Who made the edit
  final String note;         // Optional reason / description
  // Snapshot of all mutable fields BEFORE this edit
  final int coolDelivered, petDelivered, coolReturned, petReturned;
  final int coolDamaged, petDamaged;
  final double coolPrice, petPrice, billedAmount, amountCollected, damageCharge, transportFee;
  final String paymentMode;
  final String? eventStatus;

  const TxEditHistory({
    required this.editedAt, required this.editedBy, this.note = '',
    required this.coolDelivered, required this.petDelivered,
    required this.coolReturned, required this.petReturned,
    required this.coolDamaged, required this.petDamaged,
    required this.coolPrice, required this.petPrice,
    required this.billedAmount, required this.amountCollected,
    required this.damageCharge, required this.transportFee,
    required this.paymentMode, this.eventStatus,
  });

  Map<String, dynamic> toJson() => {
    'editedAt': editedAt, 'editedBy': editedBy, 'note': note,
    'coolDelivered': coolDelivered, 'petDelivered': petDelivered,
    'coolReturned': coolReturned, 'petReturned': petReturned,
    'coolDamaged': coolDamaged, 'petDamaged': petDamaged,
    'coolPrice': coolPrice, 'petPrice': petPrice,
    'billedAmount': billedAmount, 'amountCollected': amountCollected,
    'damageCharge': damageCharge, 'transportFee': transportFee,
    'paymentMode': paymentMode, 'eventStatus': eventStatus,
  };

  factory TxEditHistory.fromJson(Map<String, dynamic> j) => TxEditHistory(
    // Null fallbacks on ALL fields — a missing field must never throw and
    // cause the parent JarTransaction.fromJson to fail + disappear from list.
    editedAt: j['editedAt']?.toString() ?? _now(),
    editedBy: j['editedBy']?.toString() ?? 'Admin',
    note: j['note']?.toString() ?? '',
    coolDelivered: j['coolDelivered'] ?? 0, petDelivered: j['petDelivered'] ?? 0,
    coolReturned: j['coolReturned'] ?? 0, petReturned: j['petReturned'] ?? 0,
    coolDamaged: j['coolDamaged'] ?? 0, petDamaged: j['petDamaged'] ?? 0,
    coolPrice: (j['coolPrice'] ?? 0.0).toDouble(),
    petPrice: (j['petPrice'] ?? 0.0).toDouble(),
    billedAmount: (j['billedAmount'] ?? 0.0).toDouble(),
    amountCollected: (j['amountCollected'] ?? 0.0).toDouble(),
    damageCharge: (j['damageCharge'] ?? 0.0).toDouble(),
    transportFee: (j['transportFee'] ?? 0.0).toDouble(),
    paymentMode: j['paymentMode']?.toString() ?? 'cash',
    eventStatus: j['eventStatus']?.toString(),
  );

  /// Snapshot from a live transaction
  factory TxEditHistory.from(JarTransaction tx, {String editedBy = 'Admin', String note = ''}) =>
    TxEditHistory(
      editedAt: _now(), editedBy: editedBy, note: note,
      coolDelivered: tx.coolDelivered, petDelivered: tx.petDelivered,
      coolReturned: tx.coolReturned, petReturned: tx.petReturned,
      coolDamaged: tx.coolDamaged, petDamaged: tx.petDamaged,
      coolPrice: tx.coolPrice, petPrice: tx.petPrice,
      billedAmount: tx.billedAmount, amountCollected: tx.amountCollected,
      damageCharge: tx.damageCharge, transportFee: tx.transportFee,
      paymentMode: tx.paymentMode, eventStatus: tx.eventStatus,
    );
}

// ══════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ══════════════════════════════════════════════════════════════════════════════

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) { Future.microtask(_init); }

  StreamSubscription? _sub;

  void _init() {
    _sub?.cancel();
    _sub = FirebaseService.instance.watch(FirebaseConfig.nodeSettings).listen((data) {
      if (!mounted) return;
      if (data != null) state = AppSettings.fromJson(data);
    });
  }

  void reinit() => _init();

  Future<void> save(AppSettings s) async {
    await FirebaseService.instance.write(FirebaseConfig.nodeSettings, s.toJson());
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) => SettingsNotifier());

final themeModeProvider = Provider<ThemeMode>((ref) {
  final s = ref.watch(settingsProvider);
  return switch (s.themeMode) { 'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system };
});

class AuditNotifier extends StateNotifier<List<AuditEntry>> {
  AuditNotifier() : super([]) { Future.microtask(_init); }

  StreamSubscription? _sub;

  void reinit() { state = []; _init(); }

  void _init() {
    _sub?.cancel();
    state = [];
    FirebaseService.instance.watch('auditLog').listen((data) {  // DB node is 'auditLog'
      if (data != null) {
        state = data.values.map((e) => AuditEntry.fromJson(_castMap(e))).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        state = [];
      }
    });
  }

  void log({required String type, required String description, required String entityId, String before='', String after=''}) {
    final entry = AuditEntry(id: _uuid.v4(), type: type, description: description, entityId: entityId, before: before, after: after, performedBy: 'Admin', createdAt: _now());
    FirebaseService.instance.setChild('auditLog', entry.id, entry.toJson());  // DB node is 'auditLog'
  }

  void clear() => FirebaseService.instance.write('auditLog', {});  // DB node is 'auditLog'
}
final auditProvider = StateNotifierProvider<AuditNotifier, List<AuditEntry>>((ref) => AuditNotifier());

class InventoryNotifier extends StateNotifier<InventoryState> {
  InventoryNotifier() : super(const InventoryState()) { Future.microtask(_init); }

  StreamSubscription? _sub;

  void _init() {
    _sub?.cancel();
    _sub = FirebaseService.instance.watchInventory().listen((data) {
      if (!mounted) return;
      if (data != null) {
        state = InventoryState(
          coolTotal: (data['coolTotal'] ?? 0).toInt(),
          coolStock: (data['coolStock'] ?? 0).toInt(),
          petTotal:  (data['petTotal']  ?? 0).toInt(),
          petStock:  (data['petStock']  ?? 0).toInt(),
        );
      }
    }, onError: (e) => debugPrint('[InventoryNotifier] error: $e'));
  }

  void reinit() { state = const InventoryState(); _init(); }

  Future<void> _save() async {
    // FIX: writeInventory() calls _db.ref(nodeInventory).set() directly
    // (flat path). write(nodeInventory) goes through _ref() which prepends
    // companies/$companyId/ — causing reads and writes to diverge.
    await FirebaseService.instance.writeInventory({
      'coolTotal': state.coolTotal, 'coolStock': state.coolStock,
      'petTotal': state.petTotal, 'petStock': state.petStock,
    });
  }

  // ── Internal mutators — update cached stock AND write InventoryMovement ────
  void _apply(JarTransaction tx) {
    state = state.copyWith(
      coolStock: (state.coolStock - tx.coolDelivered + tx.coolReturned - tx.coolDamaged)
          .clamp(0, state.coolTotal + tx.coolDamaged),
      petStock:  (state.petStock  - tx.petDelivered  + tx.petReturned  - tx.petDamaged )
          .clamp(0, state.petTotal  + tx.petDamaged),
      coolTotal: state.coolTotal - tx.coolDamaged,
      petTotal:  state.petTotal  - tx.petDamaged,
    );
    _save();
  }

  void _revert(JarTransaction tx) {
    state = state.copyWith(
      coolStock: (state.coolStock + tx.coolDelivered - tx.coolReturned + tx.coolDamaged).clamp(0, 9999),
      petStock:  (state.petStock  + tx.petDelivered  - tx.petReturned  + tx.petDamaged ).clamp(0, 9999),
      coolTotal: state.coolTotal + tx.coolDamaged,
      petTotal:  state.petTotal  + tx.petDamaged,
    );
    _save();
  }

  void _writeMovement(InventoryMovement mov) {
    FirebaseService.instance.setChild(FirebaseConfig.nodeInventoryMovements, mov.invId, mov.toJson());
  }

  // ── Public API (called by TransactionsNotifier) ──────────────────────────
  void apply(JarTransaction tx, {String? revId}) {
    _apply(tx);
    _writeMovement(InventoryMovement.fromApply(tx, revId: revId));
  }

  void revert(JarTransaction tx) {
    _revert(tx);
    _writeMovement(InventoryMovement.fromRevert(tx));
  }

  void edit(JarTransaction old, JarTransaction neu, {String? revId}) {
    _revert(old);
    _apply(neu);
    _writeMovement(InventoryMovement.fromEditDelta(old, neu, revId: revId));
  }

  void addStock(int cool, int pet) {
    state = state.copyWith(
      coolStock: state.coolStock + cool, coolTotal: state.coolTotal + cool,
      petStock:  state.petStock  + pet,  petTotal:  state.petTotal  + pet);
    _save();
    _writeMovement(InventoryMovement(
      invId: _uuid.v4(), type: 'add_stock',
      coolDelta: cool, petDelta: pet,
      coolTotalDelta: cool, petTotalDelta: pet,
      createdAt: _now(), note: 'Stock-in: $cool cool, $pet PET',
    ));
  }

  void recordLoss(int cool, int pet) {
    state = state.copyWith(
      coolStock: (state.coolStock - cool).clamp(0, state.coolTotal),
      coolTotal: (state.coolTotal - cool).clamp(0, 9999),
      petStock:  (state.petStock  - pet ).clamp(0, state.petTotal),
      petTotal:  (state.petTotal  - pet ).clamp(0, 9999),
    );
    _save();
    _writeMovement(InventoryMovement(
      invId: _uuid.v4(), type: 'record_loss',
      coolDelta: -cool, petDelta: -pet,
      coolTotalDelta: -cool, petTotalDelta: -pet,
      createdAt: _now(), note: 'Loss/damage write-off: $cool cool, $pet PET',
    ));
  }

  /// Force a fresh read of inventory from Firebase.
  Future<void> refresh() async {
    // FIX: readInventory() hits the flat /inventory path directly.
    final data = await FirebaseService.instance.readInventory();
    if (data != null) {
      state = InventoryState(
        coolTotal: (data['coolTotal'] ?? 0).toInt(),
        coolStock: (data['coolStock'] ?? 0).toInt(),
        petTotal:  (data['petTotal']  ?? 0).toInt(),
        petStock:  (data['petStock']  ?? 0).toInt(),
      );
    }
  }

  void adjustForCustomerEdit(int coolDelta, int petDelta) {
    state = state.copyWith(
      coolStock: (state.coolStock - coolDelta).clamp(0, state.coolTotal),
      petStock:  (state.petStock  - petDelta ).clamp(0, state.petTotal),
    );
    _save();
  }

  // Vehicle load/unload no longer modifies inventory.
  // Inventory is solely driven by JarTransactions (add/edit/delete).
}
final inventoryProvider = StateNotifierProvider<InventoryNotifier, InventoryState>((ref) => InventoryNotifier());

class CustomersNotifier extends StateNotifier<List<Customer>> {
  CustomersNotifier() : super([]) { Future.microtask(_init); }

  StreamSubscription? _sub;

  void _init() {
    _sub?.cancel();
    state = [];
    _sub = FirebaseService.instance.watch(FirebaseConfig.nodeCustomers).listen((data) {
      if (!mounted) return;
      if (data != null) {
        final customers = <Customer>[];
        for (final entry in data.values) {
          try { customers.add(Customer.fromJson(_castMap(entry))); }
          catch (e) { debugPrint('[CustomersNotifier] parse error: $e'); }
        }
        state = customers;
      } else {
        state = [];
      }
    }, onError: (e) => debugPrint('[CustomersNotifier] error: $e'));
  }

  void reinit() => _init();

  /// Add a new customer — updates local state immediately (optimistic),
  /// then persists to Firebase. Firebase listener confirms asynchronously.
  Future<void> add(Customer c) async {
    // Optimistic: inject into local state immediately so all watching screens
    // rebuild without waiting for Firebase roundtrip (~100-500 ms).
    if (!state.any((x) => x.id == c.id)) {
      state = [...state, c];
    }
    await FirebaseService.instance.setChild(FirebaseConfig.nodeCustomers, c.id, c.toJson());
  }

  /// Update a customer — patches local state immediately (optimistic),
  /// then persists to Firebase. All ref.watch(customersProvider) screens
  /// rebuild instantly: Customer list, Payments/Dues/Credit, Ledger header.
  Future<void> update(Customer c) async {
    // Optimistic local patch — replaces the one matching customer in state.
    state = [
      for (final x in state)
        if (x.id == c.id) c else x,
    ];
    // Async Firebase write — listener will fire and re-set state (idempotent).
    await FirebaseService.instance.update('${FirebaseConfig.nodeCustomers}/${c.id}', c.toJson());
  }

  /// Apply a NEW transaction to a customer's jar counts and balance.
  /// Returns the updated Customer with the exact new balance computed in memory.
  Customer applyTx(JarTransaction tx) {
    final cIdx = state.indexWhere((c) => c.id == tx.customerId);
    if (cIdx == -1) return state.isNotEmpty ? state.first : const Customer(id: '', name: '', phone: '', createdAt: '');
    final c = state[cIdx];
    final neu = c.copyWith(
      coolOut: (c.coolOut + tx.coolDelivered - tx.coolReturned).clamp(0, 9999),
      petOut:  (c.petOut  + tx.petDelivered  - tx.petReturned ).clamp(0, 9999),
      balance: c.balance  - (tx.billedAmount  - tx.amountCollected),
    );
    update(neu);
    return neu;
  }

  /// Revert a transaction that was previously applied.
  /// Returns the updated Customer.
  Customer revertTx(JarTransaction tx) {
    final cIdx = state.indexWhere((c) => c.id == tx.customerId);
    if (cIdx == -1) return state.isNotEmpty ? state.first : const Customer(id: '', name: '', phone: '', createdAt: '');
    final c = state[cIdx];
    final neu = c.copyWith(
      coolOut: (c.coolOut - tx.coolDelivered + tx.coolReturned).clamp(0, 9999),
      petOut:  (c.petOut  - tx.petDelivered  + tx.petReturned ).clamp(0, 9999),
      balance: c.balance  + (tx.billedAmount  - tx.amountCollected),
    );
    update(neu);
    return neu;
  }

  /// Edit: atomically swap old tx for new tx in ONE customer update.
  /// Computes the NET DELTA between old and new so there is no race
  /// condition from two separate Firebase writes/listener-fires.
  ///
  /// Net delta logic:
  ///   coolOutDelta = (neu.delivered - neu.returned) - (old.delivered - old.returned)
  ///   balanceDelta = -(neu.billed - neu.collected) + (old.billed - old.collected)
  ///
  /// Example: old had delivered=5 returned=0 billed=100 collected=0
  ///          neu has  delivered=5 returned=2 billed=100 collected=0
  ///   coolOutDelta = (5-2)-(5-0) = 3-5 = -2  → customer now has 2 fewer jars out  ✓
  ///   balanceDelta = -(100-0)+(100-0) = 0     → balance unchanged (payment not touched) ✓
  /// Force a fresh read of customers from Firebase.
  Future<void> refresh() async {
    final data = await FirebaseService.instance.readOnce(FirebaseConfig.nodeCustomers);
    if (data != null) {
      state = data.values
          .map((e) => Customer.fromJson(_castMap(e)))
          .toList();
    }
  }

  Customer applyTxEdit(JarTransaction oldTx, JarTransaction newTx) {
    final cIdx = state.indexWhere((c) => c.id == newTx.customerId);
    if (cIdx == -1) return state.isNotEmpty ? state.first : const Customer(id: '', name: '', phone: '', createdAt: '');
    final c = state[cIdx];
    final oldNetJarCool = oldTx.coolDelivered - oldTx.coolReturned;
    final newNetJarCool = newTx.coolDelivered - newTx.coolReturned;
    final oldNetJarPet  = oldTx.petDelivered  - oldTx.petReturned;
    final newNetJarPet  = newTx.petDelivered  - newTx.petReturned;
    final oldNetBalance = oldTx.billedAmount - oldTx.amountCollected;
    final newNetBalance = newTx.billedAmount - newTx.amountCollected;
    final neu = c.copyWith(
      coolOut: (c.coolOut + (newNetJarCool - oldNetJarCool)).clamp(0, 9999),
      petOut:  (c.petOut  + (newNetJarPet  - oldNetJarPet )).clamp(0, 9999),
      balance: c.balance  - (newNetBalance  - oldNetBalance),
    );
    update(neu);
    return neu;
  }
}
final customersProvider = StateNotifierProvider<CustomersNotifier, List<Customer>>((ref) => CustomersNotifier());

// ══════════════════════════════════════════════════════════════════════════════
// LEDGER ENTRIES PROVIDER
// Reads the ledgerEntries node from Firebase (read-only from UI side).
// Written automatically by TransactionsNotifier on every add/edit/delete.
// ══════════════════════════════════════════════════════════════════════════════
class LedgerNotifier extends StateNotifier<List<LedgerEntry>> {
  LedgerNotifier() : super([]) { Future.microtask(_init); }

  StreamSubscription? _sub;

  void reinit() => _init();

  void _init() {
    _sub?.cancel();
    state = [];
    FirebaseService.instance.watch(FirebaseConfig.nodeLedgerEntries).listen((data) {
      if (data != null) {
        state = (data as Map).values
            .map((e) => LedgerEntry.fromJson(_castMap(e)))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        state = [];
      }
    }, onError: (e) => debugPrint('[LedgerNotifier] error: $e'));
  }

  /// Force a fresh read of ledger entries from Firebase.
  Future<void> refresh() async {
    final data = await FirebaseService.instance.readOnce(FirebaseConfig.nodeLedgerEntries);
    if (data != null) {
      state = (data as Map).values
          .map((e) => LedgerEntry.fromJson(_castMap(e)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  // All ledger entries for a specific customer, sorted oldest→newest for running balance
  List<LedgerEntry> forCustomer(String customerId) =>
      state.where((e) => e.customerId == customerId).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
}

final ledgerProvider = StateNotifierProvider<LedgerNotifier, List<LedgerEntry>>(
    (ref) => LedgerNotifier());

class TransactionsNotifier extends StateNotifier<List<JarTransaction>> {
  final Ref _ref;

  TransactionsNotifier(this._ref) : super([]) { Future.microtask(_init); }

  StreamSubscription? _sub;

  void reinit() { state = []; _init(); }

  void _init() {
    _sub?.cancel();
    state = [];
    _sub = FirebaseService.instance.watch(FirebaseConfig.nodeTransactions).listen((data) {
      if (!mounted) return;
      if (data == null) { state = []; return; }
      final parsed = <JarTransaction>[];
      for (final entry in data.values) {
        try {
          parsed.add(JarTransaction.fromJson(_castMap(entry)));
        } catch (e) {
          // skip malformed record — don't let one bad entry blank the whole list
          debugPrint('[TransactionsNotifier] skipped malformed record: $e');
        }
      }
      parsed.sort((a, b) {
        final dc = b.date.compareTo(a.date);
        return dc != 0 ? dc : b.createdAt.compareTo(a.createdAt);
      });
      state = parsed;
    }, onError: (e) => debugPrint('[TransactionsNotifier] error: $e'));
  }

  /// Force a fresh read of all four core providers from Firebase.
  /// Called by pull-to-refresh on ★★★★+ screens.
  /// Re-reads transactions, customers, inventory, and ledger entries in parallel.
  Future<void> refreshAll(WidgetRef ref) async {
    // Re-read transactions from Firebase and push into state
    final txData = await FirebaseService.instance.readOnce(FirebaseConfig.nodeTransactions);
    if (txData != null) {
      final parsed = <JarTransaction>[];
      for (final entry in txData.values) {
        try { parsed.add(JarTransaction.fromJson(_castMap(entry))); }
        catch (_) {}
      }
      parsed.sort((a, b) {
        final dc = b.date.compareTo(a.date);
        return dc != 0 ? dc : b.createdAt.compareTo(a.createdAt);
      });
      state = parsed;
    }
    // Trigger fresh reads on the other three providers
    await ref.read(customersProvider.notifier).refresh();
    await ref.read(inventoryProvider.notifier).refresh();
    await ref.read(ledgerProvider.notifier).refresh();
  }

  /// Write a LedgerEntry to Firebase.
  /// [balanceAfter] must come directly from the Customer returned by applyTx()
  /// to avoid reading a stale value from the provider (Firebase write is async).
  Future<void> _writeLedger(JarTransaction tx, double balanceAfter) async {
    final entry = LedgerEntry.fromTransaction(tx, balanceAfter);
    await FirebaseService.instance.setChild(
        FirebaseConfig.nodeLedgerEntries, entry.id, entry.toJson());
  }

  /// Cross-check today's vehicle trip against recorded customer transactions.
  /// Returns a map with all the numbers so the UI can show a reconciliation panel.
  ///
  /// Loaded (trip) = Delivered to customers (transactions) + Returned to warehouse (trip)
  /// Mismatch means some jars are unaccounted for.
  Map<String, int> reconcileWithTrips(LoadUnloadState trips, String date) {
    final txToday       = state.where((t) => t.date == date).toList();
    final txCoolDel     = txToday.fold(0, (s, t) => s + t.coolDelivered);
    final txPetDel      = txToday.fold(0, (s, t) => s + t.petDelivered);
    final txCoolRet     = txToday.fold(0, (s, t) => s + t.coolReturned);
    final txPetRet      = txToday.fold(0, (s, t) => s + t.petReturned);
    return {
      'tripCoolLoaded'  : trips.totalCoolLoaded,
      'tripPetLoaded'   : trips.totalPetLoaded,
      'tripCoolUnloaded': trips.totalCoolUnloaded,   // returned to warehouse
      'tripPetUnloaded' : trips.totalPetUnloaded,
      'txCoolDelivered' : txCoolDel,                 // sum of customer txns
      'txPetDelivered'  : txPetDel,
      'txCoolReturned'  : txCoolRet,                 // customer return txns
      'txPetReturned'   : txPetRet,
      // positive = more on truck than transactions account for (missing txns?)
      // negative = transactions claim more delivered than was loaded (bad data)
      'coolMismatch'    : trips.expectedCoolDelivered - txCoolDel,
      'petMismatch'     : trips.expectedPetDelivered  - txPetDel,
    };
  }

  /// Remove the LedgerEntry for this transaction from Firebase.
  Future<void> _deleteLedger(String txId) async {
    await FirebaseService.instance.removeChild(FirebaseConfig.nodeLedgerEntries, 'le_$txId');
  }

  Future<void> add(JarTransaction tx) async {
    await FirebaseService.instance.setChild(FirebaseConfig.nodeTransactions, tx.id, tx.toJson());
    // Step 1: customer record — jar counts (coolOut/petOut) and payment balance updated
    //   balance formula: balance -= (billedAmount - amountCollected)
    //   e.g. bill=100 paid=60 → balance drops 40 (owes more)
    //        bill=0  paid=200 → balance rises 200 (credit applied)
    final updatedCust = _ref.read(customersProvider.notifier).applyTx(tx);
    // Step 2: inventory — stock adjusted for deliveries/returns/damage
    // FIX: was missing entirely — transactions never updated inventory stock.
    _ref.read(inventoryProvider.notifier).apply(tx);
    // Step 3: ledger entry — uses balance from step 1 directly (no re-read race condition)
    await _writeLedger(tx, updatedCust.balance);
    _ref.read(auditProvider.notifier).log(
      type: 'transaction_created',
      description: 'Transaction for ${tx.customerName}',
      entityId: tx.id,
      after: 'C↓${tx.coolDelivered} C↑${tx.coolReturned} P↓${tx.petDelivered} P↑${tx.petReturned} ₹${tx.billedAmount} paid:${tx.amountCollected}',
    );
  }

  Future<void> edit(JarTransaction old, JarTransaction neu, {String editNote = ''}) async {
    // Step 1: Snapshot old, build updated tx with history
    final history = TxEditHistory.from(old, editedBy: 'Admin', note: editNote);
    final neuWithHistory = neu.copyWith(
      editHistory: [history, ...old.editHistory],
      updatedAt: _now(),
    );
    // Base tx document updated (screens read from here)
    await FirebaseService.instance.setChild(
        FirebaseConfig.nodeTransactions, neu.id, neuWithHistory.toJson());

    // Step 2: Append new revision (old revisions kept — never overwritten)
    final revNumber = old.editHistory.length + 2;
    final rev = TransactionRevision.fromTransaction(neuWithHistory,
        revNumber: revNumber, isLatest: true,
        editedBy: 'Admin', editNote: editNote);
    await FirebaseService.instance.setChild(FirebaseConfig.nodeRevisions, rev.revId, rev.toJson());

    // Step 3: Customer atomic net-delta (no Firebase listener race)
    final updatedCust = _ref.read(customersProvider.notifier).applyTxEdit(old, neuWithHistory);

    // Step 4: Inventory net-delta for the edit (revert old, apply new)
    // FIX: was missing — a comment incorrectly said inventory is driven by trips only.
    _ref.read(inventoryProvider.notifier).edit(old, neuWithHistory, revId: rev.revId);

    // Step 5: Overwrite ledger entry with new data + balance
    await _writeLedger(neuWithHistory, updatedCust.balance);

    // Step 6: Update payment record if collection changed
    if (neu.amountCollected > 0) {
      final pmt = PaymentRecord.fromTransaction(neuWithHistory);
      await FirebaseService.instance.setChild(FirebaseConfig.nodePayments, pmt.paymentId, pmt.toJson());
    }

    _ref.read(auditProvider.notifier).log(
      type: 'transaction_edited',
      description: 'Ledger edited for ${neu.customerName}${editNote.isNotEmpty ? ": $editNote" : ""}',
      entityId: neu.id,
      before: 'C↓${old.coolDelivered} C↑${old.coolReturned} ₹${old.billedAmount} coll:${old.amountCollected}',
      after:  'C↓${neu.coolDelivered} C↑${neu.coolReturned} ₹${neu.billedAmount} coll:${neu.amountCollected}',
    );
  }

  Future<void> delete(JarTransaction tx) async {
    // Step 1: Remove base transaction document.
    // Revisions + inventory movements + payment records linked via txId
    // are intentionally KEPT — they form the permanent audit trail.
    await FirebaseService.instance.removeChild(FirebaseConfig.nodeTransactions, tx.id);

    // Step 2: Customer balance + jar counts rolled back atomically
    _ref.read(customersProvider.notifier).revertTx(tx);

    // Step 3: Inventory stock rolled back for the deleted transaction
    // FIX: was missing — deleting a transaction never restored stock.
    _ref.read(inventoryProvider.notifier).revert(tx);

    // Step 4: Remove ledger entry
    await _deleteLedger(tx.id);

    _ref.read(auditProvider.notifier).log(
      type: 'transaction_deleted',
      description: 'Deleted for ${tx.customerName} — revisions + movements retained',
      entityId: tx.id,
      before: 'C↓${tx.coolDelivered} C↑${tx.coolReturned} ₹${tx.billedAmount} coll:${tx.amountCollected}',
    );
  }
}
final transactionsProvider = StateNotifierProvider<TransactionsNotifier, List<JarTransaction>>((ref) => TransactionsNotifier(ref));

// ── Tab Management ──
final tabProvider = StateProvider<int>((ref) => 0);
final selectedCustomerForTxnProvider = StateProvider<Customer?>((ref) => null);

// ══════════════════════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════════════════════
// LOAD / UNLOAD MODEL + PROVIDER  (Firebase-backed)
// ══════════════════════════════════════════════════════════════════════════════

class TripEntry {
  final String id;
  final int    tripNumber;
  final String vehicleId;
  final String date;

  // ── Load ────────────────────────────────────────────────────────────────
  final int    coolLoaded;  // filled Cool jars put on truck (warehouse stock ↓)
  final int    petLoaded;   // filled PET  jars put on truck (warehouse stock ↓)
  final String loadTime;

  // ── Unload (split into two categories) ──────────────────────────────────
  final int?   coolEmptyReturned;   // empty Cool jars collected from customers
  final int?   petEmptyReturned;    // empty PET  jars collected from customers
  final int?   coolFilledReturned;  // full Cool jars not delivered (back to stock ↑)
  final int?   petFilledReturned;   // full PET  jars not delivered (back to stock ↑)
  final String? unloadTime;
  final String? driverNote;

  // ── Status ───────────────────────────────────────────────────────────────
  // 'pending'     = loaded, not yet returned
  // 'complete'    = returned, reconciliation matches customer transactions
  // 'discrepancy' = returned, but expected ≠ actual customer deliveries
  final String status;

  const TripEntry({
    required this.id, required this.tripNumber,
    required this.vehicleId, required this.date,
    required this.coolLoaded, required this.petLoaded,
    required this.loadTime,
    this.coolEmptyReturned, this.petEmptyReturned,
    this.coolFilledReturned, this.petFilledReturned,
    this.unloadTime, this.driverNote,
    this.status = 'pending',
  });

  // ── Derived ──────────────────────────────────────────────────────────────
  bool get isComplete => unloadTime != null;

  /// Total filled jars returned to warehouse stock
  int get coolUnloaded => coolFilledReturned ?? 0;
  int get petUnloaded  => petFilledReturned  ?? 0;

  /// Expected delivered to customers = loaded − (empty returned + filled returned)
  int get coolExpectedDelivered => isComplete
      ? (coolLoaded - (coolEmptyReturned ?? 0) - (coolFilledReturned ?? 0)).clamp(0, coolLoaded) : 0;
  int get petExpectedDelivered => isComplete
      ? (petLoaded  - (petEmptyReturned  ?? 0) - (petFilledReturned  ?? 0)).clamp(0, petLoaded)  : 0;

  /// Legacy aliases so existing screen code compiles unchanged
  int get coolDelivered => coolExpectedDelivered;
  int get petDelivered  => petExpectedDelivered;

  bool get hasMismatch => status == 'discrepancy';

  Map<String, dynamic> toJson() => {
    'id': id, 'tripNumber': tripNumber, 'vehicleId': vehicleId, 'date': date,
    'coolLoaded': coolLoaded, 'petLoaded': petLoaded, 'loadTime': loadTime,
    'coolEmptyReturned':  coolEmptyReturned,
    'petEmptyReturned':   petEmptyReturned,
    'coolFilledReturned': coolFilledReturned,
    'petFilledReturned':  petFilledReturned,
    // Legacy field names for backward compat with old Firebase records
    'coolUnloaded': coolFilledReturned,
    'petUnloaded':  petFilledReturned,
    'unloadTime': unloadTime, 'driverNote': driverNote, 'status': status,
  };

  factory TripEntry.fromJson(Map<String, dynamic> j) {
    final coolFilled = j['coolFilledReturned'] ?? j['coolUnloaded'];
    final petFilled  = j['petFilledReturned']  ?? j['petUnloaded'];
    return TripEntry(
      id:         j['id']?.toString() ?? '',
      tripNumber: j['tripNumber'] ?? 0,
      vehicleId:  j['vehicleId']?.toString() ?? '',
      date:       j['date']?.toString() ?? '',
      coolLoaded: j['coolLoaded'] ?? 0,
      petLoaded:  j['petLoaded']  ?? 0,
      loadTime:   j['loadTime']?.toString() ?? _now(),
      coolEmptyReturned:  j['coolEmptyReturned'],
      petEmptyReturned:   j['petEmptyReturned'],
      coolFilledReturned: coolFilled,
      petFilledReturned:  petFilled,
      unloadTime:  j['unloadTime']?.toString(),
      driverNote:  j['driverNote']?.toString(),
      status: j['status']?.toString() ?? (coolFilled != null ? 'complete' : 'pending'),
    );
  }

  TripEntry copyWithUnload({
    required int coolEmptyReturned, required int petEmptyReturned,
    required int coolFilledReturned, required int petFilledReturned,
    required String unloadTime, required String status,
    String? driverNote,
  }) => TripEntry(
    id: id, tripNumber: tripNumber, vehicleId: vehicleId, date: date,
    coolLoaded: coolLoaded, petLoaded: petLoaded, loadTime: loadTime,
    coolEmptyReturned: coolEmptyReturned,   petEmptyReturned: petEmptyReturned,
    coolFilledReturned: coolFilledReturned, petFilledReturned: petFilledReturned,
    unloadTime: unloadTime, driverNote: driverNote ?? this.driverNote, status: status,
  );
}

class LoadUnloadState {
  final List<TripEntry> trips;
  final String vehicleId;
  final String sessionDate;

  const LoadUnloadState({
    this.trips = const [],
    this.vehicleId = 'VH-01',
    required this.sessionDate,
  });

  List<TripEntry> get todayTrips {
    final list = trips.where((t) => t.date == sessionDate).toList();
    list.sort((a, b) => a.loadTime.compareTo(b.loadTime));
    return list;
  }

  bool get hasActiveTrip => todayTrips.any((t) => !t.isComplete);
  TripEntry? get activeTrip =>
      todayTrips.where((t) => !t.isComplete).isNotEmpty
          ? todayTrips.where((t) => !t.isComplete).last
          : null;

  int get totalCoolLoaded          => todayTrips.fold(0, (s, t) => s + t.coolLoaded);
  int get totalPetLoaded           => todayTrips.fold(0, (s, t) => s + t.petLoaded);
  int get totalCoolEmptyReturned   => todayTrips.fold(0, (s, t) => s + (t.coolEmptyReturned  ?? 0));
  int get totalPetEmptyReturned    => todayTrips.fold(0, (s, t) => s + (t.petEmptyReturned   ?? 0));
  int get totalCoolFilledReturned  => todayTrips.fold(0, (s, t) => s + (t.coolFilledReturned ?? 0));
  int get totalPetFilledReturned   => todayTrips.fold(0, (s, t) => s + (t.petFilledReturned  ?? 0));
  int get totalCoolUnloaded        => totalCoolFilledReturned;
  int get totalPetUnloaded         => totalPetFilledReturned;
  int get totalCoolDelivered       => todayTrips.fold(0, (s, t) => s + t.coolExpectedDelivered);
  int get totalPetDelivered        => todayTrips.fold(0, (s, t) => s + t.petExpectedDelivered);
  bool get hasMismatch             => todayTrips.any((t) => t.hasMismatch);
  int get pendingTripCount         => todayTrips.where((t) => t.status == 'pending').length;
  int get discrepancyCount         => todayTrips.where((t) => t.status == 'discrepancy').length;

  // ── Reconciliation getters ────────────────────────────────────────────────
  // "Expected delivered" = jars loaded onto truck − jars that came back.
  // Compare with sum of JarTransaction.coolDelivered for the same date.
  // If they match → the books are clean. Mismatch → missing or unrecorded jars.
  int get expectedCoolDelivered => totalCoolLoaded - totalCoolUnloaded;
  int get expectedPetDelivered  => totalPetLoaded  - totalPetUnloaded;

  LoadUnloadState copyWith({List<TripEntry>? trips, String? vehicleId}) =>
      LoadUnloadState(
        trips: trips ?? this.trips,
        vehicleId: vehicleId ?? this.vehicleId,
        sessionDate: sessionDate,
      );
}

class LoadUnloadNotifier extends StateNotifier<LoadUnloadState> {
  LoadUnloadNotifier() : super(LoadUnloadState(
    sessionDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
  )) {
    Future.microtask(_init);
  }

  StreamSubscription? _sub;

  void reinit() => _init();

  void _init() {
    _sub?.cancel();
    _sub = FirebaseService.instance.watch(FirebaseConfig.nodeLoadUnload).listen((data) {
      if (!mounted) return;
      if (data != null) {
        final trips = (data as Map).values
            .map((e) => TripEntry.fromJson(_castMap(e)))
            .toList();
        state = state.copyWith(trips: trips);
      } else {
        state = state.copyWith(trips: []);
      }
    });
  }

  void changeVehicle(String id) => state = state.copyWith(vehicleId: id);

  /// Load: filled jars leave warehouse onto truck → warehouse stock ↓.
  Future<void> recordLoad({required int cool, required int pet, WidgetRef? ref}) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final trip = TripEntry(
      id: _uuid.v4(),
      tripNumber: state.todayTrips.length + 1,
      coolLoaded: cool, petLoaded: pet,
      loadTime: _now(), vehicleId: state.vehicleId, date: today, status: 'pending',
    );
    await FirebaseService.instance.setChild(
        FirebaseConfig.nodeLoadUnload, trip.id, trip.toJson());
    // Inventory is not affected by load/unload — only JarTransactions update stock.
  }

  /// Unload: vehicle returns with empty jars (from customers) and/or filled jars (not delivered).
  ///   emptyReturned  = empty jars collected from customers  (tracked, no stock effect)
  ///   filledReturned = full jars not delivered              (returned to warehouse stock ↑)
  /// Auto-reconciles against today's customer transaction totals.
  Future<void> recordUnload({
    required String tripId,
    required int coolEmptyReturned,
    required int petEmptyReturned,
    required int coolFilledReturned,
    required int petFilledReturned,
    String? driverNote,
    WidgetRef? ref,
    int txCoolDelivered = 0,
    int txPetDelivered  = 0,
  }) async {
    final trip = state.trips.firstWhere((t) => t.id == tripId);
    final expCool = (trip.coolLoaded - coolEmptyReturned - coolFilledReturned).clamp(0, trip.coolLoaded);
    final expPet  = (trip.petLoaded  - petEmptyReturned  - petFilledReturned ).clamp(0, trip.petLoaded);
    final reconciled = expCool == txCoolDelivered && expPet == txPetDelivered;
    final status = reconciled ? 'complete' : 'discrepancy';
    final updated = trip.copyWithUnload(
      coolEmptyReturned: coolEmptyReturned, petEmptyReturned: petEmptyReturned,
      coolFilledReturned: coolFilledReturned, petFilledReturned: petFilledReturned,
      unloadTime: _now(), driverNote: driverNote, status: status,
    );
    await FirebaseService.instance.setChild(
        FirebaseConfig.nodeLoadUnload, trip.id, updated.toJson());
    // Inventory is not affected by load/unload — only JarTransactions update stock.
  }

  /// Admin override: correct a closed trip's return counts.
  /// Adjusts inventory for the delta between old and new values, then re-reconciles.
  Future<void> editTrip({
    required String tripId,
    required int coolEmptyReturned, required int petEmptyReturned,
    required int coolFilledReturned, required int petFilledReturned,
    required TripEntry oldTrip,
    String? adminNote,
    WidgetRef? ref,
    int txCoolDelivered = 0, int txPetDelivered = 0,
  }) async {
    // Re-compute status with corrected values
    final expCool = (oldTrip.coolLoaded - coolEmptyReturned - coolFilledReturned)
        .clamp(0, oldTrip.coolLoaded);
    final expPet  = (oldTrip.petLoaded  - petEmptyReturned  - petFilledReturned )
        .clamp(0, oldTrip.petLoaded);
    final reconciled = expCool == txCoolDelivered && expPet == txPetDelivered;
    final status = reconciled ? 'complete' : 'discrepancy';

    // Build corrected trip
    final corrected = oldTrip.copyWithUnload(
      coolEmptyReturned:  coolEmptyReturned,
      petEmptyReturned:   petEmptyReturned,
      coolFilledReturned: coolFilledReturned,
      petFilledReturned:  petFilledReturned,
      unloadTime: oldTrip.unloadTime ?? _now(),
      driverNote: adminNote ?? oldTrip.driverNote,
      status: status,
    );
    await FirebaseService.instance.setChild(
        FirebaseConfig.nodeLoadUnload, tripId, corrected.toJson());
    // Inventory is not affected by load/unload edits — only JarTransactions update stock.
  }

  /// History is NEVER deleted. Trips are permanent audit records.
  /// This marks all today's pending/in-progress trips as 'discrepancy' for review.
  Future<void> markDayReviewed() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final pending = state.trips
        .where((t) => t.date == today && t.status == 'pending').toList();
    for (final trip in pending) {
      await FirebaseService.instance.update(
        '${FirebaseConfig.nodeLoadUnload}/${trip.id}',
        {'status': 'discrepancy', 'reviewedAt': _now()},
      );
    }
  }
}

final loadUnloadProvider = StateNotifierProvider<LoadUnloadNotifier, LoadUnloadState>(
    (ref) => LoadUnloadNotifier());

// DAY LOG MODEL + PROVIDER
// ══════════════════════════════════════════════════════════════════════════════
// Simple cumulative day log. One document per day at load_unload/{date}.
// Load adds to loaded totals. Unload adds to return totals.
// No trip concept — just running totals for the day.
// ══════════════════════════════════════════════════════════════════════════════

class DayLog {
  final String date;
  final int coolLoaded;
  final int petLoaded;
  final int coolEmptyReturned;
  final int petEmptyReturned;
  final int coolFilledReturned;
  final int petFilledReturned;
  final String? note;

  const DayLog({
    required this.date,
    this.coolLoaded = 0, this.petLoaded = 0,
    this.coolEmptyReturned = 0, this.petEmptyReturned = 0,
    this.coolFilledReturned = 0, this.petFilledReturned = 0,
    this.note,
  });

  // Net delivered = loaded − (empty + filled returned)
  int get coolNetDelivered =>
      (coolLoaded - coolEmptyReturned - coolFilledReturned).clamp(0, coolLoaded);
  int get petNetDelivered  =>
      (petLoaded  - petEmptyReturned  - petFilledReturned ).clamp(0, petLoaded);

  Map<String, dynamic> toJson() => {
    'date': date,
    'coolLoaded': coolLoaded, 'petLoaded': petLoaded,
    'coolEmptyReturned': coolEmptyReturned, 'petEmptyReturned': petEmptyReturned,
    'coolFilledReturned': coolFilledReturned, 'petFilledReturned': petFilledReturned,
    'note': note,
    'updatedAt': _now(),
  };

  factory DayLog.fromJson(Map<String, dynamic> j) => DayLog(
    date: j['date']?.toString() ?? '',
    coolLoaded: j['coolLoaded'] ?? 0, petLoaded: j['petLoaded'] ?? 0,
    coolEmptyReturned:  j['coolEmptyReturned']  ?? 0,
    petEmptyReturned:   j['petEmptyReturned']   ?? 0,
    coolFilledReturned: j['coolFilledReturned'] ?? 0,
    petFilledReturned:  j['petFilledReturned']  ?? 0,
    note: j['note']?.toString(),
  );

  DayLog copyWith({
    int? coolLoaded, int? petLoaded,
    int? coolEmptyReturned, int? petEmptyReturned,
    int? coolFilledReturned, int? petFilledReturned,
    String? note,
  }) => DayLog(
    date: date,
    coolLoaded: coolLoaded ?? this.coolLoaded,
    petLoaded:  petLoaded  ?? this.petLoaded,
    coolEmptyReturned:  coolEmptyReturned  ?? this.coolEmptyReturned,
    petEmptyReturned:   petEmptyReturned   ?? this.petEmptyReturned,
    coolFilledReturned: coolFilledReturned ?? this.coolFilledReturned,
    petFilledReturned:  petFilledReturned  ?? this.petFilledReturned,
    note: note ?? this.note,
  );
}

class DayLogNotifier extends StateNotifier<List<DayLog>> {
  DayLogNotifier() : super([]) { Future.microtask(_init); }

  StreamSubscription? _sub;

  void reinit() { state = []; _init(); }

  void _init() {
    _sub?.cancel();
    _sub = FirebaseService.instance.watch(FirebaseConfig.nodeLoadUnload).listen((data) {
      if (!mounted) return;
      if (data == null) { state = []; return; }
      final logs = <DayLog>[];
      for (final entry in data.values) {
        try { logs.add(DayLog.fromJson(_castMap(entry))); }
        catch (_) {}
      }
      logs.sort((a, b) => b.date.compareTo(a.date));
      state = logs;
    });
  }

  DayLog? get todayLog {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try { return state.firstWhere((d) => d.date == today); }
    catch (_) { return null; }
  }

  /// Add jars to today's load total (cumulative)
  Future<void> addLoad({required int cool, required int pet}) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final existing = todayLog ?? DayLog(date: today);
    final updated = existing.copyWith(
      coolLoaded: existing.coolLoaded + cool,
      petLoaded:  existing.petLoaded  + pet,
    );
    await FirebaseService.instance.setChild(
        FirebaseConfig.nodeLoadUnload, today, updated.toJson());
    // Inventory: filled jars leave warehouse
    // (called from screen via ref — not here to avoid circular dep)
  }

  /// Add jars to today's unload totals (cumulative)
  Future<void> addUnload({
    required int coolEmpty, required int petEmpty,
    required int coolFilled, required int petFilled,
  }) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final existing = todayLog ?? DayLog(date: today);
    final updated = existing.copyWith(
      coolEmptyReturned:  existing.coolEmptyReturned  + coolEmpty,
      petEmptyReturned:   existing.petEmptyReturned   + petEmpty,
      coolFilledReturned: existing.coolFilledReturned + coolFilled,
      petFilledReturned:  existing.petFilledReturned  + petFilled,
    );
    await FirebaseService.instance.setChild(
        FirebaseConfig.nodeLoadUnload, today, updated.toJson());
  }

  /// Owner override: set exact values for today (not additive)
  Future<void> setExact({
    required int coolLoaded, required int petLoaded,
    required int coolEmpty, required int petEmpty,
    required int coolFilled, required int petFilled,
    String? note,
  }) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final updated = DayLog(
      date: today,
      coolLoaded: coolLoaded, petLoaded: petLoaded,
      coolEmptyReturned: coolEmpty, petEmptyReturned: petEmpty,
      coolFilledReturned: coolFilled, petFilledReturned: petFilled,
      note: note,
    );
    await FirebaseService.instance.setChild(
        FirebaseConfig.nodeLoadUnload, today, updated.toJson());
  }
}

final dayLogProvider = StateNotifierProvider<DayLogNotifier, List<DayLog>>(
    (ref) => DayLogNotifier());

// STAFF  MODEL + PROVIDER
// ══════════════════════════════════════════════════════════════════════════════

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

class StaffNotifier extends StateNotifier<List<StaffMember>> {
  StaffNotifier() : super([]) { Future.microtask(_init); }

  StreamSubscription? _sub;

  void _init() {
    _sub?.cancel();
    if (CompanySession.companyId.isEmpty) {
      state = [];
      return;
    }

    _sub = RTDBUserDataSource.instance
        .watchUsers(CompanySession.companyId)
        .listen((documents) {
      if (!mounted) return;
      state = documents.map((e) => StaffMember.fromJson(_castMap(e))).toList();
    });
  }

  void reinit() => _init();

  Future<void> add(StaffMember s) async {
    await RTDBUserDataSource.instance.setUser(
        CompanySession.companyId, s.id, s.toJson());
  }

  Future<void> update(StaffMember s) async {
    await RTDBUserDataSource.instance.updateUser(
        CompanySession.companyId, s.id, s.toJson());
  }

  Future<void> remove(String id) async {
    await RTDBUserDataSource.instance.deleteUser(
        CompanySession.companyId, id);
  }

  StaffMember? byPin(String pin) {
    try {
      return state.firstWhere((s) => s.pin == pin && s.isActive);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final staffProvider = StateNotifierProvider<StaffNotifier, List<StaffMember>>(
    (ref) => StaffNotifier());

// Current session: null = owner, non-null = logged-in staff member
final sessionUserProvider = StateProvider<StaffMember?>((ref) => null);

// Firebase Auth state: emits current Firebase user (null if not logged in)
final authStateProvider = StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

// Global flag to indicate if the user has passed the PIN screen
final pinUnlockedProvider = StateProvider<bool>((ref) => false);

// ── Inactivity auto-lock provider ─────────────────────────────────────────────
// Tracks the last user-activity timestamp.  SessionManager polls this every
// 30 s and locks the app when idle > kInactivityTimeout (5 min).
// Call: ref.read(lastActivityProvider.notifier).state = DateTime.now()
// on every meaningful user interaction, OR use the ActivityDetector wrapper.
final lastActivityProvider = StateProvider<DateTime>((ref) => DateTime.now());
